//
//  EditorContainerView.swift
//  CodeNest
//

import SwiftUI

struct EditorContainerView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        if let tab = workspace.activeTab {
            switch tab.kind {
            case .code:
                CodeTextView(text: contentBinding(for: tab), language: tab.fileNode.fileExtension)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(tab.id) // force NSTextView recreation on tab switch

            case .diff(let diffContent):
                DiffTextView(content: diffContent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(tab.id) // force NSTextView recreation on tab switch
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.quaternary)
                Text("Open a file to start editing")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func contentBinding(for tab: TabItem) -> Binding<String> {
        Binding(
            get: {
                workspace.openTabs.first { $0.id == tab.id }?.content ?? ""
            },
            set: { newValue in
                if let idx = workspace.openTabs.firstIndex(where: { $0.id == tab.id }) {
                    workspace.openTabs[idx].content = newValue
                    workspace.openTabs[idx].isDirty = true
                }
            }
        )
    }
}
