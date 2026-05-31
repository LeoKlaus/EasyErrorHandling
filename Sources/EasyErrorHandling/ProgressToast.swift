//
//  ProgressToast.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//

import SwiftUI


/// A toast showing the progress of a task.
@MainActor
public final class ProgressToast: NSObject, Toast {
    public let id = UUID()

    public let maxWidth: Double = 200

    public let foregroundStyle: Color = .accentColor

    let hint: LocalizedStringResource

    public init(hint: LocalizedStringResource) {
        self.hint = hint
    }

    private(set) var progress: Double = 0

    public func invalidate() {
        progress = 1
        ErrorHandler.shared.removeToast(id)
    }

    private var progressObserver: NSKeyValueObservation?
}

extension ProgressToast: @preconcurrency URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        progressObserver = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            Task { @MainActor [weak self] in
                self?.progress = prog.fractionCompleted
            }
        }
    }
}
