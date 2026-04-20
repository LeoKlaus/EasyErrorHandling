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
    
    public let errorDescription: String
    public let rawError: Error?
    
    public init(error: Error) {
        self.errorDescription = error.localizedDescription
        self.rawError = error
    }
    
    public init(errorDescription: String) {
        self.errorDescription = errorDescription
        self.rawError = nil
    }
}
