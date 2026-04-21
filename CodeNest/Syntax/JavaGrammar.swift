//
//  JavaGrammar.swift
//  CodeNest
//

import Foundation

struct JavaGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Block comments /* ... */ and Javadoc /** ... */
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
            // 3. String literals "..."
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*""#,
                tokenType: .string
            ),
            // 4. Character literals '.'
            SyntaxRule(
                pattern: #"'(?:[^'\\]|\\.)'"#,
                tokenType: .string
            ),
            // 5. Annotations @Override, @SuppressWarnings, etc.
            SyntaxRule(
                pattern: #"@\w+"#,
                tokenType: .attribute
            ),
            // 6. Keywords
            SyntaxRule(
                pattern: #"\b(abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|null|package|private|protected|public|record|return|sealed|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|true|false|try|var|void|volatile|while|yield)\b"#,
                tokenType: .keyword
            ),
            // 7. Types (capitalized identifiers)
            SyntaxRule(
                pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#,
                tokenType: .type
            ),
            // 8. Numbers: hex, binary, float, long, int
            SyntaxRule(
                pattern: #"\b(0x[0-9A-Fa-f_]+[lL]?|0b[01_]+[lL]?|\d[\d_]*\.[\d_]*([eE][+-]?\d+)?[fFdD]?|\d[\d_]*[lLfFdD]?)\b"#,
                tokenType: .number
            ),
        ]
    }
}
