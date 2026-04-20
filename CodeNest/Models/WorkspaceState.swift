//
//  WorkspaceState.swift
//  CodeNest
//

import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class WorkspaceState {

    // MARK: - File Tree
    var rootNode: FileNode?
    var selectedNode: FileNode?

    // MARK: - Tabs
    var openTabs: [TabItem] = []
    var activeTabID: UUID?

    var activeTab: TabItem? {
        openTabs.first { $0.id == activeTabID }
    }

    // MARK: - Open Folder
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }

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

    // MARK: - File Tree Loading
    func loadChildren(of node: FileNode) {
        guard node.isDirectory else { return }
        Task {
            let children = await FileLoader.loadChildren(of: node.url)
            node.children = children
        }
    }

    // MARK: - File / Folder Mutations

    func createFile(named name: String, in parent: FileNode) {
        let url = parent.url.appendingPathComponent(name)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return }
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
    }
}
