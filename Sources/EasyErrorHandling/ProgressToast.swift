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

    public let hint: LocalizedStringResource

    public let progressUpdates: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation

    public init(hint: LocalizedStringResource) {
        (progressUpdates, continuation) = AsyncStream<Double>.makeStream()
        self.hint = hint
    }

    public func invalidate() {
        continuation.finish()
        ErrorHandler.shared.removeToast(self.id)
    }
}

extension ProgressToast: URLSessionTaskDelegate {

    nonisolated public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let observer = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            let value = prog.fractionCompleted
            self?.continuation.yield(value)
            if value >= 1 {
                self?.continuation.finish()
            }
        }
        continuation.onTermination = { _ in
            observer.invalidate()
        }
    }
}
