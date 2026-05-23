// PriorityScorer.swift
// The auto-priority score: f(impact, priority, urgency, quick-win) → 0...100.
// Ported verbatim from the prototype's scoreTask()/scoreBreakdown() so ranking
// behavior is identical. Pure and clock-injectable for deterministic tests.

import Foundation

/// Tunable weights for the four score components. Defaults match the prototype.
struct PriorityWeights: Equatable {
    var impact: Double = 0.30
    var priority: Double = 0.25
    var urgency: Double = 0.30
    var quickWin: Double = 0.15

    static let `default` = PriorityWeights()
}

/// The four normalized (0...1) inputs that make up a task's score. Surfaced in
/// the detail pane as a per-component breakdown.
struct ScoreComponents: Equatable {
    var impact: Double
    var priority: Double
    var urgency: Double
    var quickWin: Double
}

enum PriorityScorer {
    /// Default effort (minutes) assumed when a task is unestimated.
    private static let defaultEffortMinutes = 60.0

    /// Normalized components for a task, each in 0...1.
    static func components(for task: TaskItem, clock: TaskClock = TaskClock()) -> ScoreComponents {
        let impact = Double(task.impact.rawValue) / 3
        let priority = Double(task.priority.rawValue) / 3

        // Urgency: overdue/today saturates at 1; falls off linearly to 14 days
        // out; floors at 0.1; an undated task sits at a neutral 0.25.
        let urgency: Double
        if let days = clock.daysUntil(task.due) {
            urgency = days <= 0 ? 1 : max(0.1, 1 - Double(days) / 14)
        } else {
            urgency = 0.25
        }

        // Quick-win: shorter effort scores higher (10m→1, 1h→~0.7, 1d→~0.2).
        let eff = Double(task.effortMinutes ?? Int(defaultEffortMinutes))
        let quickWin = max(0.05, 1 - log10(1 + eff / 10) / 2)

        return ScoreComponents(impact: impact, priority: priority, urgency: urgency, quickWin: quickWin)
    }

    /// The 0...100 priority score for a task.
    static func score(
        for task: TaskItem,
        weights: PriorityWeights = .default,
        clock: TaskClock = TaskClock()
    ) -> Int {
        let c = components(for: task, clock: clock)
        let raw = weights.impact * c.impact
            + weights.priority * c.priority
            + weights.urgency * c.urgency
            + weights.quickWin * c.quickWin
        return Int((raw * 100).rounded())
    }
}
