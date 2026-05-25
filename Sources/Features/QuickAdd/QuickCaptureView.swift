// QuickCaptureView.swift
// The compact capture box shown by the global quick-capture hotkey (hosted in a
// floating panel). Reuses the quick-add prefix parser and preview chips. While you
// type a #tag, a folder autocomplete dropdown appears (↑/↓ + Enter/Tab/click);
// typing an i:/p: token instead surfaces a High/Medium/Low value picker the same way.
// Enter creates the task (an unknown #project prompts to create it), Esc dismisses.

import SwiftUI

struct QuickCaptureView: View {
    let model: AppModel
    var onDismiss: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var highlighted = 0
    @State private var suppressed = false
    /// Set when committing a task whose #project doesn't exist yet (awaiting confirm).
    @State private var pendingParsed: ParsedQuickAdd?

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }
    private var suggestions: [Folder] { QuickAddAutocomplete.suggestions(for: text, in: model.folders) }
    private var showSuggestions: Bool { !suppressed && !suggestions.isEmpty }
    /// The i:/p: field being typed (only when a folder list isn't already showing).
    private var activeLevel: PrefixParser.LevelField? {
        guard !suppressed, !showSuggestions else { return nil }
        return PrefixParser.activeLevelPrefix(in: text)
    }
    private var showLevels: Bool { activeLevel != nil }
    private var isSuggesting: Bool { showSuggestions || showLevels }
    private var suggestionCount: Int {
        showSuggestions ? suggestions.count : (showLevels ? Level.pickerOrder.count : 0)
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
            if showSuggestions {
                FolderSuggestionList(folders: suggestions, allFolders: model.folders,
                                     highlighted: highlighted, onPick: complete)
            } else if let field = activeLevel {
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
        .alert("Create project “\(pendingParsed?.folderSlug ?? "")”?",
               isPresented: Binding(get: { pendingParsed != nil },
                                    set: { if !$0 { pendingParsed = nil } })) {
            Button("Create") { confirmCreate() }
            Button("Cancel", role: .cancel) { pendingParsed = nil }
        } message: {
            Text("This project doesn’t exist yet.")
        }
    }

    // MARK: - Autocomplete keyboard handling

    private func moveHighlight(_ delta: Int) -> KeyPress.Result {
        guard isSuggesting else { return .ignored }
        highlighted = max(0, min(suggestionCount - 1, highlighted + delta))
        return .handled
    }

    private func acceptIfSuggesting() -> KeyPress.Result {
        if showSuggestions, suggestions.indices.contains(highlighted) {
            complete(suggestions[highlighted])
            return .handled
        }
        if showLevels, Level.pickerOrder.indices.contains(highlighted) {
            completeLevel(Level.pickerOrder[highlighted])
            return .handled
        }
        return .ignored
    }

    /// Esc: first dismiss an open suggestion dropdown, otherwise close the capture panel.
    private func handleEscape() -> KeyPress.Result {
        if isSuggesting {
            suppressed = true
            return .handled
        }
        onDismiss()
        return .handled
    }

    private func complete(_ folder: Folder) {
        text = PrefixParser.completeHashtag(in: text, with: folder.nameSlug)
        highlighted = 0
        focused = true
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
        // Unknown #project → confirm before creating (handled at commit, not while typing).
        if let slug = parsed.folderSlug, model.knownFolder(forSlug: slug) == nil {
            pendingParsed = parsed
        } else {
            model.createTask(from: parsed)
            text = ""
            onDismiss()
        }
    }

    private func confirmCreate() {
        if let parsed = pendingParsed {
            model.createFolderAndTask(from: parsed)
            text = ""
            onDismiss()
        }
        pendingParsed = nil
    }
}
