//
//  ErrorAlert.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import Foundation

public struct ErrorAlert: Identifiable {
    public var id = UUID()
    public var title: LocalizedStringResource = LocalizedStringResource("Error", bundle: .module)
    public var message: LocalizedStringResource
    public var dismissAction: (() -> Void)?
    
    public init(title: LocalizedStringResource, message: LocalizedStringResource, dismissAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.dismissAction = dismissAction
    }
    
    public init(title: LocalizedStringResource, error: any Error, dismissAction: (() -> Void)? = nil) {
        self.title = title
        self.message = LocalizedStringResource(stringLiteral: error.localizedDescription)
        self.dismissAction = dismissAction
    }
}
