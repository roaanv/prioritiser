// TaskFilter.swift
// Resolves which tasks belong to each smart view and to a selected folder, plus
// the sidebar badge tallies. Ported from filterTasks / tasksInFolder / badgeCount.
// "Live" tasks exclude completed and snoozed-away items.

import Foundation

enum TaskFilter {
    /// Tasks that appear in any working list (not done, not snoozed).
    static func live(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.state.isLive }
    }

    /// The ordered task set for a smart view.
    static func tasks(
        for view: SmartView,
        in tasks: [TaskItem],
        weights: PriorityWeights = .default,
        clock: TaskClock = TaskClock()
    ) -> [TaskItem] {
        let live = live(tasks)
        switch view {
        case .top:
            return live.sorted { a, b in
                PriorityScorer.score(for: a, weights: weights, clock: clock)
                    > PriorityScorer.score(for: b, weights: weights, clock: clock)
            }
        case .today:
            return live.filter { clock.daysUntil($0.due) == 0 }
        case .week:
            return live.filter { (0...7).contains(clock.daysUntil($0.due) ?? .min) }
        case .overdue:
            return live.filter { (clock.daysUntil($0.due) ?? 0) < 0 }
        case .quickWin:
            return live.filter { ($0.effortMinutes ?? 60) <= 30 && $0.impact >= .medium }
        case .inbox:
            return live.filter { $0.folderId == Folder.inboxID }
        case .all:
            // "All Tasks" includes snoozed (the place to find + un-snooze them);
            // only completed tasks are hidden.
            return tasks.filter { $0.state != .done }
        }
    }

    /// Live tasks in `folderId` and all its descendant folders.
    static func tasks(inFolder folderId: String, tasks: [TaskItem], folders: [Folder]) -> [TaskItem] {
        live(tasks).filter { FolderTree.isDescendant($0.folderId, ofOrEqual: folderId, in: folders) }
    }

    /// Live tasks filed directly in `folderId` (excludes descendant folders).
    static func directTasks(inFolder folderId: String, tasks: [TaskItem]) -> [TaskItem] {
        live(tasks).filter { $0.folderId == folderId }
    }

    /// Sidebar badge count for a smart view. "Top" caps at 5 (the Top-5 band);
    /// every other view reports the size of its filtered set.
    static func badgeCount(
        for view: SmartView,
        tasks: [TaskItem],
        weights: PriorityWeights = .default,
        clock: TaskClock = TaskClock()
    ) -> Int {
        if view == .top { return min(5, live(tasks).count) }
        return self.tasks(for: view, in: tasks, weights: weights, clock: clock).count
    }

    /// Count of live tasks in a folder subtree (sidebar badge).
    static func folderCount(_ folderId: String, tasks: [TaskItem], folders: [Folder]) -> Int {
        self.tasks(inFolder: folderId, tasks: tasks, folders: folders).count
    }
}
