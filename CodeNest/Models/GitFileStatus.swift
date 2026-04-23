import Foundation
import SwiftUI

enum GitStatusCode: Equatable, Sendable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case unmodified

    init?(from character: Character) {
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

    var badgeLabel: String {
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

    var badgeColor: Color {
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

    var isTracked: Bool {
        self != .untracked && self != .unmodified
    }
}

struct GitFileStatus: Identifiable, Sendable {
    let id: String // relative file path
    let path: String
    let indexStatus: GitStatusCode // staged (index vs HEAD)
    let worktreeStatus: GitStatusCode // unstaged (worktree vs index)

    var isStaged: Bool {
        indexStatus != .unmodified && indexStatus != .untracked
    }

    var displayCode: String {
        let index = indexStatus.badgeLabel
        let worktree = worktreeStatus.badgeLabel

        if !index.isEmpty {
            return index
        }
        return worktree.isEmpty ? " " : worktree
    }
}
