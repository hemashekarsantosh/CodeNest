//
//  SecurityScopedAccess.swift
//  CodeNest
//

import Foundation

enum SecurityScopedAccess {
    private static let key = "workspaceBookmark"

    static func save(bookmark: Data) {
        UserDefaults.standard.set(bookmark, forKey: key)
    }

    static func load() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
