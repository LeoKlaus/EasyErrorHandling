//
//  InfoToast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 27.08.25.
//

import SwiftUI

/// A toast showing an info message.
public final class InfoToast: Toast {
    
    public let maxWidth: Double = .infinity
    
    public let foregroundStyle: Color = .primary
    
    public let id = UUID()
    
    public let description: LocalizedStringResource
    
    public init(_ description: LocalizedStringResource) {
        self.description = description
    }
}
