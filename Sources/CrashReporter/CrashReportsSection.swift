#if os(iOS) || os(macOS)
import SwiftUI

/// A drop-in `Section` listing persisted `CrashReport`s for a host app — reads via
/// `CrashReportStore`, so it works regardless of whether the crash-generating extension is
/// present or has ever run (an app with no crashes yet just shows the empty state). Meant to be
/// placed directly inside a `List`, mirroring `ExportLogsButton`'s drop-in usage:
///
/// ```swift
/// List {
///     CrashReportsSection(appGroupIdentifier: "group.com.example.myapp")
/// }
/// ```
///
/// Every piece of user-visible text is a `LocalizedStringResource` parameter with a sensible
/// default, so a host app can either accept the defaults or fully localize/rebrand them without
/// needing this package's own string catalog.
public struct CrashReportsSection: View {
    let appGroupIdentifier: String
    let header: LocalizedStringResource
    let footer: LocalizedStringResource
    let emptyStateText: LocalizedStringResource
    let shareActionText: LocalizedStringResource
    let deleteActionText: LocalizedStringResource

    @State private var reports: [CrashReport]

    private static let dateFormat = Date.FormatStyle(date: .abbreviated, time: .standard)

    /**
     - Parameters:
       - appGroupIdentifier: The App Group the host app and its `CrashReporterExtension` both
         belong to — must match what was passed to `CrashReporter.handle(process:appGroupIdentifier:hostBundleIdentifier:)`.
       - header: Section header text.
       - footer: Section footer text.
       - emptyStateText: Shown in place of the list when no reports have been captured yet.
       - shareActionText: Label for each report's "share as plain text" menu action.
       - deleteActionText: Label for each report's "delete" menu action.
     */
    public init(
        appGroupIdentifier: String,
        header: LocalizedStringResource = LocalizedStringResource("Crash reports"),
        footer: LocalizedStringResource = LocalizedStringResource(
            "Captured automatically the next time the app launches after a crash. Reports stay only on this device until you share one."
        ),
        emptyStateText: LocalizedStringResource = LocalizedStringResource("No crash reports yet."),
        shareActionText: LocalizedStringResource = LocalizedStringResource("Share"),
        deleteActionText: LocalizedStringResource = LocalizedStringResource("Delete")
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.header = header
        self.footer = footer
        self.emptyStateText = emptyStateText
        self.shareActionText = shareActionText
        self.deleteActionText = deleteActionText
        self._reports = State(initialValue: CrashReportStore.loadAll(appGroupIdentifier: appGroupIdentifier))
    }

    public var body: some View {
        Section {
            if self.reports.isEmpty {
                Text(self.emptyStateText)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.reports) { report in
                    Menu {
                        ShareLink(item: report.formattedText) {
                            Label(self.shareActionText, systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            CrashReportStore.delete(report, appGroupIdentifier: self.appGroupIdentifier)
                            withAnimation {
                                self.reports = CrashReportStore.loadAll(appGroupIdentifier: self.appGroupIdentifier)
                            }
                        } label: {
                            Label(self.deleteActionText, systemImage: "trash")
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.exceptionSummary)
                                .lineLimit(1)
                            Text(report.date, format: Self.dateFormat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .contentShape(.rect)
                }
            }
        } header: {
            Text(self.header)
        } footer: {
            Text(self.footer)
        }
    }
}

#Preview {
    List {
        CrashReportsSection(appGroupIdentifier: "group.com.example.preview")
    }
}
#endif
