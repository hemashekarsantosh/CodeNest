//
//  FileTreeRowView.swift
//  CodeNest
//

import SwiftUI

struct FileTreeRowView: View {
    @Bindable var node: FileNode
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: $node.isExpanded,
                content: {
                    if let children = node.children {
                        ForEach(children) { child in
                            FileTreeRowView(node: child)
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
                }
            )
            .onChange(of: node.isExpanded) { _, expanded in
                if expanded && node.children == nil {
                    workspace.loadChildren(of: node)
                }
            }
        } else {
            Label(node.name, systemImage: sfSymbol(for: node.fileExtension))
                .lineLimit(1)
                .onTapGesture {
                    workspace.selectedNode = node
                    workspace.openFile(node)
                }
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
