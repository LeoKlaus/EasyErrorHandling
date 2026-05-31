//
//  ThrowingTaskViewModifier.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 15.07.25.
//

import SwiftUI

/// Modifer to execute throwing tasks with errorhandling.
struct ThrowingTaskViewModifier: ViewModifier {
    @StateObject var errorHandler = ErrorHandler.shared
    
    /// The task to execute.
    let action: () async throws -> Void
    /// Description of the task (shown in error message)
    let taskDescription: LocalizedStringResource
    /// Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled
    var suppressable: Bool = false
    /// Whether the error should be blocking (alert) or not (toast)
    var blockUserInteraction: Bool = false
    /// An action to perform when the user dismisses the alert (automatically enables blocking)
    var dismissAction: (() -> Void)?
    
    @Sendable
    func tryThrowingTask() async {
        do {
            try await action()
        } catch {
            if let dismissAction {
                self.errorHandler.handle(error, while: self.taskDescription, suppressable: self.suppressable, dismissAction: dismissAction)
            } else {
                self.errorHandler.handle(error, while: self.taskDescription, suppressable: self.suppressable, blockUserInteraction: self.blockUserInteraction)
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .task(self.tryThrowingTask)
    }
}

extension View {
    
    /**
     Adds an asynchronous throwing task to perform before this view appears.
     
     - Parameter taskDescription:       A description of the task, this will be shown to the user in error messages.
     - Parameter blockUserInteraction:  Whether the error should be blocking (alert) or not (toast)
     - Parameter action:                The task to perform.
     - Parameter suppressable:          Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled.
     - Parameter dismissAction:         An action to perform when the user dismisses the alert (automatically enables blocking).
     
     Errors will only be visibly handled if an `ErrorHandler` is injected into the calling view. If no `ErrorHandler` is present in the Environment, errors will be logged but not presented to the user.
     
     To add an `ErrorHandler` into the views context, you can use the `.withErrorHandling()` modifier:
     ``` swift
     MyView()
     .withErrorHandling()
     ```        
     */
    public func throwingTask(taskDescription: LocalizedStringResource, blockUserInteraction: Bool = false, suppressable: Bool = false, _ action: @escaping () async throws -> Void, dismissAction: (() -> Void)? = nil) -> some View {
        modifier(ThrowingTaskViewModifier(action: action, taskDescription: taskDescription, suppressable: suppressable, blockUserInteraction: blockUserInteraction, dismissAction: dismissAction))
    }
}

/// Modifer to execute throwing tasks with errorhandling.
struct ThrowingTaskViewModifierWithID<ID: Equatable>: ViewModifier {
    @StateObject var errorHandler = ErrorHandler.shared
    
    let id: ID
    /// The task to execute.
    let action: () async throws -> Void
    /// Description of the task (shown in error message)
    let taskDescription: LocalizedStringResource
    /// Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled
    var suppressable: Bool = false
    /// Whether the error should be blocking (alert) or not (toast)
    var blockUserInteraction: Bool = false
    /// An action to perform when the user dismisses the alert (automatically enables blocking)
    var dismissAction: (() -> Void)?
    
    @Sendable
    func tryThrowingTask() async {
        do {
            try await action()
        } catch {
            if let dismissAction {
                self.errorHandler.handle(error, while: self.taskDescription, suppressable: self.suppressable, dismissAction: dismissAction)
            } else {
                self.errorHandler.handle(error, while: self.taskDescription, suppressable: self.suppressable, blockUserInteraction: self.blockUserInteraction)
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .task(id: self.id, self.tryThrowingTask)
    }
}

extension View {
    
    /**
     Adds an asynchronous throwing task to perform before this view appears.
     
     - Parameter taskDescription:       A description of the task, this will be shown to the user in error messages.
     - Parameter blockUserInteraction:  Whether the error should be blocking (alert) or not (toast)
     - Parameter action:                The task to perform.
     - Parameter suppressable:          Whether this error message can be suppressed if it's a network error. Only applies if `suppressNetworkErrors` is enabled.
     - Parameter dismissAction:         An action to perform when the user dismisses the alert (automatically enables blocking).
     
     Errors will only be visibly handled if an `ErrorHandler` is injected into the calling view. If no `ErrorHandler` is present in the Environment, errors will be logged but not presented to the user.
     
     To add an `ErrorHandler` into the views context, you can use the `.withErrorHandling()` modifier:
     ``` swift
     MyView()
     .withErrorHandling()
     ```
     */
    public func throwingTask<ID: Equatable>(id: ID, taskDescription: LocalizedStringResource, blockUserInteraction: Bool = false, suppressable: Bool = false, _ action: @escaping () async throws -> Void, dismissAction: (() -> Void)? = nil) -> some View {
        modifier(ThrowingTaskViewModifierWithID(id: id, action: action, taskDescription: taskDescription, suppressable: suppressable, blockUserInteraction: blockUserInteraction, dismissAction: dismissAction))
    }
}
