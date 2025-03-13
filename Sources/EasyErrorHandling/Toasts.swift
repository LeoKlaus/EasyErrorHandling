//
//  ToastView.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 27.02.25.
//

import SwiftUI

struct ToastView: View {
    
    @Environment(\.dismissToast) var dismissToast
    
    /// The toast to display.
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
