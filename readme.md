# EasyErrorHandling

Super simple library to surface runtime errors to users and log them.

## Localization

You can manually add the following strings to the string catalog of your app to localize EasyErrorHandling (you can also check `Localizable.xcstrings` for keys):

1. Shown below the error message when `blockUserInteraction` is `true`.
```
Check the logs for more details.
```

2. Text for the "copy to clipboard" button in the log sheet
```
Copy to clipboard
```

3. Text for the "dismiss" button in the log sheet
```
Dismiss
```

4. Title for the log sheet
```
Logs
```

5. Title of the error alert when `blockUserInteraction` is `true`. %@ is `performedTask`
```
Error while %@
```

6. Task description of the log export task (this generally shouldn't fail)
```
exporting logs
```

7. Text for the dismiss button of the error alert when `blockUserInteraction` is `true`
```
Ok
```

8. Text shown below error toasts
```
Tap for more information
```

## Crash reporting (iOS 27+)

`CrashReporter` (bundled in this same package/product, alongside `CrashReporterShims`) wraps
Apple's iOS 27 `CrashReportExtension` API: instead of sending a crash report to a server, it
persists a symbolicated report to an App Group container for your app to read on its next launch.

Apple requires the actual crash-handling code to run in a separate **App Extension** process.
Swift Package Manager can't produce an `.appex`, so a small amount of per-app Xcode setup is
unavoidable. Everything else (stack walking, symbolication, on-disk format, the SwiftUI display
component) lives in this package.

### 1. Create the extension target

In Xcode: File → New → Target… → search "Crash Reporter Extension" (an ExtensionKit target).
Give it any name, e.g. `crash-handler`.

### 2. Add the App Group entitlement

The new extension target and your main app need to share the same App Group entitlement, so both
processes can read/write the same container.

### 3. Add this package as a dependency of the new target

Select the extension target → General → "Frameworks, Libraries, and Embedded Content" → **+** →
choose **EasyErrorHandling**. This one product bundles `EasyErrorHandling`, `CrashReporter`, and
`CrashReporterShims` together, so the target can `import` any of the three without adding them
separately.

### 4. Replace the generated `@main` file with

```swift
import CrashReportExtension
import CrashReporter
import ExtensionFoundation

@main
struct crash_handler: CrashReporterExtension {
    func processCrashReport(process: CrashedProcess) {
        CrashReporter.handle(
            process: process,
            appGroupIdentifier: "group.com.example.myapp",
            hostBundleIdentifier: "com.example.myapp"
        )
    }
}
```

`hostBundleIdentifier` is your app's own bundle identifier. It can't be reliably derived from
inside the extension process, so it's passed in explicitly rather than guessed.

### 5. Show captured reports in your own app

Also add `EasyErrorHandling` as a package dependency of your **host app** target (if it isn't
already), then drop `CrashReportsSection` into any `List`, e.g. a Settings/Help screen:

```swift
import CrashReporter

List {
    CrashReportsSection(appGroupIdentifier: "group.com.example.myapp")
}
```

It loads, displays, shares (as plain text via `ShareLink`), and deletes persisted reports. No
further wiring needed. Every piece of visible text is a `LocalizedStringResource` parameter with a
sensible default, so you can localize/rebrand it without touching this package's own string
catalog:

```swift
CrashReportsSection(
    appGroupIdentifier: "group.com.example.myapp",
    header: LocalizedStringResource("Crash reports"),
    footer: LocalizedStringResource("Captured automatically after a crash."),
    emptyStateText: LocalizedStringResource("No crash reports yet."),
    shareActionText: LocalizedStringResource("Share"),
    deleteActionText: LocalizedStringResource("Delete")
)
```

### Notes

- All of `CrashReporter`'s functionality is scoped to iOS and macOS (`#if os(iOS) || os(macOS)`)
  — it compiles to nothing on watchOS/tvOS, since `CrashReportExtension` doesn't exist there.
- Alongside the JSON report, a best-effort `.ips` file (Apple's crash-log format, readable by
  Console.app and Xcode's Organizer) is saved too. The format isn't officially documented, so
  treat it as informational. Xcode's own detailed crash-report viewer has been observed failing
  to render one of these (an internal, undocumented Xcode error with no public fix), even though
  the outer thread/frame list parses correctly.
