//
//  ErrorSuppressor.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 02.11.25.
//

import Foundation

public protocol ErrorSuppressor {
    func isSuppressable(_ error: any Error) -> Bool
}

class DefaultErrorSuppressor: ErrorSuppressor {
    func isSuppressable(_ error: any Error) -> Bool {
        return false
    }
}
