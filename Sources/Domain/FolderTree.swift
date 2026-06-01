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
    struct FlattenedFolder: Equatable {
        let folder: Folder
        let depth: Int
    }

    /// Build the root-level nodes of the folder tree, preserving input order.
    static func build(_ folders: [Folder]) -> [FolderNode] {
        func childrenOf(_ parentId: String?) -> [FolderNode] {
            folders
                .filter { $0.parentId == parentId }
                .map { FolderNode(folder: $0, children: childrenOf($0.id)) }
        }
        return childrenOf(nil)
    }

    /// Flatten the visible part of the tree for sidebar rendering. Descendants are
    /// included only when every ancestor on their path is expanded.
    static func flatten(_ folders: [Folder], expanded: Set<String>) -> [FlattenedFolder] {
        var roots: [Folder] = []
        var childrenByParent: [String: [Folder]] = [:]

        for folder in folders {
            if let parentId = folder.parentId {
                childrenByParent[parentId, default: []].append(folder)
            } else {
                roots.append(folder)
            }
        }

        var result: [FlattenedFolder] = []
        func append(_ nodes: [Folder], depth: Int) {
            for folder in nodes {
                result.append(FlattenedFolder(folder: folder, depth: depth))
                if expanded.contains(folder.id), let children = childrenByParent[folder.id] {
                    append(children, depth: depth + 1)
                }
            }
        }
        append(roots, depth: 0)
        return result
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

    /// Folders matching an autocomplete query, prefix matches first then substring
    /// matches, alphabetical within each group. An empty query returns the first few.
    static func search(_ query: String, in folders: [Folder], limit: Int = 6) -> [Folder] {
        let q = query.lowercased()
        guard !q.isEmpty else { return Array(folders.prefix(limit)) }
        let ranked = folders.compactMap { folder -> (folder: Folder, rank: Int)? in
            let name = folder.name.lowercased(), id = folder.id.lowercased()
            if name.hasPrefix(q) || id.hasPrefix(q) { return (folder, 0) }
            if name.contains(q) || id.contains(q) { return (folder, 1) }
            return nil
        }
        return ranked
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.folder.name < $1.folder.name }
            .prefix(limit)
            .map(\.folder)
    }

    /// Resolve a `#folder` slug to an existing folder: first by id (so a literal
    /// `#ops` still works), then by name slug (e.g. "operations" → "Operations").
    static func folder(forSlug slug: String, in folders: [Folder]) -> Folder? {
        let key = slug.lowercased()
        if let exact = folders.first(where: { $0.id.lowercased() == key }) { return exact }
        return folders.first { $0.nameSlug == key }
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
