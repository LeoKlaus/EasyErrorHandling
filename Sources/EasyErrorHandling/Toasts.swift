//
//  ToastView.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 27.02.25.
//

import SwiftUI

private struct AutoDismissModifier: ViewModifier {
    @Environment(\.dismissToast) var dismissToast
    let id: UUID

    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 10).onEnded { _ in
                withAnimation { dismissToast(id) }
            })
            .task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { dismissToast(id) }
            }
    }
}

private extension View {
    func autoDismiss(id: UUID) -> some View {
        modifier(AutoDismissModifier(id: id))
    }
}

struct ToastView: View {
    
    @Environment(\.dismissToast) var dismissToast
    
    /// The toast to display.
    let toast: any Toast
    
    @State private var progress: Double = 0
    
    var onTap: ((ErrorToast) -> Void)?
    
    var body: some View {
        VStack {
            if let error = toast as? ErrorToast {
                Label {
                    VStack(alignment: .leading) {
                        Text(error.errorDescription)
                            .lineLimit(2)
                        Text("Tap for more information", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.red)
                .onTapGesture {
                    if let onTap {
                        onTap(error)
                    } else {
                        withAnimation {
                            self.dismissToast(self.toast.id)
                        }
                    }
                }
                .autoDismiss(id: toast.id)
            } else if let progress = toast as? ProgressToast {
                ProgressView(
                    progress.hint,
                    value: self.progress
                )
                .foregroundStyle(.secondary)
                .task {
                    for await value in progress.progressUpdates {
                        self.progress = value
                    }
                    withAnimation {
                        self.dismissToast(self.toast.id)
                    }
                }
            } else if let info = toast as? InfoToast {
                Label {
                    Text(info.description)
                } icon: {
                    Image(systemName: "info")
                        .foregroundStyle(.tint)
                }
                .onTapGesture {
                    withAnimation {
                        self.dismissToast(self.toast.id)
                    }
                }
                .autoDismiss(id: toast.id)
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

#Preview {
    ToastView(toast: ErrorToast(errorDescription: "Some error", performedTask: "loading something"))
}
