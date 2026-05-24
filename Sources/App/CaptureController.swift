// CaptureController.swift
// Owns the global quick-capture hotkey and the floating capture panel, and holds the
// (persisted, configurable) shortcut. Created once at launch and shared — via the
// SwiftUI environment — with the menu bar and the Tweaks recorder.

import AppKit
import SwiftUI

@MainActor
@Observable
final class CaptureController {
    /// The configurable global hotkey; changing it re-registers and persists.
    var shortcut: CaptureShortcut {
        didSet {
            guard shortcut != oldValue else { return }
            shortcut.save()
            registerHotKey()
        }
    }

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let hotKey = GlobalHotKey()
    @ObservationIgnored private var panel: NSPanel?

    init(model: AppModel) {
        self.model = model
        self.shortcut = CaptureShortcut.load()
        hotKey.onPressed = { [weak self] in self?.toggleCapture() }
        registerHotKey()
    }

    private func registerHotKey() {
        hotKey.register(keyCode: UInt32(shortcut.keyCode), carbonModifiers: shortcut.carbonModifiers)
    }

    /// Hotkey behavior: show the panel, or dismiss it if already up.
    func toggleCapture() {
        if let panel, panel.isVisible { hideCapture() } else { showCapture() }
    }

    func showCapture() {
        let panel = panel ?? makePanel()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(x: visible.midX - size.width / 2,
                                 y: visible.midY - size.height / 2 + visible.height * 0.15)
            panel.setFrameOrigin(origin)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hideCapture() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let view = QuickCaptureView(model: model, onDismiss: { [weak self] in self?.hideCapture() })
            .environment(model)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize] // panel auto-sizes to the SwiftUI content

        let panel = KeyablePanel(contentViewController: hosting)
        panel.styleMask = [.borderless]
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true     // dismiss when the user switches to another app
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

/// A borderless panel that can still become key, so the capture field accepts typing.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
