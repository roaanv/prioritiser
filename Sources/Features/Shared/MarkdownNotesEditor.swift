// MarkdownNotesEditor.swift
// Plain-text notes editor with lightweight Markdown syntax highlighting. The raw
// markdown stays in the model; marker characters are styled with the text they mark.

import AppKit
import SwiftUI

struct MarkdownNotesEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 56
    var fontSize: CGFloat = 12.5
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = PlaceholderTextView()
        textView.placeholder = placeholder
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text
        textView.typingAttributes = MarkdownHighlighter.baseAttributes(fontSize: fontSize)
        textView.applyMarkdownHighlighting(fontSize: fontSize)
        textView.onEscape = onEscape
        context.coordinator.textView = textView
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }
        context.coordinator.text = $text
        textView.onEscape = onEscape
        textView.placeholder = placeholder
        if textView.string != text {
            textView.string = text
        }
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.typingAttributes = MarkdownHighlighter.baseAttributes(fontSize: fontSize)
        textView.applyMarkdownHighlighting(fontSize: fontSize)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        fileprivate weak var textView: PlaceholderTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PlaceholderTextView else { return }
            text.wrappedValue = textView.string
            textView.applyMarkdownHighlightingPreservingSelection()
        }
    }
}
final class PlaceholderTextView: NSTextView {
    var placeholder = "" {
        didSet { needsDisplay = true }
    }

    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .obliqueness: 0.12
        ]
        let origin = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    func applyMarkdownHighlightingPreservingSelection() {
        let ranges = selectedRanges
        applyMarkdownHighlighting(fontSize: font?.pointSize ?? 12.5)
        selectedRanges = ranges
    }

    func applyMarkdownHighlighting(fontSize: CGFloat) {
        guard let storage = textStorage else { return }
        let range = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(MarkdownHighlighter.baseAttributes(fontSize: fontSize), range: range)
        MarkdownHighlighter.apply(to: storage, range: range, fontSize: fontSize)
        storage.endEditing()
    }
}

enum MarkdownHighlighter {
    static func baseAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
    }

    static func apply(to storage: NSMutableAttributedString, range: NSRange, fontSize: CGFloat) {
        guard storage.length > 0 else { return }
        let string = storage.string as NSString
        applyLinePatterns(to: storage, string: string, range: range, fontSize: fontSize)
        applyInlinePatterns(to: storage, string: string, range: range, fontSize: fontSize)
    }

    private static func applyLinePatterns(
        to storage: NSMutableAttributedString,
        string: NSString,
        range: NSRange,
        fontSize: CGFloat
    ) {
        enumerate(pattern: #"(?m)^#{1,6}\s.+$"#, in: string as String, range: range) { match in
            let weight: NSFont.Weight = .semibold
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize + 1, weight: weight),
                .foregroundColor: NSColor.labelColor
            ], range: match.range)
        }

        enumerate(pattern: #"(?m)^\s{0,3}(?:[-*+]\s|\d+\.\s).+$"#, in: string as String, range: range) { match in
            storage.addAttributes([.foregroundColor: NSColor.labelColor], range: match.range)
        }
    }

    private static func applyInlinePatterns(
        to storage: NSMutableAttributedString,
        string: NSString,
        range: NSRange,
        fontSize: CGFloat
    ) {
        enumerate(pattern: #"(?<!\*)\*\*[^\n*](?:[^\n]*?[^\n*])?\*\*(?!\*)"#, in: string as String, range: range) { match in
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ], range: match.range)
        }

        enumerate(pattern: #"(?<!_)__[^\n_](?:[^\n]*?[^\n_])?__(?!_)"#, in: string as String, range: range) { match in
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ], range: match.range)
        }

        enumerate(pattern: #"(?<!\*)\*[^\n*](?:[^\n]*?[^\n*])?\*(?!\*)"#, in: string as String, range: range) { match in
            storage.addAttributes([
                .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.labelColor
            ], range: match.range)
        }

        enumerate(pattern: #"(?<!_)_[^\n_](?:[^\n]*?[^\n_])?_(?!_)"#, in: string as String, range: range) { match in
            storage.addAttributes([
                .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.labelColor
            ], range: match.range)
        }

        enumerate(pattern: #"`[^`\n]+`"#, in: string as String, range: range) { match in
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.textColor.withAlphaComponent(0.08)
            ], range: match.range)
        }
    }

    private static func enumerate(
        pattern: String,
        in string: String,
        range: NSRange,
        body: (NSTextCheckingResult) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: string, range: range) { match, _, _ in
            if let match {
                body(match)
            }
        }
    }
}
