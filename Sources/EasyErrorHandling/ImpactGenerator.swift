//
//  ImpactGenerator.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import Foundation
import SwiftUI

public enum DeviceAgnosticImpactStyle {
    case light, medium, heavy, soft, rigid
    
#if os(iOS)
    var deviceSpecificValue: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:
                .light
        case .medium:
                .medium
        case .heavy:
                .heavy
        case .soft:
                .soft
        case .rigid:
                .soft
        }
    }
#elseif os(watchOS)
    var deviceSpecificValue: WKHapticType {
        .click
    }
#endif
}
public enum DeviceAgnosticImpactType {
    case error, success, warning
    
#if os(iOS)
    var deviceSpecificValue: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .error:
                .error
        case .success:
                .success
        case .warning:
                .warning
        }
    }
#elseif os(watchOS)
    var deviceSpecificValue: WKHapticType {
        switch self {
        case .error:
                .failure
        case .success:
                .success
        case .warning:
                .retry
        }
    }
#endif
}

#if os(iOS) && !targetEnvironment(simulator)
/// A helper to simplify working with haptic feedback
@MainActor
public final class ImpactGenerator {
    public static let shared = ImpactGenerator()
    
    public func impactOccured(style: DeviceAgnosticImpactStyle = .medium) {
        UIImpactFeedbackGenerator(style: style.deviceSpecificValue).impactOccurred()
    }
    
    public func notify(type: DeviceAgnosticImpactType = .success) {
        UINotificationFeedbackGenerator().notificationOccurred(type.deviceSpecificValue)
    }
}
#elseif os(watchOS) && !targetEnvironment(simulator)
@MainActor
public final class ImpactGenerator {
    public static let shared = ImpactGenerator()
    
    public func impactOccured(style: DeviceAgnosticImpactStyle = .medium) {
        WKInterfaceDevice.current().play(style.deviceSpecificValue)
    }
    
    public func notify(type: DeviceAgnosticImpactType = .success) {
        WKInterfaceDevice.current().play(type.deviceSpecificValue)
    }
}
#endif
