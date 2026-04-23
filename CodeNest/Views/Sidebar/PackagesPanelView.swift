//
//  PackagesPanelView.swift
//  CodeNest
//

import SwiftUI

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

// MARK: - Package.resolved Parser
enum PackageResolver {
    static func loadPackages(from rootURL: URL) async -> [Package] {
        let packageResolvedURL = rootURL.appendingPathComponent("Package.resolved")

        guard FileManager.default.fileExists(atPath: packageResolvedURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: packageResolvedURL)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(PackageManifest.self, from: data)
            return manifest.pins.map { pin in
                Package(name: pin.identity, version: pin.state.version ?? "unknown")
            }
        } catch {
            return []
        }
    }
}

// MARK: - JSON Models
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
