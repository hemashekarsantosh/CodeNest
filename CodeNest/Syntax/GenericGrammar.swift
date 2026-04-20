//
//  GenericGrammar.swift
//  CodeNest
//

import Foundation

/// Fallback grammar for unknown file types.
/// Highlights strings and common line-comment styles.
struct GenericGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Line comments: // and #
            SyntaxRule(
                pattern: #"(//|#).*$"#,
                options: .anchorsMatchLines,
                tokenType: .comment
            ),
            // 2. Double-quoted strings
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*""#,
                tokenType: .string
            ),
            // 3. Single-quoted strings
            SyntaxRule(
                pattern: #"'(?:[^'\\]|\\.)*'"#,
                tokenType: .string
            ),
        ]
    }
}
