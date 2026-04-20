//
//  CodeTextView.swift
//  CodeNest
//

import SwiftUI
import AppKit

struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    let language: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = true
        textView.isRichText = false   // must be set before wiring highlighter
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = NSColor.textBackgroundColor

        // Disable line wrapping — horizontal scroll instead
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true

        // Wire syntax highlighter as the text storage delegate.
        textView.textStorage?.delegate = context.coordinator.highlighter
        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        // Guard prevents cursor jump on every state change.
        // Setting .string triggers didProcessEditing for the full range,
        // which causes the highlighter to highlight the whole document automatically.
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView
        let highlighter: SyntaxHighlighter

        init(_ parent: CodeTextView) {
            self.parent = parent
            self.highlighter = SyntaxHighlighter(
                grammar: Language.grammar(for: parent.language)
            )
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
