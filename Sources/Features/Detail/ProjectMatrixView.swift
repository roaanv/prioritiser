// ProjectMatrixView.swift
// The "Priority Matrix" panel pinned below the detail pane: an Eisenhower 2×2 of
// the current selection's tasks. Shown for folders and for whole-set smart views
// (Top Priorities / All Tasks / Inbox); hidden for axis-defined views (Today,
// Overdue, Next 7, Quick Wins — see SmartView.supportsMatrix). Clicking a quadrant
// filters the task list to it; cells are tinted by a count-driven temperature heat,
// and selection is conveyed by the accent ring.

import SwiftUI

struct ProjectMatrixView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let tasks = model.matrixBaseTasks {
            panel(title: title, tasks: tasks, scopeNote: scopeNote)
        }
    }

    /// Heading title: the folder name, or the smart view's name.
    private var title: String {
        switch model.selection {
        case .folder(let id): return model.folder(id: id)?.name ?? "Project"
        case .view(let view): return view.title
        }
    }

    /// Scope caption — only for folders that have sub-projects (reflects the list toggle).
    private var scopeNote: String? {
        guard case .folder(let id) = model.selection,
              model.folders.contains(where: { $0.parentId == id }) else { return nil }
        return model.includeSubprojects ? "incl. sub-projects" : "this project"
    }

    private func panel(title: String, tasks: [TaskItem], scopeNote: String?) -> some View {
        let counts = Eisenhower.counts(for: tasks, clock: model.clock)
        let maxCount = max(counts.values.max() ?? 0, 1)

        return VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                header(title: title, total: tasks.count, scopeNote: scopeNote)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        cell(.doNow, counts: counts, maxCount: maxCount)
                        cell(.plan, counts: counts, maxCount: maxCount)
                    }
                    HStack(spacing: 8) {
                        cell(.quickDecisions, counts: counts, maxCount: maxCount)
                        cell(.backlog, counts: counts, maxCount: maxCount)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(.bar)
    }

    private func header(title: String, total: Int, scopeNote: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("PRIORITY MATRIX")
                    .appFont(10.5, weight: .semibold).kerning(0.6)
                    .foregroundStyle(.tertiary)
                Text("\(title) · \(total) \(total == 1 ? "task" : "tasks")")
                    .appFont(13, weight: .semibold)
                    .lineLimit(1)
            }
            Spacer()
            if let scopeNote {
                Text(scopeNote).appFont(10.5).foregroundStyle(.tertiary)
            }
        }
    }

    private func cell(_ quadrant: EisenhowerQuadrant, counts: [EisenhowerQuadrant: Int], maxCount: Int) -> some View {
        let n = counts[quadrant] ?? 0
        let selected = model.quadrantFilter == quadrant
        // Heat encodes the count (cool → warm, relative to the busiest quadrant);
        // empty quadrants get no tint. Selection is conveyed solely by the accent ring.
        let fill: Color = n == 0 ? .clear : Palette.heat(Double(n) / Double(maxCount), scheme: scheme)
        return Button {
            model.toggleQuadrantFilter(quadrant)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(n)")
                    .appFont(22, weight: .bold, relativeTo: .title2)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(quadrant.title)
                    .appFont(11.5, weight: .semibold)
                    .foregroundStyle(.primary)
                Text(quadrant.subtitle)
                    .appFont(10)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08),
                                  lineWidth: selected ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(selected ? "Clear filter" : "Filter the list to “\(quadrant.title)”")
    }
}
