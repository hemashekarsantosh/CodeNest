//
//  SyntaxHighlighter.swift
//  CodeNest
//

import AppKit

@MainActor
final class SyntaxHighlighter: NSObject, NSTextStorageDelegate {
    private let grammar: SyntaxGrammar
    private let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    init(grammar: SyntaxGrammar) {
        self.grammar = grammar
    }

    nonisolated func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Skip attribute-only changes (our own highlight pass) to avoid infinite loop.
        guard editedMask.contains(.editedCharacters) else { return }

        MainActor.assumeIsolated {
            highlight(textStorage, editedRange: editedRange)
        }
    }

    private func highlight(_ textStorage: NSTextStorage, editedRange: NSRange) {
        let nsString = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Expand to complete line boundaries for clean token edges.
        let highlightRange = nsString.lineRange(for: editedRange)
        guard highlightRange.length > 0,
              NSMaxRange(highlightRange) <= nsString.length else { return }

        textStorage.beginEditing()

        // Reset to base style over the highlight range.
        textStorage.setAttributes(
            [.font: monoFont, .foregroundColor: HighlightTheme.plain],
            range: highlightRange
        )

        // Apply grammar rules in priority order; first match wins for each range.
        var covered: [NSRange] = []
        for rule in grammar.rules {
            // Clamp regex search to highlightRange, but allow full string for context.
            rule.regex.enumerateMatches(
                in: textStorage.string,
                options: [],
                range: highlightRange
            ) { match, _, _ in
                guard let matchRange = match?.range, matchRange.length > 0 else { return }
                // Skip if this range overlaps an already-colored token.
                let alreadyCovered = covered.contains {
                    NSIntersectionRange($0, matchRange).length > 0
                }
                guard !alreadyCovered else { return }
                covered.append(matchRange)
                textStorage.addAttribute(
                    .foregroundColor,
                    value: HighlightTheme.color(for: rule.tokenType),
                    range: matchRange
                )
            }
        }

        textStorage.endEditing()
        _ = fullRange // suppress unused warning
    }
}
