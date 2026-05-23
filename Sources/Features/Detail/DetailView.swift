// DetailView.swift
// The always-on right inspector. Shows the inspected task's breadcrumb, title,
// the big priority score with a per-component breakdown, editable fields
// (folder/due/effort read-only; impact/priority/state via segmented controls),
// notes (read-only this slice), and an activity list. Empty state when nothing
// is selected.

import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let task = model.selectedTask {
                DetailContent(task: task)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .underWindowBackground).ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.05), in: Circle())
            Text("No task selected")
                .font(.system(size: 14, weight: .semibold))
            Text("Pick a task from the list to inspect or edit its details.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .padding(40)
    }
}

private struct DetailContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let task: TaskItem

    private var folder: Folder? { model.folder(id: task.folderId) }
    private var path: [Folder] { folder.map { FolderTree.path(to: $0.id, in: model.folders) } ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleRow
                    scoreCard
                    fields
                    notes
                    activity
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag")
                .foregroundStyle(.secondary).frame(width: 26, height: 26)
            HStack(spacing: 4) {
                ForEach(Array(path.enumerated()), id: \.element.id) { index, folder in
                    if index > 0 { Text("›").foregroundStyle(.tertiary) }
                    Text(folder.name)
                        .foregroundStyle(index == path.count - 1 ? .primary : .secondary)
                        .fontWeight(index == path.count - 1 ? .medium : .regular)
                }
            }
            .font(.system(size: 12))
            .lineLimit(1)
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary).frame(width: 26, height: 26)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            CompletionToggle(task: task) { model.toggleDone(task) }
                .padding(.top, 3)
            Text(task.title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        let components = PriorityScorer.components(for: task, clock: model.clock)
        return HStack(alignment: .center, spacing: 16) {
            Text("\(model.score(for: task))")
                .font(.system(size: 38, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                Text("PRIORITY SCORE")
                    .font(.system(size: 10.5, weight: .semibold)).kerning(0.6)
                    .foregroundStyle(.tertiary)
                VStack(spacing: 4) {
                    breakdownBar("Impact", pct: components.impact, text: task.impact.label)
                    breakdownBar("Priority", pct: components.priority, text: task.priority.label)
                    breakdownBar("Urgency", pct: components.urgency,
                                 text: Formatting.dueLabel(task.due, clock: model.clock) ?? "no date")
                    breakdownBar("Quick win", pct: components.quickWin,
                                 text: Formatting.effort(task.effortMinutes) ?? "—")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func breakdownBar(_ label: String, pct: Double, text: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.accentColor.opacity(0.4), Color.accentColor],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * pct))
                }
            }
            .frame(height: 5)
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(spacing: 0) {
            field("Folder") {
                HStack(spacing: 6) {
                    if let folder { RoundedRectangle(cornerRadius: 2).fill(folder.tint).frame(width: 8, height: 8) }
                    Text(folder?.name ?? "Unfiled")
                }
            }
            Divider().opacity(0.4)
            field("Due") {
                let overdue = (model.clock.daysUntil(task.due) ?? 0) < 0
                Text(dueText)
                    .foregroundStyle(overdue ? Palette.overdueText(scheme: scheme) : .primary)
            }
            Divider().opacity(0.4)
            field("Effort") { Text(Formatting.effort(task.effortMinutes) ?? "Unestimated") }
            Divider().opacity(0.4)
            field("Impact") {
                Picker("", selection: levelBinding(\.impact)) {
                    ForEach(Level.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Divider().opacity(0.4)
            field("Priority") {
                Picker("", selection: levelBinding(\.priority)) {
                    ForEach(Level.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Divider().opacity(0.4)
            field("State") {
                Picker("", selection: stateBinding) {
                    ForEach(TaskState.editable) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private var dueText: String {
        guard let due = task.due else { return "No due date" }
        let absolute = Formatting.date(due, clock: model.clock) ?? ""
        let relative = Formatting.dueLabel(due, clock: model.clock) ?? ""
        return "\(absolute)  ·  \(relative)"
    }

    // MARK: - Notes & activity

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Notes")
            if let text = task.notes, !text.isEmpty {
                Text(text)
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Click to add notes…")
                    .font(.system(size: 12.5)).italic().foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Activity")
            activityRow(color: .secondary, "Created  ·  3 days ago")
            if task.state == .inProgress {
                activityRow(color: OKLCH(0.65, 0.15, 50).color, "Marked in progress  ·  yesterday")
            }
            if task.state == .waiting {
                activityRow(color: OKLCH(0.62, 0.12, 280).color, "Marked waiting  ·  Mon May 18")
            }
            activityRow(color: Color.accentColor, "Score recomputed  ·  just now")
        }
    }

    private func activityRow(color: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold)).kerning(0.6)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Bindings

    private func levelBinding(_ keyPath: WritableKeyPath<TaskItem, Level>) -> Binding<Level> {
        Binding(
            get: { task[keyPath: keyPath] },
            set: { var next = task; next[keyPath: keyPath] = $0; model.update(next) }
        )
    }

    private var stateBinding: Binding<TaskState> {
        Binding(
            get: { task.state == .done ? .open : task.state },
            set: { var next = task; next.state = $0; model.update(next) }
        )
    }
}
