//
//  WorkspaceState.swift
//  CodeNest
//

import Foundation
import AppKit
import Observation

enum SidebarTab { case files, packages }

@Observable
@MainActor
final class WorkspaceState {

    // MARK: - Sidebar
    var sidebarTab: SidebarTab = .files

    // MARK: - File Tree
    var rootNode: FileNode?
    var selectedNode: FileNode?

    // MARK: - Tabs
    var openTabs: [TabItem] = []
    var activeTabID: UUID?

    var activeTab: TabItem? {
        openTabs.first { $0.id == activeTabID }
    }

    // MARK: - New Project Sheet
    var showNewProjectSheet: Bool = false

    // MARK: - Open Folder
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFolderURL(url)
    }

    func openFolderURL(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            SecurityScopedAccess.save(bookmark: bookmark)
        }

        rootNode = FileNode(url: url)
        openTabs = []
        activeTabID = nil
        selectedNode = nil
        loadChildren(of: rootNode!)
    }

    // MARK: - Create Project

    /// Local scaffold — used for Angular and React.
    func createProject(options: ProjectOptions, at parentURL: URL) {
        let projectURL = parentURL.appendingPathComponent(options.name)
        do {
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        } catch {
            return
        }

        for (relativePath, content) in options.scaffold.files(options: options) {
            let fileURL = projectURL.appendingPathComponent(relativePath)
            let dir = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(content.utf8))
        }

        openFolderURL(projectURL)
    }

    /// Spring Boot via Spring Initializr — downloads and extracts the zip, then opens the project.
    /// `projectName` is the artifact id / base directory inside the zip.
    func openProjectFromExtractedZip(parentURL: URL, projectName: String) {
        let projectURL = parentURL.appendingPathComponent(projectName)
        guard FileManager.default.fileExists(atPath: projectURL.path) else { return }
        openFolderURL(projectURL)
    }

    // MARK: - File Tree Loading
    func loadChildren(of node: FileNode) {
        guard node.isDirectory else { return }
        Task {
            let children = await FileLoader.loadChildren(of: node.url)
            node.children = children
        }
    }

    // MARK: - File / Folder Mutations

    func createFile(named name: String, in parent: FileNode, content: String? = nil) {
        let url = parent.url.appendingPathComponent(name)
        let data = content.flatMap { $0.isEmpty ? nil : Data($0.utf8) }
        guard FileManager.default.createFile(atPath: url.path, contents: data) else { return }
        let node = FileNode(url: url)
        insertSorted(node, into: parent)
        openFile(node)
    }

    func createFolder(named name: String, in parent: FileNode) {
        let url = parent.url.appendingPathComponent(name)
        guard (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)) != nil else { return }
        let node = FileNode(url: url)
        node.children = []
        insertSorted(node, into: parent)
    }

    func delete(node: FileNode, from parent: FileNode) {
        guard (try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)) != nil else { return }
        parent.children?.removeAll { $0.url == node.url }
        if node.isDirectory {
            openTabs.removeAll { $0.fileNode.url.path.hasPrefix(node.url.path + "/") }
        } else {
            openTabs.removeAll { $0.fileNode.url == node.url }
        }
        if !openTabs.contains(where: { $0.id == activeTabID }) {
            activeTabID = openTabs.last?.id
        }
    }

    private func insertSorted(_ node: FileNode, into parent: FileNode) {
        guard parent.children != nil else { return }
        parent.children!.append(node)
        parent.children!.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Open File in Tab
    func openFile(_ node: FileNode) {
        guard !node.isDirectory else { return }

        if let existing = openTabs.first(where: { $0.fileNode.url == node.url }) {
            activeTabID = existing.id
            return
        }

        Task {
            let content = await FileLoader.loadContent(of: node.url)
            let tab = TabItem(fileNode: node, content: content)
            openTabs.append(tab)
            activeTabID = tab.id
        }
    }

    // MARK: - Tab Management
    func closeTab(_ tab: TabItem) {
        guard let idx = openTabs.firstIndex(of: tab) else { return }
        openTabs.remove(at: idx)
        if activeTabID == tab.id {
            if openTabs.isEmpty {
                activeTabID = nil
            } else {
                let newIdx = max(0, idx - 1)
                activeTabID = openTabs[newIdx].id
            }
        }
    }

    func activateTab(_ tab: TabItem) {
        activeTabID = tab.id
    }

    // MARK: - Open File
    func openFileFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open File"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = url.startAccessingSecurityScopedResource()
        let node = FileNode(url: url)
        openFile(node)
    }

    // MARK: - Help
    var isHelpPresented: Bool = false
    var helpTab: HelpTab = .shortcuts

    func openHelp(tab: HelpTab = .shortcuts) {
        helpTab = tab
        isHelpPresented = true
    }

    // MARK: - Bottom Panel
    var selectedBottomTab: BottomTab = .output
    var isBottomPanelVisible: Bool = false
    var terminalSession: ShellSession?

    // MARK: - Run Code
    var runOutput: String = ""
    var isRunning: Bool = false

    func runActiveTab() {
        guard let tab = activeTab else { return }
        let ext = tab.fileNode.fileExtension
        guard ext == "swift" else {
            if selectedBottomTab == .terminal {
                terminalSession?.send("echo 'Cannot run .\(ext) files.'\n")
            } else {
                runOutput = "Cannot run .\(ext) files.\n"
            }
            return
        }

        let content = tab.content
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)

        guard (try? content.write(to: tmp, atomically: true, encoding: .utf8)) != nil else { return }

        if selectedBottomTab == .terminal {
            isBottomPanelVisible = true
            terminalSession?.send("swift \(tmp.path) && rm -f \(tmp.path)\n")
        } else {
            isRunning = true
            isBottomPanelVisible = true
            runOutput = ""
            Task.detached {
                let output = await Self.captureOutput(tmpURL: tmp)
                await MainActor.run {
                    self.runOutput = output
                    self.isRunning = false
                }
            }
        }
    }

    private static func captureOutput(tmpURL: URL) async -> String {
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [tmpURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error running process: \(error.localizedDescription)\n"
        }
    }

    // MARK: - Workspace Restoration
    func restoreWorkspaceIfNeeded() {
        guard let bookmark = SecurityScopedAccess.load() else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        _ = url.startAccessingSecurityScopedResource()
        if isStale {
            if let fresh = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                SecurityScopedAccess.save(bookmark: fresh)
            }
        }

        rootNode = FileNode(url: url)
        loadChildren(of: rootNode!)
        // Note: bookmark already saved above; don't call openFolderURL to avoid double-saving
    }
}
