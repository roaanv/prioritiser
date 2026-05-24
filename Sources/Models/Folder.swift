// Folder.swift
// A project/folder in the Finder-style tree. Folders nest via `parentId`;
// root folders have a nil parent. Color is stored in OKLCH to match the design.

import Foundation

/// A folder (a.k.a. "project") tasks can be filed under. Forms a tree via `parentId`.
struct Folder: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var parentId: String?
    /// Folder accent color, authored in OKLCH like the prototype.
    var color: OKLCH
    /// System folders (e.g. Inbox) are not user-deletable.
    var isSystem: Bool = false
}

extension Folder {
    /// The `id` used for unfiled tasks captured without an explicit `#folder`.
    static let inboxID = "inbox"

    /// A grammar-safe slug derived from the display name (lowercased, alphanumerics
    /// only): "Operations" → "operations", "Design Review" → "designreview". Used by
    /// `#tag` autocomplete completion and name-based resolution so they round-trip.
    var nameSlug: String {
        name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
