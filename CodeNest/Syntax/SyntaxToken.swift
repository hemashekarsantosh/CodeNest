//
//  SyntaxToken.swift
//  CodeNest
//

import AppKit

enum TokenType {
    case keyword, string, comment, number, type, attribute, plain
}

enum HighlightTheme {
    static let plain = NSColor.labelColor

    static let keyword = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.84, green: 0.51, blue: 0.86, alpha: 1) // pink-purple
            : NSColor(red: 0.55, green: 0.08, blue: 0.64, alpha: 1) // deep purple
    }

    static let string = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.97, green: 0.50, blue: 0.37, alpha: 1) // soft orange-red
            : NSColor(red: 0.76, green: 0.10, blue: 0.10, alpha: 1) // dark red
    }

    static let comment = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.45, green: 0.67, blue: 0.42, alpha: 1) // muted green
            : NSColor(red: 0.18, green: 0.48, blue: 0.16, alpha: 1) // dark green
    }

    static let number = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.97, green: 0.72, blue: 0.35, alpha: 1) // warm amber
            : NSColor(red: 0.72, green: 0.40, blue: 0.00, alpha: 1) // dark amber
    }

    static let type = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.40, green: 0.84, blue: 0.93, alpha: 1) // bright cyan
            : NSColor(red: 0.06, green: 0.50, blue: 0.65, alpha: 1) // dark teal
    }

    static let attribute = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.97, green: 0.86, blue: 0.47, alpha: 1) // yellow
            : NSColor(red: 0.62, green: 0.46, blue: 0.00, alpha: 1) // dark gold
    }

    static func color(for tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:   return keyword
        case .string:    return string
        case .comment:   return comment
        case .number:    return number
        case .type:      return type
        case .attribute: return attribute
        case .plain:     return plain
        }
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
