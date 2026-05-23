// AppModel.swift
// The observable root state: the loaded folders/tasks, the current sidebar
// selection, the inspected task, and folder-expansion state. Owns the TaskStore
// and is the single place mutations flow through (memory + persistence stay in sync).

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var folders: [Folder]
    private(set) var tasks: [TaskItem]

    var selection: Selection = .view(.top)
    var selectedTaskID: String?
    var expandedFolders: Set<String>
    /// Set when the user invokes ⌘N; the Spotlight capture sheet observes this.
    var quickAddRequested = false

    let clock: TaskClock
    let weights = PriorityWeights.default

    @ObservationIgnored private let store: TaskStore

    init(store: TaskStore, clock: TaskClock = TaskClock()) {
        let loadedFolders = store.loadFolders()
        let loadedTasks = store.loadTasks()
        self.store = store
        self.clock = clock
        self.folders = loadedFolders
        self.tasks = loadedTasks
        // Expand top-level folders by default, matching the prototype.
        self.expandedFolders = Set(loadedFolders.filter { $0.parentId == nil }.map(\.id))
        // Open with a useful task inspected (the prototype starts on "t6").
        self.selectedTaskID = loadedTasks.first(where: { $0.id == "t6" })?.id ?? loadedTasks.first?.id
    }

    // MARK: - Derived

    var selectedTask: TaskItem? {
        guard let id = selectedTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    /// The ordered task set for the current selection.
    var visibleTasks: [TaskItem] {
        switch selection {
        case .view(let view):
            return TaskFilter.tasks(for: view, in: tasks, weights: weights, clock: clock)
        case .folder(let id):
            return TaskFilter.tasks(inFolder: id, tasks: tasks, folders: folders)
        }
    }

    func folder(id: String) -> Folder? { folders.first { $0.id == id } }

    func score(for task: TaskItem) -> Int {
        PriorityScorer.score(for: task, weights: weights, clock: clock)
    }

    // MARK: - Mutations

    /// Create a task from parsed quick-add input.
    func createTask(from parsed: ParsedQuickAdd) {
        guard !parsed.title.isEmpty else { return }
        let task = TaskItem(
            title: parsed.title,
            folderId: resolveFolder(slug: parsed.folderSlug),
            due: parsed.due,
            effortMinutes: parsed.effortMinutes,
            impact: parsed.impact ?? .medium,
            priority: parsed.priority ?? .medium,
            state: .open,
            createdAt: clock.now
        )
        // Negative, ever-decreasing order so new tasks prepend in "All".
        let order = min(store.minSortOrder(), 0) - 1
        store.insert(task, sortOrder: order)
        tasks.insert(task, at: 0)
        selectedTaskID = task.id
    }

    /// Persist an edited task and reflect it in memory.
    func update(_ task: TaskItem) {
        store.update(task)
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }

    /// Toggle a task between done and open.
    func toggleDone(_ task: TaskItem) {
        var next = task
        next.state = task.state == .done ? .open : .done
        update(next)
    }

    /// Request the Spotlight-style quick-add capture (⌘N).
    func requestQuickAdd() { quickAddRequested = true }

    func toggleFolder(_ id: String) {
        if expandedFolders.contains(id) { expandedFolders.remove(id) }
        else { expandedFolders.insert(id) }
    }

    // MARK: - Helpers

    /// Resolve a `#folder` slug to a real folder id. Falls back to the selected
    /// folder, then Inbox, when the slug doesn't match an existing folder.
    private func resolveFolder(slug: String?) -> String {
        if let slug, let match = FolderTree.folder(forSlug: slug, in: folders) {
            return match.id
        }
        if case .folder(let id) = selection { return id }
        return Folder.inboxID
    }
}
