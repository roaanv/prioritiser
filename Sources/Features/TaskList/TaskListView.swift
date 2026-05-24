// TaskListView.swift
// The center pane: a context-aware heading, a quick-add bar, and the task list.
// The List/Schedule tabs switch layout; the Sort and Filter menus reshape the
// flat list; search (from the sidebar) narrows it. On "Top Priorities" the List
// layout splits into a "Top 5 Now" band of ranked cards and a "Next Up" remainder.
// In All Tasks with manual sort and no filters, rows can be dragged to reorder.

import SwiftUI
import AppKit

struct TaskListView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("priorityViz") private var vizMode: PriorityVizMode = .cards
    @State private var layout: TaskViewMode = .list
    @State private var sortKey: TaskSort = .manual
    @State private var stateFilter: StateFilter = .all
    @FocusState private var listFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header
                QuickAddBar { model.createTask(from: $0) }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
                taskScroll
                footer
            }
            .background(Color(nsColor: .textBackgroundColor))
            .background { deleteShortcut }
            // Focus the list pane so ↑/↓ move the selection and ⌘⌫ deletes; selecting
            // a row (which changes the selection) re-focuses it, off any text editor.
            .focusable()
            .focusEffectDisabled()
            .focused($listFocused)
            .onMoveCommand { direction in move(direction, proxy: proxy) }
            .onAppear { listFocused = true }
            .onChange(of: model.selectedTaskIDs) { listFocused = true }
            .alert("Delete tasks?", isPresented: deletionAlertBinding, presenting: model.pendingDeletion) { _ in
                Button("Delete", role: .destructive) { model.confirmPendingDeletion() }
                Button("Cancel", role: .cancel) { model.pendingDeletion = nil }
            } message: { ids in
                Text("Permanently delete \(ids.count) tasks? This can’t be undone.")
            }
        }
    }

    /// ⌘⌫ deletes the current selection. A hidden command button (not `.onKeyPress`)
    /// so the ⌘-modified key is caught via key-equivalent dispatch rather than beeping.
    private var deleteShortcut: some View {
        Button(action: deleteSelectionViaShortcut) { EmptyView() }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(model.selectedTaskIDs.isEmpty)
            .opacity(0)
            .accessibilityHidden(true)
    }

    /// Skip deletion while a text field/editor is first responder, so ⌘⌫ never fires
    /// mid-edit (notes, quick-add, inline rename) — it just no-ops there.
    private func deleteSelectionViaShortcut() {
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSText { return }
        model.requestDeletion(of: model.selectedTaskIDs)
    }

    /// Drives the multi-delete confirmation alert from `model.pendingDeletion`.
    private var deletionAlertBinding: Binding<Bool> {
        Binding(get: { model.pendingDeletion != nil },
                set: { presented in if !presented { model.pendingDeletion = nil } })
    }

    // MARK: - Keyboard navigation

    /// The visible task ids in display order — what ↑/↓ steps through (matches the
    /// rendered grouping for the schedule and top-priority layouts).
    private var navigableIDs: [String] {
        if layout == .schedule {
            return DueBucket.allCases.flatMap { bucket in
                displayTasks
                    .filter { DueBucket.bucket(for: $0.due, clock: model.clock) == bucket }
                    .map(\.id)
            }
        } else if isTopView {
            return topTasks.map(\.id)
        } else {
            return displayTasks.map(\.id)
        }
    }

    /// Move the (single) selection up/down the visible list, scrolling it into view.
    /// With nothing selected, ↓ picks the first row and ↑ the last.
    private func move(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        let ids = navigableIDs
        guard !ids.isEmpty else { return }
        let current = model.selectedTaskID.flatMap { ids.firstIndex(of: $0) }
        let target: Int
        switch direction {
        case .up:   target = current.map { max(0, $0 - 1) } ?? (ids.count - 1)
        case .down: target = current.map { min(ids.count - 1, $0 + 1) } ?? 0
        default:    return
        }
        let id = ids[target]
        model.selectOnly(id)
        proxy.scrollTo(id)
    }

    // MARK: - Display pipeline

    /// State-filtered, sorted tasks for the flat / schedule layouts.
    private var displayTasks: [TaskItem] {
        sortKey.sorted(stateFilter.apply(model.visibleTasks), score: model.score)
    }

    /// Top view keeps its score ordering; only the state filter applies.
    private var topTasks: [TaskItem] { stateFilter.apply(model.visibleTasks) }

    private var isTopView: Bool {
        if case .view(.top) = model.selection { return true }
        return false
    }

    private var isCompletedView: Bool {
        if case .view(.completed) = model.selection { return true }
        return false
    }

    /// Manual reordering is only unambiguous in All Tasks, manual sort, list layout,
    /// with no active filter or search.
    private var reorderable: Bool {
        layout == .list && sortKey == .manual && stateFilter == .all
            && !model.isSearching && model.selection == .view(.all)
    }

    // MARK: - Header

    private var header: some View {
        @Bindable var model = model
        return HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(heading.title)
                        .appFont(22, weight: .semibold, relativeTo: .title)
                        .foregroundStyle(.primary)
                    if let quadrant = model.quadrantFilter {
                        quadrantChip(quadrant)
                    }
                }
                if let sub = heading.subtitle {
                    Text(sub)
                        .appFont(12.5)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            headerTools(include: $model.includeSubprojects)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private func headerTools(include: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            if folderHasChildren {
                Toggle(isOn: include) {
                    Label("Subprojects", systemImage: "list.bullet.indent")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Include tasks from sub-projects")
                Divider().frame(height: 16).padding(.horizontal, 4)
            }
            // The Completed log ignores layout/sort/filter (it's grouped by day), so
            // those controls are hidden there.
            if !isCompletedView {
                ForEach(TaskViewMode.allCases) { mode in
                    Button { layout = mode } label: {
                        Label(mode.label, systemImage: mode.systemImage)
                            .font(.system(size: 12))
                            .foregroundStyle(layout == mode ? .primary : .secondary)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(layout == mode ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.clear),
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(layout == mode ? [.isButton, .isSelected] : .isButton)
                }
                Divider().frame(height: 16).padding(.horizontal, 4)
                sortMenu
                filterMenu
            }
        }
    }

    private func quadrantChip(_ quadrant: EisenhowerQuadrant) -> some View {
        Button { model.quadrantFilter = nil } label: {
            HStack(spacing: 4) {
                Text(quadrant.title).appFont(11, weight: .medium)
                Image(systemName: "xmark.circle.fill").font(.system(size: 10))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Clear quadrant filter")
    }

    private var folderHasChildren: Bool {
        if case .folder(let id) = model.selection {
            return model.folders.contains { $0.parentId == id }
        }
        return false
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortKey) {
                ForEach(TaskSort.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("Sort")
        .accessibilityLabel("Sort")
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $stateFilter) {
                ForEach(StateFilter.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            Image(systemName: stateFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13)).foregroundStyle(stateFilter == .all ? .secondary : Color.accentColor)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("Filter")
        .accessibilityLabel("Filter")
    }

    // MARK: - List

    private var taskScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isCompletedView {
                    completedContent
                } else if layout == .schedule {
                    scheduleContent
                } else if isTopView {
                    topContent
                } else {
                    flatContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    /// Completed tasks grouped by the day they were finished, most recent first.
    /// Tasks whose completion date couldn't be determined fall into a trailing group.
    @ViewBuilder
    private var completedContent: some View {
        let done = model.visibleTasks // TaskFilter.completed → done, newest-completed first
        if done.isEmpty {
            emptyView
        } else {
            let groups = completedGroups(done)
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                band(label: group.label, trailing: "\(group.tasks.count)")
                flatRows(group.tasks, vizMode: .cards, reorderable: false)
            }
        }
    }

    /// Bucket completed tasks by start-of-day of `completedAt`, preserving the
    /// newest-first order (so the day groups come out descending).
    private func completedGroups(_ tasks: [TaskItem]) -> [(label: String, tasks: [TaskItem])] {
        var order: [Date] = []
        var byDay: [Date: [TaskItem]] = [:]
        for task in tasks {
            let day = task.completedAt.map { model.clock.startOfDay($0) } ?? .distantPast
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(task)
        }
        return order.map { (completedDayLabel($0), byDay[$0] ?? []) }
    }

    private func completedDayLabel(_ day: Date) -> String {
        if day == .distantPast { return "Completion date unknown" }
        switch model.clock.daysUntil(day) {
        case 0: return "Today"
        case -1: return "Yesterday"
        default: return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }

    @ViewBuilder
    private var topContent: some View {
        let tasks = topTasks
        let top = Array(tasks.prefix(5))
        let rest = Array(tasks.dropFirst(5))

        band(label: "Top 5 now",
             trailing: "Recalculated \(Date().formatted(date: .omitted, time: .shortened))")
        VStack(spacing: 4) {
            ForEach(Array(top.enumerated()), id: \.element.id) { index, task in
                TaskRowView(task: task, rank: vizMode == .cards ? index + 1 : nil, vizMode: vizMode)
                    .id(task.id)
            }
        }
        if !rest.isEmpty {
            band(label: "Next up", trailing: "\(rest.count) more").padding(.top, 18)
            flatRows(rest, vizMode: .cards, reorderable: false)
        }
    }

    @ViewBuilder
    private var flatContent: some View {
        let tasks = displayTasks
        if tasks.isEmpty {
            emptyView
        } else {
            flatRows(tasks, vizMode: vizMode, reorderable: reorderable)
        }
    }

    @ViewBuilder
    private var scheduleContent: some View {
        let tasks = displayTasks
        if tasks.isEmpty {
            emptyView
        } else {
            ForEach(DueBucket.allCases) { bucket in
                let group = tasks.filter { DueBucket.bucket(for: $0.due, clock: model.clock) == bucket }
                if !group.isEmpty {
                    band(label: bucket.title, trailing: "\(group.count)")
                    flatRows(group, vizMode: vizMode, reorderable: false)
                }
            }
        }
    }

    private var emptyView: some View {
        Text(model.isSearching ? "No matching tasks." : emptyMessage)
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }

    private func flatRows(_ tasks: [TaskItem], vizMode: PriorityVizMode, reorderable: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider().opacity(0.4).padding(.horizontal, 14)
                }
                row(task, vizMode: vizMode, reorderable: reorderable)
                    .id(task.id)
            }
        }
    }

    @ViewBuilder
    private func row(_ task: TaskItem, vizMode: PriorityVizMode, reorderable: Bool) -> some View {
        if reorderable {
            TaskRowView(task: task, vizMode: vizMode)
                .draggable(task.id)
                .dropDestination(for: String.self) { items, _ in
                    if let dragged = items.first { model.moveTask(dragged, before: task.id) }
                    return true
                }
        } else {
            TaskRowView(task: task, vizMode: vizMode)
        }
    }

    private func band(label: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold)).kerning(0.6)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(trailing)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8).padding(.bottom, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            let count = isCompletedView ? model.visibleTasks.count
                : (layout == .schedule || !isTopView ? displayTasks.count : topTasks.count)
            Text("\(count) \(count == 1 ? "task" : "tasks")")
            Text("·")
            Spacer()
            HStack(spacing: 4) {
                KeyCap("⌘"); KeyCap("N"); Text("Quick add")
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 24).padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Heading & empty copy

    private var heading: (title: String, subtitle: String?) {
        if model.isSearching {
            return ("Search", "Results for “\(model.searchQuery.trimmingCharacters(in: .whitespaces))”")
        }
        switch model.selection {
        case .view(let view):
            return (view.title, view.subtitle)
        case .folder(let id):
            let path = FolderTree.path(to: id, in: model.folders)
            let title = path.last?.name ?? "Folder"
            let sub = path.count > 1 ? path.dropLast().map(\.name).joined(separator: "  ›  ") : nil
            return (title, sub)
        }
    }

    private var emptyMessage: String {
        switch model.selection {
        case .view(let view): return view.emptyMessage
        case .folder: return "This folder is empty."
        }
    }
}
