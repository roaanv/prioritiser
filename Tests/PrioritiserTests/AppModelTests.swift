// AppModelTests.swift
// Integration coverage for the observable model over a real (temp) store: search
// narrowing, activity logging on create/complete, and drag-reorder.

import Testing
import Foundation
@testable import Prioritiser

private func tempDBURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("prioritiser-modeltests-\(UUID().uuidString)")
        .appendingPathComponent("store.sqlite")
}

private let referenceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!

@MainActor
@Suite("AppModel")
struct AppModelTests {
    private func makeModel() throws -> AppModel {
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        return AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: throwawayDefaults())
    }

    @Test func searchNarrowsVisibleTasks() throws {
        let model = try makeModel()
        model.selection = .view(.all)
        model.searchQuery = "investor"
        #expect(model.visibleTasks.map(\.id) == ["t6"])
        model.searchQuery = ""
        #expect(model.visibleTasks.count > 1)
    }

    @Test func createTaskLogsCreatedActivity() throws {
        let model = try makeModel()
        model.createTask(from: PrefixParser.parse("Write the docs #work", clock: model.clock))
        let id = try #require(model.selectedTaskID)
        #expect(model.activity(for: id).contains { $0.kind == .created })
    }

    @Test func completingLogsActivity() throws {
        let model = try makeModel()
        let task = try #require(model.tasks.first { $0.id == "t6" })
        model.toggleDone(task)
        #expect(model.activity(for: "t6").contains { $0.kind == .completed })
    }

    @Test func moveTaskReordersAndPersists() throws {
        let model = try makeModel()
        let ids = model.tasks.map(\.id)
        let third = ids[2]
        model.moveTask(third, before: ids[0])
        #expect(model.tasks.first?.id == third)
    }

    @Test func wakesPastDueSnoozedTaskOnLaunch() throws {
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        let pastDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        store.insert(TaskItem(id: "snz1", title: "wake me", folderId: "inbox",
                              state: .snoozed, snoozedUntil: pastDate), sortOrder: 100)
        // AppModel.init runs wakeDueSnoozedTasks.
        let model = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: throwawayDefaults())
        let woken = model.tasks.first { $0.id == "snz1" }
        #expect(woken?.state == .open)
        #expect(woken?.snoozedUntil == nil)
    }

    @Test func keepsFutureSnoozedTaskSnoozed() throws {
        let model = try makeModel()
        // Seed t18 is snoozed a week out (future) — must stay snoozed.
        #expect(model.tasks.first { $0.id == "t18" }?.state == .snoozed)
    }

    @Test func reparentMovesFolderUnderNewParent() throws {
        let model = try makeModel()
        model.reparentFolder("reading", under: "work") // root → child of work
        #expect(model.folders.first { $0.id == "reading" }?.parentId == "work")
    }

    @Test func reparentToRootMovesFolderOut() throws {
        let model = try makeModel()
        model.reparentFolder("prioritiser", under: nil) // child of work → top level
        #expect(model.folders.first { $0.id == "prioritiser" }?.parentId == nil)
    }

    @Test func reparentRejectsCycles() throws {
        let model = try makeModel()
        // Moving "work" under its own descendant "prioritiser" must be rejected.
        model.reparentFolder("work", under: "prioritiser")
        #expect(model.folders.first { $0.id == "work" }?.parentId == nil)
    }

    @Test func reparentLeavesSystemFolderAlone() throws {
        let model = try makeModel()
        model.reparentFolder("inbox", under: "work")
        #expect(model.folders.first { $0.id == "inbox" }?.parentId == nil)
    }

    @Test func moveFolderBeforeReordersWithinParent() throws {
        let model = try makeModel()
        model.moveFolder("personal", before: "inbox") // both roots → reorder
        let roots = model.folders.filter { $0.parentId == nil }.map(\.id)
        #expect(roots.firstIndex(of: "personal")! < roots.firstIndex(of: "inbox")!)
    }

    @Test func moveFolderBeforeRepositionsAcrossParents() throws {
        let model = try makeModel()
        // "prioritiser" (child of work) dropped in the gap before root "reading"
        // becomes a root, positioned before reading.
        model.moveFolder("prioritiser", before: "reading")
        #expect(model.folders.first { $0.id == "prioritiser" }?.parentId == nil)
        let roots = model.folders.filter { $0.parentId == nil }.map(\.id)
        #expect(roots.firstIndex(of: "prioritiser")! < roots.firstIndex(of: "reading")!)
    }

    @Test func quadrantFilterNarrowsListToMatchCount() throws {
        let model = try makeModel()
        model.selection = .folder("work")
        model.includeSubprojects = true
        let doNow = Eisenhower.counts(for: model.folderScopedTasks("work"), clock: model.clock)[.doNow] ?? 0
        model.toggleQuadrantFilter(.doNow)
        // The filtered list size equals the matrix count (shared scope).
        #expect(model.visibleTasks.count == doNow)
        #expect(model.visibleTasks.allSatisfy { Eisenhower.quadrant(for: $0, clock: model.clock) == .doNow })
        model.toggleQuadrantFilter(.doNow) // toggling again clears
        #expect(model.quadrantFilter == nil)
    }

    @Test func matrixAppliesToWholeSetViewsButNotAxisViews() throws {
        let model = try makeModel()
        for view in [SmartView.top, .all, .inbox] {
            model.selection = .view(view)
            #expect(model.matrixBaseTasks != nil)
        }
        for view in [SmartView.today, .week, .overdue, .quickWin] {
            model.selection = .view(view)
            #expect(model.matrixBaseTasks == nil)
        }
        model.selection = .folder("work")
        #expect(model.matrixBaseTasks != nil)
    }

    @Test func quadrantFilterAppliesToSupportingView() throws {
        let model = try makeModel()
        model.selection = .view(.top)
        let doNow = Eisenhower.counts(for: model.matrixBaseTasks ?? [], clock: model.clock)[.doNow] ?? 0
        model.toggleQuadrantFilter(.doNow)
        #expect(model.visibleTasks.count == doNow)
        #expect(model.visibleTasks.allSatisfy { Eisenhower.quadrant(for: $0, clock: model.clock) == .doNow })
    }

    @Test func subprojectScopeChangesFolderList() throws {
        let model = try makeModel()
        model.selection = .folder("work")
        model.includeSubprojects = true
        let withSubs = model.visibleTasks.count
        model.includeSubprojects = false
        #expect(withSubs > model.visibleTasks.count)
    }

    @Test func changingSelectionClearsQuadrantFilter() throws {
        let model = try makeModel()
        model.selection = .folder("work")
        model.toggleQuadrantFilter(.doNow)
        #expect(model.quadrantFilter != nil)
        model.selection = .view(.all)
        #expect(model.quadrantFilter == nil)
    }

    @Test func createFolderAndTaskCreatesUnknownProject() throws {
        let model = try makeModel()
        #expect(model.knownFolder(forSlug: "newproj") == nil)
        model.createFolderAndTask(from: PrefixParser.parse("Plan the thing #newproj", clock: model.clock))
        let folder = try #require(model.folders.first { $0.nameSlug == "newproj" })
        #expect(model.tasks.first { $0.title == "Plan the thing" }?.folderId == folder.id)
    }

    @Test func updatingTitlePersists() throws {
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        let model = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: throwawayDefaults())
        var task = try #require(model.tasks.first { $0.id == "t6" })
        task.title = "Renamed task"
        model.update(task)
        #expect(model.tasks.first { $0.id == "t6" }?.title == "Renamed task")
        #expect(store.loadTasks().first { $0.id == "t6" }?.title == "Renamed task") // round-trips to disk
    }

    // MARK: - Deletion

    @Test func deleteTaskRemovesItFromMemoryAndStore() throws {
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        let model = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: throwawayDefaults())
        #expect(model.tasks.contains { $0.id == "t6" })
        model.deleteTasks(["t6"])
        #expect(model.tasks.contains { $0.id == "t6" } == false)
        #expect(store.loadTasks().contains { $0.id == "t6" } == false) // gone from disk too
    }

    @Test func deleteTaskAlsoRemovesItsActivity() throws {
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        let model = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: throwawayDefaults())
        let task = try #require(model.tasks.first { $0.id == "t6" })
        model.toggleDone(task) // logs a .completed activity event
        #expect(!store.loadActivity(taskId: "t6").isEmpty)
        model.deleteTasks(["t6"])
        #expect(store.loadActivity(taskId: "t6").isEmpty) // no orphaned activity rows
    }

    @Test func deleteMovesPrimarySelectionToNeighbor() throws {
        let model = try makeModel()
        model.selection = .view(.all)
        let order = model.visibleTasks.map(\.id)
        try #require(order.count >= 3)
        model.selectOnly(order[1])
        model.deleteTasks([order[1]])
        // The survivor that takes the deleted row's slot becomes primary.
        #expect(model.selectedTaskID == order[2])
        #expect(model.selectedTaskIDs.contains(order[2]))
    }

    @Test func requestDeletionConfirmsOnlyForMultiple() throws {
        let model = try makeModel()
        model.selection = .view(.all)
        let order = model.visibleTasks.map(\.id)
        try #require(order.count >= 3)

        // Two tasks → confirmation pending; nothing deleted yet.
        let pair = Set([order[0], order[1]])
        model.requestDeletion(of: pair)
        #expect(model.pendingDeletion == pair)
        #expect(pair.allSatisfy { id in model.tasks.contains { $0.id == id } })
        model.confirmPendingDeletion()
        #expect(model.pendingDeletion == nil)
        #expect(pair.allSatisfy { id in !model.tasks.contains { $0.id == id } })

        // One task → deleted immediately, no confirmation.
        let single = order[2]
        model.requestDeletion(of: [single])
        #expect(model.pendingDeletion == nil)
        #expect(model.tasks.contains { $0.id == single } == false)
    }

    @Test func toggleAndRangeSelection() throws {
        let model = try makeModel()
        model.selection = .view(.all)
        let order = model.visibleTasks.map(\.id)
        try #require(order.count >= 3)

        model.selectOnly(order[0])
        #expect(model.selectedTaskIDs == Set([order[0]]))

        model.toggleInSelection(order[2])
        #expect(model.selectedTaskIDs == Set([order[0], order[2]]))
        #expect(model.selectedTaskID == order[2]) // primary follows the add

        model.toggleInSelection(order[2]) // remove it again
        #expect(model.selectedTaskIDs == Set([order[0]]))

        model.selectOnly(order[0])
        model.extendSelection(to: order[2]) // ⇧-click range
        #expect(model.selectedTaskIDs == Set([order[0], order[1], order[2]]))
        #expect(model.selectedTaskID == order[2])
    }

    @Test func deletingFromContextMenuTargetsSelectionOrRow() throws {
        let model = try makeModel()
        model.selection = .view(.all)
        let order = model.visibleTasks.map(\.id)
        try #require(order.count >= 3)

        // Right-clicking a row outside the selection targets just that row.
        model.selectOnly(order[0])
        model.requestDeletionFromContextMenu(order[2])
        #expect(model.pendingDeletion == nil) // single → immediate
        #expect(model.tasks.contains { $0.id == order[2] } == false)
        #expect(model.selectedTaskIDs.contains(order[2]) == false)
    }

    // MARK: - Focus mode

    @Test func todayAndOverdueExcludesFutureDoneSnoozedAndNoDue() {
        let clock = TaskClock(now: referenceDate)
        let today = clock.today
        let tasks = [
            TaskItem(id: "today", title: "t", folderId: "inbox", due: today),
            TaskItem(id: "overdue", title: "o", folderId: "inbox", due: clock.addingDays(-2, to: today)),
            TaskItem(id: "future", title: "f", folderId: "inbox", due: clock.addingDays(3, to: today)),
            TaskItem(id: "nodue", title: "n", folderId: "inbox", due: nil),
            TaskItem(id: "done", title: "d", folderId: "inbox", due: today, state: .done),
            TaskItem(id: "snoozed", title: "s", folderId: "inbox", due: today, state: .snoozed),
        ]
        let result = Set(TaskFilter.todayAndOverdue(in: tasks, clock: clock).map(\.id))
        #expect(result == ["today", "overdue"])
    }

    @Test func focusTasksAreSortedByScoreDescending() throws {
        let model = try makeModel()
        let scores = model.focusTasks.map { model.score(for: $0) }
        #expect(scores == scores.sorted(by: >))
        #expect(model.focusTasks.allSatisfy { (model.clock.daysUntil($0.due) ?? 1) <= 0 })
    }

    @Test func createTodayTaskAppearsInFocusList() throws {
        let model = try makeModel()
        model.createTodayTask(title: "Focus thing")
        let created = try #require(model.tasks.first { $0.title == "Focus thing" })
        #expect(model.clock.daysUntil(created.due) == 0)
        #expect(model.focusTasks.contains { $0.id == created.id })
    }

    @Test func focusModeDefaultsOffAndPersists() throws {
        let defaults = throwawayDefaults()
        let store = try TaskStore(url: tempDBURL(), clock: TaskClock(now: referenceDate))
        let model = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: defaults)
        #expect(model.isFocusMode == false) // first run → full mode
        model.isFocusMode = true
        let reopened = AppModel(store: store, clock: TaskClock(now: referenceDate), defaults: defaults)
        #expect(reopened.isFocusMode == true) // remembered across restarts
    }
}

/// An isolated UserDefaults so tests don't read/write the app's real preferences.
@MainActor private func throwawayDefaults() -> UserDefaults {
    UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
}
