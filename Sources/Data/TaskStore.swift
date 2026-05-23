// TaskStore.swift
// Repository over the SQLite database: opens the file, runs migrations, seeds
// first-run content, and reads/writes folders and tasks. Dates are stored as
// Unix epoch seconds. Runs on the main actor — the dataset is tiny, so synchronous
// access keeps the model simple.

import Foundation

@MainActor
final class TaskStore {
    private let db: Database

    init(url: URL, clock: TaskClock = TaskClock()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        db = try Database(path: url.path)
        try Migrations.migrate(db)
        try seedIfEmpty(clock: clock)
    }

    /// Default on-disk location: ~/Library/Application Support/Prioritiser/.
    static func defaultURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return base.appendingPathComponent("Prioritiser/prioritiser.sqlite")
    }

    // MARK: - Loading

    func loadFolders() -> [Folder] {
        guard let stmt = try? db.prepare("""
            SELECT id, name, parent_id, color_l, color_c, color_h, is_system
            FROM folders ORDER BY sort_order ASC;
            """) else { return [] }
        defer { stmt.finalize() }

        var folders: [Folder] = []
        while stmt.step() {
            folders.append(Folder(
                id: stmt.text(0) ?? "",
                name: stmt.text(1) ?? "",
                parentId: stmt.text(2),
                color: OKLCH(stmt.double(3) ?? 0, stmt.double(4) ?? 0, stmt.double(5) ?? 0),
                isSystem: (stmt.int(6) ?? 0) != 0
            ))
        }
        return folders
    }

    func loadTasks() -> [TaskItem] {
        guard let stmt = try? db.prepare("""
            SELECT id, title, folder_id, due, effort_minutes, impact, priority,
                   state, notes, snoozed_until, created_at
            FROM tasks ORDER BY sort_order ASC;
            """) else { return [] }
        defer { stmt.finalize() }

        var tasks: [TaskItem] = []
        while stmt.step() {
            tasks.append(TaskItem(
                id: stmt.text(0) ?? "",
                title: stmt.text(1) ?? "",
                folderId: stmt.text(2) ?? Folder.inboxID,
                due: stmt.double(3).map { Date(timeIntervalSince1970: $0) },
                effortMinutes: stmt.int(4),
                impact: Level(rawValue: stmt.int(5) ?? 2) ?? .medium,
                priority: Level(rawValue: stmt.int(6) ?? 2) ?? .medium,
                state: TaskState(rawValue: stmt.text(7) ?? "open") ?? .open,
                notes: stmt.text(8),
                snoozedUntil: stmt.double(9).map { Date(timeIntervalSince1970: $0) },
                createdAt: stmt.double(10).map { Date(timeIntervalSince1970: $0) } ?? Date()
            ))
        }
        return tasks
    }

    // MARK: - Writing

    /// Insert a new task (or replace one with the same id). `sortOrder` controls
    /// list position (lower = earlier). Used for seeding and freshly created tasks.
    func insert(_ task: TaskItem, sortOrder: Int) {
        guard let stmt = try? db.prepare("""
            INSERT OR REPLACE INTO tasks
              (id, title, folder_id, due, effort_minutes, impact, priority,
               state, notes, snoozed_until, created_at, sort_order)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12);
            """) else { return }
        defer { stmt.finalize() }
        stmt.bind(1, task.id)
            .bind(2, task.title)
            .bind(3, task.folderId)
            .bind(4, task.due?.timeIntervalSince1970)
            .bind(5, task.effortMinutes)
            .bind(6, task.impact.rawValue)
            .bind(7, task.priority.rawValue)
            .bind(8, task.state.rawValue)
            .bind(9, task.notes)
            .bind(10, task.snoozedUntil?.timeIntervalSince1970)
            .bind(11, task.createdAt.timeIntervalSince1970)
            .bind(12, sortOrder)
        try? stmt.run()
    }

    /// Update an existing task's fields, leaving its `sort_order` (list position)
    /// untouched — editing a task must not move it.
    func update(_ task: TaskItem) {
        guard let stmt = try? db.prepare("""
            UPDATE tasks SET
              title = ?2, folder_id = ?3, due = ?4, effort_minutes = ?5,
              impact = ?6, priority = ?7, state = ?8, notes = ?9, snoozed_until = ?10
            WHERE id = ?1;
            """) else { return }
        defer { stmt.finalize() }
        stmt.bind(1, task.id)
            .bind(2, task.title)
            .bind(3, task.folderId)
            .bind(4, task.due?.timeIntervalSince1970)
            .bind(5, task.effortMinutes)
            .bind(6, task.impact.rawValue)
            .bind(7, task.priority.rawValue)
            .bind(8, task.state.rawValue)
            .bind(9, task.notes)
            .bind(10, task.snoozedUntil?.timeIntervalSince1970)
        try? stmt.run()
    }

    /// The smallest `sort_order` currently stored (used to prepend new tasks).
    func minSortOrder() -> Int {
        guard let stmt = try? db.prepare("SELECT MIN(sort_order) FROM tasks;") else { return 0 }
        defer { stmt.finalize() }
        return stmt.step() ? (stmt.int(0) ?? 0) : 0
    }

    /// Update only a task's list position (used by drag-reorder).
    func updateSortOrder(id: String, sortOrder: Int) {
        guard let stmt = try? db.prepare("UPDATE tasks SET sort_order = ?2 WHERE id = ?1;") else { return }
        defer { stmt.finalize() }
        stmt.bind(1, id).bind(2, sortOrder)
        try? stmt.run()
    }

    // MARK: - Activity

    func appendActivity(_ event: ActivityEvent) {
        guard let stmt = try? db.prepare("""
            INSERT OR REPLACE INTO activity (id, task_id, kind, detail, timestamp)
            VALUES (?1, ?2, ?3, ?4, ?5);
            """) else { return }
        defer { stmt.finalize() }
        stmt.bind(1, event.id)
            .bind(2, event.taskId)
            .bind(3, event.kind.rawValue)
            .bind(4, event.detail)
            .bind(5, event.timestamp.timeIntervalSince1970)
        try? stmt.run()
    }

    /// Activity for a task, newest first.
    func loadActivity(taskId: String) -> [ActivityEvent] {
        guard let stmt = try? db.prepare("""
            SELECT id, task_id, kind, detail, timestamp FROM activity
            WHERE task_id = ?1 ORDER BY timestamp DESC;
            """) else { return [] }
        defer { stmt.finalize() }
        stmt.bind(1, taskId)

        var events: [ActivityEvent] = []
        while stmt.step() {
            guard let kind = ActivityKind(rawValue: stmt.text(2) ?? "") else { continue }
            events.append(ActivityEvent(
                id: stmt.text(0) ?? "",
                taskId: stmt.text(1) ?? "",
                kind: kind,
                detail: stmt.text(3),
                timestamp: Date(timeIntervalSince1970: stmt.double(4) ?? 0)
            ))
        }
        return events
    }

    func deleteTask(id: String) {
        guard let stmt = try? db.prepare("DELETE FROM tasks WHERE id = ?1;") else { return }
        defer { stmt.finalize() }
        stmt.bind(1, id)
        try? stmt.run()
    }

    /// Insert a folder (or replace one with the same id).
    func insertFolder(_ folder: Folder, sortOrder: Int) {
        guard let stmt = try? db.prepare("""
            INSERT OR REPLACE INTO folders
              (id, name, parent_id, color_l, color_c, color_h, is_system, sort_order)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);
            """) else { return }
        defer { stmt.finalize() }
        stmt.bind(1, folder.id)
            .bind(2, folder.name)
            .bind(3, folder.parentId)
            .bind(4, folder.color.l)
            .bind(5, folder.color.c)
            .bind(6, folder.color.h)
            .bind(7, folder.isSystem ? 1 : 0)
            .bind(8, sortOrder)
        try? stmt.run()
    }

    /// Update a folder's name / parent / color (leaving sort order untouched).
    func updateFolder(_ folder: Folder) {
        guard let stmt = try? db.prepare("""
            UPDATE folders SET name = ?2, parent_id = ?3, color_l = ?4, color_c = ?5, color_h = ?6
            WHERE id = ?1;
            """) else { return }
        defer { stmt.finalize() }
        stmt.bind(1, folder.id)
            .bind(2, folder.name)
            .bind(3, folder.parentId)
            .bind(4, folder.color.l)
            .bind(5, folder.color.c)
            .bind(6, folder.color.h)
        try? stmt.run()
    }

    /// Delete a (non-system) folder without losing data: its direct tasks are
    /// reassigned to `reassignTasksTo`, and its direct child folders are reparented
    /// to `reparentChildrenTo`. Tasks in descendant folders stay where they are.
    func deleteFolder(id: String, reassignTasksTo: String, reparentChildrenTo: String?) {
        try? db.transaction {
            let move = try db.prepare("UPDATE tasks SET folder_id = ?2 WHERE folder_id = ?1;")
            defer { move.finalize() }
            move.bind(1, id).bind(2, reassignTasksTo)
            try move.run()

            let reparent = try db.prepare("UPDATE folders SET parent_id = ?2 WHERE parent_id = ?1;")
            defer { reparent.finalize() }
            reparent.bind(1, id).bind(2, reparentChildrenTo)
            try reparent.run()

            let remove = try db.prepare("DELETE FROM folders WHERE id = ?1 AND is_system = 0;")
            defer { remove.finalize() }
            remove.bind(1, id)
            try remove.run()
        }
    }

    /// Update only a folder's list position (used by folder drag-reorder).
    func updateFolderSortOrder(id: String, sortOrder: Int) {
        guard let stmt = try? db.prepare("UPDATE folders SET sort_order = ?2 WHERE id = ?1;") else { return }
        defer { stmt.finalize() }
        stmt.bind(1, id).bind(2, sortOrder)
        try? stmt.run()
    }

    /// The largest folder `sort_order` (so new folders append after existing ones).
    func maxFolderSortOrder() -> Int {
        guard let stmt = try? db.prepare("SELECT MAX(sort_order) FROM folders;") else { return 0 }
        defer { stmt.finalize() }
        return stmt.step() ? (stmt.int(0) ?? 0) : 0
    }

    // MARK: - Seeding

    private func seedIfEmpty(clock: TaskClock) throws {
        let stmt = try db.prepare("SELECT COUNT(*) FROM folders;")
        defer { stmt.finalize() }
        let count = stmt.step() ? (stmt.int(0) ?? 0) : 0
        guard count == 0 else { return }

        try db.transaction {
            for (index, folder) in SeedData.folders.enumerated() {
                insertFolder(folder, sortOrder: index)
            }
            for (index, task) in SeedData.tasks(clock: clock).enumerated() {
                insert(task, sortOrder: index)
                appendActivity(ActivityEvent(id: "created-\(task.id)", taskId: task.id,
                                             kind: .created, timestamp: task.createdAt))
                if task.state == .inProgress {
                    appendActivity(ActivityEvent(taskId: task.id, kind: .stateChanged,
                                                 detail: "In progress",
                                                 timestamp: clock.addingDays(-1, to: clock.today)))
                } else if task.state == .waiting {
                    appendActivity(ActivityEvent(taskId: task.id, kind: .stateChanged,
                                                 detail: "Waiting",
                                                 timestamp: clock.addingDays(-2, to: clock.today)))
                }
            }
        }
    }
}
