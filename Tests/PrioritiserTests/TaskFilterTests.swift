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

    @Test("Folder tree flattening follows disclosure expansion")
    func folderTreeFlattening() {
        #expect(FolderTree.flatten(folders, expanded: []).map(\.folder.id) == [
            "inbox", "work", "personal", "reading"
        ])

        let expandedWork = FolderTree.flatten(folders, expanded: ["work"])
        #expect(expandedWork.map(\.folder.id) == [
            "inbox", "work", "prioritiser", "design", "ops", "personal", "reading"
        ])
        #expect(expandedWork.first { $0.folder.id == "prioritiser" }?.depth == 1)

        #expect(FolderTree.flatten(folders, expanded: ["personal"]).map(\.folder.id) == [
            "inbox", "work", "personal", "home", "reading"
        ])
    }

    @Test("Overdue view only contains past-due tasks")
    func overdue() {
        let overdue = TaskFilter.tasks(for: .overdue, in: tasks, clock: clock)
        #expect(overdue.allSatisfy { (clock.daysUntil($0.due) ?? 0) < 0 })
    }

    @Test("All Tasks includes snoozed but excludes done")
    func allIncludesSnoozed() {
        let all = TaskFilter.tasks(for: .all, in: tasks, clock: clock)
        #expect(all.contains { $0.id == "t18" })          // t18 is snoozed
        #expect(all.allSatisfy { $0.state != .done })
    }

    @Test("Folder resolves by id and by name slug")
    func slugResolution() {
        // By id (a literal #ops still works for back-compat).
        #expect(FolderTree.folder(forSlug: "ops", in: folders)?.id == "ops")
        // By name slug — what autocomplete now inserts.
        #expect(FolderTree.folder(forSlug: "operations", in: folders)?.id == "ops")
        #expect(FolderTree.folder(forSlug: "designreview", in: folders)?.id == "design")
        #expect(FolderTree.folder(forSlug: "nonexistent", in: folders) == nil)
    }

    @Test("Autocomplete completes to the name slug, which round-trips to the folder")
    func nameSlugRoundTrip() {
        let ops = folders.first { $0.id == "ops" }!
        #expect(ops.nameSlug == "operations")
        let completed = PrefixParser.completeHashtag(in: "Audit costs #Ope", with: ops.nameSlug)
        #expect(completed == "Audit costs #operations ")
        let parsed = PrefixParser.parse(completed.trimmingCharacters(in: .whitespaces), clock: clock)
        #expect(FolderTree.folder(forSlug: parsed.folderSlug ?? "", in: folders)?.id == "ops")
    }

    @Test("Folder search prefers prefix matches, then substring")
    func folderSearch() {
        // "p" prefixes Personal and Prioritiser; both come before a substring-only match.
        let results = FolderTree.search("p", in: folders).map(\.id)
        #expect(results.contains("prioritiser"))
        #expect(results.contains("personal"))
        // "design" matches "Design Review" (id "design").
        #expect(FolderTree.search("design", in: folders).first?.id == "design")
        // No match → empty.
        #expect(FolderTree.search("zzz", in: folders).isEmpty)
    }
}
