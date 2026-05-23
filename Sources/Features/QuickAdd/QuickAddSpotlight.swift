// QuickAddSpotlight.swift
// The ⌘N floating capture: a Spotlight-style card over a dimmed, blurred backdrop.
// Parses as you type, previews the resolved title + prefix chips, and lists the
// grammar in the footer. Enter creates the task; Escape or a backdrop click cancels.

import SwiftUI

struct QuickAddSpotlight: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool
    let onClose: () -> Void
    let onCreate: (ParsedQuickAdd) -> Void

    private var parsed: ParsedQuickAdd { PrefixParser.parse(text, clock: model.clock) }

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
                .font(.system(size: 17))
                .focused($focused)
                .onSubmit(commit)
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
        onCreate(parsed)
        onClose()
    }
}
