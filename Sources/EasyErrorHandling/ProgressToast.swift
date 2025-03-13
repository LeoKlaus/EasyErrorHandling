//
//  ProgressToast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import SwiftUI


/// A toast showing the progress of a task.
public final class ProgressToast: NSObject, Toast, @unchecked Sendable {
    public let id = UUID()
    
    public let maxWidth: Double = 200
    
    public let foregroundStyle: Color = .accentColor
    
    let hint: String
    
    public init(hint: String) {
        self.hint = hint
    }
    
    private let queue: DispatchQueue = DispatchQueue(label: "ProgressToast.sync")
    
    private var _progress: Double = 0
    
    var progress: Double { queue.sync { _progress } }
    
    func update(_ newValue: Double) {
        queue.sync { _progress = newValue }
    }
    
    var progressObserver: NSKeyValueObservation?
}

extension ProgressToast: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        self.progressObserver = task.progress.observe(\.fractionCompleted) { prog, _ in
            //self.progress = prog.fractionCompleted
            self.update(prog.fractionCompleted)
        }
    }
}
