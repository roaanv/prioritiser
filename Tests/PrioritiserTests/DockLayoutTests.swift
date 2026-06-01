// DockLayoutTests.swift
// Dockable tab layout invariants.

import Foundation
import Testing
@testable import Prioritiser

@Suite("Dock layout")
struct DockLayoutTests {
    @Test func movingTabOntoExistingGroupCreatesTabGroup() {
        var layout = DockLayout.default
        let target = layout.left[0].id

        layout.move(.notes, to: .left, groupID: target)

        #expect(layout.left[0].tabs == [.views, .notes])
        #expect(layout.left[0].selected == .notes)
        #expect(!layout.right.flatMap(\.tabs).contains(.notes))
    }

    @Test func movingTabToAreaCreatesSeparateGroupAtEnd() {
        var layout = DockLayout.default

        layout.move(.activity, to: .left, groupID: nil)

        #expect(layout.left.last?.tabs == [.activity])
        #expect(layout.left.last?.selected == .activity)
        #expect(!layout.right.flatMap(\.tabs).contains(.activity))
    }

    @Test func movingTabWithinGroupCanInsertBetweenExistingTabs() {
        let group = DockGroup(tabs: [.views, .folders, .notes])
        var layout = DockLayout(left: [group], right: [], bottom: [], hiddenTabs: [.activity, .priorityMatrix, .priorityScore, .itemDetails])

        layout.move(.views, to: .left, groupID: group.id, insertionIndex: 2)

        #expect(layout.left[0].tabs == [.folders, .views, .notes])
        #expect(layout.left[0].selected == .views)
    }

    @Test func movingTabFromLaterPositionCanInsertBeforeEarlierTab() {
        let group = DockGroup(tabs: [.views, .folders, .notes])
        var layout = DockLayout(left: [group], right: [], bottom: [], hiddenTabs: [.activity, .priorityMatrix, .priorityScore, .itemDetails])

        layout.move(.notes, to: .left, groupID: group.id, insertionIndex: 1)

        #expect(layout.left[0].tabs == [.views, .notes, .folders])
        #expect(layout.left[0].selected == .notes)
    }

    @Test func movingTabFromOtherGroupCanInsertAtIndex() {
        let left = DockGroup(tabs: [.views, .folders])
        let right = DockGroup(tabs: [.notes])
        var layout = DockLayout(left: [left], right: [right], bottom: [], hiddenTabs: [.activity, .priorityMatrix, .priorityScore, .itemDetails])

        layout.move(.notes, to: .left, groupID: left.id, insertionIndex: 1)

        #expect(layout.left[0].tabs == [.views, .notes, .folders])
        #expect(layout.left[0].selected == .notes)
        #expect(layout.right.isEmpty)
    }

    @Test func decodingRepairsMissingTabs() throws {
        let data = try JSONEncoder().encode(DockLayout(left: [], right: [], bottom: []))
        let defaults = UserDefaults(suiteName: "DockLayoutTests-\(UUID().uuidString)")!
        defaults.set(data, forKey: DockLayout.storageKey)

        let layout = DockLayout.load(from: defaults)
        let tabs = Set((layout.left + layout.right + layout.bottom).flatMap(\.tabs))

        #expect(tabs == Set(DockTab.allCases))
    }

    @Test func hiddenTabsAreRemovedAndNotRepairedBackIntoLayout() throws {
        var layout = DockLayout.default

        layout.setVisible(.notes, false)

        let visibleTabs = Set((layout.left + layout.right + layout.bottom).flatMap(\.tabs))
        #expect(!layout.isVisible(.notes))
        #expect(!visibleTabs.contains(.notes))

        let data = try JSONEncoder().encode(layout)
        var decoded = try JSONDecoder().decode(DockLayout.self, from: data)
        decoded.move(.activity, to: .left, groupID: nil)

        let repairedTabs = Set((decoded.left + decoded.right + decoded.bottom).flatMap(\.tabs))
        #expect(!decoded.isVisible(.notes))
        #expect(!repairedTabs.contains(.notes))
    }

    @Test func showingHiddenTabRestoresItToDefaultDockArea() {
        var layout = DockLayout.default

        layout.setVisible(.priorityMatrix, false)
        layout.setVisible(.priorityMatrix, true)

        #expect(layout.isVisible(.priorityMatrix))
        #expect(layout.bottom.last?.tabs == [.priorityMatrix])
    }

    @Test func decodingWithHiddenTabsRemovesThemFromSavedGroups() throws {
        let layout = DockLayout(left: [DockGroup(tabs: [.views, .folders])],
                                right: [DockGroup(tabs: [.notes])],
                                bottom: [],
                                hiddenTabs: [.folders])
        let defaults = UserDefaults(suiteName: "DockLayoutTests-\(UUID().uuidString)")!
        defaults.set(try JSONEncoder().encode(layout), forKey: DockLayout.storageKey)

        let loaded = DockLayout.load(from: defaults)
        let tabs = Set((loaded.left + loaded.right + loaded.bottom).flatMap(\.tabs))

        #expect(!loaded.isVisible(.folders))
        #expect(!tabs.contains(.folders))
        #expect(tabs.contains(.views))
        #expect(tabs.contains(.notes))
    }

    @Test func collapsedAreasKeepTheirTabsAndPersist() throws {
        var layout = DockLayout.default

        layout.setExpanded(.left, false)

        #expect(!layout.isExpanded(.left))
        #expect(layout.left.flatMap(\.tabs).contains(.views))

        let decoded = try JSONDecoder().decode(DockLayout.self, from: try JSONEncoder().encode(layout))
        #expect(!decoded.isExpanded(.left))
        #expect(decoded.left.flatMap(\.tabs).contains(.views))
    }

    @Test func showingHiddenTabExpandsItsArea() {
        var layout = DockLayout.default

        layout.setVisible(.priorityMatrix, false)
        layout.setExpanded(.bottom, false)
        layout.setVisible(.priorityMatrix, true)

        #expect(layout.isVisible(.priorityMatrix))
        #expect(layout.isExpanded(.bottom))
        #expect(layout.bottom.last?.tabs == [.priorityMatrix])
    }

    @Test func movingTabToCollapsedAreaExpandsThatArea() {
        var layout = DockLayout.default

        layout.setExpanded(.left, false)
        layout.move(.notes, to: .left, groupID: nil)

        #expect(layout.isExpanded(.left))
        #expect(layout.left.last?.tabs == [.notes])
    }

    @Test func groupHeightRatiosAreStoredRelativeToMeasuredAreaHeight() {
        let top = DockGroup(tabs: [.views])
        let bottom = DockGroup(tabs: [.folders])
        var layout = DockLayout(left: [top, bottom],
                                right: [],
                                bottom: [],
                                hiddenTabs: [.activity, .priorityMatrix, .notes, .priorityScore, .itemDetails])

        layout.setHeightRatios([top.id: 240, bottom.id: 160], in: .left)

        #expect(abs((layout.heightRatio(for: top.id, in: .left) ?? 0) - 0.6) < 0.000_001)
        #expect(abs((layout.heightRatio(for: bottom.id, in: .left) ?? 0) - 0.4) < 0.000_001)
    }

    @Test func groupHeightRatiosPersistAcrossEncoding() throws {
        let top = DockGroup(tabs: [.views])
        let bottom = DockGroup(tabs: [.folders])
        var layout = DockLayout(left: [top, bottom],
                                right: [],
                                bottom: [],
                                hiddenTabs: [.activity, .priorityMatrix, .notes, .priorityScore, .itemDetails])
        layout.setHeightRatios([top.id: 75, bottom.id: 25], in: .left)

        let decoded = try JSONDecoder().decode(DockLayout.self, from: try JSONEncoder().encode(layout))

        #expect(abs((decoded.heightRatio(for: top.id, in: .left) ?? 0) - 0.75) < 0.000_001)
        #expect(abs((decoded.heightRatio(for: bottom.id, in: .left) ?? 0) - 0.25) < 0.000_001)
    }

    @Test func staleGroupHeightRatiosAreRemovedDuringRepair() throws {
        let group = DockGroup(tabs: [.views])
        let staleID = UUID()
        let layout = DockLayout(left: [group],
                                right: [],
                                bottom: [],
                                hiddenTabs: [.activity, .priorityMatrix, .notes, .folders, .priorityScore, .itemDetails],
                                groupHeightRatios: DockGroupHeightRatios(left: [group.id: 0.25, staleID: 0.75]))
        let defaults = UserDefaults(suiteName: "DockLayoutTests-\(UUID().uuidString)")!
        defaults.set(try JSONEncoder().encode(layout), forKey: DockLayout.storageKey)

        let loaded = DockLayout.load(from: defaults)

        #expect(loaded.heightRatio(for: group.id, in: .left) == 1.0)
        #expect(loaded.heightRatio(for: staleID, in: .left) == nil)
    }

    @Test func bottomDockHeightRatioPersistsAcrossEncoding() throws {
        var layout = DockLayout.default
        layout.setBottomDockHeightRatio(0.32)

        let decoded = try JSONDecoder().decode(DockLayout.self, from: try JSONEncoder().encode(layout))

        #expect(decoded.bottomDockHeightRatio == 0.32)
    }

    @Test func invalidBottomDockHeightRatioIsDiscarded() {
        var layout = DockLayout.default

        layout.setBottomDockHeightRatio(1.2)

        #expect(layout.bottomDockHeightRatio == nil)
    }

    @Test func sideDockWidthRatiosPersistAcrossEncoding() throws {
        var layout = DockLayout.default
        layout.setDockWidthRatio(0.22, for: .left)
        layout.setDockWidthRatio(0.31, for: .right)

        let decoded = try JSONDecoder().decode(DockLayout.self, from: try JSONEncoder().encode(layout))

        #expect(decoded.dockWidthRatio(for: .left) == 0.22)
        #expect(decoded.dockWidthRatio(for: .right) == 0.31)
        #expect(decoded.dockWidthRatio(for: .bottom) == nil)
    }

    @Test func invalidSideDockWidthRatiosAreDiscarded() {
        var layout = DockLayout.default

        layout.setDockWidthRatio(-0.1, for: .left)
        layout.setDockWidthRatio(1.0, for: .right)

        #expect(layout.dockWidthRatio(for: .left) == nil)
        #expect(layout.dockWidthRatio(for: .right) == nil)
    }
}
