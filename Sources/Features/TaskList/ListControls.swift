// ListControls.swift
// Display-layer options for the task list: List vs Schedule layout, the sort key
// (Sort menu), the state filter (Filter menu), and the due buckets the Schedule
// view groups by. These are presentation concerns owned by TaskListView.

import Foundation

/// Whether the center pane shows a flat list or a date-grouped schedule.
enum TaskViewMode: String, CaseIterable, Identifiable {
    case list, schedule
    var id: String { rawValue }
    var label: String { self == .list ? "List" : "Schedule" }
    var systemImage: String { self == .list ? "list.bullet" : "calendar" }
}

/// Sort key applied to flat lists (and within Schedule buckets).
enum TaskSort: String, CaseIterable, Identifiable {
    case manual, score, due, title, effort
    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .score: return "Priority score"
        case .due: return "Due date"
        case .title: return "Title"
        case .effort: return "Effort"
        }
    }

    /// Apply the sort. `manual` preserves the incoming (stored) order.
    func sorted(_ tasks: [TaskItem], score: (TaskItem) -> Int) -> [TaskItem] {
        switch self {
        case .manual:
            return tasks
        case .score:
            return tasks.sorted { score($0) > score($1) }
        case .due:
            return tasks.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        case .title:
            return tasks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .effort:
            return tasks.sorted { ($0.effortMinutes ?? .max) < ($1.effortMinutes ?? .max) }
        }
    }
}

/// Filter the list to a subset of task states.
enum StateFilter: String, CaseIterable, Identifiable {
    case all, open, inProgress, waiting
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All states"
        case .open: return "Open"
        case .inProgress: return "In progress"
        case .waiting: return "Waiting"
        }
    }

    func apply(_ tasks: [TaskItem]) -> [TaskItem] {
        switch self {
        case .all: return tasks
        case .open: return tasks.filter { $0.state == .open }
        case .inProgress: return tasks.filter { $0.state == .inProgress }
        case .waiting: return tasks.filter { $0.state == .waiting }
        }
    }
}

/// Due-date grouping used by the Schedule view.
enum DueBucket: Int, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, later, someday
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .later: return "Later"
        case .someday: return "No Date"
        }
    }

    static func bucket(for due: Date?, clock: TaskClock) -> DueBucket {
        guard let days = clock.daysUntil(due) else { return .someday }
        switch days {
        case ..<0: return .overdue
        case 0: return .today
        case 1: return .tomorrow
        case 2...7: return .thisWeek
        default: return .later
        }
    }
}
