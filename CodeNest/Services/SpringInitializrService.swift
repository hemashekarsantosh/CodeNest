//
//  SpringInitializrService.swift
//  CodeNest
//
//  Fetches metadata and generates projects via https://start.spring.io
//

import Foundation

// MARK: - Models

struct InitializrVersionOption: Identifiable, Hashable {
    let id: String    // e.g. "3.2.2" or "21"
    let name: String  // human-readable label
    let isDefault: Bool
}

struct DependencyOption: Identifiable, Hashable {
    let id: String        // e.g. "web", "data-jpa"
    let name: String      // e.g. "Spring Web"
    let description: String
}

struct DependencyCategory: Identifiable {
    let id: String                       // lowercased name, spaces→dashes
    let name: String                     // e.g. "Web", "SQL"
    let dependencies: [DependencyOption]
}

struct InitializrMetadata {
    let bootVersions: [InitializrVersionOption]
    let javaVersions: [InitializrVersionOption]
    let dependencyCategories: [DependencyCategory]
}

// MARK: - Service

enum SpringInitializrError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case parseError
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let e):    return "Network error: \(e.localizedDescription)"
        case .invalidResponse:        return "Unexpected response from start.spring.io"
        case .parseError:             return "Could not parse Spring Initializr metadata"
        case .extractionFailed(let s): return "Failed to extract project: \(s)"
        }
    }
}

struct SpringInitializrService {

    static let baseURL = "https://start.spring.io"

    // MARK: - Fetch Metadata

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

    private static func parseMetadata(from data: Data) throws -> InitializrMetadata {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpringInitializrError.parseError
        }

        let bootVersions = parseVersionGroup(json["bootVersion"])
        let javaVersions = parseVersionGroup(json["javaVersion"])

        guard !bootVersions.isEmpty, !javaVersions.isEmpty else {
            throw SpringInitializrError.parseError
        }

        let dependencyCategories = parseDependencyCategories(json["dependencies"])

        return InitializrMetadata(
            bootVersions: bootVersions,
            javaVersions: javaVersions,
            dependencyCategories: dependencyCategories
        )
    }

    private static func parseVersionGroup(_ raw: Any?) -> [InitializrVersionOption] {
        guard let group = raw as? [String: Any],
              let values = group["values"] as? [[String: Any]] else { return [] }
        let defaultID = group["default"] as? String ?? ""
        return values.compactMap { item in
            guard let id = item["id"] as? String, let name = item["name"] as? String else { return nil }
            return InitializrVersionOption(id: id, name: name, isDefault: id == defaultID)
        }
    }

    private static func parseDependencyCategories(_ raw: Any?) -> [DependencyCategory] {
        guard let root = raw as? [String: Any],
              let categoryArray = root["values"] as? [[String: Any]] else { return [] }

        return categoryArray.compactMap { categoryDict -> DependencyCategory? in
            guard let categoryName = categoryDict["name"] as? String,
                  let depArray = categoryDict["values"] as? [[String: Any]] else { return nil }

            let categoryId = categoryName
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")

            let deps: [DependencyOption] = depArray.compactMap { depDict in
                guard let id = depDict["id"] as? String,
                      let name = depDict["name"] as? String else { return nil }
                let description = depDict["description"] as? String ?? ""
                return DependencyOption(id: id, name: name, description: description)
            }

            guard !deps.isEmpty else { return nil }
            return DependencyCategory(id: categoryId, name: categoryName, dependencies: deps)
        }
    }

    // MARK: - Generate Project (download zip)

    /// Downloads a Spring Boot project zip from start.spring.io and extracts it into `destinationURL`.
    /// `destinationURL` should be the *parent* directory; the zip itself contains a top-level folder named `baseDir`.
    static func generateProject(options: ProjectOptions, into destinationURL: URL) async throws {
        let zipURL = try await downloadZip(options: options)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try extractZip(at: zipURL, into: destinationURL)
    }

    // MARK: - Build URL

    static func generateURL(for options: ProjectOptions) -> URL? {
        var components = URLComponents(string: "\(baseURL)/starter.zip")
        let type: String = options.buildTool == .maven ? "maven-project" : "gradle-project"
        let group = options.groupId.isEmpty ? "com.example" : options.groupId
        let artifact = options.name.isEmpty ? "demo" : options.name
        let packageName = "\(group).\(artifact)"

        components?.queryItems = [
            URLQueryItem(name: "type",        value: type),
            URLQueryItem(name: "language",    value: "java"),
            URLQueryItem(name: "bootVersion", value: options.springBootVersion),
            URLQueryItem(name: "baseDir",     value: artifact),
            URLQueryItem(name: "groupId",     value: group),
            URLQueryItem(name: "artifactId",  value: artifact),
            URLQueryItem(name: "name",        value: artifact),
            URLQueryItem(name: "description", value: "\(artifact) Spring Boot project"),
            URLQueryItem(name: "packageName", value: packageName),
            URLQueryItem(name: "packaging",   value: "jar"),
            URLQueryItem(name: "javaVersion", value: options.javaVersion),
        ]

        if !options.selectedDependencies.isEmpty {
            let depsValue = options.selectedDependencies.sorted().joined(separator: ",")
            components?.queryItems?.append(URLQueryItem(name: "dependencies", value: depsValue))
        }

        return components?.url
    }

    // MARK: - Private Helpers

    private static func downloadZip(options: ProjectOptions) async throws -> URL {
        guard let url = generateURL(for: options) else {
            throw SpringInitializrError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpringInitializrError.invalidResponse
        }

        let tmpZip = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        try data.write(to: tmpZip)
        return tmpZip
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
