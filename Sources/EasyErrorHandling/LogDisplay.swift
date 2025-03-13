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

public struct LogDisplay: View {
    
    @Environment(\.dismiss) var dismiss
    
    let entries: [LogEntry]

    public init(
        entries: [String],
        title: LocalizedStringKey,
        dismissButtonText: LocalizedStringKey,
        copyToClipboardButtonText: LocalizedStringKey
    ) {
        self.entries = entries.map{ LogEntry(entry: $0) }
        self.title = title
        self.dismissButtonText = dismissButtonText
        self.copyToClipboardButtonText = copyToClipboardButtonText
    }
    
    let title: LocalizedStringKey
    let dismissButtonText: LocalizedStringKey
    let copyToClipboardButtonText: LocalizedStringKey
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(entries.reversed()) { entry in
                        Text(entry.entry)
                    }
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label(dismissButtonText, systemImage: "xmark.circle")
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
                        Label(copyToClipboardButtonText, systemImage: "doc.on.doc.fill")
                    }
                }
            }
        }
    }
}
