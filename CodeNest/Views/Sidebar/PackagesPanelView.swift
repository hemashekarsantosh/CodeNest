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
                        ForEach(sourceRoots) { sourceRoot in
                            PackageRowView(sourceRoot: sourceRoot, sourceRootLabel: sourceRoot.label)
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
    let node: FileNode?
    let children: [SourceRoot]
    let sourceType: SourceType?
    
    init(label: String, node: FileNode, sourceType: SourceType? = nil) {
        self.label = label
        self.node = node
        self.children = []
        self.sourceType = sourceType
    }
    
    init(label: String, children: [SourceRoot], sourceType: SourceType? = nil) {
        self.label = label
        self.node = nil
        self.children = children
        self.sourceType = sourceType
    }
}

enum SourceType {
    case main
    case test
    case resources
    case testResources
    
    var color: Color {
        switch self {
        case .main: return .blue
        case .test: return .green
        case .resources: return .purple
        case .testResources: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .main: return "folder.fill"
        case .test: return "flask.fill"
        case .resources: return "doc.fill"
        case .testResources: return "doc.fill"
        }
    }
}

// MARK: - Package Row View
struct PackageRowView: View {
    @Environment(WorkspaceState.self) var workspace
    let sourceRoot: SourceRoot
    let sourceRootLabel: String

    var body: some View {
        if let node = sourceRoot.node {
            // Leaf node with actual file system content
            renderNode(node, sourceType: sourceRoot.sourceType)
        } else {
            // Group node
            DisclosureGroup {
                ForEach(sourceRoot.children) { child in
                    PackageRowView(sourceRoot: child, sourceRootLabel: sourceRootLabel)
                }
            } label: {
                HStack(spacing: 4) {
                    if let sourceType = sourceRoot.sourceType {
                        Image(systemName: sourceType.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(sourceType.color)
                    } else {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text(sourceRoot.label)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderNode(_ node: FileNode, sourceType: SourceType?) -> some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { node.isExpanded = $0 }
                ),
                content: {
                    if let children = node.children {
                        if children.isEmpty {
                            Text("Empty")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        } else {
                            ForEach(children) { child in
                                PackageRowView(sourceRoot: SourceRoot(label: child.name, node: child, sourceType: sourceType), sourceRootLabel: sourceRootLabel)
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
                            .foregroundStyle(sourceType?.color ?? .orange)
                        Text(displayLabel(for: node))
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
                    Image(systemName: fileIcon(for: node.name))
                        .font(.system(size: 10))
                        .foregroundStyle(sourceType?.color ?? .secondary)
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
    private func displayLabel(for node: FileNode) -> String {
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
    
    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "java": return "doc.text.fill"
        case "kt", "kts": return "doc.text.fill"
        case "xml": return "doc.badge.gearshape"
        case "properties": return "doc.text"
        case "json": return "curlybraces"
        case "yml", "yaml": return "doc.text"
        default: return "doc"
        }
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
        var mainEntries: [(String, SourceRoot)] = []
        var testEntries: [(String, SourceRoot)] = []
        var resourcesChildren: [SourceRoot] = []
        var testResourcesChildren: [SourceRoot] = []

        // Helper to process a given source directory (java or kotlin)
        func processSourceDir(baseURL: URL, sourceType: SourceType, collectInto entries: inout [(String, SourceRoot)]) async {
            guard FileManager.default.fileExists(atPath: baseURL.path) else { return }
            let children = await FileLoader.loadChildren(of: baseURL)
            for child in children {
                // Compute compressed package label like IntelliJ (e.g. com.example)
                let childURL = baseURL.appendingPathComponent(child.name)
                let compressed = compressedPackageLabel(startingAt: childURL)
                let sr = SourceRoot(label: child.name, node: child, sourceType: sourceType)
                entries.append((compressed, sr))
            }
        }

        // main/java and main/kotlin
        let mainJavaURL = rootURL.appendingPathComponent("src/main/java")
        let mainKotlinURL = rootURL.appendingPathComponent("src/main/kotlin")
        await processSourceDir(baseURL: mainJavaURL, sourceType: .main, collectInto: &mainEntries)
        await processSourceDir(baseURL: mainKotlinURL, sourceType: .main, collectInto: &mainEntries)

        // test/java and test/kotlin
        let testJavaURL = rootURL.appendingPathComponent("src/test/java")
        let testKotlinURL = rootURL.appendingPathComponent("src/test/kotlin")
        await processSourceDir(baseURL: testJavaURL, sourceType: .test, collectInto: &testEntries)
        await processSourceDir(baseURL: testKotlinURL, sourceType: .test, collectInto: &testEntries)

        // Resources
        let resourcesURL = rootURL.appendingPathComponent("src/main/resources")
        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            let children = await FileLoader.loadChildren(of: resourcesURL)
            for child in children {
                resourcesChildren.append(SourceRoot(label: child.name, node: child, sourceType: .resources))
            }
        }
        let testResourcesURL = rootURL.appendingPathComponent("src/test/resources")
        if FileManager.default.fileExists(atPath: testResourcesURL.path) {
            let children = await FileLoader.loadChildren(of: testResourcesURL)
            for child in children {
                testResourcesChildren.append(SourceRoot(label: child.name, node: child, sourceType: .testResources))
            }
        }

        // Merge packages IntelliJ-style: group by compressed package name, then by source type
        var packageMap: [String: [SourceRoot]] = [:]
        for (label, root) in mainEntries { packageMap[label, default: []].append(root) }
        for (label, root) in testEntries { packageMap[label, default: []].append(root) }

        var roots: [SourceRoot] = []

        for (packageName, sources) in packageMap.sorted(by: { $0.key < $1.key }) {
            // Always present packages grouped under the compressed label, even if only one source exists.
            roots.append(SourceRoot(label: packageName, children: sources))
        }

        // Add resources separately at the end
        if !resourcesChildren.isEmpty {
            roots.append(SourceRoot(label: "resources", children: resourcesChildren, sourceType: .resources))
        }
        if !testResourcesChildren.isEmpty {
            roots.append(SourceRoot(label: "test resources", children: testResourcesChildren, sourceType: .testResources))
        }

        return roots
    }

    /// Computes a compressed package label by walking single-child directory chains.
    /// For example, a directory structure com/example/app will yield "com.example.app".
    private static func compressedPackageLabel(startingAt url: URL) -> String {
        var components: [String] = [url.lastPathComponent]
        var current = url
        let fm = FileManager.default

        while true {
            guard let items = try? fm.contentsOfDirectory(at: current, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                break
            }
            var subdirs: [URL] = []
            var hasFiles = false
            for item in items {
                if let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory), isDir == true {
                    subdirs.append(item)
                } else {
                    hasFiles = true
                }
            }
            // Only compress when there is exactly one subdirectory and no files in the current directory
            if subdirs.count == 1 && hasFiles == false {
                current = subdirs[0]
                components.append(current.lastPathComponent)
            } else {
                break
            }
        }

        return components.joined(separator: ".")
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

        let children = await FileLoader.loadChildren(of: sourcesURL)
        return children.map { SourceRoot(label: $0.name, node: $0) }
    }

    // MARK: - Node Detection
    private static func isNodeProject(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("package.json").path)
    }

    private static func loadNodeSourceRoots(from rootURL: URL) async -> [SourceRoot] {
        let srcURL = rootURL.appendingPathComponent("src")
        if FileManager.default.fileExists(atPath: srcURL.path) {
            let children = await FileLoader.loadChildren(of: srcURL)
            return children.map { SourceRoot(label: $0.name, node: $0) }
        }

        // Fallback to root if src/ doesn't exist
        let children = await FileLoader.loadChildren(of: rootURL)
        return children.map { SourceRoot(label: $0.name, node: $0) }
    }
}

