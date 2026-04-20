//
//  MarkdownGrammar.swift
//  CodeNest
//

import Foundation

struct MarkdownGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Fenced code blocks ```...```
            SyntaxRule(
                pattern: #"```[\s\S]*?```"#,
                tokenType: .string
            ),
            // 2. Inline code `...`
            SyntaxRule(
                pattern: #"`[^`]+`"#,
                tokenType: .string
            ),
            // 3. Headings # through ######
            SyntaxRule(
                pattern: #"^#{1,6}\s.*$"#,
                options: .anchorsMatchLines,
                tokenType: .keyword
            ),
            // 4. Bold **text** or __text__
            SyntaxRule(
                pattern: #"(\*\*|__)(?!\s)[\s\S]*?(?<!\s)\1"#,
                tokenType: .type
            ),
            // 5. Italic *text* or _text_
            SyntaxRule(
                pattern: #"(\*|_)(?!\s)[^\n]*?(?<!\s)\1"#,
                tokenType: .attribute
            ),
            // 6. Links [text](url)
            SyntaxRule(
                pattern: #"\[([^\]]+)\]\([^\)]+\)"#,
                tokenType: .number
            ),
            // 7. Blockquotes >
            SyntaxRule(
                pattern: #"^>.*$"#,
                options: .anchorsMatchLines,
                tokenType: .comment
            ),
        ]
    }
}
