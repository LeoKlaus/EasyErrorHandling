#if os(iOS) || os(macOS)
import CrashReporterShims
import CrashReportExtension
import Darwin.Mach
import Foundation

/// One thread's walked backtrace plus the raw register snapshot `thread_get_state` handed back —
/// captured together since both come from the same `arm_thread_state64_t` read and
/// `IPSReportBuilder` needs the registers for `.ips`'s `threadState` block, not just the
/// addresses.
@available(iOS 27, macOS 27, *)
struct ThreadSnapshot {
    let addresses: [UInt64]
    /// x0...x28, in order.
    let generalRegisters: [UInt64]
    let fp: UInt64
    let lr: UInt64
    let sp: UInt64
    let pc: UInt64
    let cpsr: UInt32
}

/// `CrashedProcess` only exposes `reason` (the Mach exception type/codes), `binaryImages`, and
/// `symbolicateAddress(es)` — it doesn't hand you an unwound call stack, only a way to turn
/// addresses *you already have* into symbols. Getting real frames means walking the crashed
/// process's threads via lower-level Mach calls against `process.corpsePort`
/// (`task_threads`/`thread_get_state`/`vm_read_overwrite`, all against the corpse — a frozen,
/// read-only snapshot of the crashed process, safe to inspect from here). `vm_read_overwrite`
/// rather than the 64-bit `mach_vm_*` family — `<mach/mach_vm.h>` is explicitly blocked on iOS
/// (`#error mach_vm.h unsupported`); the legacy `vm_*` calls in `<mach/vm_map.h>` take the same
/// 64-bit-wide `vm_address_t`/`vm_size_t` on arm64 and aren't blocked. See `CrashReporterShims`
/// for why PC/LR/FP/SP can't just be read off the raw register struct on arm64e devices.
@available(iOS 27, macOS 27, *)
enum CrashStackWalker {
    /// Enumerates the corpse's threads and walks each one's frame-pointer chain. Bounded on both
    /// axes (threads and frames per thread) since a corrupted chain could otherwise loop or run
    /// away, and this must never itself hang or crash.
    static func walkAllThreads(in task: mach_port_t, maxThreads: Int = 8) -> [ThreadSnapshot] {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(task, &threadList, &threadCount) == KERN_SUCCESS, let threadList else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }

        var results: [ThreadSnapshot] = []
        for i in 0..<min(Int(threadCount), maxThreads) {
            if let snapshot = self.backtrace(for: threadList[i], in: task) {
                results.append(snapshot)
            }
        }
        return results
    }

    /// Walks a single thread's frame-pointer chain: start at PC, then repeatedly read the saved
    /// [frame pointer, return address] pair pointed to by the current frame pointer. Relies on
    /// arm64's standard FP-chaining ABI (every non-leaf function preserves the caller's FP), which
    /// is what makes this approach viable without full DWARF unwind info.
    private static func backtrace(for thread: thread_t, in task: mach_port_t, maxFrames: Int = 64) -> ThreadSnapshot? {
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &state) { statePointer -> kern_return_t in
            statePointer.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { rebound in
                thread_get_state(thread, thread_state_flavor_t(ARM_THREAD_STATE64), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pc = CrashReporterGetPC(state)
        var addresses: [UInt64] = [pc]
        var framePointer = CrashReporterGetFP(state)
        var previousFramePointer: UInt64 = 0
        for _ in 0..<maxFrames {
            // The stack grows down; a well-formed chain always moves to a strictly higher
            // address, which also protects against looping on a corrupted chain.
            guard framePointer != 0, framePointer > previousFramePointer else { break }

            var savedPair = [UInt64](repeating: 0, count: 2)
            var bytesRead: vm_size_t = 0
            let readResult = savedPair.withUnsafeMutableBytes { buffer -> kern_return_t in
                vm_read_overwrite(
                    task,
                    vm_address_t(framePointer),
                    vm_size_t(MemoryLayout<UInt64>.size * 2),
                    vm_address_t(UInt(bitPattern: buffer.baseAddress)),
                    &bytesRead
                )
            }
            guard readResult == KERN_SUCCESS, bytesRead == vm_size_t(MemoryLayout<UInt64>.size * 2) else { break }

            let savedReturnAddress = savedPair[1]
            guard savedReturnAddress != 0 else { break }
            addresses.append(savedReturnAddress)
            previousFramePointer = framePointer
            framePointer = savedPair[0]
        }

        // `__x` (x0...x28) is a plain C fixed-size array, imported by Swift as a 29-element tuple
        // — `withUnsafeBytes` reinterprets its contiguous storage as `[UInt64]` without needing
        // any of the PAC-stripping the shim provides for pc/lr/fp/sp specifically
        // (general-purpose registers aren't code/data pointers subject to pointer authentication).
        let generalRegisters = withUnsafeBytes(of: state.__x) { Array($0.bindMemory(to: UInt64.self)) }

        return ThreadSnapshot(
            addresses: addresses,
            generalRegisters: generalRegisters,
            fp: CrashReporterGetFP(state),
            lr: CrashReporterGetLR(state),
            sp: CrashReporterGetSP(state),
            pc: pc,
            cpsr: state.__cpsr
        )
    }

    /// The most specific loaded image containing `address` — when several images' ranges all
    /// claim to contain it, prefers the smallest (tightest) one rather than just the first match.
    /// Needed for addresses inside the dyld shared cache: UIKitCore, CoreFoundation, libdispatch,
    /// libobjc, and the libsystem_* libraries are all sub-ranges of one giant shared mapping, and
    /// at least one of them (observed: `libobjc.A.dylib`) reports a `baseAddress`/`size` broad
    /// enough to swallow addresses that actually belong to a different, more specific image —
    /// taking the first match alone mislabels essentially every system-framework frame as
    /// whichever over-broad image happens to be enumerated first.
    static func image(containing address: UInt64, in images: [BinaryImageInfo]) -> BinaryImageInfo? {
        images
            .filter { address >= $0.baseAddress && address < $0.baseAddress + $0.size }
            .min { $0.size < $1.size }
    }

    /// Narrows the full loaded-image list down to only the images that actually contain one of
    /// the given addresses — a typical process has hundreds of loaded dyld shared-cache images,
    /// nearly all irrelevant to any single crash.
    static func binaryImages(containing addresses: [UInt64], in images: [BinaryImageInfo]) -> [BinaryImageInfo] {
        guard !addresses.isEmpty else { return [] }
        return images.filter { image in
            addresses.contains { $0 >= image.baseAddress && $0 < image.baseAddress + image.size }
        }
    }
}
#endif
