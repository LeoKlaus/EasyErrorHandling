//
//  ErrorAlert.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import Foundation

struct ErrorAlert: Identifiable {
    var id = UUID()
    var title: LocalizedStringResource = LocalizedStringResource("Error", bundle: .module)
    var message: LocalizedStringResource
    var dismissAction: (() -> Void)?
    
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
