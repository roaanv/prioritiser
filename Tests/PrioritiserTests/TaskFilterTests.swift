// TaskFilterTests.swift
// Verifies the smart-view filters against the seeded sample data: live exclusion,
// the Top ranking, quick-wins, and folder-subtree scoping.

import Testing
import Foundation
@testable import Prioritiser

private let clock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!
)
private let folders = SeedData.folders
private let tasks = SeedData.tasks(clock: clock)

@Suite("TaskFilter")
struct TaskFilterTests {
    @Test("Live excludes done and snoozed")
    func liveExcludes() {
        let live = TaskFilter.live(tasks)
        #expect(live.allSatisfy { $0.state != .done && $0.state != .snoozed })
        // Seed has one snoozed task (t18) — it should be gone.
        #expect(!live.contains { $0.id == "t18" })
    }

    @Test("Top view ranks the due-today high/high task first")
    func topRanking() {
        let top = TaskFilter.tasks(for: .top, in: tasks, clock: clock)
        #expect(top.first?.id == "t6")
    }

    @Test("Quick wins are short and impactful")
    func quickWins() {
        let wins = TaskFilter.tasks(for: .quickWin, in: tasks, clock: clock)
        #expect(wins.allSatisfy { ($0.effortMinutes ?? 60) <= 30 && $0.impact >= .medium })
        #expect(!wins.isEmpty)
    }

    @Test("Folder scope includes descendants")
    func folderSubtree() {
        // "work" has children prioritiser/design/ops; its scope must include them.
        let inWork = TaskFilter.tasks(inFolder: "work", tasks: tasks, folders: folders)
        #expect(inWork.contains { $0.folderId == "prioritiser" })
        #expect(inWork.contains { $0.folderId == "work" })
    }

    @Test("Overdue view only contains past-due tasks")
    func overdue() {
        let overdue = TaskFilter.tasks(for: .overdue, in: tasks, clock: clock)
        #expect(overdue.allSatisfy { (clock.daysUntil($0.due) ?? 0) < 0 })
    }

    @Test("Folder slug resolves by id and by space-stripped name")
    func slugResolution() {
        #expect(FolderTree.folder(forSlug: "prioritiser", in: folders)?.id == "prioritiser")
        #expect(FolderTree.folder(forSlug: "designreview", in: folders)?.id == "design")
        #expect(FolderTree.folder(forSlug: "nonexistent", in: folders) == nil)
    }
}
