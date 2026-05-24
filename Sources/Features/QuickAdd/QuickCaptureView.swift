// QuickCaptureView.swift
// The compact capture box shown by the global quick-capture hotkey (hosted in a
// floating panel). Reuses the quick-add prefix parser and preview chips; typing an
// i:/p: token surfaces a High/Medium/Low value picker (↑/↓ + Enter/Tab/click).
// Enter creates the task (unknown #projects default to Inbox), Esc dismisses.

import SwiftUI

struct QuickCaptureView: View {
    let model: AppModel
    var onDismiss: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var highlighted = 0
    @State private var suppressed = false

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }
    /// The i:/p: field being typed, surfacing its valid values.
    private var activeLevel: PrefixParser.LevelField? {
        suppressed ? nil : PrefixParser.activeLevelPrefix(in: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                TextField("Add a task…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($focused)
                    .onChange(of: text) { highlighted = defaultHighlight(); suppressed = false }
                    .onSubmit(commit)
                    .onKeyPress(.upArrow) { moveHighlight(-1) }
                    .onKeyPress(.downArrow) { moveHighlight(1) }
                    .onKeyPress(.return) { acceptIfSuggesting() }
                    .onKeyPress(.tab) { acceptIfSuggesting() }
                    .onKeyPress(.escape) { handleEscape() }
            }
            if let field = activeLevel {
                LevelSuggestionList(field: field, highlighted: highlighted, onPick: completeLevel)
            } else if parsed.tokens.isEmpty {
                Text("#project   due:tomorrow   t:30m   i:h   p:h")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                PrefixChipRow(parsed: parsed, folders: model.folders, clock: model.clock)
            }
        }
        .padding(20)
        .frame(width: 560, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .onAppear { focused = true }
    }

    // MARK: - Value picker keyboard handling

    private func moveHighlight(_ delta: Int) -> KeyPress.Result {
        guard activeLevel != nil else { return .ignored }
        highlighted = max(0, min(Level.pickerOrder.count - 1, highlighted + delta))
        return .handled
    }

    private func acceptIfSuggesting() -> KeyPress.Result {
        guard activeLevel != nil, Level.pickerOrder.indices.contains(highlighted) else { return .ignored }
        completeLevel(Level.pickerOrder[highlighted])
        return .handled
    }

    /// Esc: first dismiss the value picker if open, otherwise close the capture panel.
    private func handleEscape() -> KeyPress.Result {
        if activeLevel != nil {
            suppressed = true
            return .handled
        }
        onDismiss()
        return .handled
    }

    private func completeLevel(_ level: Level) {
        text = PrefixParser.completeLevel(in: text, with: level)
        highlighted = 0
        focused = true
    }

    /// Which row to highlight when the text changes: the value already typed in an
    /// i:/p: token (e.g. "p:l" → Low), otherwise the first row.
    private func defaultHighlight() -> Int {
        if let level = PrefixParser.activeLevelValue(in: text),
           let index = Level.pickerOrder.firstIndex(of: level) {
            return index
        }
        return 0
    }

    private func commit() {
        guard !parsed.title.isEmpty else { return }
        model.createTask(from: parsed)
        text = ""
        onDismiss()
    }
}
