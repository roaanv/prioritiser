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
                // .id keeps editor state (notes draft) stable per task and resets
                // it when a different task is selected.
                DetailContent(task: task).id(task.id)
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

    /// Local editing buffer for notes (persisted on change), kept stable across the
    /// re-renders that editing triggers. Reset by the parent's `.id(task.id)`.
    @State private var notesDraft = ""

    /// Common effort presets offered in the effort menu (minutes).
    private let effortPresets = [5, 10, 15, 30, 45, 60, 120, 240, 480, 960, 1440]

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
        .onAppear { notesDraft = task.notes ?? "" }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag")
                .foregroundStyle(.secondary).frame(width: 26, height: 26)
                .accessibilityHidden(true)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Folder path: " + path.map(\.name).joined(separator: ", "))
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary).frame(width: 26, height: 26)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            CompletionToggle(task: task) { model.toggleDone(task) }
                .padding(.top, 3)
            Text(task.title)
                .appFont(19, weight: .semibold, relativeTo: .title2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        let components = PriorityScorer.components(for: task, clock: model.clock)
        return HStack(alignment: .center, spacing: 16) {
            Text("\(model.score(for: task))")
                .appFont(38, weight: .bold, relativeTo: .largeTitle)
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
            field("Folder") { folderMenu }
            Divider().opacity(0.4)
            field("Due") { dueEditor }
            Divider().opacity(0.4)
            field("Effort") { effortMenu }
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
            if task.state == .snoozed {
                Divider().opacity(0.4)
                field("Snooze until") {
                    DatePicker("", selection: snoozeBinding, displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact).fixedSize()
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .appFont(12.5).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
                .appFont(12.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Editors

    private var folderMenu: some View {
        Menu {
            ForEach(model.folders) { option in
                Button {
                    setField { $0.folderId = option.id }
                } label: {
                    Text(folderPathLabel(option))
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let folder { RoundedRectangle(cornerRadius: 2).fill(folder.tint).frame(width: 8, height: 8) }
                Text(folder?.name ?? "Unfiled")
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var dueEditor: some View {
        if task.due != nil {
            HStack(spacing: 8) {
                DatePicker("", selection: dueBinding, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact).fixedSize()
                let overdue = (model.clock.daysUntil(task.due) ?? 0) < 0
                Text(Formatting.dueLabel(task.due, clock: model.clock) ?? "")
                    .foregroundStyle(overdue ? Palette.overdueText(scheme: scheme) : .secondary)
                Button { setField { $0.due = nil } } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .help("Clear due date")
            }
        } else {
            Button("Add due date") { setField { $0.due = model.clock.today } }
                .buttonStyle(.link)
        }
    }

    private var effortMenu: some View {
        Menu {
            Button("Unestimated") { setField { $0.effortMinutes = nil } }
            ForEach(effortPresets, id: \.self) { minutes in
                Button(Formatting.effort(minutes) ?? "") { setField { $0.effortMinutes = minutes } }
            }
        } label: {
            HStack(spacing: 4) {
                Text(Formatting.effort(task.effortMinutes) ?? "Unestimated")
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func folderPathLabel(_ folder: Folder) -> String {
        FolderTree.path(to: folder.id, in: model.folders).map(\.name).joined(separator: " › ")
    }

    /// Mutate a copy of the task and persist it.
    private func setField(_ mutate: (inout TaskItem) -> Void) {
        var next = task
        mutate(&next)
        model.update(next)
    }

    private var dueBinding: Binding<Date> {
        Binding(get: { task.due ?? model.clock.today }, set: { date in setField { $0.due = date } })
    }

    // MARK: - Notes & activity

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Notes")
            TextEditor(text: $notesDraft)
                .appFont(12.5)
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 56)
                .overlay(alignment: .topLeading) {
                    if notesDraft.isEmpty {
                        Text("Add notes…")
                            .font(.system(size: 12.5)).italic().foregroundStyle(.tertiary)
                            .padding(.top, 1)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: notesDraft) { _, new in
                    setField { $0.notes = new.isEmpty ? nil : new }
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
            let events = model.activity(for: task.id)
            if events.isEmpty {
                Text("No activity yet.").font(.system(size: 11.5)).foregroundStyle(.tertiary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: 8) {
                        Image(systemName: event.kind.systemImage)
                            .font(.system(size: 9))
                            .foregroundStyle(color(for: event.kind))
                            .frame(width: 11)
                        Text(event.summary).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(relativeTime(event.timestamp)).foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 11.5))
                }
            }
        }
    }

    private func color(for kind: ActivityKind) -> Color {
        switch kind {
        case .created: return .secondary
        case .completed: return OKLCH(0.60, 0.15, 145).color   // green
        case .reopened: return .secondary
        case .stateChanged: return OKLCH(0.65, 0.15, 50).color  // orange
        case .dueChanged, .folderChanged: return Color.accentColor
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: model.clock.now)
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
            set: { newState in
                setField { next in
                    next.state = newState
                    // Snoozing defaults to a week out; leaving snooze clears the date.
                    if newState == .snoozed {
                        if next.snoozedUntil == nil {
                            next.snoozedUntil = model.clock.addingDays(7, to: model.clock.today)
                        }
                    } else {
                        next.snoozedUntil = nil
                    }
                }
            }
        )
    }

    private var snoozeBinding: Binding<Date> {
        Binding(
            get: { task.snoozedUntil ?? model.clock.addingDays(7, to: model.clock.today) },
            set: { date in setField { $0.snoozedUntil = date } }
        )
    }
}
