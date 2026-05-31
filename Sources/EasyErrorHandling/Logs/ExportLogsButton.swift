//
//  ExportLogsButton.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 25.01.25.
//

import SwiftUI
import OSLog

public struct ExportLogsButton: View {
    
    let description: LocalizedStringResource
    
    @EnvironmentObject var errorHandler: ErrorHandler
    
    @State private var isCollectingLogs: Bool = false
    
    @State private var entries: [String] = []
    
    @State private var showExport: Bool = false
    
    @MainActor
    private func exportLogs() async {
        do {
            entries = try await self.errorHandler.exportLogs()
        } catch {
            errorHandler.handle(error, while: LocalizedStringResource("exporting logs"))
        }
    }
    
    /**
     A button to export debug logs.
     - Parameter description: The text to show on the button.
     */
    public init(_ description: LocalizedStringResource) {
        self.description = description
    }
    
    public var body: some View {
        Button {
            isCollectingLogs = true
            Task {
                await exportLogs()
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
            LogDisplay(
                entries: entries,
                title: LocalizedStringResource("Logs"),
                dismissButtonText: LocalizedStringResource("Dismiss"),
                copyToClipboardButtonText: LocalizedStringResource("Copy to clipboard")
            )
            .padding(.horizontal)
        }
    }
}

#Preview {
    ExportLogsButton("Export Debug Logs")
}
