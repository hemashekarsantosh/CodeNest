//
//  TabItem.swift
//  CodeNest
//

import Foundation

struct TabItem: Identifiable, Equatable {
    let id: UUID
    let fileNode: FileNode
    var content: String
    var isDirty: Bool = false

    var title: String { fileNode.name }

    init(fileNode: FileNode, content: String = "") {
        self.id = UUID()
        self.fileNode = fileNode
        self.content = content
    }

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}
