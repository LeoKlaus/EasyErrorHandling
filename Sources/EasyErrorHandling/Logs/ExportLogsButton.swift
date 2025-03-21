//
//  ExportLogsButton.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 25.01.25.
//

import SwiftUI
import OSLog

public struct ExportLogsButton: View {
    
    let description: LocalizedStringKey
    
    @EnvironmentObject var errorHandler: ErrorHandler
    
    @State private var isCollectingLogs: Bool = false
    
    @State private var entries: [String] = []
    
    @State private var showExport: Bool = false
    
    private func exportLogs() {
        do {
            entries = try self.errorHandler.exportLogs()
        } catch {
            errorHandler.handle(error, while: "exporting logs")
        }
    }
    
    /**
     A button to export debug logs.
     - Parameter description: The text to show on the button.
     */
    public init(_ description: LocalizedStringKey) {
        self.description = description
    }
    
    public var body: some View {
        Button {
            isCollectingLogs = true
            DispatchQueue.global(qos: .userInitiated).async {
                exportLogs()
                isCollectingLogs = false
                showExport = true
            }
        } label: {
            if isCollectingLogs {
                ProgressView()
            } else {
                Label(description, systemImage: "doc.text.fill")
            }
        }
        .sheet(isPresented: $showExport) {
            LogDisplay(entries: entries, title: "Logs", dismissButtonText: "Dismiss", copyToClipboardButtonText: "Copy to Clipboard")
        }
    }
}

#Preview {
    ExportLogsButton("Export Debug Logs")
}
