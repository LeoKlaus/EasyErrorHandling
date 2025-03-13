//
//  ErrorHandler.swift
//  Paperparrot-Next
//
//  Created by Leo Wehrfritz on 20.12.24.
//

import OSLog
import SwiftUI



class ErrorHandler: ObservableObject {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ErrorHandler.self)
    )
    
    @Published var currentAlert: ErrorAlert?
    @Published private(set) var toasts: [any Toast] = []
    
    
    @MainActor
    func showToast(_ toast: any Toast) {
        withAnimation {
            self.toasts.append(toast)
        }
    }
    
    @MainActor
    func removeToast(_ uuid: UUID) {
        withAnimation {
            self.toasts.removeAll(where: {
                $0.id == uuid
            })
        }
    }
    
    @MainActor
    private func clearAll() {
        self.toasts = []
    }
    
    @MainActor
    func handle(_ text: String, while performedTask: String, blockUserInteraction: Bool = false) {
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
    
    @MainActor
    func handle(_ text: String, while performedTask: String, blockUserInteraction: Bool = false, dismissAction: (() -> Void)?) {
        Self.logger.error("Error while \(performedTask):\n\(text, privacy: .public)")
        
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: text, dismissAction: dismissAction)
        } else {
            self.showToast(ErrorToast(errorDescription: text))
        }
        
        #if os(iOS)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
    
    @MainActor
    func handle(_ error: Error, while performedTask: String, blockUserInteraction: Bool = false) {
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
    
    @MainActor
    func handle(_ error: Error, while performedTask: String, blockUserInteraction: Bool = false, dismissAction: (() -> Void)?) {
        Self.logger.error("Error while \(performedTask): \(error.localizedDescription, privacy: .public)\n\(String(describing: error), privacy: .public)")
        if blockUserInteraction {
            currentAlert = ErrorAlert(title: "Error \(performedTask)", message: error.localizedDescription, dismissAction: dismissAction)
        } else {
            self.showToast(ErrorToast(error: error))
        }
        
        #if os(iOS)
        ImpactGenerator.shared.notify(type: .error)
        #endif
    }
}
