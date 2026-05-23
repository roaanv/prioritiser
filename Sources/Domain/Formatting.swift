// Formatting.swift
// Human-readable labels for effort and due dates. Ported from the prototype's
// fmtEffort / fmtDate / fmtDueLabel so wording matches ("in 3d", "2d overdue").

import Foundation

enum Formatting {
    /// One workday in minutes (the prototype treats "t:1d" as 8 hours).
    private static let workdayMinutes = 60 * 8

    /// Effort label from minutes: "10m", "1h", "1.5h", "3d". Nil for unestimated.
    static func effort(_ minutes: Int?) -> String? {
        guard let minutes else { return nil }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < workdayMinutes {
            let hours = Double(minutes) / 60
            return minutes % 60 == 0 ? "\(minutes / 60)h" : String(format: "%.1fh", hours)
        }
        let days = Double(minutes) / Double(workdayMinutes)
        return days.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(days))d"
            : String(format: "%.1fd", days)
    }

    /// Absolute date label like "May 23" (adds the year when not the current year).
    static func date(_ date: Date?, clock: TaskClock = TaskClock()) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let sameYear = clock.calendar.component(.year, from: date)
            == clock.calendar.component(.year, from: clock.now)
        formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Relative due label: "Today", "Tomorrow", "Yesterday", "2d overdue",
    /// "in 3d", or an absolute date when more than a week out.
    static func dueLabel(_ due: Date?, clock: TaskClock = TaskClock()) -> String? {
        guard let due, let n = clock.daysUntil(due) else { return nil }
        switch n {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case ..<0: return "\(-n)d overdue"
        case 1..<7: return "in \(n)d"
        default: return date(due, clock: clock)
        }
    }
}
