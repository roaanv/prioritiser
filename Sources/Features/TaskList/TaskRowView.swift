// TaskRowView.swift
// A single task row. Renders the completion checkbox, the title (with a state
// glyph), the metadata chips (folder / due / effort), and the right-side impact
// pips + priority score. The priority-visualization mode decides extra treatment:
//   • cards — Top-5 rows (rank != nil) become ranked, elevated cards; rank 1 gets
//     a "NOW" badge and an accent wash.
//   • bars  — a thin score bar runs along the bottom of every row.
//   • heat  — every row is tinted by score intensity.

import SwiftUI

struct TaskRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let task: TaskItem
    /// Rank within the Top-5 band (1-based); nil for non-ranked rows.
    var rank: Int? = nil
    var vizMode: PriorityVizMode = .cards

    private var score: Int { model.score(for: task) }
    private var isSelected: Bool { model.selectedTaskID == task.id }

    private var isCard: Bool { vizMode == .cards && rank != nil }
    private var isTopCard: Bool { isCard && rank == 1 }
    private var showBar: Bool { vizMode == .bars }
    private var isHeat: Bool { vizMode == .heat }
    /// 0…1 intensity: 55 → 0, 100 → 1 (prototype's heat ramp).
    private var heat: Double { max(0, min(1, (Double(score) - 55) / 45)) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isCard { rankColumn.accessibilityHidden(true) }
            CompletionToggle(task: task) { model.toggleDone(task) }
            HStack(alignment: .center, spacing: 12) {
                titleAndChips
                Spacer(minLength: 8)
                rightColumn
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selectedTaskID = task.id }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .padding(.top, isTopCard ? 14 : 10)
        .padding(.bottom, (isTopCard ? 14 : 10) + (showBar ? 8 : 0))
        .padding(.horizontal, 14)
        .background(rowBackground)
        .overlay(rowBorder)
        .overlay(alignment: .bottom) { if showBar { scoreBar.accessibilityHidden(true) } }
    }

    /// Spoken description for VoiceOver, e.g. "Ship beta, Prioritiser, due Tomorrow,
    /// 3h, impact High, score 86, In progress".
    private var accessibilityLabel: String {
        var parts = [task.title]
        if let folder = model.folder(id: task.folderId) { parts.append(folder.name) }
        if let due = Formatting.dueLabel(task.due, clock: model.clock) { parts.append("due \(due)") }
        if let effort = Formatting.effort(task.effortMinutes) { parts.append(effort) }
        parts.append("impact \(task.impact.label)")
        parts.append("score \(score)")
        if task.state != .open { parts.append(task.state.label) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Columns

    @ViewBuilder
    private var rankColumn: some View {
        Group {
            if rank == 1 {
                Text("NOW")
                    .font(.system(size: 9, weight: .bold)).kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
            } else {
                Text("\(rank ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 30)
    }

    private var titleAndChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                stateGlyph
                Text(task.title)
                    .appFont(isTopCard ? 15 : 13.5, weight: isTopCard || isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            if let folder = model.folder(id: task.folderId) {
                MetaChip(dotColor: folder.tint, text: folder.name, colors: Palette.neutralChip())
            }
            if let due = Formatting.dueLabel(task.due, clock: model.clock) {
                let overdue = (model.clock.daysUntil(task.due) ?? 0) < 0
                let today = model.clock.daysUntil(task.due) == 0
                MetaChip(systemImage: "calendar", text: due,
                         colors: Palette.due(overdue: overdue, today: today, scheme: scheme))
            }
            if let effort = Formatting.effort(task.effortMinutes) {
                MetaChip(systemImage: "bolt.fill", text: effort, colors: Palette.effort(scheme: scheme))
            }
        }
    }

    private var rightColumn: some View {
        HStack(spacing: 10) {
            ImpactPips(level: task.impact, activeColor: isSelected ? Color.accentColor : .secondary)
            Text("\(score)")
                .appFont(11.5, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var stateGlyph: some View {
        switch task.state {
        case .inProgress:
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 11)).foregroundStyle(OKLCH(0.55, 0.15, 50).color)
        case .waiting:
            Image(systemName: "hourglass")
                .font(.system(size: 11)).foregroundStyle(OKLCH(0.55, 0.12, 280).color)
        case .snoozed:
            Image(systemName: "moon.fill")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    // MARK: - Score bar (bars mode)

    private var scoreBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.06))
                Capsule()
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.3), Color.accentColor],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * Double(score) / 100)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        if isHeat {
            shape.fill(Color.accentColor.opacity((isSelected ? 0.20 : 0) + heat * 0.14))
        } else if isSelected {
            shape.fill(Color.accentColor.opacity(0.12))
        } else if isTopCard {
            shape.fill(Color.accentColor.opacity(scheme == .dark ? 0.10 : 0.05))
                .background(shape.fill(.background))
                .shadow(color: Color.accentColor.opacity(0.14), radius: 6, y: 2)
        } else if isCard {
            shape.fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        if isSelected {
            shape.strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5)
        } else if isTopCard {
            shape.strokeBorder(Color.accentColor.opacity(0.30), lineWidth: 0.5)
        } else if isCard {
            shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
}

/// The circular completion checkbox, filled with the accent when done.
struct CompletionToggle: View {
    let task: TaskItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(task.isDone ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(task.isDone ? Color.accentColor : Color.primary.opacity(0.25), lineWidth: 1.3))
                if task.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
    }
}
