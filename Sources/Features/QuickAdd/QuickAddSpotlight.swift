// QuickAddSpotlight.swift
// The ⌘N floating capture: a Spotlight-style card over a dimmed, blurred backdrop.
// Parses as you type, previews the resolved title + prefix chips, and lists the
// grammar in the footer. Enter creates the task; Escape or a backdrop click cancels.

import SwiftUI

struct QuickAddSpotlight: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var highlighted = 0
    @State private var suppressed = false
    @State private var pendingParsed: ParsedQuickAdd?
    let onClose: () -> Void
    let onCreate: (ParsedQuickAdd) -> Void

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }
    private var suggestions: [Folder] { QuickAddAutocomplete.suggestions(for: text, in: model.folders) }
    private var showSuggestions: Bool { !suppressed && !suggestions.isEmpty }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                backdrop
                card
                    .frame(width: min(640, geo.size.width - 48))
                    .padding(.top, geo.size.height * 0.18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: onClose)
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

    private var backdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.12))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onClose)
    }

    private var card: some View {
        VStack(spacing: 0) {
            inputRow
            if showSuggestions {
                Divider()
                FolderSuggestionList(folders: suggestions, allFolders: model.folders,
                                     highlighted: highlighted, onPick: complete)
                    .padding(8)
            }
            Divider()
            previewRow
            Divider()
            footer
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.32), radius: 40, y: 24)
    }

    private var inputRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            TextField("What needs doing?", text: $text)
                .textFieldStyle(.plain)
                .appFont(17, relativeTo: .title3)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: text) { highlighted = 0; suppressed = false }
                .onKeyPress(.upArrow) { moveHighlight(-1) }
                .onKeyPress(.downArrow) { moveHighlight(1) }
                .onKeyPress(.return) { acceptIfSuggesting() }
                .onKeyPress(.tab) { acceptIfSuggesting() }
                .onKeyPress(.escape) { dismissIfSuggesting() } // first Esc closes the list, then the sheet
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var previewRow: some View {
        HStack(spacing: 8) {
            if parsed.title.isEmpty {
                Text("Use prefixes to add context")
                    .foregroundStyle(.tertiary)
            } else {
                Text(parsed.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            PrefixChipRow(parsed: parsed, folders: model.folders, clock: model.clock)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 42)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            legendItem("#folder", "project")
            legendItem("due:", "date")
            legendItem("t:", "effort")
            legendItem("i:", "impact")
            legendItem("p:", "priority")
            Spacer()
            KeyCap("esc")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    private func legendItem(_ code: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            Text(label)
        }
    }

    private func commit() {
        guard !parsed.title.isEmpty else { return }
        // Unknown #project → confirm before creating (handled at commit, not while typing).
        if let slug = parsed.folderSlug, model.knownFolder(forSlug: slug) == nil {
            pendingParsed = parsed
        } else {
            onCreate(parsed)
            onClose()
        }
    }

    private func confirmCreate() {
        if let parsed = pendingParsed {
            model.createFolderAndTask(from: parsed)
            onClose()
        }
        pendingParsed = nil
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
        guard showSuggestions else { return .ignored } // let Esc close the sheet
        suppressed = true
        return .handled
    }

    private func complete(_ folder: Folder) {
        text = PrefixParser.completeHashtag(in: text, with: folder.nameSlug)
        highlighted = 0
        focused = true
    }
}
