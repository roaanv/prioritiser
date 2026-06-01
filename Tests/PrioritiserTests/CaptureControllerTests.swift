// CaptureControllerTests.swift
// Coverage for quick-capture's window-visibility restoration.

import AppKit
import Testing
@testable import Prioritiser

@MainActor
@Suite("CaptureController")
struct CaptureControllerTests {
    @Test func restorationActionPreservesPriorMiniaturizedState() {
        let state = WindowVisibilityState(wasVisible: true, wasMiniaturized: true)

        #expect(state.restoration(currentVisible: true, currentMiniaturized: false) == .miniaturize)
        #expect(state.restoration(currentVisible: true, currentMiniaturized: true) == .none)
    }

    @Test func restorationActionPreservesPriorVisibleState() {
        let state = WindowVisibilityState(wasVisible: true, wasMiniaturized: false)

        #expect(state.restoration(currentVisible: true, currentMiniaturized: true) == .deminiaturize)
        #expect(state.restoration(currentVisible: true, currentMiniaturized: false) == .none)
    }

    @Test func restoringSnapshotHidesPreviouslyHiddenWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Prioritiser hidden visibility test \(UUID().uuidString)"
        window.orderOut(nil)
        #expect(!window.isVisible)

        let snapshot = AppVisibilitySnapshot.capture(excluding: nil)
        window.orderFrontRegardless()
        #expect(window.isVisible)

        snapshot.restore()
        #expect(!window.isVisible)

        window.close()
    }
}
