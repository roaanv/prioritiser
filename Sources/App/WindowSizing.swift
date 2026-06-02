// WindowSizing.swift
// Gives Focus and Full modes independent window frames (position AND size) plus
// per-mode min/max bounds. Frames are restored on launch and tracked in memory
// while the app runs, but written to UserDefaults only during app termination.

import SwiftUI
import AppKit

@MainActor
final class WindowFrameStore {
    private var focusFrame: NSRect?
    private var fullFrame: NSRect?

    init(focusFrame: NSRect? = nil, fullFrame: NSRect? = nil) {
        self.focusFrame = Self.validFrame(focusFrame)
        self.fullFrame = Self.validFrame(fullFrame)
    }

    static func load(from defaults: UserDefaults = .standard) -> WindowFrameStore {
        WindowFrameStore(
            focusFrame: rect(forKey: focusFrameKey, defaults: defaults),
            fullFrame: rect(forKey: fullFrameKey, defaults: defaults)
        )
    }

    func frame(focus: Bool) -> NSRect? {
        focus ? focusFrame : fullFrame
    }

    func setFrame(_ frame: NSRect, focus: Bool) {
        guard let frame = Self.validFrame(frame) else { return }
        if focus {
            focusFrame = frame
        } else {
            fullFrame = frame
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        set(focusFrame, forKey: Self.focusFrameKey, defaults: defaults)
        set(fullFrame, forKey: Self.fullFrameKey, defaults: defaults)
    }

    private func set(_ frame: NSRect?, forKey key: String, defaults: UserDefaults) {
        if let frame {
            defaults.set(NSStringFromRect(frame), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func rect(forKey key: String, defaults: UserDefaults) -> NSRect? {
        guard let string = defaults.string(forKey: key) else { return nil }
        return validFrame(NSRectFromString(string))
    }

    private static func validFrame(_ frame: NSRect?) -> NSRect? {
        guard let frame, frame.width > 0, frame.height > 0 else { return nil }
        return frame
    }

    private static let focusFrameKey = "win.focus.frame"
    private static let fullFrameKey = "win.full.frame"
}

struct WindowConfigurator: NSViewRepresentable {
    var isFocusMode: Bool
    let frameStore: WindowFrameStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let focus = isFocusMode
        DispatchQueue.main.async { context.coordinator.attach(to: view.window, focus: focus) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let focus = isFocusMode
        DispatchQueue.main.async { context.coordinator.apply(focus: focus, window: nsView.window) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(frameStore: frameStore) }

    @MainActor
    final class Coordinator {
        private var window: NSWindow?
        private var currentFocus: Bool?
        private let frameStore: WindowFrameStore

        init(frameStore: WindowFrameStore) {
            self.frameStore = frameStore
        }
        func attach(to window: NSWindow?, focus: Bool) {
            guard self.window == nil, let window else { return }
            self.window = window
            AppWindowRegistry.shared.remember(window)
            // Track each mode's frame in memory as the user resizes or moves the
            // window. UserDefaults is written only from the app termination hook.
            for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.captureCurrentFrame() }
                }
            }
            apply(focus: focus, window: window)
        }

        func apply(focus: Bool, window: NSWindow?) {
            guard let window = self.window ?? window else { return }
            AppWindowRegistry.shared.remember(window)
            self.window = window
            if let currentFocus, currentFocus != focus {
                captureCurrentFrame()
            }
            guard currentFocus != focus else {
                captureCurrentFrame()
                return
            }
            currentFocus = focus
            let (minSize, maxSize) = Self.bounds(focus: focus)
            window.contentMinSize = minSize
            window.contentMaxSize = maxSize

            // Restore this mode's saved frame; first time, keep the current position
            // and use the mode's default size.
            let savedFrame = frameStore.frame(focus: focus)
            let contentSize = savedFrame.map { window.contentRect(forFrameRect: $0).size }
                ?? Self.defaultSize(focus: focus)
            let topLeft = savedFrame.map { NSPoint(x: $0.minX, y: $0.maxY) }
                ?? NSPoint(x: window.frame.minX, y: window.frame.maxY)

            let size = NSSize(
                width: min(max(contentSize.width, minSize.width), maxSize.width),
                height: min(max(contentSize.height, minSize.height), maxSize.height)
            )
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            frame.origin.x = topLeft.x
            frame.origin.y = topLeft.y - frame.height // anchor the top-left corner
            window.setFrame(Self.onScreen(frame), display: true, animate: false)
            captureCurrentFrame()
        }

        private func captureCurrentFrame() {
            guard let window, let focus = currentFocus else { return }
            frameStore.setFrame(window.frame, focus: focus)
        }

        /// Keep the frame on a visible screen; if it's entirely off-screen (display
        /// changed), re-center on the main screen so the window can't get lost.
        private static func onScreen(_ frame: NSRect) -> NSRect {
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return frame }
            guard let visible = NSScreen.main?.visibleFrame else { return frame }
            var centered = frame
            centered.origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
            return centered
        }

        private static func bounds(focus: Bool) -> (min: NSSize, max: NSSize) {
            focus
                ? (NSSize(width: 360, height: 420),  NSSize(width: 680, height: 100_000))
                : (NSSize(width: 900, height: 560),  NSSize(width: 100_000, height: 100_000))
        }
        private static func defaultSize(focus: Bool) -> NSSize {
            focus ? NSSize(width: 500, height: 700) : NSSize(width: 1040, height: 680)
        }
    }
}
