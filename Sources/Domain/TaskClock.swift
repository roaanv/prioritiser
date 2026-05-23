// TaskClock.swift
// A small, injectable "today" reference used by scoring, date parsing, and
// formatting. The prototype hardcoded today to 2026-05-23 so demo data stayed
// stable; the real app uses the actual current day, but keeps it injectable so
// the domain logic is deterministic under test.

import Foundation

/// Provides the current day and day-arithmetic helpers, relative to a fixed
/// reference instant. Inject a fixed `now` in tests for determinism.
struct TaskClock {
    var now: Date
    var calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    /// Midnight of the reference day.
    var today: Date { calendar.startOfDay(for: now) }

    /// Midnight of the given date.
    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// `date` shifted by a whole number of days.
    func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Whole days from today until `due` (negative = overdue). Nil for no due date.
    func daysUntil(_ due: Date?) -> Int? {
        guard let due else { return nil }
        return calendar.dateComponents([.day], from: today, to: startOfDay(due)).day
    }
}
