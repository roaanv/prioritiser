// TaskListView.swift
// The center pane: a context-aware heading, a quick-add bar, and the task list.
// On "Top Priorities" the list splits into a "Top 5 Now" band of ranked cards and
// a "Next Up" remainder; every other view renders a flat list. Empty states match
// the prototype's per-view copy.
//
// Note: the quick-add here parses on commit (Enter). The live preview-chip
// variant and the ⌘N Spotlight capture arrive in slice 2.

import SwiftUI

struct TaskListView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("priorityViz") private var vizMode: PriorityVizMode = .cards

    var body: some View {
        VStack(spacing: 0) {
            header
            QuickAddBar { model.createTask(from: $0) }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            Divider().opacity(0)
            taskScroll
            footer
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(heading.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                if let sub = heading.subtitle {
                    Text(sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            headerTools
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var headerTools: some View {
        HStack(spacing: 4) {
            tab("List", systemImage: "list.bullet", active: true)
            tab("Schedule", systemImage: "calendar", active: false)
            Divider().frame(height: 16).padding(.horizontal, 4)
            toolButton("arrow.up.arrow.down", help: "Sort")
            toolButton("line.3.horizontal.decrease", help: "Filter")
        }
    }

    private func tab(_ title: String, systemImage: String, active: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(active ? .primary : .secondary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(active ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private func toolButton(_ systemImage: String, help: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .help(help)
    }

    // MARK: - List

    private var taskScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if case .view(.top) = model.selection {
                    topContent
                } else {
                    flatContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var topContent: some View {
        let tasks = model.visibleTasks
        let top = Array(tasks.prefix(5))
        let rest = Array(tasks.dropFirst(5))

        band(label: "Top 5 now",
             trailing: "Recalculated \(Date().formatted(date: .omitted, time: .shortened))")
        VStack(spacing: 4) {
            ForEach(Array(top.enumerated()), id: \.element.id) { index, task in
                TaskRowView(task: task, rank: vizMode == .cards ? index + 1 : nil, vizMode: vizMode)
            }
        }

        if !rest.isEmpty {
            band(label: "Next up", trailing: "\(rest.count) more")
                .padding(.top, 18)
            // "Next up" is always plain (.cards + no rank), matching the prototype.
            flatRows(rest, vizMode: .cards)
        }
    }

    @ViewBuilder
    private var flatContent: some View {
        let tasks = model.visibleTasks
        if tasks.isEmpty {
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        } else {
            flatRows(tasks, vizMode: vizMode)
        }
    }

    private func flatRows(_ tasks: [TaskItem], vizMode: PriorityVizMode) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider().opacity(0.4).padding(.horizontal, 14)
                }
                TaskRowView(task: task, vizMode: vizMode)
            }
        }
    }

    private func band(label: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold)).kerning(0.6)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(trailing)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8).padding(.bottom, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            let count = model.visibleTasks.count
            Text("\(count) \(count == 1 ? "task" : "tasks")")
            Text("·")
            Spacer()
            HStack(spacing: 4) {
                KeyCap("⌘"); KeyCap("N"); Text("Quick add")
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 24).padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Heading & empty copy

    private var heading: (title: String, subtitle: String?) {
        switch model.selection {
        case .view(let view):
            return (view.title, view.subtitle)
        case .folder(let id):
            let path = FolderTree.path(to: id, in: model.folders)
            let title = path.last?.name ?? "Folder"
            let sub = path.count > 1 ? path.dropLast().map(\.name).joined(separator: "  ›  ") : nil
            return (title, sub)
        }
    }

    private var emptyMessage: String {
        switch model.selection {
        case .view(let view): return view.emptyMessage
        case .folder: return "This folder is empty."
        }
    }
}
