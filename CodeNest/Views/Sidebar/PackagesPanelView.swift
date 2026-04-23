//
//  PackagesPanelView.swift
//  CodeNest
//

import SwiftUI

struct PackagesPanelView: View {
    @Environment(WorkspaceState.self) var workspace
    @State private var sourceRoots: [SourceRoot] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if let root = workspace.rootNode {
                if sourceRoots.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No source structure found")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    List {
                        ProgressView("Loading...")
                    }
                    .listStyle(.sidebar)
                } else {
                    List {
                        ForEach(sourceRoots, id: \.label) { sourceRoot in
                            PackageRowView(node: sourceRoot.node, sourceRootLabel: sourceRoot.label)
                        }
                    }
                    .listStyle(.sidebar)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No folder open")
                        .foregroundStyle(.secondary)
                    Button("Open Folder...") {
                        workspace.openFolder()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: workspace.rootNode?.url) {
            loadSourceRoots()
        }
        .onAppear {
            loadSourceRoots()
        }
    }

    private func loadSourceRoots() {
        guard let root = workspace.rootNode else {
            sourceRoots = []
            return
        }

        isLoading = true
        Task {
            let roots = await ProjectTypeDetector.detectSourceRoots(from: root.url)
            await MainActor.run {
                sourceRoots = roots
                isLoading = false
            }
        }
    }
}

// MARK: - Source Root Model
struct SourceRoot: Identifiable {
    let id = UUID()
    let label: String
    let node: FileNode
}

// MARK: - Package Row View
struct PackageRowView: View {
    @Environment(WorkspaceState.self) var workspace
    @Bindable var node: FileNode
    let sourceRootLabel: String

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: $node.isExpanded,
                content: {
                    if let children = node.children {
                        if children.isEmpty {
                            Text("Empty")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        } else {
                            ForEach(children) { child in
                                PackageRowView(node: child, sourceRootLabel: sourceRootLabel)
                            }
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .leading)
                    }
                },
                label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(displayLabel)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
            )
            .onChange(of: node.isExpanded) { _, expanded in
                if expanded && node.children == nil {
                    workspace.loadChildren(of: node)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                workspace.selectedNode = node
            })
        } else {
            Button(action: {
                workspace.openFile(node)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(node.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onTapGesture {
                workspace.selectedNode = node
            }
        }
    }

    // Java package label compression: collapse single-child directory chains
    private var displayLabel: String {
        var current = node
        var path = [current.name]

        while let children = current.children,
              children.count == 1,
              let onlyChild = children.first,
              onlyChild.isDirectory {
            path.append(onlyChild.name)
            current = onlyChild
        }

        return path.joined(separator: ".")
    }
}

// MARK: - Project Type Detection
enum ProjectTypeDetector {
    static func detectSourceRoots(from rootURL: URL) async -> [SourceRoot] {
        // Check for Java project (Maven or Gradle)
        if isJavaProject(at: rootURL) {
            return await loadJavaSourceRoots(from: rootURL)
        }

        // Check for Swift project
        if isSwiftProject(at: rootURL) {
            return await loadSwiftSourceRoots(from: rootURL)
        }

        // Check for Node.js project
        if isNodeProject(at: rootURL) {
            return await loadNodeSourceRoots(from: rootURL)
        }

        return []
    }

    // MARK: - Java Detection
    private static func isJavaProject(at url: URL) -> Bool {
        let hasPom = FileManager.default.fileExists(atPath: url.appendingPathComponent("pom.xml").path)
        let hasBuildGradle = FileManager.default.fileExists(atPath: url.appendingPathComponent("build.gradle").path)
        let hasBuildGradleKts = FileManager.default.fileExists(atPath: url.appendingPathComponent("build.gradle.kts").path)
        return hasPom || hasBuildGradle || hasBuildGradleKts
    }

    private static func loadJavaSourceRoots(from rootURL: URL) async -> [SourceRoot] {
        var roots: [SourceRoot] = []

        let mainJavaURL = rootURL.appendingPathComponent("src/main/java")
        if FileManager.default.fileExists(atPath: mainJavaURL.path) {
            let mainNode = FileNode(url: mainJavaURL)
            let children = await FileLoader.loadChildren(of: mainJavaURL)
            mainNode.children = children
            roots.append(SourceRoot(label: "main", node: mainNode))
        }

        let testJavaURL = rootURL.appendingPathComponent("src/test/java")
        if FileManager.default.fileExists(atPath: testJavaURL.path) {
            let testNode = FileNode(url: testJavaURL)
            let children = await FileLoader.loadChildren(of: testJavaURL)
            testNode.children = children
            roots.append(SourceRoot(label: "test", node: testNode))
        }

        let resourcesURL = rootURL.appendingPathComponent("src/main/resources")
        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            let resourcesNode = FileNode(url: resourcesURL)
            let children = await FileLoader.loadChildren(of: resourcesURL)
            resourcesNode.children = children
            roots.append(SourceRoot(label: "resources", node: resourcesNode))
        }

        return roots
    }

    // MARK: - Swift Detection
    private static func isSwiftProject(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path)
    }

    private static func loadSwiftSourceRoots(from rootURL: URL) async -> [SourceRoot] {
        let sourcesURL = rootURL.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sourcesURL.path) else {
            return []
        }

        let sourcesNode = FileNode(url: sourcesURL)
        let children = await FileLoader.loadChildren(of: sourcesURL)
        sourcesNode.children = children
        return [SourceRoot(label: "Sources", node: sourcesNode)]
    }

    // MARK: - Node Detection
    private static func isNodeProject(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("package.json").path)
    }

    private static func loadNodeSourceRoots(from rootURL: URL) async -> [SourceRoot] {
        let srcURL = rootURL.appendingPathComponent("src")
        if FileManager.default.fileExists(atPath: srcURL.path) {
            let srcNode = FileNode(url: srcURL)
            let children = await FileLoader.loadChildren(of: srcURL)
            srcNode.children = children
            return [SourceRoot(label: "src", node: srcNode)]
        }

        // Fallback to root if src/ doesn't exist
        let rootNode = FileNode(url: rootURL)
        let children = await FileLoader.loadChildren(of: rootURL)
        rootNode.children = children
        return [SourceRoot(label: "root", node: rootNode)]
    }
}
