//
//  SpringInitializrService.swift
//  CodeNest
//
//  Fetches metadata and generates projects via https://start.spring.io
//

import Foundation

// MARK: - Metadata models

struct InitializrVersionOption: Identifiable, Hashable {
    let id: String      // e.g. "3.4.4" or "21"
    let name: String    // human-readable label
    let isDefault: Bool
}

struct InitializrDependency: Identifiable, Hashable {
    let id: String          // e.g. "web"
    let name: String        // e.g. "Spring Web"
    let description: String
}

struct InitializrDependencyGroup: Identifiable {
    let id: String                          // group name used as stable id
    let name: String                        // e.g. "Web", "SQL"
    let dependencies: [InitializrDependency]
}

struct InitializrMetadata {
    let bootVersions: [InitializrVersionOption]
    let javaVersions: [InitializrVersionOption]
    let dependencyGroups: [InitializrDependencyGroup]
}

// MARK: - Error

enum SpringInitializrError: LocalizedError {
    case invalidResponse
    case parseError
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:          return "Unexpected response from start.spring.io"
        case .parseError:               return "Could not parse Spring Initializr metadata"
        case .extractionFailed(let s):  return "Failed to extract project: \(s)"
        }
    }
}

// MARK: - Service

struct SpringInitializrService {

    static let baseURL = "https://start.spring.io"

    // MARK: Fetch metadata

    static func fetchMetadata() async throws -> InitializrMetadata {
        guard let url = URL(string: baseURL) else { throw SpringInitializrError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.initializr.v2.2+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpringInitializrError.invalidResponse
        }

        return try parseMetadata(from: data)
    }

    // MARK: Generate project (download + extract zip)

    static func generateProject(options: ProjectOptions, into destinationURL: URL) async throws {
        let zipURL = try await downloadZip(options: options)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try extractZip(at: zipURL, into: destinationURL)
    }

    // MARK: Build starter.zip URL (public for debugging / preview)

    static func generateURL(for options: ProjectOptions) -> URL? {
        var components = URLComponents(string: "\(baseURL)/starter.zip")
        let type: String = options.buildTool == .maven ? "maven-project" : "gradle-project"
        let group    = options.groupId.isEmpty ? "com.example" : options.groupId
        let artifact = options.name.isEmpty   ? "demo"         : options.name

        var items: [URLQueryItem] = [
            URLQueryItem(name: "type",        value: type),
            URLQueryItem(name: "language",    value: "java"),
            URLQueryItem(name: "bootVersion", value: options.springBootVersion),
            URLQueryItem(name: "baseDir",     value: artifact),
            URLQueryItem(name: "groupId",     value: group),
            URLQueryItem(name: "artifactId",  value: artifact),
            URLQueryItem(name: "name",        value: artifact),
            URLQueryItem(name: "description", value: "\(artifact) Spring Boot project"),
            URLQueryItem(name: "packageName", value: "\(group).\(artifact)"),
            URLQueryItem(name: "packaging",   value: "jar"),
            URLQueryItem(name: "javaVersion", value: options.javaVersion),
        ]

        for dep in options.selectedDependencies {
            items.append(URLQueryItem(name: "dependencies", value: dep))
        }

        components?.queryItems = items
        return components?.url
    }

    // MARK: - Private

    private static func parseMetadata(from data: Data) throws -> InitializrMetadata {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpringInitializrError.parseError
        }

        let bootVersions  = parseVersionGroup(json["bootVersion"])
        let javaVersions  = parseVersionGroup(json["javaVersion"])
        let depGroups     = parseDependencyGroups(json["dependencies"])

        guard !bootVersions.isEmpty, !javaVersions.isEmpty else {
            throw SpringInitializrError.parseError
        }

        return InitializrMetadata(
            bootVersions: bootVersions,
            javaVersions: javaVersions,
            dependencyGroups: depGroups
        )
    }

    private static func parseVersionGroup(_ raw: Any?) -> [InitializrVersionOption] {
        guard let group  = raw as? [String: Any],
              let values = group["values"] as? [[String: Any]] else { return [] }
        let defaultID = group["default"] as? String ?? ""
        return values.compactMap { item in
            guard let id   = item["id"]   as? String,
                  let name = item["name"] as? String else { return nil }
            return InitializrVersionOption(id: id, name: name, isDefault: id == defaultID)
        }
    }

    private static func parseDependencyGroups(_ raw: Any?) -> [InitializrDependencyGroup] {
        guard let root   = raw as? [String: Any],
              let groups = root["values"] as? [[String: Any]] else { return [] }
        return groups.compactMap { group in
            guard let name   = group["name"]   as? String,
                  let values = group["values"] as? [[String: Any]] else { return nil }
            let deps = values.compactMap { dep -> InitializrDependency? in
                guard let id   = dep["id"]   as? String,
                      let name = dep["name"] as? String else { return nil }
                let desc = dep["description"] as? String ?? ""
                return InitializrDependency(id: id, name: name, description: desc)
            }
            return deps.isEmpty ? nil : InitializrDependencyGroup(id: name, name: name, dependencies: deps)
        }
    }

    private static func downloadZip(options: ProjectOptions) async throws -> URL {
        guard let url = generateURL(for: options) else {
            throw SpringInitializrError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpringInitializrError.invalidResponse
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        try data.write(to: tmp)
        return tmp
    }

    private static func extractZip(at zipURL: URL, into destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", destination.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SpringInitializrError.extractionFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw SpringInitializrError.extractionFailed(msg)
        }
    }
}
