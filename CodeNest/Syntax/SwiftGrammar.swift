//
//  SwiftGrammar.swift
//  CodeNest
//

import Foundation

struct SwiftGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Block comments /* ... */ (highest priority)
            SyntaxRule(
                pattern: #"/\*[\s\S]*?\*/"#,
                tokenType: .comment
            ),
            // 2. Line comments // ...
            SyntaxRule(
                pattern: #"//.*$"#,
                options: .anchorsMatchLines,
                tokenType: .comment
            ),
            // 3. String literals "..." (handles escape sequences like \", \\)
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*""#,
                tokenType: .string
            ),
            // 4. Attributes @decorator
            SyntaxRule(
                pattern: #"@\w+"#,
                tokenType: .attribute
            ),
            // 5. Keywords
            SyntaxRule(
                pattern: #"\b(actor|any|as|async|await|break|case|catch|class|continue|default|defer|deinit|do|else|enum|extension|fallthrough|false|final|for|func|guard|if|import|in|init|inout|internal|is|let|mutating|nil|nonisolated|open|operator|override|package|precedencegroup|private|protocol|public|repeat|required|rethrows|return|self|Self|some|static|struct|subscript|super|switch|throw|throws|true|try|typealias|var|where|while)\b"#,
                tokenType: .keyword
            ),
            // 6. Types (capitalized identifiers: structs, classes, enums, protocols)
            SyntaxRule(
                pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#,
                tokenType: .type
            ),
            // 7. Numbers: hex, binary, octal, float, int (with underscores)
            SyntaxRule(
                pattern: #"\b(0x[0-9A-Fa-f_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*\.[\d_]+([eE][+-]?[\d_]+)?|\d[\d_]*)\b"#,
                tokenType: .number
            ),
        ]
    }
}
