// StoreTests.swift
// Exercises the data layer: the migration runner builds the schema and stamps the
// version; TaskStore seeds on first run and round-trips inserts/updates; and
// deleting a folder reassigns its tasks rather than losing them.

import Testing
import Foundation
@testable import Prioritiser

/// A fresh, unique database path under the temp directory for each test.
private func tempDBURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("prioritiser-tests-\(UUID().uuidString)")
        .appendingPathComponent("store.sqlite")
}

@Suite("Storage")
struct StoreTests {
    @Test("Migration builds the schema and stamps the version")
    func migration() throws {
        let url = tempDBURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let db = try Database(path: url.path)
        #expect(db.userVersion == 0)
        try Migrations.migrate(db)
        #expect(db.userVersion == Migrations.latestVersion)
        // Tables now exist — preparing/stepping a query against them succeeds.
        let stmt = try db.prepare("SELECT COUNT(*) FROM tasks;")
        #expect(stmt.step())
    }

    @Test @MainActor func seedsOnFirstRun() throws {
        let store = try TaskStore(url: tempDBURL())
        #expect(store.loadFolders().count == 8)
        #expect(store.loadTasks().count == 20)
    }

    @Test @MainActor func insertAndUpdateRoundTrip() throws {
        let store = try TaskStore(url: tempDBURL())
        let task = TaskItem(id: "x1", title: "New task", folderId: "inbox",
                            effortMinutes: 25, impact: .high, priority: .low)
        store.insert(task, sortOrder: -1)

        let reloaded = store.loadTasks().first { $0.id == "x1" }
        #expect(reloaded?.title == "New task")
        #expect(reloaded?.effortMinutes == 25)
        #expect(reloaded?.impact == .high)

        var edited = task
        edited.title = "Edited"
        store.update(edited)
        #expect(store.loadTasks().first { $0.id == "x1" }?.title == "Edited")
    }

    @Test @MainActor func deletingFolderReassignsTasksAndKeepsData() throws {
        let store = try TaskStore(url: tempDBURL())
        let before = store.loadTasks().count

        // "prioritiser" is a child of "work" with several tasks and no sub-folders.
        store.deleteFolder(id: "prioritiser", reassignTasksTo: "work", reparentChildrenTo: "work")

        let folders = store.loadFolders()
        let tasks = store.loadTasks()
        #expect(!folders.contains { $0.id == "prioritiser" })
        #expect(!tasks.contains { $0.folderId == "prioritiser" }) // no orphans
        #expect(tasks.count == before)                            // no data lost
    }

    @Test @MainActor func systemFolderCannotBeDeleted() throws {
        let store = try TaskStore(url: tempDBURL())
        store.deleteFolder(id: "inbox", reassignTasksTo: "inbox", reparentChildrenTo: nil)
        #expect(store.loadFolders().contains { $0.id == "inbox" })
    }
}
