//
//  HandleErrorsViewModifier.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 20.12.24.
//

import SwiftUI

/// A view modifier to show alerts
struct HandleErrorsViewModifier: ViewModifier {
    
    @StateObject var errorHandler = ErrorHandler.shared
    
    func dismiss(_ uuid: UUID) {
        self.errorHandler.removeToast(uuid)
    }
    
    var onTap: ((ErrorToast) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .environmentObject(self.errorHandler)
            .overlay(alignment: .top) {
                VStack {
                    ForEach(self.errorHandler.toasts.prefix(3), id: \.id) { toast in
                        ToastView(toast: toast, onTap: self.onTap)
                            .environment(\.dismissToast, dismiss)
                    }
                }
                #if os(iOS)
                .padding(.top, 45)
                #endif
            }
        
            .background(
                EmptyView()
                    .alert(item: $errorHandler.currentAlert) { currentAlert in
                        Alert(
                            title: Text(currentAlert.title),
                            message: Text(String(localized: currentAlert.message) + "\n" +  String(localized: "Check the logs for more details.", bundle: .module)),
                            dismissButton: .default(Text("Ok", bundle: .module)) {
                                currentAlert.dismissAction?()
                            }
                        )
                    }
            )
    }
}

extension View {
    /// Enable error handling for this view. Injects `ErrorHandler` environmentObject that can be used to show error messages.
    public func withErrorHandling(onTap: ((ErrorToast) -> Void)? = nil) -> some View {
        modifier(HandleErrorsViewModifier(onTap: onTap))
    }
}
