// ListControlsTests.swift
// Covers the presentation helpers: due bucketing for the Schedule view, the sort
// keys, and the state filter.

import Testing
import Foundation
@testable import Prioritiser

private let clock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!
)

@Suite("ListControls")
struct ListControlsTests {
    @Test("Due dates fall into the right schedule bucket")
    func buckets() {
        #expect(DueBucket.bucket(for: nil, clock: clock) == .someday)
        #expect(DueBucket.bucket(for: clock.today, clock: clock) == .today)
        #expect(DueBucket.bucket(for: clock.addingDays(1, to: clock.today), clock: clock) == .tomorrow)
        #expect(DueBucket.bucket(for: clock.addingDays(3, to: clock.today), clock: clock) == .thisWeek)
        #expect(DueBucket.bucket(for: clock.addingDays(20, to: clock.today), clock: clock) == .later)
        #expect(DueBucket.bucket(for: clock.addingDays(-1, to: clock.today), clock: clock) == .overdue)
    }

    @Test("Title sort is alphabetical; manual preserves order")
    func sorting() {
        let tasks = [
            TaskItem(id: "b", title: "Banana", folderId: "inbox"),
            TaskItem(id: "a", title: "Apple", folderId: "inbox"),
        ]
        #expect(TaskSort.title.sorted(tasks, score: { _ in 0 }).map(\.id) == ["a", "b"])
        #expect(TaskSort.manual.sorted(tasks, score: { _ in 0 }).map(\.id) == ["b", "a"])
    }

    @Test("State filter narrows to a single state")
    func stateFilter() {
        let tasks = [
            TaskItem(id: "1", title: "x", folderId: "inbox", state: .open),
            TaskItem(id: "2", title: "y", folderId: "inbox", state: .waiting),
        ]
        #expect(StateFilter.waiting.apply(tasks).map(\.id) == ["2"])
        #expect(StateFilter.all.apply(tasks).count == 2)
    }

    @Test("Selection round-trips through its persisted string")
    func selectionPersistence() {
        #expect(Selection(persisted: Selection.view(.today).persistedString) == .view(.today))
        #expect(Selection(persisted: Selection.folder("work").persistedString) == .folder("work"))
        #expect(Selection(persisted: "garbage") == nil)
    }
}
