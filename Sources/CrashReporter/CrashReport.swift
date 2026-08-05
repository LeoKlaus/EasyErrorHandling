#if os(iOS) || os(macOS)
import Foundation

/// A crash report captured by a `CrashReporterExtension` (iOS 27+) and persisted to disk for the
/// host app to pick up on its next launch, rather than sending it anywhere.
///
/// Deliberately independent of `CrashReportExtension`'s own types (`SymbolicatedFrame`,
/// `BinaryImageInfo`) rather than reusing them directly — those require iOS 27, and gating every
/// place a host app reads a stored report behind that availability check would ripple through its
/// own UI code for no benefit. `CrashReporter.handle(process:appGroupIdentifier:)` (which does
/// require iOS 27) is the one place that translates from the OS-provided types into this plain,
/// stable format.
public struct CrashReport: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    /// Human-readable exception type + codes (e.g. "EXC_BAD_ACCESS (codes: 0x1, 0x0)") — kept as
    /// a summary rather than the raw exception fields, since interpreting Mach exception codes
    /// meaningfully needs the same domain knowledge a full symbolicating crash reporter would.
    public let exceptionName: String
    /// One entry per thread that could be walked, closest-to-crash frame first. Usually just the
    /// crashed thread, but a hang/watchdog-style report can have several.
    public let threads: [CrashThreadReport]
    /// "path (uuid)" per loaded binary image, for matching against dSYMs later if ever needed.
    public let binaryImages: [String]

    public init(id: UUID, date: Date, exceptionName: String, threads: [CrashThreadReport], binaryImages: [String]) {
        self.id = id
        self.date = date
        self.exceptionName = exceptionName
        self.threads = threads
        self.binaryImages = binaryImages
    }

    /// The closest-to-crash symbolicated frame across all threads, if any — this is what actually
    /// tells you "what crashed and where," so it leads both the one-line list-row summary and
    /// `formattedText`, ahead of the raw Mach exception name.
    public var topFrame: String? {
        self.threads.first(where: { !$0.frames.isEmpty })?.frames.first
    }

    /// One-line summary for list rows: the top frame when available, otherwise the bare
    /// exception name (e.g. no thread could be walked).
    public var exceptionSummary: String {
        self.topFrame ?? self.exceptionName
    }

    /// A plain-text rendering suitable for `ShareLink` — the on-disk format is JSON (simple,
    /// robust), but that's not pleasant to read once shared over Messages/Mail/etc.
    public var formattedText: String {
        var lines = ["Crash report", self.date.formatted(date: .abbreviated, time: .standard), "", self.exceptionName]
        for thread in self.threads {
            lines.append("")
            lines.append("Thread \(thread.index)\(thread.index == 0 ? " (likely crashed)" : ""):")
            if thread.frames.isEmpty {
                lines.append("  <no frames>")
            } else {
                for (frameIndex, frame) in thread.frames.enumerated() {
                    lines.append("  \(frameIndex)  \(frame)")
                }
            }
        }
        if !self.binaryImages.isEmpty {
            lines.append("")
            lines.append("Binary images:")
            lines.append(contentsOf: self.binaryImages.map { "  \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

/// A single thread's symbolicated backtrace, closest-to-crash frame first.
public struct CrashThreadReport: Codable, Hashable, Sendable {
    public let index: Int
    public let frames: [String]

    public init(index: Int, frames: [String]) {
        self.index = index
        self.frames = frames
    }
}
#endif
