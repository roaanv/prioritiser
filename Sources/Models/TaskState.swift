// TaskState.swift
// Lifecycle state of a task. Mirrors the prototype's task.state values plus the
// "done" terminal state. "snoozed" and "done" tasks are excluded from live views.

import Foundation

/// Where a task sits in its lifecycle.
enum TaskState: String, CaseIterable, Codable, Identifiable {
    case open
    case inProgress = "in-progress"
    case waiting
    case snoozed
    case done

    var id: String { rawValue }

    /// Label used by the detail pane's segmented control.
    var label: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In progress"
        case .waiting: return "Waiting"
        case .snoozed: return "Snoozed"
        case .done: return "Done"
        }
    }

    /// States the editable segmented control offers (excludes the terminal `done`,
    /// which is driven by the row checkbox).
    static var editable: [TaskState] { [.open, .inProgress, .waiting, .snoozed] }

    /// Whether a task in this state appears in "live" lists (everything but the
    /// completed and the snoozed-away).
    var isLive: Bool { self != .done && self != .snoozed }
}
