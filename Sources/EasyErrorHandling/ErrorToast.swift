//
//  ErrorToast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import SwiftUI

/// A toast showing an error message.
public class ErrorToast: Toast {
    
    public let maxWidth: Double = .infinity
    
    public let foregroundStyle: Color = .red
    
    public let id = UUID()
    
    /// Textual description of the error
    public let errorDescription: String
    
    /// The thrown error, if applicable
    public let rawError: Error?
    
    /// Textual description of the task that caused the error
    public let performedTask: LocalizedStringResource
    
    public init(error: Error, performedTask: LocalizedStringResource) {
        self.errorDescription = error.localizedDescription
        self.rawError = error
        self.performedTask = performedTask
    }
    
    public init(errorDescription: LocalizedStringResource, performedTask: LocalizedStringResource) {
        self.errorDescription = String(localized: errorDescription)
        self.rawError = nil
        self.performedTask = performedTask
    }
}
