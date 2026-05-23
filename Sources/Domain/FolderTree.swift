// FolderTree.swift
// Pure helpers for the Finder-style folder hierarchy: building the nested tree,
// resolving a folder's ancestor path (breadcrumb), and ancestor membership tests.
// Ported from buildFolderTree / folderPath / folderInTree.

import Foundation

/// A folder plus its nested children, for rendering the disclosure tree.
struct FolderNode: Identifiable {
    let folder: Folder
    var children: [FolderNode]
    var id: String { folder.id }
}

enum FolderTree {
    /// Build the root-level nodes of the folder tree, preserving input order.
    static func build(_ folders: [Folder]) -> [FolderNode] {
        func childrenOf(_ parentId: String?) -> [FolderNode] {
            folders
                .filter { $0.parentId == parentId }
                .map { FolderNode(folder: $0, children: childrenOf($0.id)) }
        }
        return childrenOf(nil)
    }

    /// Ancestor-to-self path, e.g. [Work, Prioritiser]. Empty if not found.
    static func path(to folderId: String, in folders: [Folder]) -> [Folder] {
        let byId = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var path: [Folder] = []
        var current = byId[folderId]
        while let folder = current {
            path.insert(folder, at: 0)
            current = folder.parentId.flatMap { byId[$0] }
        }
        return path
    }

    /// Resolve a `#folder` slug to an existing folder: first by id, then by a
    /// space-stripped name match (e.g. "designreview" → "Design Review").
    static func folder(forSlug slug: String, in folders: [Folder]) -> Folder? {
        let key = slug.lowercased()
        if let exact = folders.first(where: { $0.id.lowercased() == key }) { return exact }
        return folders.first {
            $0.name.lowercased().replacingOccurrences(of: " ", with: "") == key
        }
    }

    /// True if `folderId` is `ancestorId` itself or a descendant of it.
    static func isDescendant(_ folderId: String, ofOrEqual ancestorId: String, in folders: [Folder]) -> Bool {
        let byId = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var current = byId[folderId]
        while let folder = current {
            if folder.id == ancestorId { return true }
            current = folder.parentId.flatMap { byId[$0] }
        }
        return false
    }
}
