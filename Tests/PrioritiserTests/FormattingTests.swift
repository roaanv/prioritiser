// FormattingTests.swift
// Checks the effort and due-date label wording matches the prototype.

import Testing
import Foundation
@testable import Prioritiser

private let clock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))!
)

@Suite("Formatting")
struct FormattingTests {
    @Test("Effort labels")
    func effort() {
        #expect(Formatting.effort(10) == "10m")
        #expect(Formatting.effort(60) == "1h")
        #expect(Formatting.effort(90) == "1.5h")
        #expect(Formatting.effort(1440) == "3d")
        #expect(Formatting.effort(nil) == nil)
    }

    @Test("Relative due labels")
    func dueLabels() {
        #expect(Formatting.dueLabel(clock.today, clock: clock) == "Today")
        #expect(Formatting.dueLabel(clock.addingDays(1, to: clock.today), clock: clock) == "Tomorrow")
        #expect(Formatting.dueLabel(clock.addingDays(-1, to: clock.today), clock: clock) == "Yesterday")
        #expect(Formatting.dueLabel(clock.addingDays(-3, to: clock.today), clock: clock) == "3d overdue")
        #expect(Formatting.dueLabel(clock.addingDays(3, to: clock.today), clock: clock) == "in 3d")
        #expect(Formatting.dueLabel(nil, clock: clock) == nil)
    }

    @Test("Distant dates fall back to an absolute label")
    func absoluteDate() {
        let distant = clock.addingDays(30, to: clock.today)
        #expect(Formatting.dueLabel(distant, clock: clock) == Formatting.date(distant, clock: clock))
    }
}
