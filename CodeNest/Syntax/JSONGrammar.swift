//
//  JSONGrammar.swift
//  CodeNest
//

import Foundation

struct JSONGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Object keys — "key": (string followed by colon)
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*"(?=\s*:)"#,
                tokenType: .attribute
            ),
            // 2. String values
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*""#,
                tokenType: .string
            ),
            // 3. Numbers (integer and float, with optional sign)
            SyntaxRule(
                pattern: #"-?\d+(\.\d+)?([eE][+-]?\d+)?"#,
                tokenType: .number
            ),
            // 4. Keywords: true, false, null
            SyntaxRule(
                pattern: #"\b(true|false|null)\b"#,
                tokenType: .keyword
            ),
        ]
    }
}
