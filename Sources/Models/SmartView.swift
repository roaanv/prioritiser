// SmartView.swift
// The sidebar's smart lists. Each is a saved filter over the task set, ordered
// to match the prototype's VIEWS array.

import Foundation

/// A built-in smart list shown in the sidebar's "Views" section.
enum SmartView: String, CaseIterable, Identifiable {
    case top
    case today
    case week
    case overdue
    case quickWin = "quickwin"
    case inbox
    case all
    case completed

    var id: String { rawValue }

    /// Display name in the sidebar and as the list heading.
    var title: String {
        switch self {
        case .top: return "Top Priorities"
        case .today: return "Today"
        case .week: return "Next 7 Days"
        case .overdue: return "Overdue"
        case .quickWin: return "Quick Wins"
        case .inbox: return "Inbox"
        case .all: return "All Tasks"
        case .completed: return "Completed"
        }
    }

    /// One-line subtitle under the heading.
    var subtitle: String {
        switch self {
        case .top: return "Auto-ranked by impact, priority, due-soonness and effort."
        case .today: return "Due today."
        case .week: return "Due in the next seven days."
        case .overdue: return "Past their due date."
        case .quickWin: return "30 minutes or less with medium-plus impact."
        case .inbox: return "Tasks not yet filed."
        case .all: return "Every open task."
        case .completed: return "Done, grouped by the day you completed them."
        }
    }

    /// Empty-state copy shown when the filtered list is empty.
    var emptyMessage: String {
        switch self {
        case .today: return "Nothing due today. Cherry-pick from Top Priorities."
        case .overdue: return "No overdue tasks. Stay sharp."
        case .quickWin: return "No quick wins waiting."
        case .inbox: return "Inbox is empty."
        case .completed: return "No completed tasks yet. Check one off to see it here."
        default: return "Nothing here yet."
        }
    }

    /// SF Symbol name for the sidebar row.
    var systemImage: String {
        switch self {
        case .top: return "sparkles"
        case .today: return "calendar"
        case .week: return "calendar.day.timeline.left"
        case .overdue: return "clock.badge.exclamationmark"
        case .quickWin: return "bolt.fill"
        case .inbox: return "tray"
        case .all: return "list.bullet"
        case .completed: return "checkmark.circle"
        }
    }

    /// Whether this view's badge should render in the "alert" (overdue) color.
    var isAlert: Bool { self == .overdue }

    /// Whether the project priority matrix is meaningful for this view. Shown for
    /// whole-set views; hidden for views defined by a matrix axis — Today/Overdue
    /// (due-date) would have two structurally-empty quadrants, and Next 7 / Quick
    /// Wins already filter on due/effort, so the matrix would just re-slice them.
    var supportsMatrix: Bool {
        switch self {
        case .top, .all, .inbox: return true
        case .today, .week, .overdue, .quickWin, .completed: return false
        }
    }
}
