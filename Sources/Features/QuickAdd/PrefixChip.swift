// PrefixChip.swift
// Renders a parsed prefix token as a colored preview chip (folder / due / effort /
// impact / priority), and a row of such chips for a ParsedQuickAdd. Used by both
// the inline quick-add bar and the ⌘N Spotlight capture — as you type, recognized
// prefixes surface here as chips, matching the prototype's preview treatment.

import SwiftUI

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
