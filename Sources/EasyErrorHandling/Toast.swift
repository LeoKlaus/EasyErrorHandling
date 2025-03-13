//
//  Toast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import SwiftUI

/// Protocol for toasts
public protocol Toast: Identifiable {
    var id: UUID { get }
    
    var maxWidth: Double { get }
    var foregroundStyle: Color { get }
}
