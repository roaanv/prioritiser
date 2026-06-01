// DockWorkspaceView.swift
// Three dock areas around the task list. Tabs can be dragged between areas or onto
// an existing tab strip to form a tab group.

import SwiftUI
import AppKit

struct DockWorkspaceView: View {
    @Binding var layout: DockLayout

    var body: some View {
        HSplitView {
            DockAreaSlot(area: .left, layout: $layout) {
                DockAreaView(area: .left, layout: $layout)
                    .frame(minWidth: 190, idealWidth: 230, maxWidth: 360)
            }

            VSplitView {
                TaskListView()
                    .frame(minWidth: 420, minHeight: 280)
                DockAreaSlot(area: .bottom, layout: $layout) {
                    DockAreaView(area: .bottom, layout: $layout)
                        .frame(minHeight: 180, idealHeight: 240, maxHeight: 420)
                }
            }

            DockAreaSlot(area: .right, layout: $layout) {
                DockAreaView(area: .right, layout: $layout)
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: 520)
            }
        }
    }
}

private struct DockAreaSlot<Content: View>: View {
    let area: DockArea
    @Binding var layout: DockLayout
    private let content: Content

    init(area: DockArea, layout: Binding<DockLayout>, @ViewBuilder content: () -> Content) {
        self.area = area
        _layout = layout
        self.content = content()
    }

    var body: some View {
        if layout.isExpanded(area) {
            content
                .overlay(alignment: area.collapseButtonAlignment) {
                    Button {
                        layout.setExpanded(area, false)
                    } label: {
                        Image(systemName: area.collapseSystemImage)
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .help("Collapse \(area.title)")
                    .padding(6)
                }
        } else {
            CollapsedDockAreaBar(area: area, layout: $layout)
        }
    }
}

private struct CollapsedDockAreaBar: View {
    let area: DockArea
    @Binding var layout: DockLayout
    @State private var isTargeted = false

    var body: some View {
        Button {
            expand()
        } label: {
            Image(systemName: area.expandSystemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: area == .bottom ? nil : 32,
               height: area == .bottom ? 32 : nil)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035))
        .overlay {
            Rectangle()
                .strokeBorder(isTargeted ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let tab = items.lazy.compactMap(DockTab.fromDragString).first else { return false }
            layout.move(tab, to: area, groupID: nil)
            isTargeted = false
            return true
        } isTargeted: { isTargeted = $0 }
        .help("Expand \(area.title)")
        .accessibilityLabel("Expand \(area.title)")
    }

    private func expand() {
        layout.setExpanded(area, true)
    }
}

private extension DockArea {
    var collapseButtonAlignment: Alignment {
        switch self {
        case .left, .bottom:
            .topTrailing
        case .right:
            .topLeading
        }
    }

    var collapseSystemImage: String {
        switch self {
        case .left:
            "chevron.left"
        case .right:
            "chevron.right"
        case .bottom:
            "chevron.down"
        }
    }

    var expandSystemImage: String {
        switch self {
        case .left:
            "chevron.right"
        case .right:
            "chevron.left"
        case .bottom:
            "chevron.up"
        }
    }
}



private final class DockSplitNotificationObserver {
    var token: NSObjectProtocol?

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

private struct DockSplitViewAccessor: NSViewRepresentable {
    let area: DockArea
    let groupIDs: [DockGroup.ID]
    @Binding var layout: DockLayout

    func makeCoordinator() -> Coordinator {
        Coordinator(area: area, groupIDs: groupIDs, layout: $layout)
    }

    func makeNSView(context: Context) -> FinderView {
        let view = FinderView()
        view.onResolve = { [weak coordinator = context.coordinator] splitView in
            coordinator?.configure(splitView)
        }
        return view
    }

    func updateNSView(_ nsView: FinderView, context: Context) {
        context.coordinator.update(area: area, groupIDs: groupIDs, layout: $layout)
        nsView.onResolve = { [weak coordinator = context.coordinator] splitView in
            coordinator?.configure(splitView)
        }
        DispatchQueue.main.async {
            nsView.resolveSplitView()
        }
    }

    final class FinderView: NSView {
        var onResolve: ((NSSplitView) -> Void)?
        private weak var resolvedSplitView: NSSplitView?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            DispatchQueue.main.async { [weak self] in
                self?.resolveSplitView()
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.resolveSplitView()
            }
        }

        func resolveSplitView() {
            if let resolvedSplitView {
                onResolve?(resolvedSplitView)
                return
            }

            var view = superview
            while let current = view {
                if let splitView = current as? NSSplitView {
                    resolvedSplitView = splitView
                    onResolve?(splitView)
                    return
                }
                view = current.superview
            }
        }
    }

    @MainActor
    final class Coordinator {
        private var area: DockArea
        private var groupIDs: [DockGroup.ID]
        private var layout: Binding<DockLayout>
        private weak var splitView: NSSplitView?
        private let resizeObserver = DockSplitNotificationObserver()
        private var appliedGroupIDs: [DockGroup.ID] = []
        private var isApplyingSavedLayout = false

        init(area: DockArea, groupIDs: [DockGroup.ID], layout: Binding<DockLayout>) {
            self.area = area
            self.groupIDs = groupIDs
            self.layout = layout
        }
        func update(area: DockArea, groupIDs: [DockGroup.ID], layout: Binding<DockLayout>) {
            self.area = area
            self.groupIDs = groupIDs
            self.layout = layout
            if let splitView {
                configure(splitView)
            }
        }

        func configure(_ splitView: NSSplitView) {
            guard groupIDs.count > 1 else {
                detachObserver()
                self.splitView = splitView
                appliedGroupIDs = groupIDs
                return
            }

            let splitChanged = self.splitView !== splitView
            let groupsChanged = appliedGroupIDs != groupIDs
            if splitChanged {
                detachObserver()
                self.splitView = splitView
            }

            if splitChanged || groupsChanged {
                appliedGroupIDs = groupIDs
                isApplyingSavedLayout = true
                DispatchQueue.main.async { [weak self, weak splitView] in
                    guard let self, let splitView else { return }
                    self.applySavedLayoutWhenReady(to: splitView, attempt: 0)
                }
            } else {
                attachObserver(to: splitView)
            }
        }

        private func attachObserver(to splitView: NSSplitView) {
            guard resizeObserver.token == nil else { return }
            resizeObserver.token = NotificationCenter.default.addObserver(
                forName: NSSplitView.didResizeSubviewsNotification,
                object: splitView,
                queue: .main
            ) { [weak self, weak splitView] _ in
                MainActor.assumeIsolated {
                    guard let self, let splitView, !self.isApplyingSavedLayout else { return }
                    self.captureRatios(from: splitView)
                }
            }
        }

        private func detachObserver() {
            if let token = resizeObserver.token {
                NotificationCenter.default.removeObserver(token)
                resizeObserver.token = nil
            }
        }

        private func applySavedLayoutWhenReady(to splitView: NSSplitView, attempt: Int) {
            if applySavedLayout(to: splitView) {
                attachObserver(to: splitView)
                DispatchQueue.main.async { [weak self] in
                    self?.isApplyingSavedLayout = false
                }
            } else if attempt >= 8 {
                appliedGroupIDs = []
                isApplyingSavedLayout = false
            } else {
                DispatchQueue.main.async { [weak self, weak splitView] in
                    guard let self, let splitView else { return }
                    self.applySavedLayoutWhenReady(to: splitView, attempt: attempt + 1)
                }
            }
        }

        private func applySavedLayout(to splitView: NSSplitView) -> Bool {
            let savedRatios = groupIDs.compactMap { layout.wrappedValue.heightRatio(for: $0, in: area) }
            guard !savedRatios.isEmpty else { return true }

            guard !splitView.isVertical,
                  splitView.arrangedSubviews.count == groupIDs.count,
                  splitView.bounds.height > 0 else { return false }

            let ratiosTopToBottom = normalizedRatios()
            let ratiosBottomToTop = ratiosTopToBottom.reversed()
            let dividerThickness = splitView.dividerThickness
            let contentHeight = max(0, splitView.bounds.height - dividerThickness * CGFloat(groupIDs.count - 1))
            guard contentHeight > 0 else { return false }

            var cumulativeSubviewHeights: CGFloat = 0
            for (dividerIndex, ratio) in ratiosBottomToTop.dropLast().enumerated() {
                cumulativeSubviewHeights += contentHeight * CGFloat(ratio)
                let position = cumulativeSubviewHeights + dividerThickness * CGFloat(dividerIndex)
                splitView.setPosition(position, ofDividerAt: dividerIndex)
            }
            return true
        }

        private func captureRatios(from splitView: NSSplitView) {
            guard splitView.arrangedSubviews.count == groupIDs.count else { return }

            var heights = [DockGroup.ID: Double]()
            heights.reserveCapacity(groupIDs.count)
            for (groupID, subview) in zip(groupIDs.reversed(), splitView.arrangedSubviews) {
                let height = subview.frame.height
                guard height.isFinite, height > 0 else { continue }
                heights[groupID] = Double(height)
            }
            layout.wrappedValue.setHeightRatios(heights, in: area)
        }

        private func normalizedRatios() -> [Double] {
            let equal = 1 / Double(groupIDs.count)
            var ratios = [Double]()
            ratios.reserveCapacity(groupIDs.count)
            for groupID in groupIDs {
                ratios.append(layout.wrappedValue.heightRatio(for: groupID, in: area) ?? equal)
            }
            let total = ratios.reduce(0, +)
            guard total > 0 else { return Array(repeating: equal, count: groupIDs.count) }
            return ratios.map { $0 / total }
        }
    }
}

private struct DockAreaView: View {
    let area: DockArea
    @Binding var layout: DockLayout
    @State private var isTargeted = false

    private var groups: [DockGroup] { layout[area] }

    var body: some View {
        dockGroups
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(areaBackground)
        .dropDestination(for: String.self) { items, _ in
            guard let tab = items.lazy.compactMap(DockTab.fromDragString).first else { return false }
            layout.move(tab, to: area, groupID: nil)
            isTargeted = false
            return true
        } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder
    private var dockGroups: some View {
        if groups.isEmpty {
            emptyDropTarget
        } else {
            GeometryReader { proxy in
                VSplitView {
                    ForEach(groups) { group in
                        DockGroupView(group: group, layout: $layout)
                            .frame(idealHeight: idealHeight(for: group, availableHeight: proxy.size.height))
                            .background {
                                if group.id == groups.first?.id {
                                    DockSplitViewAccessor(area: area,
                                                          groupIDs: groups.map(\.id),
                                                          layout: $layout)
                                }
                            }
                    }
                }
            }
        }
    }

    private func idealHeight(for group: DockGroup, availableHeight: CGFloat) -> CGFloat? {
        guard let ratio = layout.heightRatio(for: group.id, in: area), availableHeight > 0 else { return nil }
        return availableHeight * ratio
    }

    private var areaBackground: some View {
        Rectangle()
            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.025))
    }

    private var emptyDropTarget: some View {
        VStack(spacing: 8) {
            Image(systemName: "dock.rectangle")
            Text("Drop tabs here")
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


private struct DockGroupView: View {
    let group: DockGroup
    @Binding var layout: DockLayout
    @State private var isTargeted = false

    private var selected: DockTab { group.tabs.contains(group.selected) ? group.selected : group.tabs[0] }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().opacity(0.5)
            DockTabContent(tab: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isTargeted ? 1.5 : 0.5)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let tab = items.lazy.compactMap(DockTab.fromDragString).first,
                  let area = areaContainingGroup else { return false }
            layout.move(tab, to: area, groupID: group.id)
            isTargeted = false
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                    DockTabInsertionTarget(groupID: group.id, insertionIndex: index, layout: $layout)
                    tabButton(tab)
                }
                DockTabInsertionTarget(groupID: group.id, insertionIndex: group.tabs.count, layout: $layout)
            }
            .padding(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabButton(_ tab: DockTab) -> some View {
        Button {
            layout.select(tab, in: group.id)
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11.5, weight: selected == tab ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected == tab ? Color.accentColor.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected == tab ? Color.primary : Color.secondary)
        .draggable(tab.dragString)
        .help("Drag to dock \(tab.title) elsewhere")
    }

    private var areaContainingGroup: DockArea? {
        DockArea.allCases.first { area in
            layout[area].contains { $0.id == group.id }
        }
    }
}

private struct DockTabInsertionTarget: View {
    let groupID: DockGroup.ID
    let insertionIndex: Int
    @Binding var layout: DockLayout
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 1)
                }
            }
            .overlay {
                if isTargeted {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: isTargeted ? 42 : 8, height: 26)
            .animation(.easeOut(duration: 0.12), value: isTargeted)
            .dropDestination(for: String.self) { items, _ in
                guard let tab = items.lazy.compactMap(DockTab.fromDragString).first,
                      let area = areaContainingGroup else { return false }
                layout.move(tab, to: area, groupID: groupID, insertionIndex: insertionIndex)
                isTargeted = false
                return true
            } isTargeted: { isTargeted = $0 }
            .accessibilityHidden(true)
    }

    private var areaContainingGroup: DockArea? {
        DockArea.allCases.first { area in
            layout[area].contains { $0.id == groupID }
        }
    }
}

private struct DockTabContent: View {
    let tab: DockTab

    var body: some View {
        switch tab {
        case .views:
            ViewsDockPane()
        case .folders:
            FoldersDockPane()
        case .activity:
            ActivityDockPane()
        case .priorityMatrix:
            ProjectMatrixView()
        case .notes:
            NotesDockPane()
        case .priorityScore:
            PriorityScoreDockPane()
        case .itemDetails:
            ItemDetailsDockPane()
        }
    }
}
