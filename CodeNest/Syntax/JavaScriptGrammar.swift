//
//  JavaScriptGrammar.swift
//  CodeNest
//

import Foundation

struct JavaScriptGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Block comments /* ... */
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
            // 3. Template literals `...`
            SyntaxRule(
                pattern: #"`(?:[^`\\]|\\.)*`"#,
                tokenType: .string
            ),
            // 4. String literals "..." and '...'
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'"#,
                tokenType: .string
            ),
            // 5. Decorators @decorator
            SyntaxRule(
                pattern: #"@\w+"#,
                tokenType: .attribute
            ),
            // 6. Keywords
            SyntaxRule(
                pattern: #"\b(async|await|break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|false|finally|for|from|function|if|import|in|instanceof|let|new|null|of|return|static|super|switch|this|throw|true|try|typeof|undefined|var|void|while|with|yield)\b"#,
                tokenType: .keyword
            ),
            // 7. Types / constructors (capitalized identifiers)
            SyntaxRule(
                pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#,
                tokenType: .type
            ),
            // 8. Numbers
            SyntaxRule(
                pattern: #"\b(0x[0-9A-Fa-f_]+n?|0b[01_]+n?|0o[0-7_]+n?|\d[\d_]*\.[\d_]*([eE][+-]?\d+)?|\d[\d_]*n?)\b"#,
                tokenType: .number
            ),
        ]
    }
}
