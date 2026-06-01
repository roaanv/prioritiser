// DockPanes.swift
// Content for each dockable tab.

import SwiftUI

struct ViewsDockPane: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    private let topTint = OKLCH(0.62, 0.18, 60).color

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            DockSearchField(text: $model.searchQuery, focused: $searchFocused)
                .padding(.horizontal, 8)
                .padding(.top, 8)
            VStack(spacing: 2) {
                ForEach(SmartView.allCases) { view in
                    Button { model.selection = .view(view) } label: {
                        row(view)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .onChange(of: model.focusSearchToken) { searchFocused = true }
    }

    private func row(_ view: SmartView) -> some View {
        let selected = model.selection == .view(view)
        let count = TaskFilter.badgeCount(for: view, tasks: model.tasks,
                                          weights: model.weights, clock: model.clock)
        return HStack(spacing: 6) {
            Image(systemName: view.systemImage)
                .frame(width: 18)
                .foregroundStyle(selected ? AnyShapeStyle(.white)
                                 : AnyShapeStyle(view == .top ? topTint : Color.accentColor))
            Text(view.title)
                .foregroundStyle(selected ? .white : .primary)
            Spacer(minLength: 4)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: view.isAlert ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(selected ? AnyShapeStyle(.white)
                                     : AnyShapeStyle(view.isAlert ? Palette.overdueText(scheme: .light) : Color.secondary))
            }
        }
        .appFont(13)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

struct FoldersDockPane: View {
    @Environment(AppModel.self) private var model
    @State private var rootTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            header
                .padding(.horizontal, 8)
                .padding(.top, 8)
            FolderOutlineView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Text("Folders")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                let id = model.addFolder(name: "New Folder", parentId: nil)
                model.selection = .folder(id)
            } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New folder")
            .accessibilityLabel("New folder")
        }
        .contentShape(Rectangle())
        .background(rootTargeted ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let draggedID = DraggedFolderPayload.folderID(from: raw) else { return false }
            model.reparentFolder(draggedID, under: nil)
            rootTargeted = false
            return true
        } isTargeted: { rootTargeted = $0 }
    }
}

struct PriorityScoreDockPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let task = model.selectedTask {
            let components = PriorityScorer.components(for: task, clock: model.clock)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(model.score(for: task))")
                        .appFont(42, weight: .bold, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                    Text("PRIORITY SCORE")
                        .font(.system(size: 10.5, weight: .semibold)).kerning(0.6)
                        .foregroundStyle(.tertiary)
                }
                scoreBar("Impact", pct: components.impact, value: task.impact.label)
                scoreBar("Priority", pct: components.priority, value: task.priority.label)
                scoreBar("Urgency", pct: components.urgency,
                         value: Formatting.dueLabel(task.due, clock: model.clock) ?? "no date")
                scoreBar("Quick win", pct: components.quickWin,
                         value: Formatting.effort(task.effortMinutes) ?? "—")
                Spacer(minLength: 0)
            }
            .padding(14)
        } else {
            EmptyDockPaneText("Select a task to see its priority score.")
        }
    }

    private func scoreBar(_ label: String, pct: Double, value: String) -> some View {
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
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .frame(minWidth: 58, alignment: .trailing)
        }
    }
}

struct ItemDetailsDockPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let effortPresets = [5, 10, 15, 30, 45, 60, 120, 240, 480, 960, 1440]

    var body: some View {
        if let task = model.selectedTask {
            VStack(alignment: .leading, spacing: 0) {
                field("Folder") { folderMenu(task) }
                Divider().opacity(0.4)
                field("Due") { dueEditor(task) }
                Divider().opacity(0.4)
                field("Effort") { effortMenu(task) }
                Divider().opacity(0.4)
                field("Impact") {
                    Picker("", selection: levelBinding(task, \.impact)) {
                        ForEach(Level.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                Divider().opacity(0.4)
                field("Priority") {
                    Picker("", selection: levelBinding(task, \.priority)) {
                        ForEach(Level.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                Divider().opacity(0.4)
                field("State") {
                    Picker("", selection: stateBinding(task)) {
                        ForEach(TaskState.editable) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                if task.state == .snoozed {
                    Divider().opacity(0.4)
                    field("Snooze until") {
                        DatePicker("", selection: snoozeBinding(task), displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact).fixedSize()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        } else {
            EmptyDockPaneText("Select a task to edit its details.")
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .appFont(12.5).foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            content()
                .appFont(12.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private func folderMenu(_ task: TaskItem) -> some View {
        Menu {
            ForEach(model.folders) { option in
                Button { setField(task) { $0.folderId = option.id } } label: {
                    Text(FolderTree.path(to: option.id, in: model.folders).map(\.name).joined(separator: " › "))
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let folder = model.folder(id: task.folderId) {
                    RoundedRectangle(cornerRadius: 2).fill(folder.tint).frame(width: 8, height: 8)
                    Text(folder.name)
                } else {
                    Text("Unfiled")
                }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func dueEditor(_ task: TaskItem) -> some View {
        if task.due != nil {
            HStack(spacing: 8) {
                DatePicker("", selection: dueBinding(task), displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact).fixedSize()
                let overdue = (model.clock.daysUntil(task.due) ?? 0) < 0
                Text(Formatting.dueLabel(task.due, clock: model.clock) ?? "")
                    .foregroundStyle(overdue ? Palette.overdueText(scheme: scheme) : .secondary)
                Button { setField(task) { $0.due = nil } } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .help("Clear due date")
            }
        } else {
            Button("Add due date") { setField(task) { $0.due = model.clock.today } }
                .buttonStyle(.link)
        }
    }

    private func effortMenu(_ task: TaskItem) -> some View {
        Menu {
            Button("Unestimated") { setField(task) { $0.effortMinutes = nil } }
            ForEach(effortPresets, id: \.self) { minutes in
                Button(Formatting.effort(minutes) ?? "") { setField(task) { $0.effortMinutes = minutes } }
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

    private func setField(_ task: TaskItem, _ mutate: (inout TaskItem) -> Void) {
        var next = task
        mutate(&next)
        model.update(next)
    }

    private func dueBinding(_ task: TaskItem) -> Binding<Date> {
        Binding(get: { task.due ?? model.clock.today }, set: { date in setField(task) { $0.due = date } })
    }

    private func levelBinding(_ task: TaskItem, _ keyPath: WritableKeyPath<TaskItem, Level>) -> Binding<Level> {
        Binding(get: { task[keyPath: keyPath] }, set: { value in setField(task) { $0[keyPath: keyPath] = value } })
    }

    private func stateBinding(_ task: TaskItem) -> Binding<TaskState> {
        Binding(
            get: { task.state == .done ? .open : task.state },
            set: { newState in
                setField(task) { next in
                    next.state = newState
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

    private func snoozeBinding(_ task: TaskItem) -> Binding<Date> {
        Binding(
            get: { task.snoozedUntil ?? model.clock.addingDays(7, to: model.clock.today) },
            set: { date in setField(task) { $0.snoozedUntil = date } }
        )
    }
}

struct NotesDockPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let task = model.selectedTask {
            MarkdownNotesEditor(
                text: Binding(
                    get: { model.selectedTask?.notes ?? "" },
                    set: { newValue in
                        guard var next = model.selectedTask else { return }
                        next.notes = newValue.isEmpty ? nil : newValue
                        model.update(next)
                    }
                ),
                placeholder: "Add notes…",
                minHeight: 120,
                fontSize: 12.5
            )
            .id(task.id)
            .padding(14)
        } else {
            EmptyDockPaneText("Select a task to edit notes.")
        }
    }
}

struct ActivityDockPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let task = model.selectedTask {
            let events = model.activity(for: task.id)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if events.isEmpty {
                        Text("No activity yet.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        } else {
            EmptyDockPaneText("Select a task to see activity.")
        }
    }

    private func color(for kind: ActivityKind) -> Color {
        switch kind {
        case .created: .secondary
        case .completed: OKLCH(0.60, 0.15, 145).color
        case .reopened: .secondary
        case .stateChanged: OKLCH(0.65, 0.15, 50).color
        case .dueChanged, .folderChanged: Color.accentColor
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: model.clock.now)
    }
}

private struct DockSearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused(focused)
            if text.isEmpty {
                KeyCap("⌘F")
            } else {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyDockPaneText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
    }
}
