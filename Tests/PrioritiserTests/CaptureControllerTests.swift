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

    // The end-to-end behaviour — a window that was hidden before quick-capture
    // is re-hidden on restore — reduces to this decision. We assert the decision
    // directly rather than driving a live NSWindow, which requires a window
    // server and hangs/crashes on headless CI runners.
    @Test func restorationActionReHidesPreviouslyHiddenWindow() {
        let state = WindowVisibilityState(wasVisible: false, wasMiniaturized: false)

        #expect(state.restoration(currentVisible: true, currentMiniaturized: false) == .orderOut)
        #expect(state.restoration(currentVisible: false, currentMiniaturized: false) == .none)
    }
}
