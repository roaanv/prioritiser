// PriorityScorerTests.swift
// Verifies the ported scoring math against hand-computed values so any drift in
// weights or the urgency/quick-win curves is caught.

import Testing
import Foundation
@testable import Prioritiser

private let referenceClock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!
)

@Suite("PriorityScorer")
struct PriorityScorerTests {
    @Test("High/high task due today scores 94")
    func investorUpdate() {
        // impact=1, priority=1, urgency=1 (due today), quickWin(60m)=~0.5775
        let task = TaskItem(title: "Send investor update", folderId: "work",
                            due: referenceClock.today, effortMinutes: 60,
                            impact: .high, priority: .high)
        #expect(PriorityScorer.score(for: task, clock: referenceClock) == 94)
    }

    @Test("Low/low undated task scores 35")
    func readingTask() {
        let task = TaskItem(title: "Read a chapter", folderId: "reading",
                            due: nil, effortMinutes: 45, impact: .low, priority: .low)
        #expect(PriorityScorer.score(for: task, clock: referenceClock) == 35)
    }

    @Test("Overdue saturates urgency at 1")
    func overdueUrgency() {
        let overdue = TaskItem(title: "x", folderId: "inbox",
                               due: referenceClock.addingDays(-5, to: referenceClock.today),
                               effortMinutes: 60, impact: .medium, priority: .medium)
        let components = PriorityScorer.components(for: overdue, clock: referenceClock)
        #expect(components.urgency == 1)
    }

    @Test("Shorter effort yields a higher quick-win component")
    func quickWinMonotonic() {
        let short = TaskItem(title: "a", folderId: "inbox", effortMinutes: 10)
        let long = TaskItem(title: "b", folderId: "inbox", effortMinutes: 480)
        let s = PriorityScorer.components(for: short, clock: referenceClock).quickWin
        let l = PriorityScorer.components(for: long, clock: referenceClock).quickWin
        #expect(s > l)
    }
}
