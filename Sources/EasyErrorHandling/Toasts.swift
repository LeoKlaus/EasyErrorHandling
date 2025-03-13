//
//  Toasts.swift
//  Paperparrot-Next
//
//  Created by Leo Wehrfritz on 27.02.25.
//

import SwiftUI

protocol Toast: Identifiable {
    var id: UUID { get }
    
    var maxWidth: Double { get }
    var foregroundStyle: Color { get }
}


class ErrorToast: Toast {
    
    let maxWidth: Double = .infinity
    
    let foregroundStyle: Color = .red
    
    let id = UUID()
    
    let errorDescription: String
    
    init(error: Error) {
        self.errorDescription = error.localizedDescription
    }
    
    init(errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

final class ProgressToast: NSObject, Toast, @unchecked Sendable {
    let id = UUID()
    
    let maxWidth: Double = 200
    
    let foregroundStyle: Color = .accentColor
    
    let hint: String
    
    init(hint: String) {
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

struct ToastView: View {
    
    @Environment(\.dismissToast) var dismissToast
    
    let toast: any Toast
    
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack {
            if let error = toast as? ErrorToast {
                Label(
                    error.errorDescription,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.red)
                .onTapGesture {
                    withAnimation {
                        self.dismissToast(self.toast.id)
                    }
                }
                .gesture(DragGesture(minimumDistance: 10).onEnded { _ in
                    withAnimation {
                        self.dismissToast(self.toast.id)
                    }
                })
                .task {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            self.dismissToast(self.toast.id)
                        }
                    }
                }
            } else if let progress = toast as? ProgressToast {
                ProgressView(
                    progress.hint,
                    value: self.progress
                )
                .foregroundStyle(.secondary)
                .task {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                        DispatchQueue.main.async {
                            self.progress = progress.progress
                        }
                        
                        if progress.progress >= 1 {
                            DispatchQueue.main.async {
                                withAnimation {
                                    self.dismissToast(self.toast.id)
                                }
                                self.timer = nil
                            }
                            timer.invalidate()
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .padding()
        .background {
            Capsule(style: .circular).fill(.thinMaterial)
        }
        .frame(maxWidth: toast.maxWidth)
    }
}


extension EnvironmentValues {
    @Entry var dismissToast: (UUID) -> () = { _ in }
}
