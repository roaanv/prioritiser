// EisenhowerTests.swift
// Verifies the Eisenhower mapping (important=high impact, urgent=due≤2d) and the
// per-quadrant tally, including the direct vs. subtree scoping the panel toggle uses.

import Testing
import Foundation
@testable import Prioritiser

private let clock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!
)
private let folders = SeedData.folders
private let tasks = SeedData.tasks(clock: clock)

@Suite("Eisenhower")
struct EisenhowerTests {
    private func task(_ id: String) -> TaskItem { tasks.first { $0.id == id }! }

    @Test("Importance is high impact only")
    func importance() {
        #expect(Eisenhower.isImportant(task("t6")))   // high
        #expect(!Eisenhower.isImportant(task("t2")))  // medium
        #expect(!Eisenhower.isImportant(task("t5")))  // low
    }

    @Test("Urgency is overdue or due within 2 days; no due date is never urgent")
    func urgency() {
        #expect(Eisenhower.isUrgent(task("t6"), clock: clock))  // due today
        #expect(Eisenhower.isUrgent(task("t1"), clock: clock))  // due +2
        #expect(Eisenhower.isUrgent(task("t4"), clock: clock))  // overdue
        #expect(!Eisenhower.isUrgent(task("t3"), clock: clock)) // due +5
        #expect(!Eisenhower.isUrgent(task("t5"), clock: clock)) // no due date
    }

    @Test("Quadrant assignment")
    func quadrants() {
        #expect(Eisenhower.quadrant(for: task("t6"), clock: clock) == .doNow)          // high + today
        #expect(Eisenhower.quadrant(for: task("t3"), clock: clock) == .plan)           // high + +5
        #expect(Eisenhower.quadrant(for: task("t2"), clock: clock) == .quickDecisions) // medium + +1
        #expect(Eisenhower.quadrant(for: task("t5"), clock: clock) == .backlog)        // low + no due
    }

    @Test("Counts cover every quadrant and sum to the input size")
    func countsSum() {
        let subset = [task("t6"), task("t3"), task("t2"), task("t5")]
        let counts = Eisenhower.counts(for: subset, clock: clock)
        #expect(counts.count == 4) // all quadrants present
        #expect(counts.values.reduce(0, +) == subset.count)
        #expect(counts[.doNow] == 1)
    }

    @Test("Subtree scope includes more than direct scope for a parent folder")
    func directVsSubtree() {
        // "work" has child folders (prioritiser/design/ops) with their own tasks.
        let direct = TaskFilter.directTasks(inFolder: "work", tasks: tasks)
        let subtree = TaskFilter.tasks(inFolder: "work", tasks: tasks, folders: folders)
        #expect(subtree.count > direct.count)
        #expect(direct.allSatisfy { $0.folderId == "work" })
    }
}
