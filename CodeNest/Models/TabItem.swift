//
//  TabItem.swift
//  CodeNest
//

import Foundation

enum TabKind {
    case code
    case diff(content: String)
}

struct TabItem: Identifiable, Equatable {
    let id: UUID
    let fileNode: FileNode
    var content: String
    var isDirty: Bool = false
    var kind: TabKind = .code

    var title: String { fileNode.name }

    init(fileNode: FileNode, content: String = "", kind: TabKind = .code) {
        self.id = UUID()
        self.fileNode = fileNode
        self.content = content
        self.kind = kind
    }

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}
