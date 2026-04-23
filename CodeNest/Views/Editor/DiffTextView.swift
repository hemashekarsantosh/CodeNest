import SwiftUI
import AppKit

struct DiffTextView: NSViewRepresentable {
    let content: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = NSColor(calibratedHue: 0, saturation: 0, brightness: 0.97, alpha: 1)

        let attributedString = NSMutableAttributedString(string: content)
        attributedString.addAttribute(.font, value: textView.font!, range: NSRange(location: 0, length: content.count))

        // Color diff lines
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var currentLocation = 0

        for line in lines {
            let lineLength = line.count + 1 // +1 for newline
            let lineString = String(line)

            let range = NSRange(location: currentLocation, length: lineLength - 1)

            if lineString.hasPrefix("+") && !lineString.hasPrefix("+++") {
                // Added line
                let greenColor = NSColor(calibratedRed: 0, green: 0.8, blue: 0, alpha: 0.1)
                attributedString.addAttribute(.backgroundColor, value: greenColor, range: range)
            } else if lineString.hasPrefix("-") && !lineString.hasPrefix("---") {
                // Removed line
                let redColor = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.1)
                attributedString.addAttribute(.backgroundColor, value: redColor, range: range)
            } else if lineString.hasPrefix("@@") {
                // Hunk header
                let blueColor = NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 0.15)
                attributedString.addAttribute(.backgroundColor, value: blueColor, range: range)
            }

            currentLocation += lineLength
        }

        textView.textStorage?.setAttributedString(attributedString)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Updates are handled through id() on the parent view
    }
}
