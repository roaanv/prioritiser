// QuickAddBar.swift
// The inline quick-add row at the top of the task list: a styled text field that
// parses the prefix grammar as you type. While you're typing a `#tag`, a folder
// autocomplete dropdown appears (Todoist-style: ↑/↓ to move, Enter/Tab/click to
// pick, Esc to dismiss); otherwise recognized prefixes show as preview chips.

import SwiftUI

struct QuickAddBar: View {
    @Environment(AppModel.self) private var model
    let onCreate: (ParsedQuickAdd) -> Void

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
        VStack(alignment: .leading, spacing: 8) {
            inputShell
            if showSuggestions {
                FolderSuggestionList(folders: suggestions, allFolders: model.folders,
                                     highlighted: highlighted, onPick: complete)
            } else if let field = activeLevel {
                LevelSuggestionList(field: field, highlighted: highlighted, onPick: completeLevel)
            } else if !parsed.tokens.isEmpty {
                PrefixChipRow(parsed: parsed, folders: model.folders, clock: model.clock)
                    .padding(.leading, 2)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isSuggesting)
        .animation(.easeOut(duration: 0.12), value: parsed.tokens.count)
        .alert("Create project “\(pendingParsed?.folderSlug ?? "")”?",
               isPresented: Binding(get: { pendingParsed != nil },
                                    set: { if !$0 { pendingParsed = nil } })) {
            Button("Create") { confirmCreate() }
            Button("Cancel", role: .cancel) { pendingParsed = nil }
        } message: {
            Text("This project doesn’t exist yet.")
        }
    }

    private var inputShell: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

            TextField("Add a task — try #work due:tomorrow t:1h i:h p:h", text: $text)
                .textFieldStyle(.plain)
                .appFont(13)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: text) { highlighted = defaultHighlight(); suppressed = false }
                .onKeyPress(.upArrow) { moveHighlight(-1) }
                .onKeyPress(.downArrow) { moveHighlight(1) }
                .onKeyPress(.return) { acceptIfSuggesting() }
                .onKeyPress(.tab) { acceptIfSuggesting() }
                .onKeyPress(.escape) { handleEscape() }

            HStack(spacing: 6) {
                Text("Add").foregroundStyle(.tertiary)
                KeyCap("⏎")
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(focused ? Color.accentColor : Color.primary.opacity(0.08),
                              lineWidth: focused ? 1.5 : 0.5)
        )
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

    /// Escape: first dismiss an open suggestion dropdown; otherwise clear the whole
    /// field (which also removes the preview chips, since they derive from text).
    private func handleEscape() -> KeyPress.Result {
        if isSuggesting {
            suppressed = true
            return .handled
        }
        guard !text.isEmpty else { return .ignored }
        text = ""
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
            onCreate(parsed)
            text = ""
        }
    }

    private func confirmCreate() {
        if let parsed = pendingParsed {
            model.createFolderAndTask(from: parsed)
            text = ""
        }
        pendingParsed = nil
    }
}
