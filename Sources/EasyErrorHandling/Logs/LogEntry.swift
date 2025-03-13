//
//  LogEntry.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import Foundation

/// A single log entry
struct LogEntry: Identifiable {
    let id = UUID()
    let entry: String
}
