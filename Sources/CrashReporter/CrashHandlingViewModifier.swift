#if os(iOS) || os(macOS)
import SwiftUI

struct CrashHandlingViewModifier: ViewModifier {
    let appGroupIdentifier: String
    let handler: (CrashReport) -> Void

    @State private var hasChecked = false

    func body(content: Content) -> some View {
        content
            .task {
                guard !self.hasChecked else { return }
                self.hasChecked = true
                guard let latest = CrashReportStore.loadAll(appGroupIdentifier: self.appGroupIdentifier).first else { return }
                self.handler(latest)
            }
    }
}

extension View {
    /**
     Calls `handler` once, at launch, with the most recent `CrashReport` persisted for
     `appGroupIdentifier` i.e. whenever the app is being reopened after a previous launch
     crashed (assuming a `CrashReporterExtension` sharing the same App Group actually captured
     one). `handler` isn't called at all if there are none.

     Deliberately does nothing beyond that single call: the report is neither deleted nor marked
     as seen here, so it gets handed to `handler` again on the *next* launch too, unless your own
     `handler` removes it (e.g. via `CrashReportStore.delete(_:appGroupIdentifier:)`) or the user
     clears it from `CrashReportsSection`. Tracking which crashes have already been acknowledged
     is the calling app's responsibility, not this modifier's.

     - Parameters:
       - appGroupIdentifier: Must match what was passed to
         `CrashReporter.handle(process:appGroupIdentifier:hostBundleIdentifier:)`.
       - handler: Called with the most recent pending report, if any.

     ``` swift
     ContentView()
         .withCrashHandling(appGroupIdentifier: "group.com.example.myapp") { report in
             self.crashReportToPresent = report
         }
         .sheet(item: $crashReportToPresent) { report in
             CrashReportSheet(report: report)
         }
     ```
     */
    public func withCrashHandling(appGroupIdentifier: String, perform handler: @escaping (CrashReport) -> Void) -> some View {
        modifier(CrashHandlingViewModifier(appGroupIdentifier: appGroupIdentifier, handler: handler))
    }
}
#endif
