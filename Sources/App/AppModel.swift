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

    // Sidebar state persists across launches (see didSet observers).
    var selection: Selection {
        didSet {
            defaults.set(selection.persistedString, forKey: Keys.selection)
            quadrantFilter = nil // a quadrant filter is scoped to one project view
        }
    }
    var selectedTaskID: String? {
        didSet { defaults.set(selectedTaskID, forKey: Keys.selectedTask) }
    }
    var expandedFolders: Set<String> {
        didSet { defaults.set(Array(expandedFolders), forKey: Keys.expanded) }
    }
    /// Set when the user invokes ⌘N; the Spotlight capture sheet observes this.
    var quickAddRequested = false
    /// Live search text from the sidebar; filters the visible task set.
    var searchQuery = ""
    /// Bumped when ⌘F is pressed; the sidebar search field focuses on change.
    var focusSearchToken = 0
    /// Shared folder scope: include descendant projects in the list AND the matrix.
    var includeSubprojects: Bool {
        didSet { defaults.set(includeSubprojects, forKey: Keys.includeSubprojects) }
    }
    /// When set (via the matrix), the folder list is narrowed to this quadrant.
    var quadrantFilter: EisenhowerQuadrant?

    let clock: TaskClock
    let weights = PriorityWeights.default

    @ObservationIgnored private let store: TaskStore
    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let selection = "ui.selection"
        static let selectedTask = "ui.selectedTaskID"
        static let expanded = "ui.expandedFolders"
        static let includeSubprojects = "ui.includeSubprojects"
    }

    init(store: TaskStore, clock: TaskClock = TaskClock(), defaults: UserDefaults = .standard) {
        let loadedFolders = store.loadFolders()
        let loadedTasks = store.loadTasks()
        self.store = store
        self.clock = clock
        self.defaults = defaults
        self.folders = loadedFolders
        self.tasks = loadedTasks
        // Default to showing sub-projects (the list's pre-existing behavior).
        self.includeSubprojects = defaults.object(forKey: Keys.includeSubprojects) as? Bool ?? true
        self.quadrantFilter = nil

        // Restore expanded folders (default: top-level folders open).
        if let saved = defaults.array(forKey: Keys.expanded) as? [String] {
            self.expandedFolders = Set(saved)
        } else {
            self.expandedFolders = Set(loadedFolders.filter { $0.parentId == nil }.map(\.id))
        }

        // Restore the last selection, validating any folder still exists.
        if let raw = defaults.string(forKey: Keys.selection),
           let saved = Selection(persisted: raw),
           Self.isValid(saved, in: loadedFolders) {
            self.selection = saved
        } else {
            self.selection = .view(.top)
        }

        // Restore the inspected task (default: the prototype's "t6").
        if let savedTask = defaults.string(forKey: Keys.selectedTask),
           loadedTasks.contains(where: { $0.id == savedTask }) {
            self.selectedTaskID = savedTask
        } else {
            self.selectedTaskID = loadedTasks.first(where: { $0.id == "t6" })?.id ?? loadedTasks.first?.id
        }

        wakeDueSnoozedTasks()
    }

    private static func isValid(_ selection: Selection, in folders: [Folder]) -> Bool {
        switch selection {
        case .view: return true
        case .folder(let id): return folders.contains { $0.id == id }
        }
    }

    // MARK: - Derived

    var selectedTask: TaskItem? {
        guard let id = selectedTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    /// Live tasks for a folder at the current scope (this folder, or + descendants).
    /// Used by both the task list and the project matrix so their counts agree.
    func folderScopedTasks(_ folderId: String) -> [TaskItem] {
        includeSubprojects
            ? TaskFilter.tasks(inFolder: folderId, tasks: tasks, folders: folders)
            : TaskFilter.directTasks(inFolder: folderId, tasks: tasks)
    }

    /// The task set the project matrix summarizes for the current selection, or nil
    /// when the matrix doesn't apply (Today / Overdue / Next 7 / Quick Wins). This is
    /// the same base the list uses, so quadrant counts equal the filtered list size.
    var matrixBaseTasks: [TaskItem]? {
        switch selection {
        case .folder(let id):
            return folderScopedTasks(id)
        case .view(let view):
            return view.supportsMatrix
                ? TaskFilter.tasks(for: view, in: tasks, weights: weights, clock: clock)
                : nil
        }
    }

    /// The ordered task set for the current selection, narrowed by the quadrant
    /// filter (where the matrix applies) and the search query.
    var visibleTasks: [TaskItem] {
        var base: [TaskItem]
        switch selection {
        case .view(let view):
            base = TaskFilter.tasks(for: view, in: tasks, weights: weights, clock: clock)
            if let quadrant = quadrantFilter, view.supportsMatrix {
                base = base.filter { Eisenhower.quadrant(for: $0, clock: clock) == quadrant }
            }
        case .folder(let id):
            base = folderScopedTasks(id)
            if let quadrant = quadrantFilter {
                base = base.filter { Eisenhower.quadrant(for: $0, clock: clock) == quadrant }
            }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return base }
        return base.filter { task in
            task.title.localizedCaseInsensitiveContains(query)
                || (task.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var isSearching: Bool { !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    func toggleQuadrantFilter(_ quadrant: EisenhowerQuadrant) {
        quadrantFilter = (quadrantFilter == quadrant) ? nil : quadrant
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
        store.appendActivity(ActivityEvent(taskId: task.id, kind: .created, timestamp: task.createdAt))
        tasks.insert(task, at: 0)
        selectedTaskID = task.id
    }

    /// Persist an edited task, reflect it in memory, and log notable changes.
    func update(_ task: TaskItem) {
        let previous = tasks.first { $0.id == task.id }
        store.update(task)
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        if let previous { logChanges(from: previous, to: task) }
    }

    /// Toggle a task between done and open (logged as completed / reopened).
    func toggleDone(_ task: TaskItem) {
        var next = task
        next.state = task.state == .done ? .open : .done
        update(next) // logChanges skips done transitions; we log them explicitly below
        store.appendActivity(ActivityEvent(taskId: task.id,
                                            kind: next.state == .done ? .completed : .reopened))
    }

    /// Activity events for a task, newest first.
    func activity(for taskId: String) -> [ActivityEvent] {
        store.loadActivity(taskId: taskId)
    }

    /// Return any snoozed task whose snooze date has passed to the open state.
    /// Run at launch — like a "scheduled for later" task waking up on the due day.
    func wakeDueSnoozedTasks() {
        let due = tasks.filter { task in
            task.state == .snoozed
                && (task.snoozedUntil.map { clock.startOfDay($0) <= clock.today } ?? false)
        }
        for task in due {
            var next = task
            next.state = .open
            next.snoozedUntil = nil
            update(next) // logs the state change to "Open"
        }
    }

    /// Move a folder under a new parent (`nil` = top level), persisting the change.
    /// Guards against moving a system folder, and against cycles (a folder can't be
    /// moved into itself or one of its own descendants). The moved folder is placed
    /// last among its new siblings.
    func reparentFolder(_ draggedID: String, under newParentID: String?) {
        guard let dragged = folder(id: draggedID), !dragged.isSystem,
              dragged.parentId != newParentID,
              let index = folders.firstIndex(where: { $0.id == draggedID }) else { return }
        if let newParentID {
            guard newParentID != draggedID,
                  !FolderTree.isDescendant(newParentID, ofOrEqual: draggedID, in: folders) else { return }
        }
        folders[index].parentId = newParentID
        store.updateFolder(folders[index])
        store.updateFolderSortOrder(id: draggedID, sortOrder: store.maxFolderSortOrder() + 1)
        folders = store.loadFolders() // re-sort in memory to match the persisted order
        if let newParentID { expandedFolders.insert(newParentID) } // reveal the move
    }

    /// Insert a folder immediately before `targetID`, among `target`'s siblings
    /// (re-parenting to the target's parent if needed). Used for drop-between
    /// reordering. Guards system folders and cycles, then persists the new order.
    func moveFolder(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID,
              let dragged = folder(id: draggedID), !dragged.isSystem,
              let target = folder(id: targetID),
              let from = folders.firstIndex(where: { $0.id == draggedID }) else { return }
        let newParent = target.parentId
        if let newParent {
            guard newParent != draggedID,
                  !FolderTree.isDescendant(newParent, ofOrEqual: draggedID, in: folders) else { return }
        }
        var moved = folders.remove(at: from)
        moved.parentId = newParent
        let targetIndex = folders.firstIndex(where: { $0.id == targetID }) ?? folders.endIndex
        folders.insert(moved, at: targetIndex)
        store.updateFolder(moved)
        for (index, folder) in folders.enumerated() {
            store.updateFolderSortOrder(id: folder.id, sortOrder: index)
        }
        if let newParent { expandedFolders.insert(newParent) }
    }

    /// The existing folder a `#slug` resolves to, if any (nil = would be new).
    func knownFolder(forSlug slug: String) -> Folder? {
        FolderTree.folder(forSlug: slug, in: folders)
    }

    /// Create the task, first creating a new top-level folder for an unknown
    /// `#slug` and filing the task directly into it.
    func createFolderAndTask(from parsed: ParsedQuickAdd) {
        var parsed = parsed
        if let slug = parsed.folderSlug, knownFolder(forSlug: slug) == nil {
            parsed.folderSlug = addFolder(name: slug, parentId: nil) // point at the real new id
        }
        createTask(from: parsed)
    }

    /// Move `draggedID` to just before `targetID` and persist the new ordering.
    func moveTask(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID,
              let from = tasks.firstIndex(where: { $0.id == draggedID }) else { return }
        let item = tasks.remove(at: from)
        let insertAt = tasks.firstIndex(where: { $0.id == targetID }) ?? tasks.endIndex
        tasks.insert(item, at: insertAt)
        for (index, task) in tasks.enumerated() {
            store.updateSortOrder(id: task.id, sortOrder: index)
        }
    }

    /// Append activity for state / due / folder changes (done transitions are
    /// logged by `toggleDone`, so they're skipped here).
    private func logChanges(from old: TaskItem, to new: TaskItem) {
        if old.state != new.state, new.state != .done, old.state != .done {
            store.appendActivity(ActivityEvent(taskId: new.id, kind: .stateChanged, detail: new.state.label))
        }
        if old.due != new.due {
            let detail = new.due.flatMap { Formatting.dueLabel($0, clock: clock) } ?? "cleared"
            store.appendActivity(ActivityEvent(taskId: new.id, kind: .dueChanged, detail: detail))
        }
        if old.folderId != new.folderId {
            store.appendActivity(ActivityEvent(taskId: new.id, kind: .folderChanged,
                                               detail: folder(id: new.folderId)?.name))
        }
    }

    /// Request the Spotlight-style quick-add capture (⌘N).
    func requestQuickAdd() { quickAddRequested = true }

    // MARK: - Folder mutations

    /// Create a folder under `parentId` and return its new id.
    @discardableResult
    func addFolder(name: String, parentId: String?) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let displayName = trimmed.isEmpty ? "New Folder" : trimmed
        let folder = Folder(
            id: uniqueSlug(from: displayName),
            name: displayName,
            parentId: parentId,
            // Cycle hues so new folders get distinct, on-brand colors.
            color: OKLCH(0.68, 0.13, Double((folders.count * 47) % 360))
        )
        store.insertFolder(folder, sortOrder: store.maxFolderSortOrder() + 1)
        folders.append(folder)
        if let parentId { expandedFolders.insert(parentId) }
        return folder.id
    }

    func renameFolder(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = trimmed
        store.updateFolder(folders[index])
    }

    /// Delete a non-system folder. Its tasks move to the parent (or Inbox); its
    /// child folders reparent up one level. No task data is lost.
    func deleteFolder(id: String) {
        guard let folder = folder(id: id), !folder.isSystem else { return }
        let reassignTo = folder.parentId ?? Folder.inboxID
        store.deleteFolder(id: id, reassignTasksTo: reassignTo, reparentChildrenTo: folder.parentId)
        folders = store.loadFolders()
        tasks = store.loadTasks()
        if selection == .folder(id) { selection = .view(.all) }
    }

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

    /// Build a unique, slug-style folder id from a name (so `#myfolder` resolves).
    private func uniqueSlug(from name: String) -> String {
        let base = String(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        let slug = base.isEmpty ? "folder" : base
        guard folders.contains(where: { $0.id == slug }) else { return slug }
        var n = 2
        while folders.contains(where: { $0.id == "\(slug)-\(n)" }) { n += 1 }
        return "\(slug)-\(n)"
    }
}
