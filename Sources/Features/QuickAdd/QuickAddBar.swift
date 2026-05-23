// QuickAddBar.swift
// The inline quick-add row at the top of the task list: a styled text field that
// parses the prefix grammar as you type and surfaces recognized prefixes as
// preview chips beneath, then creates the task on commit (Enter).

import SwiftUI

struct QuickAddBar: View {
    @Environment(AppModel.self) private var model
    let onCreate: (ParsedQuickAdd) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inputShell
            if !parsed.tokens.isEmpty {
                PrefixChipRow(parsed: parsed, folders: model.folders, clock: model.clock)
                    .padding(.leading, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

    private func commit() {
        guard !parsed.title.isEmpty else { return }
        onCreate(parsed)
        text = ""
    }
}
