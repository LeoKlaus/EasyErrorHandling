//
//  LogDisplay.swift
//  OpenAirScan-next
//
//  Created by Leo Wehrfritz on 25.01.25.
//

import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let entry: String
}

struct LogDisplay: View {
    
    @Environment(\.dismiss) var dismiss
    
    let entries: [LogEntry]

    init(entries: [String]) {
        self.entries = entries.map{ LogEntry(entry: $0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(entries.reversed()) { entry in
                        Text(entry.entry)
                    }
                }
            }
            .navigationTitle("Logs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Dismiss", systemImage: "xmark.circle")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = entries.map{ $0.entry }.joined(separator: "\n")
                        #else
                        NSPasteboard.general.setString(entries.map{ $0.entry }.joined(separator: "\n"), forType: .multipleTextSelection)
                        #endif
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc.fill")
                    }
                }
            }
        }
    }
}
