#if os(iOS) || os(macOS)
import CrashReportExtension
import Foundation

/// Builds a best-effort Apple `.ips` crash report — the two-part JSON format Console.app and
/// Xcode's Organizer read — from the same data `CrashStackWalker` already collects.
///
/// The format isn't officially documented by Apple; this is reconstructed by diffing against a
/// real macOS-generated `.ips` (`~/Library/Logs/DiagnosticReports`). Several fields that report
/// has simply aren't obtainable through `CrashReportExtension`'s API at all — code-signing
/// details, parent process, boot/wake session UUIDs, `esr`/`far` (which need a second
/// `thread_get_state` call with a different flavor this codebase doesn't make) — those are
/// omitted rather than faked. Fields that data already in hand can support (`version`, per-thread
/// general-purpose registers, `exception.signal`, `termination`) are included.
///
/// Xcode's own crash-report viewer has been observed failing to render the detailed frame view
/// for a report built this way (`IDEKit.IDECrashReportGeneratedContentProvider.CrashReportError`,
/// no further detail) even once the outer thread list parses correctly — that's an internal,
/// undocumented Xcode code path with no public spec, and not something this builder can reliably
/// target further. Console.app and Xcode's outer thread/frame list both work; full Xcode-native
/// re-symbolication may not.
@available(iOS 27, macOS 27, *)
enum IPSReportBuilder {
    static func build(
        process: CrashedProcess,
        threadSnapshots: [ThreadSnapshot],
        images: [BinaryImageInfo],
        exceptionTypeName: String,
        hostBundleIdentifier: String,
        incidentID: UUID,
        date: Date
    ) -> Data {
        let mainImage = Self.mainExecutableImage(in: images)
        let procName = mainImage.map { ($0.path as NSString).lastPathComponent } ?? hostBundleIdentifier
        let procPath = mainImage?.path ?? ""

        let usedImages: [[String: Any]] = images.map { image in
            [
                "source": "P",
                "arch": Self.archName(for: image),
                "base": image.baseAddress,
                "size": image.size,
                "uuid": image.uuid?.uuidString.lowercased() ?? "00000000-0000-0000-0000-000000000000",
                "path": image.path,
                "name": (image.path as NSString).lastPathComponent,
            ]
        }

        let signal = Self.signalName(for: process.reason.exception)

        let threads: [[String: Any]] = threadSnapshots.enumerated().map { threadIndex, snapshot in
            var thread: [String: Any] = [
                "id": threadIndex,
                // Best-effort, not a guarantee: `CrashedProcess` doesn't tell us which thread
                // actually raised the exception, so thread 0 (task_threads' own enumeration
                // order) is treated as the likely-crashed one, same convention the plain-text
                // report uses.
                "triggered": threadIndex == 0,
                "frames": Self.frames(for: snapshot.addresses, process: process, images: images),
            ]
            if !snapshot.generalRegisters.isEmpty {
                thread["threadState"] = [
                    // Raw UInt64/UInt32, not Int(...): general-purpose registers hold whatever
                    // arbitrary data the crashed code last put there, not necessarily a valid
                    // pointer — a value with the high bit set (a Debug-build memory-poison
                    // pattern like 0xAAAA..., a negative number's bit pattern, a large counter)
                    // exceeds Int64.max and Int(_:) traps on overflow. That trap would crash the
                    // extension mid-build, silently losing the .ips with no error surfaced
                    // anywhere.
                    "x": snapshot.generalRegisters.map { ["value": $0] },
                    "flavor": "ARM_THREAD_STATE64",
                    "fp": ["value": snapshot.fp],
                    "lr": ["value": snapshot.lr],
                    "sp": ["value": snapshot.sp],
                    "pc": ["value": snapshot.pc],
                    "cpsr": ["value": snapshot.cpsr],
                ]
            }
            return thread
        }

        let timestamp = Self.formattedTimestamp(date)

        let header: [String: Any] = [
            "app_name": procName,
            "timestamp": timestamp,
            "slice_uuid": mainImage?.uuid?.uuidString.lowercased() ?? "00000000-0000-0000-0000-000000000000",
            "platform": 2, // best-effort: 2 is the commonly-documented code for iOS
            "bundleID": hostBundleIdentifier,
            "share_with_app_devs": 0,
            "is_first_party": 0,
            "bug_type": "309", // ReportCrash's standard "Crash" bug type
            "os_version": "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "roots_installed": 0,
            "incident_id": incidentID.uuidString,
            "name": procName,
        ]

        let body: [String: Any] = [
            // A real macOS-generated .ips carries this at the top of its body — likely a format
            // discriminator the consuming parser checks before anything else, so a file missing
            // it may simply be silently ignored rather than shown with an error.
            "version": 2,
            "captureTime": timestamp,
            "incident": incidentID.uuidString,
            "pid": 0, // not exposed by CrashedProcess
            "procRole": "Foreground", // best-effort: assumes the host app is normally frontmost
            "userID": 501, // standard "mobile" UID on a real iOS device
            "cpuType": "ARM-64",
            "procName": procName,
            "procPath": procPath,
            "bundleInfo": ["CFBundleIdentifier": hostBundleIdentifier],
            "exception": [
                "type": exceptionTypeName,
                "codes": process.reason.codes.map { "0x\(String($0, radix: 16))" }.joined(separator: ", "),
                "rawCodes": process.reason.codes,
                "signal": signal,
            ],
            "termination": [
                "namespace": "SIGNAL",
                "indicator": signal,
                "byProc": procName,
            ],
            "os_fault": ["process": procName],
            "faultingThread": 0,
            "threads": threads,
            "usedImages": usedImages,
        ]

        var data = (try? JSONSerialization.data(withJSONObject: header)) ?? Data()
        data.append(0x0A)
        data.append((try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])) ?? Data())
        return data
    }

    /// A loaded image is treated as the crashed process's own main executable when its path ends
    /// in `<something>.app/<name>` with no further path components — matches the app's own
    /// binary but not an embedded framework (`.app/Frameworks/Foo.framework/Foo` has more path
    /// segments after `.app/`).
    ///
    /// Xcode's Debug-only "debug dylib" build acceleration loads the app's real code from a
    /// `<name>.debug.dylib` sitting next to a thin executable stub — both match the pattern
    /// above, but only the stub is a genuine, launchable Mach-O executable (`.dylib` isn't).
    /// Prefer any non-dylib match; fall back to the dylib only if it's truly the sole candidate
    /// (e.g. no frame in this particular crash ever touched the stub — common, since the stub
    /// does nothing but load the dylib and never runs any other code).
    private static func mainExecutableImage(in images: [BinaryImageInfo]) -> BinaryImageInfo? {
        let candidates = images.filter { $0.path.range(of: #"\.app/[^/]+$"#, options: .regularExpression) != nil }
        return candidates.first { !$0.path.hasSuffix(".debug.dylib") } ?? candidates.first
    }

    /// `CPU_TYPE_ARM64`/`CPU_SUBTYPE_ARM64E` are stable, well-known Mach constants (unlike most of
    /// what this file guesses at) — `BinaryImageInfo` already carries the real value per image, so
    /// there's no reason to hardcode a single architecture string for every image.
    private static func archName(for image: BinaryImageInfo) -> String {
        guard Int32(image.cpuType) == CPU_TYPE_ARM64 else { return "unknown" }
        return Int32(image.cpuSubType) == CPU_SUBTYPE_ARM64E ? "arm64e" : "arm64"
    }

    /// Best-effort Mach exception → POSIX signal name, matching the convention real crash reports
    /// use in `exception.signal`/`termination.indicator`.
    private static func signalName(for exception: Int32) -> String {
        switch exception {
        case EXC_BAD_ACCESS: "SIGSEGV"
        case EXC_BAD_INSTRUCTION: "SIGILL"
        case EXC_ARITHMETIC: "SIGFPE"
        case EXC_SOFTWARE: "SIGABRT"
        case EXC_BREAKPOINT: "SIGTRAP"
        case EXC_CRASH: "SIGABRT"
        default: "SIGKILL"
        }
    }

    /// Index of the most specific loaded image containing `address` — mirrors
    /// `CrashStackWalker.image(containing:in:)`'s tightest-match strategy: when several images'
    /// ranges all claim to contain an address (observed for the dyld shared cache, where
    /// `libobjc.A.dylib` reported bounds broad enough to swallow addresses that actually belong
    /// to UIKitCore/CoreFoundation/libdispatch/etc.), the smallest matching range wins rather
    /// than just the first one in the array.
    private static func imageIndex(containing address: UInt64, in images: [BinaryImageInfo]) -> Int? {
        images.indices
            .filter { address >= images[$0].baseAddress && address < images[$0].baseAddress + images[$0].size }
            .min { images[$0].size < images[$1].size }
    }

    private static func frames(for addresses: [UInt64], process: CrashedProcess, images: [BinaryImageInfo]) -> [[String: Any]] {
        guard !addresses.isEmpty else { return [] }
        var perAddressFrames = process.symbolicateAddresses(addresses)
        if perAddressFrames.count != addresses.count {
            perAddressFrames = addresses.map { process.symbolicateAddress($0) }
        }
        return zip(addresses, perAddressFrames).map { address, symbolicated in
            var frame: [String: Any] = [:]
            if let imageIndex = Self.imageIndex(containing: address, in: images) {
                frame["imageIndex"] = imageIndex
                frame["imageOffset"] = address - images[imageIndex].baseAddress
            } else {
                frame["imageIndex"] = -1
                frame["imageOffset"] = 0
            }
            // Only the first symbol at this address (an inlined chain collapses to one frame
            // here) — Xcode's own re-symbolication against a dSYM is what recovers the full
            // inline chain properly; this is just what's opportunistically already known.
            if let symbol = symbolicated.first {
                frame["symbol"] = symbol.symbol
                frame["symbolLocation"] = symbol.symbolOffset
            }
            return frame
        }
    }

    private static func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS Z"
        return formatter.string(from: date)
    }
}
#endif
