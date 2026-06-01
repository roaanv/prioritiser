// DockLayout.swift
// Model for the app's dockable tab layout. A dock area contains ordered tab
// groups; a group with multiple tabs renders as a normal tab strip.

import Foundation

enum DockArea: String, Codable, CaseIterable, Identifiable, Hashable {
    case left
    case right
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left Dock"
        case .right: "Right Dock"
        case .bottom: "Bottom Dock"
        }
    }
}

enum DockTab: String, Codable, CaseIterable, Identifiable, Hashable {
    case views
    case folders
    case activity
    case priorityMatrix
    case notes
    case priorityScore
    case itemDetails

    var id: String { rawValue }

    var title: String {
        switch self {
        case .views: "Views"
        case .folders: "Folders"
        case .activity: "Activity"
        case .priorityMatrix: "Priority Matrix"
        case .notes: "Notes"
        case .priorityScore: "Priority Score"
        case .itemDetails: "Item Details"
        }
    }

    var systemImage: String {
        switch self {
        case .views: "line.3.horizontal"
        case .folders: "folder"
        case .activity: "clock.arrow.circlepath"
        case .priorityMatrix: "square.grid.2x2"
        case .notes: "note.text"
        case .priorityScore: "gauge.with.dots.needle.67percent"
        case .itemDetails: "slider.horizontal.3"
        }
    }

    var defaultDockArea: DockArea {
        switch self {
        case .views, .folders:
            .left
        case .priorityMatrix:
            .bottom
        case .activity, .notes, .priorityScore, .itemDetails:
            .right
        }
    }

    var dragString: String { Self.dragPrefix + rawValue }

    static let dragPrefix = "io.0112.prioritiser.dock-tab:"

    static func fromDragString(_ string: String) -> DockTab? {
        guard string.hasPrefix(dragPrefix) else { return nil }
        return DockTab(rawValue: String(string.dropFirst(dragPrefix.count)))
    }
}

struct DockGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var tabs: [DockTab]
    var selected: DockTab

    init(id: UUID = UUID(), tabs: [DockTab], selected: DockTab? = nil) {
        self.id = id
        self.tabs = tabs
        self.selected = selected ?? tabs.first ?? .views
    }
}

struct DockGroupHeightRatios: Codable, Equatable {
    var left: [DockGroup.ID: Double]
    var right: [DockGroup.ID: Double]
    var bottom: [DockGroup.ID: Double]

    init(left: [DockGroup.ID: Double] = [:],
         right: [DockGroup.ID: Double] = [:],
         bottom: [DockGroup.ID: Double] = [:]) {
        self.left = left
        self.right = right
        self.bottom = bottom
    }

    subscript(area: DockArea) -> [DockGroup.ID: Double] {
        get {
            switch area {
            case .left: left
            case .right: right
            case .bottom: bottom
            }
        }
        set {
            switch area {
            case .left: left = newValue
            case .right: right = newValue
            case .bottom: bottom = newValue
            }
        }
    }
}


struct DockLayout: Codable, Equatable {
    var left: [DockGroup]
    var right: [DockGroup]
    var bottom: [DockGroup]
    var hiddenTabs: Set<DockTab>
    var collapsedAreas: Set<DockArea>
    var groupHeightRatios: DockGroupHeightRatios
    static let storageKey = "ui.dockLayout"

    static let `default` = DockLayout(
        left: [
            DockGroup(tabs: [.views]),
            DockGroup(tabs: [.folders])
        ],
        right: [
            DockGroup(tabs: [.priorityScore, .itemDetails, .notes, .activity], selected: .priorityScore)
        ],
        bottom: [
            DockGroup(tabs: [.priorityMatrix])
        ]
    )

    init(left: [DockGroup],
         right: [DockGroup],
         bottom: [DockGroup],
         hiddenTabs: Set<DockTab> = [],
         collapsedAreas: Set<DockArea> = [],
         groupHeightRatios: DockGroupHeightRatios = DockGroupHeightRatios()) {
        self.left = left
        self.right = right
        self.bottom = bottom
        self.hiddenTabs = hiddenTabs
        self.collapsedAreas = collapsedAreas
        self.groupHeightRatios = groupHeightRatios
    }

    private enum CodingKeys: String, CodingKey {
        case left
        case right
        case bottom
        case hiddenTabs
        case collapsedAreas
        case groupHeightRatios
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = try container.decode([DockGroup].self, forKey: .left)
        right = try container.decode([DockGroup].self, forKey: .right)
        bottom = try container.decode([DockGroup].self, forKey: .bottom)
        hiddenTabs = try container.decodeIfPresent(Set<DockTab>.self, forKey: .hiddenTabs) ?? []
        collapsedAreas = try container.decodeIfPresent(Set<DockArea>.self, forKey: .collapsedAreas) ?? []
        groupHeightRatios = try container.decodeIfPresent(DockGroupHeightRatios.self, forKey: .groupHeightRatios) ?? DockGroupHeightRatios()
    }

    subscript(area: DockArea) -> [DockGroup] {
        get {
            switch area {
            case .left: left
            case .right: right
            case .bottom: bottom
            }
        }
        set {
            switch area {
            case .left: left = newValue
            case .right: right = newValue
            case .bottom: bottom = newValue
            }
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> DockLayout {
        guard let data = defaults.data(forKey: storageKey),
              var decoded = try? JSONDecoder().decode(DockLayout.self, from: data) else {
            return .default
        }
        decoded.repair()
        return decoded
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func isVisible(_ tab: DockTab) -> Bool {
        !hiddenTabs.contains(tab)
    }

    func isExpanded(_ area: DockArea) -> Bool {
        !collapsedAreas.contains(area)
    }

    mutating func setExpanded(_ area: DockArea, _ expanded: Bool) {
        if expanded {
            collapsedAreas.remove(area)
        } else {
            collapsedAreas.insert(area)
        }
        repair()
    }

    mutating func setVisible(_ tab: DockTab, _ visible: Bool) {
        if visible {
            hiddenTabs.remove(tab)
            if !contains(tab) {
                self[tab.defaultDockArea].append(DockGroup(tabs: [tab], selected: tab))
            }
            collapsedAreas.remove(area(containing: tab) ?? tab.defaultDockArea)
        } else {
            hiddenTabs.insert(tab)
            remove(tab)
        }
        repair()
    }

    mutating func move(_ tab: DockTab, to area: DockArea, groupID: DockGroup.ID?, insertionIndex: Int? = nil) {
        let originalLocation = location(of: tab)
        hiddenTabs.remove(tab)
        collapsedAreas.remove(area)
        remove(tab)
        if let groupID, let groupIndex = self[area].firstIndex(where: { $0.id == groupID }) {
            var targetIndex = insertionIndex ?? self[area][groupIndex].tabs.endIndex
            if let originalLocation,
               originalLocation.area == area,
               originalLocation.groupID == groupID,
               originalLocation.index < targetIndex {
                targetIndex -= 1
            }
            targetIndex = min(max(targetIndex, 0), self[area][groupIndex].tabs.count)
            self[area][groupIndex].tabs.insert(tab, at: targetIndex)
            self[area][groupIndex].selected = tab
        } else {
            self[area].append(DockGroup(tabs: [tab], selected: tab))
        }
        repair()
    }

    mutating func select(_ tab: DockTab, in groupID: DockGroup.ID) {
        for area in DockArea.allCases {
            guard let index = self[area].firstIndex(where: { $0.id == groupID }),
                  self[area][index].tabs.contains(tab) else { continue }
            self[area][index].selected = tab
            return
        }
    }

    func heightRatio(for groupID: DockGroup.ID, in area: DockArea) -> Double? {
        guard let ratio = groupHeightRatios[area][groupID], ratio.isFinite, ratio > 0 else { return nil }
        return ratio
    }

    mutating func setHeightRatios(_ heights: [DockGroup.ID: Double], in area: DockArea) {
        let groups = self[area]
        guard groups.count > 1 else {
            groupHeightRatios[area] = [:]
            return
        }

        var measuredHeights = [DockGroup.ID: Double]()
        measuredHeights.reserveCapacity(groups.count)
        for group in groups {
            guard let height = heights[group.id], height.isFinite, height > 0 else { continue }
            measuredHeights[group.id] = height
        }

        let total = measuredHeights.values.reduce(0, +)
        guard total > 0 else { return }

        var ratios = [DockGroup.ID: Double]()
        ratios.reserveCapacity(measuredHeights.count)
        for group in groups {
            guard let height = measuredHeights[group.id] else { continue }
            ratios[group.id] = height / total
        }
        groupHeightRatios[area] = ratios
        repairHeightRatios(in: area)
    }

    private func contains(_ tab: DockTab) -> Bool {
        DockArea.allCases.contains { area in
            self[area].contains { $0.tabs.contains(tab) }
        }
    }

    private func area(containing tab: DockTab) -> DockArea? {
        DockArea.allCases.first { area in
            self[area].contains { $0.tabs.contains(tab) }
        }
    }

    private struct TabLocation {
        let area: DockArea
        let groupID: DockGroup.ID
        let index: Int
    }

    private func location(of tab: DockTab) -> TabLocation? {
        for area in DockArea.allCases {
            for group in self[area] {
                if let index = group.tabs.firstIndex(of: tab) {
                    return TabLocation(area: area, groupID: group.id, index: index)
                }
            }
        }
        return nil
    }

    private mutating func remove(_ tab: DockTab) {
        for area in DockArea.allCases {
            var groups = self[area]
            for index in groups.indices.reversed() {
                groups[index].tabs.removeAll { $0 == tab }
                if groups[index].tabs.isEmpty {
                    groups.remove(at: index)
                } else if !groups[index].tabs.contains(groups[index].selected) {
                    groups[index].selected = groups[index].tabs[0]
                }
            }
            self[area] = groups
        }
    }

    private mutating func repairHeightRatios(in area: DockArea) {
        let groupIDs = Set(self[area].map(\.id))
        var ratios = groupHeightRatios[area].filter { groupIDs.contains($0.key) && $0.value.isFinite && $0.value > 0 }
        let total = ratios.values.reduce(0, +)
        guard total > 0 else {
            groupHeightRatios[area] = [:]
            return
        }
        for key in ratios.keys {
            ratios[key] = ratios[key].map { $0 / total }
        }
        groupHeightRatios[area] = ratios
    }

    private mutating func repair() {
        hiddenTabs.formIntersection(DockTab.allCases)
        collapsedAreas.formIntersection(DockArea.allCases)

        var seen = Set<DockTab>()
        for area in DockArea.allCases {
            var groups = self[area]
            for index in groups.indices.reversed() {
                groups[index].tabs.removeAll { tab in
                    if hiddenTabs.contains(tab) { return true }
                    if seen.contains(tab) { return true }
                    seen.insert(tab)
                    return false
                }
                if groups[index].tabs.isEmpty {
                    groups.remove(at: index)
                } else if !groups[index].tabs.contains(groups[index].selected) {
                    groups[index].selected = groups[index].tabs[0]
                }
            }
            self[area] = groups
            repairHeightRatios(in: area)
        }

        for tab in DockTab.allCases where !hiddenTabs.contains(tab) && !seen.contains(tab) {
            self[tab.defaultDockArea].append(DockGroup(tabs: [tab], selected: tab))
        }

        for area in DockArea.allCases {
            repairHeightRatios(in: area)
        }
    }
}
