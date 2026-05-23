// Task.swift
// The core task entity. Effort is stored internally as minutes (matching the
// prototype); impact and priority use the shared `Level` scale.

import Foundation

/// A single todo item. `TaskItem` rather than `Task` to avoid colliding with
/// Swift Concurrency's `Task`.
struct TaskItem: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var folderId: String
    var due: Date?
    /// Estimated effort in minutes (e.g. "t:1h" → 60). Nil = unestimated.
    var effortMinutes: Int?
    var impact: Level
    var priority: Level
    var state: TaskState
    var notes: String?
    var snoozedUntil: Date?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        folderId: String,
        due: Date? = nil,
        effortMinutes: Int? = nil,
        impact: Level = .medium,
        priority: Level = .medium,
        state: TaskState = .open,
        notes: String? = nil,
        snoozedUntil: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.folderId = folderId
        self.due = due
        self.effortMinutes = effortMinutes
        self.impact = impact
        self.priority = priority
        self.state = state
        self.notes = notes
        self.snoozedUntil = snoozedUntil
        self.createdAt = createdAt
    }

    var isDone: Bool { state == .done }
}
