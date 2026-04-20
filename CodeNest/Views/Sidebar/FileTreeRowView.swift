//
//  FileTreeRowView.swift
//  CodeNest
//

import SwiftUI

enum CreationMode: Identifiable {
    case file, folder
    var id: Self { self }
    var title: String { self == .file ? "New File" : "New Folder" }
    var placeholder: String { self == .file ? "filename.swift" : "FolderName" }
}

struct FileTreeRowView: View {
    @Bindable var node: FileNode
    var parent: FileNode?
    @Environment(WorkspaceState.self) var workspace

    @State private var creationMode: CreationMode? = nil
    @State private var newItemName: String = ""
    @State private var showDeleteConfirmation = false

    private var isSelected: Bool { workspace.selectedNode?.url == node.url }

    var body: some View {
        Group {
            if node.isDirectory {
                DisclosureGroup(
                    isExpanded: $node.isExpanded,
                    content: {
                        if let children = node.children {
                            ForEach(children) { child in
                                FileTreeRowView(node: child, parent: node)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.5)
                                .frame(height: 20)
                        }
                    },
                    label: {
                        Label(node.name, systemImage: node.isExpanded ? "folder.fill" : "folder")
                            .lineLimit(1)
                            .contentShape(Rectangle())
                            .simultaneousGesture(TapGesture().onEnded {
                                workspace.selectedNode = node
                            })
                    }
                )
                .onChange(of: node.isExpanded) { _, expanded in
                    if expanded && node.children == nil {
                        workspace.loadChildren(of: node)
                    }
                }
            } else {
                Button {
                    workspace.selectedNode = node
                    workspace.openFile(node)
                } label: {
                    Label(node.name, systemImage: sfSymbol(for: node.fileExtension))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            if node.isDirectory {
                Button("New File...") { creationMode = .file }
                Button("New Folder...") { creationMode = .folder }
                if parent != nil {
                    Divider()
                    Button("Delete", role: .destructive) { showDeleteConfirmation = true }
                }
            } else {
                Button("Delete", role: .destructive) { showDeleteConfirmation = true }
            }
        }
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.2))
                : nil
        )
        .sheet(item: $creationMode) { mode in
            CreationSheet(mode: mode, name: $newItemName) {
                if mode == .file {
                    workspace.createFile(named: newItemName, in: node)
                } else {
                    workspace.createFolder(named: newItemName, in: node)
                }
                newItemName = ""
            }
        }
        .alert("Delete \"\(node.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let parent { workspace.delete(node: node, from: parent) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(node.isDirectory
                 ? "This will move the folder and all its contents to the Trash."
                 : "This will move the file to the Trash.")
        }
    }

    private func sfSymbol(for ext: String) -> String {
        switch ext.lowercased() {
        case "swift":           return "swift"
        case "js", "ts":        return "square.stack.3d.up"
        case "json":            return "curlybraces"
        case "md", "markdown":  return "doc.text"
        case "html", "htm":     return "globe"
        case "css":             return "paintbrush"
        case "py":              return "terminal"
        case "sh", "zsh":       return "terminal.fill"
        case "png", "jpg",
             "jpeg", "gif",
             "svg", "webp":     return "photo"
        case "pdf":             return "doc.richtext"
        case "txt":             return "doc.plaintext"
        case "xml", "plist":    return "chevron.left.forwardslash.chevron.right"
        default:                return "doc"
        }
    }
}

private struct CreationSheet: View {
    let mode: CreationMode
    @Binding var name: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(mode.title).font(.headline)
            TextField(mode.placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") {
                    onCreate()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
    }
}
