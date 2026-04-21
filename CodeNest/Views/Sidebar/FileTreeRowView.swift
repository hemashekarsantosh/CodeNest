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
                    Label {
                        Text(node.name)
                    } icon: {
                        Image(systemName: sfSymbol(for: node.fileExtension))
                            .foregroundStyle(iconColor(for: node.fileExtension))
                    }
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
            CreationSheet(mode: mode, name: $newItemName) { content in
                if mode == .file {
                    workspace.createFile(named: newItemName, in: node, content: content)
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

    private func iconColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "swift":                       return .orange
        case "js":                          return Color(red: 0.95, green: 0.77, blue: 0.06)
        case "ts":                          return .blue
        case "json":                        return .yellow
        case "md", "markdown":              return .gray
        case "html", "htm":                 return Color(red: 0.9, green: 0.45, blue: 0.1)
        case "css":                         return .blue
        case "py":                          return Color(red: 0.22, green: 0.56, blue: 0.80)
        case "sh", "zsh":                   return .green
        case "png", "jpg", "jpeg",
             "gif", "svg", "webp":          return .purple
        case "pdf":                         return .red
        case "java", "kt":                  return Color(red: 0.8, green: 0.3, blue: 0.1)
        case "xml", "plist":                return .teal
        default:                            return .secondary
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
        case "java", "kt":      return "cup.and.saucer"
        case "xml", "plist":    return "chevron.left.forwardslash.chevron.right"
        default:                return "doc"
        }
    }
}

struct CreationSheet: View {
    let mode: CreationMode
    @Binding var name: String
    let onCreate: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: FileTemplate? = nil
    @State private var includeMain: Bool = false

    private var currentExtension: String {
        name.contains(".") ? String(name.split(separator: ".").last ?? "") : ""
    }

    private var templates: [FileTemplate]? {
        guard mode == .file else { return nil }
        return FileTemplate.templates(for: currentExtension)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField(mode.placeholder, text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: currentExtension) { _, _ in
                        // Reset template selection when extension changes
                        selectedTemplate = templates?.first
                    }
            }

            if let templates {
                VStack(alignment: .leading, spacing: 6) {
                    Text("File Type")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedTemplate) {
                        ForEach(templates) { template in
                            Text(template.label).tag(Optional(template))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onAppear {
                        if selectedTemplate == nil || !templates.contains(where: { $0.id == selectedTemplate?.id }) {
                            selectedTemplate = templates.first
                            includeMain = false
                        }
                    }
                    .onChange(of: selectedTemplate) { _, _ in
                        includeMain = false
                    }
                }

                if selectedTemplate?.makeContentWithMain != nil {
                    Toggle("Generate main method", isOn: $includeMain)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let content = selectedTemplate.map { tmpl in
                        let baseName = name.contains(".")
                            ? String(name.split(separator: ".").dropLast().joined(separator: "."))
                            : name
                        if includeMain, let withMain = tmpl.makeContentWithMain {
                            return withMain(baseName)
                        }
                        return tmpl.makeContent(baseName)
                    }
                    onCreate(content)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
