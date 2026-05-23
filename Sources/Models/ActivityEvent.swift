// ActivityEvent.swift
// A logged change to a task, shown in the detail pane's Activity feed. Persisted
// in the `activity` table (migration v2).

import Foundation

enum ActivityKind: String, Codable {
    case created
    case completed
    case reopened
    case stateChanged
    case dueChanged
    case folderChanged

    /// SF Symbol shown next to the event.
    var systemImage: String {
        switch self {
        case .created: return "plus.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .reopened: return "arrow.uturn.backward.circle.fill"
        case .stateChanged: return "circle.lefthalf.filled"
        case .dueChanged: return "calendar"
        case .folderChanged: return "folder.fill"
        }
    }
}

struct ActivityEvent: Identifiable {
    let id: String
    let taskId: String
    let kind: ActivityKind
    /// Optional human detail, e.g. the new state or folder name.
    let detail: String?
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        taskId: String,
        kind: ActivityKind,
        detail: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.kind = kind
        self.detail = detail
        self.timestamp = timestamp
    }

    /// The headline text for the feed (the timestamp is rendered separately).
    var summary: String {
        switch kind {
        case .created: return "Created"
        case .completed: return "Completed"
        case .reopened: return "Reopened"
        case .stateChanged: return detail.map { "Marked \($0.lowercased())" } ?? "State changed"
        case .dueChanged: return detail.map { "Due \($0)" } ?? "Due date changed"
        case .folderChanged: return detail.map { "Moved to \($0)" } ?? "Moved"
        }
    }
}
