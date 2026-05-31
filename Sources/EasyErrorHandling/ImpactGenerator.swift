//
//  ImpactGenerator.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//


import Foundation
import SwiftUI

#if os(iOS) && !targetEnvironment(simulator)
/// A helper to simplify working with haptic feedback
@MainActor
public final class ImpactGenerator {
    public static let shared = ImpactGenerator()
    
    public func impactOccured(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    public func notify(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#endif
