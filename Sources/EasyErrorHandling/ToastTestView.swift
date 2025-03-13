//
//  ToastTestView.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 13.03.25.
//


import SwiftUI

struct ToastTestView: View {
    
    @EnvironmentObject var errorHandler: ErrorHandler
    
    var body: some View {
        List {
            Button {
                errorHandler.handle(
                    URLError(.appTransportSecurityRequiresSecureConnection),
                    while: "getting preview image",
                    blockUserInteraction: false
                )
            } label: {
                Text(verbatim: "Add Error")
            }
            
            Button {
                
                let toast = ProgressToast(hint: "Downloading Preview")
                
                errorHandler.showToast(toast)
                
                Task {
                    do {
                        let (_, _) = try await URLSession.shared.data(from: URL(string: "https://files.testfile.org/PDF/10MB-TESTFILE.ORG.pdf")!, delegate: toast)
                    } catch {
                        self.errorHandler.removeToast(toast.id)
                        self.errorHandler.handle(error, while: "downloading preview", blockUserInteraction: false)
                    }
                }
                
            } label: {
                Text(verbatim: "Add Progress")
            }
            
            Button {
                
                let toast = ProgressToast(hint: "Downloading Preview")
                
                errorHandler.showToast(toast)
                
                Task {
                    do {
                        throw URLError(.notConnectedToInternet)
                    } catch {
                        self.errorHandler.removeToast(toast.id)
                        self.errorHandler.handle(error, while: "downloading preview", blockUserInteraction: false)
                    }
                }
                
            } label: {
                Text(verbatim: "Add Progress (Failing)")
            }
        }
    }
}


#Preview {
    ToastTestView()
        .withErrorHandling()
        .tint(.green)
}
