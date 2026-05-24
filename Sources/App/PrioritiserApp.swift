// PrioritiserApp.swift
// App entry point. Boots the SQLite-backed store, constructs the observable
// AppModel, and hosts the three-pane window.

import SwiftUI
import AppKit

@main
struct PrioritiserApp: App {
    @State private var model: AppModel
    @State private var capture: CaptureController

    init() {
        // Open (and migrate/seed) the on-disk store. If it can't be opened we
        // fall back to a temporary file so the app still launches.
        let store: TaskStore
        do {
            store = try TaskStore(url: try TaskStore.defaultURL())
        } catch {
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("prioritiser-fallback.sqlite")
            store = (try? TaskStore(url: fallback))!
        }
        let model = AppModel(store: store)
        _model = State(initialValue: model)
        // Registers the global capture hotkey and owns the floating capture panel.
        _capture = State(initialValue: CaptureController(model: model))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(capture)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Add Task") { model.requestQuickAdd() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Find") { model.focusSearchToken += 1 }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }

        // Menu-bar item: always-available capture + the current shortcut.
        MenuBarExtra("Prioritiser", systemImage: "checklist") {
            Button("Quick Capture  (\(capture.shortcut.displayString))") { capture.showCapture() }
            Divider()
            Button("Open Prioritiser") { NSApp.activate(ignoringOtherApps: true) }
            Button("Quit Prioritiser") { NSApp.terminate(nil) }
        }

        // Settings (⌘,) mirrors the toolbar Tweaks popover.
        Settings {
            TweaksView()
                .environment(capture)
                .padding(.vertical, 8)
        }
    }
}
