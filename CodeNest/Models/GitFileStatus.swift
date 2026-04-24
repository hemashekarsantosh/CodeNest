import Foundation
import SwiftUI

enum GitStatusCode: Sendable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case unmodified

    nonisolated init?(from character: Character) {
        switch character {
        case "M":
            self = .modified
        case "A":
            self = .added
        case "D":
            self = .deleted
        case "R":
            self = .renamed
        case "?":
            self = .untracked
        case " ":
            self = .unmodified
        default:
            return nil
        }
    }

    nonisolated var badgeLabel: String {
        switch self {
        case .modified:
            return "M"
        case .added:
            return "A"
        case .deleted:
            return "D"
        case .renamed:
            return "R"
        case .untracked:
            return "U"
        case .unmodified:
            return ""
        }
    }

    nonisolated var badgeColor: Color {
        switch self {
        case .modified:
            return .orange
        case .added:
            return .green
        case .deleted:
            return .red
        case .renamed:
            return .blue
        case .untracked:
            return .gray
        case .unmodified:
            return .clear
        }
    }

    nonisolated var isTracked: Bool {
        switch self {
        case .untracked, .unmodified:
            return false
        default:
            return true
        }
    }
}

extension GitStatusCode: Equatable {
    nonisolated static func == (lhs: GitStatusCode, rhs: GitStatusCode) -> Bool {
        switch (lhs, rhs) {
        case (.modified, .modified), (.added, .added), (.deleted, .deleted),
             (.renamed, .renamed), (.untracked, .untracked), (.unmodified, .unmodified):
            return true
        default:
            return false
        }
    }
}

struct GitFileStatus: Identifiable, Sendable {
    let id: String // relative file path
    let path: String
    let indexStatus: GitStatusCode // staged (index vs HEAD)
    let worktreeStatus: GitStatusCode // unstaged (worktree vs index)

    nonisolated var isStaged: Bool {
        // True if there are staged changes for the file (indexStatus is not unmodified or untracked)
        switch indexStatus {
        case .modified, .added, .deleted, .renamed:
            return true
        default:
            return false
        }
    }

    nonisolated var displayCode: String {
        let index = indexStatus.badgeLabel
        let worktree = worktreeStatus.badgeLabel

        if !index.isEmpty {
            return index
        }
        return worktree.isEmpty ? " " : worktree
    }
}
