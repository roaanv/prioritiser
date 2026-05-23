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

    @Test func moveFolderReordersSiblings() throws {
        let model = try makeModel()
        model.moveFolder("personal", before: "inbox")
        let roots = model.folders.filter { $0.parentId == nil }.map(\.id)
        #expect(roots.firstIndex(of: "personal")! < roots.firstIndex(of: "inbox")!)
    }

    @Test func moveFolderIgnoresCrossParentDrops() throws {
        let model = try makeModel()
        let before = model.folders.map(\.id)
        model.moveFolder("prioritiser", before: "inbox") // child of work onto a root → ignored
        #expect(model.folders.map(\.id) == before)
    }
}

/// An isolated UserDefaults so tests don't read/write the app's real preferences.
@MainActor private func throwawayDefaults() -> UserDefaults {
    UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
}
