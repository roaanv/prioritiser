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

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }
    private var suggestions: [Folder] { QuickAddAutocomplete.suggestions(for: text, in: model.folders) }
    private var showSuggestions: Bool { !suppressed && !suggestions.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inputShell
            if showSuggestions {
                FolderSuggestionList(folders: suggestions, allFolders: model.folders,
                                     highlighted: highlighted, onPick: complete)
            } else if !parsed.tokens.isEmpty {
                PrefixChipRow(parsed: parsed, folders: model.folders, clock: model.clock)
                    .padding(.leading, 2)
            }
        }
        .animation(.easeOut(duration: 0.12), value: showSuggestions)
        .animation(.easeOut(duration: 0.12), value: parsed.tokens.count)
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
                .onChange(of: text) { highlighted = 0; suppressed = false }
                .onKeyPress(.upArrow) { moveHighlight(-1) }
                .onKeyPress(.downArrow) { moveHighlight(1) }
                .onKeyPress(.return) { acceptIfSuggesting() }
                .onKeyPress(.tab) { acceptIfSuggesting() }
                .onKeyPress(.escape) { dismissIfSuggesting() }

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
        guard showSuggestions else { return .ignored }
        highlighted = max(0, min(suggestions.count - 1, highlighted + delta))
        return .handled
    }

    private func acceptIfSuggesting() -> KeyPress.Result {
        guard showSuggestions, suggestions.indices.contains(highlighted) else { return .ignored }
        complete(suggestions[highlighted])
        return .handled
    }

    private func dismissIfSuggesting() -> KeyPress.Result {
        guard showSuggestions else { return .ignored }
        suppressed = true
        return .handled
    }

    private func complete(_ folder: Folder) {
        text = PrefixParser.completeHashtag(in: text, with: folder.nameSlug)
        highlighted = 0
        focused = true
    }

    private func commit() {
        guard !parsed.title.isEmpty else { return }
        onCreate(parsed)
        text = ""
    }
}
