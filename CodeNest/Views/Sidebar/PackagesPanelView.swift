//
//  PackagesPanelView.swift
//  CodeNest
//

import SwiftUI
import Foundation

struct PackagesPanelView: View {
    @Environment(WorkspaceState.self) var workspace
    @State private var packages: [Package] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if let root = workspace.rootNode {
                if packages.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No packages found")
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
                        ForEach(packages) { package in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(package.name)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(package.version)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
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
            loadPackages()
        }
        .onAppear {
            loadPackages()
        }
    }

    private func loadPackages() {
        guard let root = workspace.rootNode else {
            packages = []
            return
        }

        isLoading = true
        Task {
            let loaded = await PackageResolver.loadPackages(from: root.url)
            await MainActor.run {
                packages = loaded
                isLoading = false
            }
        }
    }
}

// MARK: - Package Model
struct Package: Identifiable {
    let id = UUID()
    let name: String
    let version: String
}

// MARK: - Package Resolver (supports Swift, Maven, Gradle)
enum PackageResolver {
    static func loadPackages(from rootURL: URL) async -> [Package] {
        // Try Swift Package Manager first
        if let swiftPackages = await loadSwiftPackages(from: rootURL) {
            return swiftPackages
        }

        // Try Maven
        if let mavenPackages = await loadMavenPackages(from: rootURL) {
            return mavenPackages
        }

        // Try Gradle
        if let gradlePackages = await loadGradlePackages(from: rootURL) {
            return gradlePackages
        }

        return []
    }

    // MARK: - Swift Package Manager
    private static func loadSwiftPackages(from rootURL: URL) async -> [Package]? {
        let packageResolvedURL = rootURL.appendingPathComponent("Package.resolved")

        guard FileManager.default.fileExists(atPath: packageResolvedURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: packageResolvedURL)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(PackageManifest.self, from: data)
            return manifest.pins.map { pin in
                Package(name: pin.identity, version: pin.state.version ?? "unknown")
            }
        } catch {
            return nil
        }
    }

    // MARK: - Maven
    private static func loadMavenPackages(from rootURL: URL) async -> [Package]? {
        let pomURL = rootURL.appendingPathComponent("pom.xml")
        guard FileManager.default.fileExists(atPath: pomURL.path) else {
            return nil
        }

        do {
            let content = try String(contentsOf: pomURL, encoding: .utf8)
            let parser = MavenPomParser()
            return parser.parseDependencies(from: content)
        } catch {
            return nil
        }
    }

    // MARK: - Gradle
    private static func loadGradlePackages(from rootURL: URL) async -> [Package]? {
        let buildGradleKtsURL = rootURL.appendingPathComponent("build.gradle.kts")
        let buildGradleURL = rootURL.appendingPathComponent("build.gradle")

        var content: String?
        var fileURL: URL?

        if FileManager.default.fileExists(atPath: buildGradleKtsURL.path) {
            content = try? String(contentsOf: buildGradleKtsURL, encoding: .utf8)
            fileURL = buildGradleKtsURL
        } else if FileManager.default.fileExists(atPath: buildGradleURL.path) {
            content = try? String(contentsOf: buildGradleURL, encoding: .utf8)
            fileURL = buildGradleURL
        }

        guard let content = content else {
            return nil
        }

        let parser = GradleBuildParser()
        return parser.parseDependencies(from: content)
    }
}

// MARK: - JSON Models (Swift)
private struct PackageManifest: Codable {
    let pins: [PackagePin]
}

private struct PackagePin: Codable {
    let identity: String
    let state: PackageState
}

private struct PackageState: Codable {
    let version: String?
    let branch: String?
    let revision: String?

    enum CodingKeys: String, CodingKey {
        case version
        case branch
        case revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        branch = try container.decodeIfPresent(String.self, forKey: .branch)
        revision = try container.decodeIfPresent(String.self, forKey: .revision)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(branch, forKey: .branch)
        try container.encodeIfPresent(revision, forKey: .revision)
    }
}

// MARK: - Maven POM Parser
private class MavenPomParser: NSObject, XMLParserDelegate {
    private var dependencies: [Package] = []
    private var currentElement = ""
    private var currentDependency: (groupId: String, artifactId: String, version: String) = ("", "", "")

    func parseDependencies(from pomXml: String) -> [Package] {
        guard let data = pomXml.data(using: .utf8) else { return [] }
        let parser = XMLParser(data: data)
        parser.delegate = self
        _ = parser.parse()
        return dependencies
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "groupId":
            currentDependency.groupId = trimmed
        case "artifactId":
            currentDependency.artifactId = trimmed
        case "version":
            currentDependency.version = trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "dependency" && !currentDependency.artifactId.isEmpty {
            let name = "\(currentDependency.groupId):\(currentDependency.artifactId)"
            let version = currentDependency.version.isEmpty ? "unknown" : currentDependency.version
            dependencies.append(Package(name: name, version: version))
            currentDependency = ("", "", "")
        }
    }
}

// MARK: - Gradle Build Parser
private class GradleBuildParser {
    func parseDependencies(from buildGradle: String) -> [Package] {
        var packages: [Package] = []

        // Pattern for dependencies: implementation, api, etc.
        // Examples:
        // - implementation 'org.springframework.boot:spring-boot-starter-web:3.0.0'
        // - implementation("org.springframework:spring-core:6.0.0")

        let patterns = [
            "(?:implementation|api|testImplementation|compileOnly)\\s+['\\\"]([^'\\\"]+)['\\\"]",
            "(?:implementation|api|testImplementation|compileOnly)\\(\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*\\)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(buildGradle.startIndex..<buildGradle.endIndex, in: buildGradle)
            let matches = regex.matches(in: buildGradle, options: [], range: range)

            for match in matches {
                if let range = Range(match.range(at: 1), in: buildGradle) {
                    let dependency = String(buildGradle[range])
                    let parts = dependency.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)

                    if parts.count >= 2 {
                        let name = "\(parts[0]):\(parts[1])"
                        let version = parts.count > 2 ? String(parts[2]) : "unknown"
                        packages.append(Package(name: name, version: version))
                    }
                }
            }
        }

        // Remove duplicates
        var seen = Set<String>()
        return packages.filter { package in
            let key = package.name
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}
