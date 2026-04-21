//
//  SidebarView.swift
//  CodeNest
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) var workspace

    @State private var creationMode: CreationMode? = nil
    @State private var newItemName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(workspace.rootNode?.name ?? "CodeNest")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if workspace.rootNode != nil {
                    Button { creationMode = .file } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("New File")

                    Button { creationMode = .folder } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("New Folder")
                }
                Button {
                    workspace.showNewProjectSheet = true
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("New Project")

                Button {
                    workspace.openFolder()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Open Folder")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            if let root = workspace.rootNode {
                if let children = root.children {
                    if children.isEmpty {
                        VStack(spacing: 10) {
                            Text("Folder is empty")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                            HStack(spacing: 8) {
                                Button("New File") { creationMode = .file }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                Button("New Folder") { creationMode = .folder }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        List {
                            ForEach(children) { node in
                                FileTreeRowView(node: node, parent: root)
                            }
                        }
                        .listStyle(.sidebar)
                    }
                } else {
                    List {
                        ProgressView("Loading...")
                    }
                    .listStyle(.sidebar)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No folder open")
                        .foregroundStyle(.secondary)
                    Button("New Project...") {
                        workspace.showNewProjectSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Open Folder...") {
                        workspace.openFolder()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(item: $creationMode) { mode in
            CreationSheet(mode: mode, name: $newItemName) { content in
                guard let root = workspace.rootNode else { return }
                if mode == .file {
                    workspace.createFile(named: newItemName, in: root, content: content)
                } else {
                    workspace.createFolder(named: newItemName, in: root)
                }
                newItemName = ""
            }
        }
    }
}
