//
//  LogDisplay.swift
//  EasyErrorHandling
//
//  Created by Leo Wehrfritz on 25.01.25.
//

import SwiftUI



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
                            .font(.system(size: 12, design: .monospaced))
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
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(entries.map{ $0.entry }.joined(separator: "\n"), forType: .string)
                        print(entries.map{ $0.entry }.joined(separator: "\n"))
                        #endif
                    } label: {
                        Label(copyToClipboardButtonText, systemImage: "doc.on.doc.fill")
                    }
                }
            }
        }
    }
}


#Preview {
    LogDisplay(
        entries: [
            "Entry A",
            "Entry B",
            "Entry C",
            "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet."
        ],
        title: "Logs",
        dismissButtonText: "Dismiss",
        copyToClipboardButtonText: "Copy to clipboard"
    )
}
