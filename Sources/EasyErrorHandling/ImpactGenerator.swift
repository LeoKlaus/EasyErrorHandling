//
//  ImpactGenerator.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//


import Foundation
import SwiftUI

#if os(iOS)
class ImpactGenerator {
    static let shared = ImpactGenerator()
    
    func impactOccured(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    func notify(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#endif