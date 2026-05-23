// SidebarView.swift
// The translucent left sidebar: a decorative search field, the "Views" smart
// lists, and a Finder-style "Folders" tree with disclosure triangles, nesting,
// colored folder dots, and per-row counts. Selection uses the native sidebar
// list style so the active row gets the system accent fill.

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""

    /// Gold tint for the "Top Priorities" spark icon (prototype: oklch 0.62 0.18 60).
    private let topTint = OKLCH(0.62, 0.18, 60).color

    var body: some View {
        @Bindable var model = model

        List(selection: selectionBinding(for: model)) {
            SearchField(text: $searchText)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))
                .listRowSeparator(.hidden)
                .selectionDisabled()

            Section("Views") {
                ForEach(SmartView.allCases) { view in
                    viewRow(view)
                        .tag(Selection.view(view))
                }
            }

            Section("Folders") {
                ForEach(flattenedFolders, id: \.folder.id) { item in
                    folderRow(item)
                        .tag(Selection.folder(item.folder.id))
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { userFooter }
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
        .font(.system(size: 13))
    }

    @ViewBuilder
    private func folderRow(_ item: FlatFolder) -> some View {
        let folder = item.folder
        let selected = model.selection == .folder(folder.id)
        let hasChildren = model.folders.contains { $0.parentId == folder.id }
        let count = TaskFilter.folderCount(folder.id, tasks: model.tasks, folders: model.folders)

        HStack(spacing: 6) {
            disclosure(folder: folder, hasChildren: hasChildren, selected: selected)
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(folder.tint))
            Text(folder.name)
                .foregroundStyle(selected ? .white : .primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if count > 0 { badge(count, alert: false, selected: selected) }
        }
        .font(.system(size: 13))
        .padding(.leading, CGFloat(item.depth) * 14)
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

    private var userFooter: some View {
        HStack(spacing: 8) {
            Text("A")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            Text("Alex")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
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

/// A non-functional rounded search field matching the prototype's sidebar search.
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            KeyCap("⌘F")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}
