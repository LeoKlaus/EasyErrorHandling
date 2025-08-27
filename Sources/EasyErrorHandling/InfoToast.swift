//
//  InfoToast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 27.08.25.
//

import SwiftUI

/// A toast showing an info message.
public class InfoToast: Toast {
    
    public let maxWidth: Double = .infinity
    
    public let foregroundStyle: Color = .primary
    
    public let id = UUID()
    
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}
