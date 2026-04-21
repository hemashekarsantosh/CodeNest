//
//  SidebarView.swift
//  CodeNest
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(workspace.rootNode?.name ?? "CodeNest")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    workspace.openFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Open Folder")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

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
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
