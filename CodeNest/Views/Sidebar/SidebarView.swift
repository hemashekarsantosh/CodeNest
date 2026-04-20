//
//  SidebarView.swift
//  CodeNest
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        Group {
            if let root = workspace.rootNode {
                List {
                    if let children = root.children {
                        ForEach(children) { node in
                            FileTreeRowView(node: node, parent: root)
                        }
                    } else {
                        ProgressView("Loading...")
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No folder open")
                        .foregroundStyle(.secondary)
                    Button("Open Folder...") {
                        workspace.openFolder()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(workspace.rootNode?.name ?? "CodeNest")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    workspace.openFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Open Folder")
            }
        }
    }
}
