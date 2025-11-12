//
//  ErrorHandler.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 20.12.24.
//

import OSLog
import SwiftUI

public class ErrorHandler: ObservableObject {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ErrorHandler.self)
    )
    
    public static let shared = ErrorHandler()
    
    /// Whether to show error messages for network errors
    private(set) var suppressErrors: Bool = false
    
    /**
     Object that determines whether an error is suppressable or not. Always returns false by default.
     
     Override
     ``` swift
     ErrorSuppressor.isSuppressable(any Error)
     ```
     to define which errors can be suppressed.
     
     To enable/disable suppression, use
     ``` swift
     ErrorHandler.enableErrorSuppression(ErrorSuppressor, Bool)
     ```
     and
     ``` swift
     ErrorHandler.disableErrorSuppression()
     ```
     */
    private(set) var suppressor: ErrorSuppressor = DefaultErrorSuppressor()
    
    /**
     Whether to automatically set `suppressErrors` to true after the first matching error is handled.
     
     To use this, pass `true` for `enableAutomaticSuppression` when enabling suppression with
     ``` swift
     ErrorHandler.enableErrorSuppression(ErrorSuppressor, Bool)
     ```
    */
    private(set) var autoSuppressErrors: Bool = false
    
    /**
     Enable suppression of certain errors.
     
     - Parameter suppressor: The suppressor that should be used for error suppression. `isSuppressable(any Error)` should be overriden.
     - Parameter showFirstInstance: Whether or not to show the first instance of the error to the user.
     
     Which errors are suppressable is determined by
     ``` swift
     ErrorSuppressor.isSuppressable(any Error)
     ```
     the default implementation always returns false.  Additionally, when calling any of the
     ``` swift
     ErrorHandler.handle
     ```
     methods, `suppressable` has to be set to true.
     
     Even with suppression active, all handled errors will still be logged, only the user facing toasts/alerts are suppressed.
     */
    public func enableErrorSuppression(_ suppressor: ErrorSuppressor, showFirstInstance: Bool = false) {
        self.suppressor = suppressor
        self.autoSuppressErrors = showFirstInstance
        self.suppressErrors = !showFirstInstance
    }
    
    /**
     Disable error suppression.
     
     For more information, refer to the documentation of
     ``` swift
     ErrorHandler.enableErrorSuppression(ErrorSuppressor, Bool)
     ```
     */
    public func disableErrorSuppression() {
        self.suppressor = DefaultErrorSuppressor()
        self.suppressErrors = false
        self.autoSuppressErrors = false
    }
    
    /// The currently shown alert
    @Published var currentAlert: ErrorAlert?
    
    /// Currently visible toasts
    @Published private(set) var toasts: [any Toast] = []
    
    
    private init() { }
    
    /**
     Shows the given toast to the user.
     - Parameter toast: Toast to show.
     */
    @MainActor
    public func showToast(_ toast: any Toast) {
        withAnimation {
            self.toasts.append(toast)
        }
    }
    
    
    /**
     Removes the toast with the given id.
     - Parameter uuid: ID of the toast to remove.
     */
    @MainActor
    public func removeToast(_ uuid: UUID) {
        withAnimation {
            self.toasts.removeAll(where: {
                $0.id == uuid
            })
        }
    }
    
    
    /**
     Removes all toasts.
     */
    @MainActor
    private func clearAll() {
        self.toasts = []
    }
    
    /**
     Export collected logs.
     - Returns: An array of strings, each representing a single log entry.
     */
    public func exportLogs() throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let date = Date.now.addingTimeInterval(-24 * 3600)
        let position = store.position(date: date)
        
        return try store
            .getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == Bundle.main.bundleIdentifier! }
            .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
    }
    
    /**
     Display information.
     - Parameters:
     - text: Information to display.
     */
    @MainActor
    public func showInfo(_ text: String) {
        self.showToast(InfoToast(text))
#if os(iOS) && !targetEnvironment(simulator)
        ImpactGenerator.shared.notify(type: .success)
#endif
    }
    
    /**
     Handle an error.
     - Parameters:
        - text: Description of the error.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - blockUserInteraction: Whether this error should be shown as toast or alert.
     */
    @MainActor
    public func handle(_ text: String, while performedTask: String, blockUserInteraction: Bool = false) {
        Self.logger.error("Error while \(performedTask, privacy: .public):\n\(text, privacy: .public)")
        
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: text)
        } else {
            self.showToast(ErrorToast(errorDescription: text))
        }
        
        #if os(iOS) && !targetEnvironment(simulator)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
    
    
    /**
     Handle an error.
     - Parameters:
        - text: Description of the error.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - dismissAction: A function that will be executed when the user dismisses the alert.
     */
    @MainActor
    public func handle(_ text: String, while performedTask: String, blockUserInteraction: Bool = false, dismissAction: (() -> Void)?) {
        Self.logger.error("Error while \(performedTask, privacy: .public):\n\(text, privacy: .public)")
        
        currentAlert = ErrorAlert(title: "Error \(performedTask)", message: text, dismissAction: dismissAction)
        
        #if os(iOS) && !targetEnvironment(simulator)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
    
    /**
     Handle an error.
     - Parameters:
        - error: The error to handle. Should conform to `LocalizedError`.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - suppressable: Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled.
        - blockUserInteraction: Whether this error should be shown as toast or alert.
     */
    @MainActor
    public func handle(_ error: Error, while performedTask: String, suppressable: Bool = false, blockUserInteraction: Bool = false) {
        Self.logger.error("Error while \(performedTask, privacy: .public): \(error.localizedDescription, privacy: .public)\n\(String(describing: error), privacy: .public)")
        
        if self.suppressErrors && suppressable && self.suppressor.isSuppressable(error) {
            return
        }
        
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: error.localizedDescription)
        } else {
            self.showToast(ErrorToast(error: error))
        }
        
        #if os(iOS) && !targetEnvironment(simulator)
        ImpactGenerator.shared.notify(type: .error)
        #endif
        
        if autoSuppressErrors && self.suppressor.isSuppressable(error) {
            self.suppressErrors = true
        }
    }
    
    
    /**
     Handle an error.
     - Parameters:
        - error: The error to handle. Should conform to `LocalizedError`.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - suppressable: Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled.
        - dismissAction: A function that will be executed when the user dismisses the alert.
     */
    @MainActor
    public func handle(_ error: Error, while performedTask: String, suppressable: Bool = false, dismissAction: (() -> Void)?) {
        Self.logger.error("Error while \(performedTask, privacy: .public): \(error.localizedDescription, privacy: .public)\n\(String(describing: error), privacy: .public)")
        
        if self.suppressErrors && suppressable && self.suppressor.isSuppressable(error) {
            return
        }
        
        currentAlert = ErrorAlert(title: "Error \(performedTask)", message: error.localizedDescription, dismissAction: dismissAction)
        
        #if os(iOS) && !targetEnvironment(simulator)
        ImpactGenerator.shared.notify(type: .error)
        #endif
        
        if autoSuppressErrors && self.suppressor.isSuppressable(error) {
            self.suppressErrors = true
        }
    }
}
