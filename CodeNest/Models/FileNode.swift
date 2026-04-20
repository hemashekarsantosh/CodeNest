//
//  FileNode.swift
//  CodeNest
//

import Foundation
import Observation

@Observable
final class FileNode: Identifiable, @unchecked Sendable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    var fileExtension: String { url.pathExtension }

    var children: [FileNode]?
    var isExpanded: Bool = false

    nonisolated init(url: URL) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
    }
}
