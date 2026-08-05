#if os(iOS) || os(macOS)
import CrashReportExtension
import Foundation
import os

/// Entry point for a host app's `CrashReporterExtension` — does the actual work of turning a
/// `CrashedProcess` into a persisted `CrashReport` (plus a best-effort `.ips` sibling), so the
/// extension target itself only needs a few lines:
///
/// ```swift
/// import CrashReportExtension
/// import CrashReporter
/// import ExtensionFoundation
///
/// @main
/// struct crash_handler: CrashReporterExtension {
///     func processCrashReport(process: CrashedProcess) {
///         CrashReporter.handle(
///             process: process,
///             appGroupIdentifier: "group.com.example.myapp",
///             hostBundleIdentifier: "com.example.myapp"
///         )
///     }
/// }
/// ```
///
/// An App Extension target is unavoidable per host app — Swift Package Manager can't produce an
/// `.appex` itself — but that's the only piece that can't be shared.
@available(iOS 27, macOS 27, *)
public enum CrashReporter {
    private static let logger = Logger(subsystem: "CrashReporter", category: "CrashReporter")

    /// - Parameters:
    ///   - process: The value handed to `CrashReporterExtension.processCrashReport(process:)`.
    ///   - appGroupIdentifier: The App Group the host app and this extension both belong to —
    ///     where the report (and its `.ips` sibling) get written for the host app to read on its
    ///     next launch via `CrashReportStore`/`CrashReportsSection`.
    ///   - hostBundleIdentifier: The host app's own bundle identifier. Not derivable from inside
    ///     the extension process in a way that's safe to assume across different apps' target
    ///     naming conventions, so the caller states it directly.
    public static func handle(process: CrashedProcess, appGroupIdentifier: String, hostBundleIdentifier: String) {
        var threadSnapshots = CrashStackWalker.walkAllThreads(in: process.corpsePort)
        var threadReports = threadSnapshots.enumerated().map { index, snapshot in
            CrashThreadReport(index: index, frames: Self.describe(addresses: snapshot.addresses, in: process))
        }

        // Stack walking can come back completely empty (e.g. task_threads/thread_get_state
        // failed, or every frame-pointer chain was unreadable from the very first frame) — fall
        // back to symbolicating the raw exception codes, since for exceptions like EXC_BAD_ACCESS
        // one of those is documented to carry the faulting address. Better than an empty report
        // even though it's not a real backtrace.
        if threadSnapshots.isEmpty {
            let fallbackAddresses = process.reason.codes
            let fallbackFrames = Self.describe(addresses: fallbackAddresses, in: process)
            if !fallbackFrames.isEmpty {
                threadSnapshots = [
                    ThreadSnapshot(addresses: fallbackAddresses, generalRegisters: [], fp: 0, lr: 0, sp: 0, pc: 0, cpsr: 0),
                ]
                threadReports = [CrashThreadReport(index: 0, frames: fallbackFrames)]
            }
        }

        // Only the images actually referenced by a collected address, not every one of the
        // hundreds of dyld shared-cache libraries loaded into a typical process — otherwise this
        // list dwarfs the actual backtrace and defeats the point of making reports readable.
        let referencedImages = CrashStackWalker.binaryImages(
            containing: threadSnapshots.flatMap { $0.addresses },
            in: process.binaryImages
        )

        let id = UUID()
        let date = Date.now
        let report = CrashReport(
            id: id,
            date: date,
            exceptionName: Self.describe(process.reason),
            threads: threadReports,
            binaryImages: referencedImages.map(Self.describe)
        )
        CrashReportStore.save(report, appGroupIdentifier: appGroupIdentifier)

        let ipsData = IPSReportBuilder.build(
            process: process,
            threadSnapshots: threadSnapshots,
            images: referencedImages,
            exceptionTypeName: Self.exceptionName(process.reason.exception),
            hostBundleIdentifier: hostBundleIdentifier,
            incidentID: id,
            date: date
        )
        CrashReportStore.saveIPS(ipsData, for: id, appGroupIdentifier: appGroupIdentifier)

        Self.logger.info("Saved crash report \(id, privacy: .public) — \(threadReports.count, privacy: .public) thread(s)")
    }

    // MARK: - Formatting

    /// Symbolicates a sequence of addresses into display lines, closest-to-crash first — one or
    /// more lines per address (an inlined call chain resolves to several `SymbolicatedFrame`s at
    /// the same address). Every input address is guaranteed to produce at least one line: when
    /// `symbolicateAddresses` finds no symbol for an address (a system library with no dSYM, a
    /// stripped binary), the address would otherwise just silently vanish from the backtrace —
    /// instead it falls back to `describe(unresolvedAddress:in:)`. Every line, resolved or not, is
    /// prefixed with its owning image's name — without that, `CrashReport.binaryImages` is a list
    /// nothing else in the report points back to, and there's no way to tell app code from system
    /// frameworks at a glance.
    private static func describe(addresses: [UInt64], in process: CrashedProcess) -> [String] {
        guard !addresses.isEmpty else { return [] }
        var perAddressFrames = process.symbolicateAddresses(addresses)
        if perAddressFrames.count != addresses.count {
            // Defensive: `symbolicateAddresses` is documented to return one entry per input
            // address, but if that batch ordering ever doesn't line up, falling back to
            // symbolicating one address at a time keeps frames from silently misaligning.
            perAddressFrames = addresses.map { process.symbolicateAddress($0) }
        }
        var lines: [String] = []
        for (address, frames) in zip(addresses, perAddressFrames) {
            let image = CrashStackWalker.image(containing: address, in: process.binaryImages)
            if frames.isEmpty {
                lines.append(Self.describe(unresolvedAddress: address, in: image))
            } else {
                lines.append(contentsOf: frames.map { Self.describe($0, in: image) })
            }
        }
        return lines
    }

    /// "ImageName: 0xoffset" for an address that couldn't be symbolicated but does fall inside a
    /// known loaded image — the same fallback Apple's own crash logs use for unresolved frames.
    /// Falls back further to a bare address if the address doesn't land in any loaded image at
    /// all (a corrupted frame-pointer chain wandered off into unmapped memory).
    private static func describe(unresolvedAddress address: UInt64, in image: BinaryImageInfo?) -> String {
        guard let image else { return "0x\(String(address, radix: 16))" }
        let offset = address - image.baseAddress
        return "\(Self.imageName(image)): 0x\(String(offset, radix: 16))"
    }

    private static func imageName(_ image: BinaryImageInfo) -> String {
        (image.path as NSString).lastPathComponent
    }

    private static func describe(_ reason: CrashReason) -> String {
        let codesText = reason.codes.map { "0x\(String($0, radix: 16))" }.joined(separator: ", ")
        return "\(self.exceptionName(reason.exception)) (codes: \(codesText))"
    }

    private static func exceptionName(_ exception: Int32) -> String {
        switch exception {
        case EXC_BAD_ACCESS: "EXC_BAD_ACCESS"
        case EXC_BAD_INSTRUCTION: "EXC_BAD_INSTRUCTION"
        case EXC_ARITHMETIC: "EXC_ARITHMETIC"
        case EXC_EMULATION: "EXC_EMULATION"
        case EXC_SOFTWARE: "EXC_SOFTWARE"
        case EXC_BREAKPOINT: "EXC_BREAKPOINT"
        case EXC_SYSCALL: "EXC_SYSCALL"
        case EXC_MACH_SYSCALL: "EXC_MACH_SYSCALL"
        case EXC_RPC_ALERT: "EXC_RPC_ALERT"
        case EXC_CRASH: "EXC_CRASH"
        case EXC_RESOURCE: "EXC_RESOURCE"
        case EXC_GUARD: "EXC_GUARD"
        case EXC_CORPSE_NOTIFY: "EXC_CORPSE_NOTIFY"
        default: "Unknown exception (\(exception))"
        }
    }

    private static func describe(_ frame: SymbolicatedFrame, in image: BinaryImageInfo?) -> String {
        var text = image.map { "\(Self.imageName($0)): " } ?? ""
        text += frame.symbol
        if frame.symbolOffset > 0 {
            text += " + \(frame.symbolOffset)"
        }
        if let sourceFile = frame.sourceFile {
            text += frame.sourceLine.map { " (\(sourceFile):\($0))" } ?? " (\(sourceFile))"
        }
        if frame.isInline {
            text += " [inlined]"
        }
        return text
    }

    private static func describe(_ image: BinaryImageInfo) -> String {
        "\(image.path) (\(image.uuid?.uuidString ?? "no uuid"))"
    }
}
#endif
