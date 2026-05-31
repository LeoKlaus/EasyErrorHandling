import Testing
import Foundation
@testable import EasyErrorHandling

// MARK: - Helpers

private struct TestError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class AlwaysSuppressor: ErrorSuppressor {
    func isSuppressable(_ error: any Error) -> Bool { true }
}

private final class NeverSuppressor: ErrorSuppressor {
    func isSuppressable(_ error: any Error) -> Bool { false }
}

// Outer suite is serialized so all tests sharing ErrorHandler.shared run sequentially.
@MainActor
@Suite("EasyErrorHandling", .serialized)
struct EasyErrorHandlingTests {

    // MARK: - ErrorHandler: handle routing

    @MainActor
    @Suite("ErrorHandler.handle routing")
    struct HandleRoutingTests {

        let handler = ErrorHandler.shared

        init() { handler.reset() }

        @Test("Default shows toast, not alert")
        func defaultShowsToast() {
            handler.handle(TestError(message: "oops"), while: "testing")
            #expect(handler.toasts.count == 1)
            #expect(handler.currentAlert == nil)
        }

        @Test("blockUserInteraction shows alert, not toast")
        func blockingShowsAlert() {
            handler.handle(TestError(message: "oops"), while: "testing", blockUserInteraction: true)
            #expect(handler.toasts.isEmpty)
            #expect(handler.currentAlert != nil)
        }

        @Test("dismissAction shows alert and invokes callback on dismiss")
        func dismissActionShowsAlertAndCallsBack() {
            var dismissed = false
            handler.handle(TestError(message: "oops"), while: "testing", dismissAction: { dismissed = true })
            #expect(handler.toasts.isEmpty)
            #expect(handler.currentAlert != nil)
            handler.currentAlert?.dismissAction?()
            #expect(dismissed)
        }

        @Test("Text variant default shows toast, not alert")
        func textDefaultShowsToast() {
            handler.handle("Something went wrong", while: "testing")
            #expect(handler.toasts.count == 1)
            #expect(handler.currentAlert == nil)
        }

        @Test("Text variant blockUserInteraction shows alert, not toast")
        func textBlockingShowsAlert() {
            handler.handle("Something went wrong", while: "testing", blockUserInteraction: true)
            #expect(handler.toasts.isEmpty)
            #expect(handler.currentAlert != nil)
        }
    }

    // MARK: - ErrorHandler: suppression

    @MainActor
    @Suite("ErrorHandler suppression")
    struct SuppressionTests {

        let handler = ErrorHandler.shared

        init() { handler.reset() }

        @Test("Suppressable error is hidden when suppression is active")
        func suppressableErrorHidden() {
            handler.enableErrorSuppression(AlwaysSuppressor())
            handler.handle(TestError(message: "oops"), while: "testing", suppressable: true)
            #expect(handler.toasts.isEmpty)
            #expect(handler.currentAlert == nil)
        }

        @Test("Non-suppressable error shown even when suppression is active")
        func nonSuppressableErrorAlwaysShown() {
            handler.enableErrorSuppression(AlwaysSuppressor())
            handler.handle(TestError(message: "oops"), while: "testing", suppressable: false)
            #expect(handler.toasts.count == 1)
        }

        @Test("Suppressable error shown after suppression is disabled")
        func errorShownAfterSuppressionDisabled() {
            handler.enableErrorSuppression(AlwaysSuppressor())
            handler.disableErrorSuppression()
            handler.handle(TestError(message: "oops"), while: "testing", suppressable: true)
            #expect(handler.toasts.count == 1)
        }

        @Test("NeverSuppressor never suppresses even when suppressable: true")
        func neverSuppressorShowsAll() {
            handler.enableErrorSuppression(NeverSuppressor())
            handler.handle(TestError(message: "oops"), while: "testing", suppressable: true)
            #expect(handler.toasts.count == 1)
        }

        @Test("showFirstInstance shows first error then auto-suppresses subsequent ones")
        func showFirstInstanceThenSuppresses() {
            handler.enableErrorSuppression(AlwaysSuppressor(), showFirstInstance: true)

            handler.handle(TestError(message: "first"), while: "testing", suppressable: true)
            #expect(handler.toasts.count == 1)
            #expect(handler.suppressErrors == true)

            handler.handle(TestError(message: "second"), while: "testing", suppressable: true)
            #expect(handler.toasts.count == 1)
        }

        @Test("showFirstInstance does not suppress non-suppressable errors")
        func showFirstInstanceDoesNotSuppressNonSuppressable() {
            handler.enableErrorSuppression(AlwaysSuppressor(), showFirstInstance: true)
            handler.handle(TestError(message: "first"), while: "testing", suppressable: true)

            handler.handle(TestError(message: "second"), while: "testing", suppressable: false)
            #expect(handler.toasts.count == 2)
        }
    }

    // MARK: - ProgressToast

    @MainActor
    @Suite("ProgressToast")
    struct ProgressToastTests {

        @Test("invalidate() finishes the progress stream")
        func invalidateFinishesStream() async {
            let toast = ProgressToast(hint: "Testing")

            let collectTask = Task {
                var received: [Double] = []
                for await value in toast.progressUpdates {
                    received.append(value)
                }
                return received
            }

            toast.invalidate()
            let received = await collectTask.value
            #expect(received.isEmpty)
        }

        @Test("Stream yields values and terminates when task progress reaches 1")
        func streamYieldsAndTerminatesViaDelegate() async {
            let toast = ProgressToast(hint: "Testing")

            let task = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://example.com")!))
            toast.urlSession(URLSession.shared, didCreateTask: task)

            let collectTask = Task {
                var received: [Double] = []
                for await value in toast.progressUpdates {
                    received.append(value)
                }
                return received
            }

            task.progress.totalUnitCount = 100
            task.progress.completedUnitCount = 50
            task.progress.completedUnitCount = 100

            try? await Task.sleep(for: .milliseconds(100))

            let received = await collectTask.value
            #expect(received.contains(1.0))
            #expect(received.last == 1.0)
        }
    }
}
