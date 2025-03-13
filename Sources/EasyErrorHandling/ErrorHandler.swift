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
    
    /// The currently shown alert
    @Published var currentAlert: ErrorAlert?
    
    /// Currently visible toasts
    @Published private(set) var toasts: [any Toast] = []
    
    
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
     Handle an error.
     - Parameters:
        - text: Description of the error.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - blockUserInteraction: Whether this error should be shown as toast or alert.
     */
    @MainActor
    public func handle(_ text: String, while performedTask: String, blockUserInteraction: Bool = false) {
        Self.logger.error("Error while \(performedTask):\n\(text, privacy: .public)")
        
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: text)
        } else {
            self.showToast(ErrorToast(errorDescription: text))
        }
        
        #if os(iOS)
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
        Self.logger.error("Error while \(performedTask):\n\(text, privacy: .public)")
        
        currentAlert = ErrorAlert(title: "Error \(performedTask)", message: text, dismissAction: dismissAction)
        
        #if os(iOS)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
    
    
    /**
     Handle an error.
     - Parameters:
        - error: The error to handle. Should conform to `LocalizedError`.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - blockUserInteraction: Whether this error should be shown as toast or alert.
     */
    @MainActor
    public func handle(_ error: Error, while performedTask: String, blockUserInteraction: Bool = false) {
        Self.logger.error("Error while \(performedTask): \(error.localizedDescription, privacy: .public)\n\(String(describing: error), privacy: .public)")
        
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: error.localizedDescription)
        } else {
            self.showToast(ErrorToast(error: error))
        }
        
        #if os(iOS)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
    
    
    /**
     Handle an error.
     - Parameters:
        - error: The error to handle. Should conform to `LocalizedError`.
        - while: The task that is throwing the error (this will be shown to the user as `Error while <performedTask>`).
        - dismissAction: A function that will be executed when the user dismisses the alert.
     */
    @MainActor
    public func handle(_ error: Error, while performedTask: String, dismissAction: (() -> Void)?) {
        Self.logger.error("Error while \(performedTask): \(error.localizedDescription, privacy: .public)\n\(String(describing: error), privacy: .public)")
        
        currentAlert = ErrorAlert(title: "Error \(performedTask)", message: error.localizedDescription, dismissAction: dismissAction)
        
        #if os(iOS)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
}
