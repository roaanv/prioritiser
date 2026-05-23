// Selection.swift
// What the sidebar currently has selected — either a smart view or a folder.
// Drives the task list pane's contents and heading.

import Foundation

/// The active sidebar selection.
enum Selection: Hashable {
    case view(SmartView)
    case folder(String)
}
