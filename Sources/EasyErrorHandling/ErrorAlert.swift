//
//  ErrorAlert.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import Foundation

struct ErrorAlert: Identifiable {
    var id = UUID()
    var title: String = "Error"
    var message: String
    var dismissAction: (() -> Void)?
}
