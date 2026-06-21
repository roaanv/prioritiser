// SidebarView.swift
// The translucent left sidebar: search, smart views, and an AppKit-backed folder
// outline so the project tree behaves like a normal macOS tree control.

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool
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
                FolderOutlineView(model: model)
                    .frame(height: folderOutlineHeight)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 4))
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
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
                let id = model.addFolder(name: "New Folder", parentId: nil)
                model.selection = .folder(id)
                model.requestFolderEdit(id: id)
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
            guard let raw = items.first,
                  let draggedID = DraggedFolderPayload.folderID(from: raw) else { return false }
            model.reparentFolder(draggedID, under: nil)
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

    private func badge(_ count: Int, alert: Bool, selected: Bool) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: alert ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(selected ? AnyShapeStyle(.white)
                             : AnyShapeStyle(alert ? Palette.overdueText(scheme: .light) : Color.secondary))
    }

    private var folderOutlineHeight: CGFloat {
        let rowCount = max(1, FolderTree.flatten(model.folders, expanded: model.expandedFolders).count)
        return CGFloat(rowCount * 23 + 6)
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
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
