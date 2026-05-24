// PrefixChip.swift
// Renders a parsed prefix token as a colored preview chip (folder / due / effort /
// impact / priority), and a row of such chips for a ParsedQuickAdd. Used by both
// the inline quick-add bar and the ⌘N Spotlight capture — as you type, recognized
// prefixes surface here as chips, matching the prototype's preview treatment.

import SwiftUI

/// Shared autocomplete logic: the folder suggestions for an in-progress `#tag`.
enum QuickAddAutocomplete {
    static func suggestions(for text: String, in folders: [Folder]) -> [Folder] {
        guard let query = PrefixParser.activeHashtagQuery(in: text) else { return [] }
        return FolderTree.search(query, in: folders)
    }
}

struct PrefixChip: View {
    let token: PrefixToken
    let folders: [Folder]
    let clock: TaskClock
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        MetaChip(systemImage: systemImage, text: label, colors: colors)
    }

    private var systemImage: String {
        switch token {
        case .folder: return "folder.fill"
        case .due: return "calendar"
        case .effort: return "clock"
        case .impact: return "chart.bar.fill"
        case .priority: return "star.fill"
        }
    }

    private var label: String {
        switch token {
        case .folder(let slug):
            return FolderTree.folder(forSlug: slug, in: folders)?.name ?? slug
        case .due(let date):
            return Formatting.dueLabel(date, clock: clock) ?? ""
        case .effort(let minutes):
            return Formatting.effort(minutes) ?? ""
        case .impact(let level):
            return "\(level.label) impact"
        case .priority(let level):
            return "\(level.label) priority"
        }
    }

    private var colors: ChipColors {
        switch token {
        case .folder:
            return Palette.folder(scheme: scheme)
        case .due(let date):
            let overdue = (clock.daysUntil(date) ?? 0) < 0
            let today = clock.daysUntil(date) == 0
            return Palette.due(overdue: overdue, today: today, scheme: scheme)
        case .effort:
            return Palette.effort(scheme: scheme)
        case .impact:
            return Palette.impact(scheme: scheme)
        case .priority:
            return Palette.priority(scheme: scheme)
        }
    }
}

/// Todoist-style folder autocomplete dropdown shown while typing a `#tag`.
struct FolderSuggestionList: View {
    let folders: [Folder]
    let allFolders: [Folder]
    let highlighted: Int
    let onPick: (Folder) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                Button { onPick(folder) } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(folder.tint).frame(width: 10, height: 10)
                        Text(folder.name).foregroundStyle(.primary)
                        if let parents = parentPath(folder) {
                            Text(parents).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .appFont(12.5)
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == highlighted ? Color.accentColor.opacity(0.18) : .clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    /// Ancestor path (without the folder itself), for disambiguating same-named folders.
    private func parentPath(_ folder: Folder) -> String? {
        let parents = FolderTree.path(to: folder.id, in: allFolders).dropLast()
        return parents.isEmpty ? nil : parents.map(\.name).joined(separator: " › ")
    }
}

/// A horizontal run of preview chips for a parsed quick-add result.
struct PrefixChipRow: View {
    let parsed: ParsedQuickAdd
    let folders: [Folder]
    let clock: TaskClock

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(parsed.tokens.enumerated()), id: \.offset) { _, token in
                PrefixChip(token: token, folders: folders, clock: clock)
            }
        }
    }
}
