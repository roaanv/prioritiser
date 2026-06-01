// MarkdownNotesEditorTests.swift
// Markdown notes keep raw markup visible while styling the marked span.

import AppKit
import Testing
@testable import Prioritiser

@Suite("Markdown notes")
struct MarkdownNotesEditorTests {
    @Test func boldMarkersAreStyledWithTheirContent() {
        let source = "**I'm bold**"
        let attributed = NSMutableAttributedString(
            string: source,
            attributes: MarkdownHighlighter.baseAttributes(fontSize: 12.5)
        )

        MarkdownHighlighter.apply(
            to: attributed,
            range: NSRange(location: 0, length: attributed.length),
            fontSize: 12.5
        )

        let firstFont = try! #require(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let lastFont = try! #require(attributed.attribute(.font, at: source.count - 1, effectiveRange: nil) as? NSFont)
        let bodyFont = try! #require(attributed.attribute(.font, at: 4, effectiveRange: nil) as? NSFont)

        #expect(NSFontManager.shared.traits(of: firstFont).contains(.boldFontMask))
        #expect(NSFontManager.shared.traits(of: lastFont).contains(.boldFontMask))
        #expect(NSFontManager.shared.traits(of: bodyFont).contains(.boldFontMask))
        #expect(attributed.string == source)
    }

    @MainActor
    @Test func escapeKeyInvokesEditorCancelHandler() {
        let textView = PlaceholderTextView()
        var didEscape = false
        textView.onEscape = { didEscape = true }

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        )

        textView.keyDown(with: try! #require(event))
        #expect(didEscape)
    }
}
