// Eisenhower.swift
// An Eisenhower-style 2×2 of the project's tasks. Axes map onto our fields:
//   Important = impact is High;  Urgent = overdue or due within `urgentWithinDays`.
// (Priority and effort are intentionally not axes — they live in the score.)
// Pure and clock-injectable for deterministic tests.

import Foundation

/// The four Eisenhower quadrants. `doNow` = urgent+important, etc.
enum EisenhowerQuadrant: Int, CaseIterable, Identifiable {
    case doNow          // urgent + important
    case plan           // not urgent + important
    case quickDecisions // urgent + not important
    case backlog        // not urgent + not important

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .doNow: return "Do Now"
        case .plan: return "Plan"
        case .quickDecisions: return "Quick Decisions"
        case .backlog: return "Backlog"
        }
    }

    var subtitle: String {
        switch self {
        case .doNow: return "Urgent · important"
        case .plan: return "Important, not urgent"
        case .quickDecisions: return "Urgent, lower impact"
        case .backlog: return "Neither"
        }
    }

    var isImportant: Bool { self == .doNow || self == .plan }
    var isUrgent: Bool { self == .doNow || self == .quickDecisions }
}

enum Eisenhower {
    /// A task due this many days out (or sooner / overdue) counts as urgent.
    static let urgentWithinDays = 2

    /// Important = high impact (the "consequence" axis).
    static func isImportant(_ task: TaskItem) -> Bool { task.impact == .high }

    /// Urgent = overdue or due within `urgentWithinDays`; no due date is never urgent.
    static func isUrgent(_ task: TaskItem, clock: TaskClock = TaskClock()) -> Bool {
        guard let days = clock.daysUntil(task.due) else { return false }
        return days <= urgentWithinDays
    }

    static func quadrant(for task: TaskItem, clock: TaskClock = TaskClock()) -> EisenhowerQuadrant {
        switch (isUrgent(task, clock: clock), isImportant(task)) {
        case (true, true): return .doNow
        case (false, true): return .plan
        case (true, false): return .quickDecisions
        case (false, false): return .backlog
        }
    }

    /// Tally tasks into the four quadrants (all keys present, defaulting to 0).
    static func counts(for tasks: [TaskItem], clock: TaskClock = TaskClock()) -> [EisenhowerQuadrant: Int] {
        var result = Dictionary(uniqueKeysWithValues: EisenhowerQuadrant.allCases.map { ($0, 0) })
        for task in tasks {
            result[quadrant(for: task, clock: clock), default: 0] += 1
        }
        return result
    }
}
