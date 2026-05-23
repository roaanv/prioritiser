// Selection.swift
// What the sidebar currently has selected — either a smart view or a folder.
// Drives the task list pane's contents and heading.

import Foundation

/// The active sidebar selection.
enum Selection: Hashable {
    case view(SmartView)
    case folder(String)
}

extension Selection {
    /// Stable string form for persisting the last selection across launches.
    var persistedString: String {
        switch self {
        case .view(let view): return "view:\(view.rawValue)"
        case .folder(let id): return "folder:\(id)"
        }
    }

    init?(persisted: String) {
        let parts = persisted.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "view":
            guard let view = SmartView(rawValue: String(parts[1])) else { return nil }
            self = .view(view)
        case "folder":
            self = .folder(String(parts[1]))
        default:
            return nil
        }
    }
}
