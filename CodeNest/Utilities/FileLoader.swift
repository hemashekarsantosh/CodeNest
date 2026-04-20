//
//  FileLoader.swift
//  CodeNest
//

import Foundation

enum FileLoader {
    static func loadChildren(of url: URL) async -> [FileNode] {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return contents
                .map { FileNode(url: $0) }
                .sorted {
                    if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
        }.value
    }

    static func loadContent(of url: URL) async -> String {
        return await Task.detached(priority: .userInitiated) {
            (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }.value
    }
}
