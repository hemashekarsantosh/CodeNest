//
//  TabBarView.swift
//  CodeNest
//

import SwiftUI

struct TabBarView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(workspace.openTabs) { tab in
                    TabPillView(tab: tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(height: 36)
        .background(.bar)
    }
}

private struct TabPillView: View {
    let tab: TabItem
    @Environment(WorkspaceState.self) var workspace
    @State private var isHovered = false

    var isActive: Bool { workspace.activeTabID == tab.id }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: sfSymbol(for: tab.fileNode.fileExtension))
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)

            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            if tab.isDirty {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
            }

            Button {
                workspace.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isActive ? 1 : 0)
            .frame(width: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.activateTab(tab)
        }
        .onHover { isHovered = $0 }
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
        case "java", "kt":      return "cup.and.saucer"
        case "xml", "plist":    return "chevron.left.forwardslash.chevron.right"
        default:                return "doc"
        }
    }
}
