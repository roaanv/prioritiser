// QuickCaptureView.swift
// The compact capture box shown by the global quick-capture hotkey (hosted in a
// floating panel). Reuses the quick-add prefix parser and preview chips; Enter
// creates the task (defaulting unknown #projects to Inbox), Esc dismisses.

import SwiftUI

struct QuickCaptureView: View {
    let model: AppModel
    var onDismiss: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }

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
                    .onSubmit(commit)
                    .onKeyPress(.escape) { onDismiss(); return .handled }
            }
            if parsed.tokens.isEmpty {
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

    private func commit() {
        guard !parsed.title.isEmpty else { return }
        model.createTask(from: parsed)
        text = ""
        onDismiss()
    }
}
