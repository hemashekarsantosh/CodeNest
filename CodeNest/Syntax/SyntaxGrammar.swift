//
//  SyntaxGrammar.swift
//  CodeNest
//

import Foundation

struct SyntaxRule {
    let regex: NSRegularExpression
    let tokenType: TokenType

    init(pattern: String, options: NSRegularExpression.Options = [], tokenType: TokenType) {
        // Grammar authors are responsible for valid patterns; crash at startup is preferable to silent failure.
        // swiftlint:disable:next force_try
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
        self.tokenType = tokenType
    }
}

protocol SyntaxGrammar {
    /// Ordered highest-to-lowest priority. First match for a given range wins.
    var rules: [SyntaxRule] { get }
}

enum Language {
    static func grammar(for fileExtension: String) -> SyntaxGrammar {
        switch fileExtension.lowercased() {
        case "swift":          return SwiftGrammar()
        case "json":           return JSONGrammar()
        case "md", "markdown": return MarkdownGrammar()
        default:               return GenericGrammar()
        }
    }
}
