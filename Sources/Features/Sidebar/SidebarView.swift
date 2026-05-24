// SidebarView.swift
// The translucent left sidebar: a decorative search field, the "Views" smart
// lists, and a Finder-style "Folders" tree with disclosure triangles, nesting,
// colored folder dots, and per-row counts. Selection uses the native sidebar
// list style so the active row gets the system accent fill.

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var editingFolderID: String?
    @State private var draftName = ""
    @FocusState private var renameFocused: Bool
    @FocusState private var searchFocused: Bool
    /// Folder id currently hovered as a drag drop-target for "move into" (highlight).
    @State private var dropTargetID: String?
    /// Folder id whose top-edge insertion strip is hovered (reorder "before" line).
    @State private var insertTargetID: String?
    /// True while a folder is dragged over the "Folders" header (move-to-root target).
    @State private var rootTargeted = false

    /// Gold tint for the "Top Priorities" spark icon (prototype: oklch 0.62 0.18 60).
    private let topTint = OKLCH(0.62, 0.18, 60).color

    var body: some View {
        @Bindable var model = model

        List(selection: selectionBinding(for: model)) {
            SearchField(text: $model.searchQuery, focused: $searchFocused)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))
                .listRowSeparator(.hidden)
                .selectionDisabled()

            Section("Views") {
                ForEach(SmartView.allCases) { view in
                    viewRow(view)
                        .tag(Selection.view(view))
                }
            }

            Section {
                ForEach(flattenedFolders, id: \.folder.id) { item in
                    folderRow(item)
                        .tag(Selection.folder(item.folder.id))
                }
            } header: {
                foldersHeader
            }
        }
        .listStyle(.sidebar)
        .onChange(of: model.focusSearchToken) { searchFocused = true }
    }

    private var foldersHeader: some View {
        HStack {
            Text("Folders")
            Spacer()
            Button {
                startNewFolder(parentID: nil)
            } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New folder")
            .accessibilityLabel("New folder")
        }
        .contentShape(Rectangle())
        .background(rootTargeted ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        // Drop a folder here to move it to the top level (out of its parent).
        .dropDestination(for: String.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged, under: nil) }
            rootTargeted = false
            return true
        } isTargeted: { rootTargeted = $0 }
    }

    // MARK: - Rows

    @ViewBuilder
    private func viewRow(_ view: SmartView) -> some View {
        let selected = model.selection == .view(view)
        let count = TaskFilter.badgeCount(for: view, tasks: model.tasks,
                                          weights: model.weights, clock: model.clock)
        HStack(spacing: 6) {
            Image(systemName: view.systemImage)
                .frame(width: 18)
                .foregroundStyle(selected ? AnyShapeStyle(.white)
                                 : AnyShapeStyle(view == .top ? topTint : Color.accentColor))
            Text(view.title)
                .foregroundStyle(selected ? .white : .primary)
            Spacer(minLength: 4)
            if count > 0 {
                badge(count, alert: view.isAlert, selected: selected)
            }
        }
        .appFont(13)
    }

    @ViewBuilder
    private func folderRow(_ item: FlatFolder) -> some View {
        let folder = item.folder
        let selected = model.selection == .folder(folder.id)
        let hasChildren = model.folders.contains { $0.parentId == folder.id }
        let count = TaskFilter.folderCount(folder.id, tasks: model.tasks, folders: model.folders)
        let isEditing = editingFolderID == folder.id

        HStack(spacing: 6) {
            disclosure(folder: folder, hasChildren: hasChildren, selected: selected)
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(folder.tint))
            if isEditing {
                TextField("Folder name", text: $draftName)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit(commitRename)
                    .onChange(of: renameFocused) { _, focused in if !focused { commitRename() } }
            } else {
                Text(folder.name)
                    .foregroundStyle(selected ? .white : .primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if count > 0 && !isEditing { badge(count, alert: false, selected: selected) }
        }
        .appFont(13)
        .padding(.leading, CGFloat(item.depth) * 14)
        .background(dropTargetID == folder.id ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        // Top-edge strip = the gap above this row: drop here to reorder (insert before).
        .overlay(alignment: .top) { insertionStrip(before: folder.id, depth: item.depth) }
        .contextMenu {
            Button("Rename") { beginRename(folder) }
            Button("New Subfolder") { startNewFolder(parentID: folder.id) }
            if !folder.isSystem && folder.parentId != nil {
                Button("Move to Top Level") { model.reparentFolder(folder.id, under: nil) }
            }
            if !folder.isSystem {
                Divider()
                Button("Delete", role: .destructive) { model.deleteFolder(id: folder.id) }
            }
        }
        .draggable(folder.id)
        // Drop another folder here to move it into this one (re-parent).
        .dropDestination(for: String.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged, under: folder.id) }
            dropTargetID = nil
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? folder.id : (dropTargetID == folder.id ? nil : dropTargetID)
        }
    }

    /// A thin drop strip on a row's top edge — the gap above it. Dropping a folder
    /// here reorders it to just before this row (within this row's parent); an accent
    /// line shows the insertion point.
    private func insertionStrip(before folderID: String, depth: Int) -> some View {
        Color.clear
            .frame(height: 9)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                if let dragged = items.first { model.moveFolder(dragged, before: folderID) }
                insertTargetID = nil
                return true
            } isTargeted: { targeted in
                insertTargetID = targeted ? folderID : (insertTargetID == folderID ? nil : insertTargetID)
            }
            .overlay(alignment: .top) {
                if insertTargetID == folderID {
                    Capsule().fill(Color.accentColor).frame(height: 2)
                        .padding(.leading, CGFloat(depth) * 14 + 4)
                }
            }
    }

    // MARK: - Folder editing

    private func startNewFolder(parentID: String?) {
        let id = model.addFolder(name: "New Folder", parentId: parentID)
        model.selection = .folder(id)
        editingFolderID = id
        draftName = "New Folder"
        Task { renameFocused = true } // next runloop tick, on the main actor
    }

    private func beginRename(_ folder: Folder) {
        editingFolderID = folder.id
        draftName = folder.name
        Task { renameFocused = true }
    }

    private func commitRename() {
        if let id = editingFolderID { model.renameFolder(id: id, to: draftName) }
        editingFolderID = nil
    }

    @ViewBuilder
    private func disclosure(folder: Folder, hasChildren: Bool, selected: Bool) -> some View {
        if hasChildren {
            Button {
                withAnimation(.easeOut(duration: 0.12)) { model.toggleFolder(folder.id) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                    .rotationEffect(.degrees(model.expandedFolders.contains(folder.id) ? 90 : 0))
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.expandedFolders.contains(folder.id) ? "Collapse" : "Expand")
        } else {
            Color.clear.frame(width: 12, height: 12)
        }
    }

    private func badge(_ count: Int, alert: Bool, selected: Bool) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: alert ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(selected ? AnyShapeStyle(.white)
                             : AnyShapeStyle(alert ? Palette.overdueText(scheme: .light) : Color.secondary))
    }

    // MARK: - Folder flattening

    /// A folder plus its indentation depth, expanded subtree only.
    struct FlatFolder { let folder: Folder; let depth: Int }

    private var flattenedFolders: [FlatFolder] {
        var result: [FlatFolder] = []
        func walk(_ nodes: [FolderNode], depth: Int) {
            for node in nodes {
                result.append(FlatFolder(folder: node.folder, depth: depth))
                if model.expandedFolders.contains(node.folder.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(FolderTree.build(model.folders), depth: 0)
        return result
    }

    private func selectionBinding(for model: AppModel) -> Binding<Selection?> {
        Binding(
            get: { model.selection },
            set: { if let new = $0 { model.selection = new } }
        )
    }
}

/// The sidebar search field; filters the task list as you type. ⌘F focuses it.
private struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused(focused)
            if text.isEmpty {
                KeyCap("⌘F")
            } else {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}
