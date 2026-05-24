// WindowSizing.swift
// Gives Focus and Full modes independent window frames (position AND size) plus
// per-mode min/max bounds. Each mode's frame is remembered (UserDefaults) and
// restored when you switch to it — so Focus can live top-left while Full sits
// bottom-right. Focus is capped narrow with a lower minimum so it stays slim;
// Full keeps the wide minimum and is freely resizable.

import SwiftUI
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    var isFocusMode: Bool

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var window: NSWindow?
        private var currentFocus: Bool?

        func attach(to window: NSWindow?, focus: Bool) {
            guard self.window == nil, let window else { return }
            self.window = window
            // Remember each mode's frame as the user resizes or moves the window. The
            // resize/move that `apply` itself triggers just re-saves the value we set
            // (for the already-current mode), so it's idempotent — no guarding needed.
            for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.saveCurrentFrame() }
                }
            }
            apply(focus: focus, window: window)
        }

        func apply(focus: Bool, window: NSWindow?) {
            guard let window = self.window ?? window else { return }
            self.window = window
            guard currentFocus != focus else { return }
            currentFocus = focus

            let (minSize, maxSize) = Self.bounds(focus: focus)
            window.contentMinSize = minSize
            window.contentMaxSize = maxSize

            // Restore this mode's saved frame; first time, keep the current position
            // and use the mode's default size.
            let savedFrame = savedFrame(focus: focus)
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
        }

        private func saveCurrentFrame() {
            guard let window, let focus = currentFocus else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.frameKey(focus))
        }

        private func savedFrame(focus: Bool) -> NSRect? {
            guard let string = UserDefaults.standard.string(forKey: Self.frameKey(focus)) else { return nil }
            let rect = NSRectFromString(string)
            return (rect.width > 0 && rect.height > 0) ? rect : nil
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
        private static func frameKey(_ focus: Bool) -> String { focus ? "win.focus.frame" : "win.full.frame" }
    }
}
