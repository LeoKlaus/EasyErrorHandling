//
//  Error.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 02.11.25.
//

import Foundation

extension Error {
    var isNetworkingError: Bool {
        switch self {
        case URLError.cannotFindHost, URLError.cannotConnectToHost, URLError.notConnectedToInternet:
            true
        default:
            false
        }
    }
}
