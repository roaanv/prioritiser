// PrioritiserApp.swift
// App entry point. Boots the SQLite-backed store, constructs the observable
// AppModel, and hosts the three-pane window.

import SwiftUI
import AppKit

@main
struct PrioritiserApp: App {
    @State private var model: AppModel
    @State private var capture: CaptureController
    @State private var dockLayout: DockLayout
    @State private var windowFrames: WindowFrameStore

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
        _dockLayout = State(initialValue: DockLayout.load())
        _windowFrames = State(initialValue: WindowFrameStore.load())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dockLayout: $dockLayout, windowFrames: windowFrames)
                .environment(model)
                .environment(capture)
                // Per-mode min/max + size are managed by WindowConfigurator (Focus is
                // capped narrow with a lower minimum; Full keeps the wide minimum).
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    saveApplicationState()
                }
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
            CommandGroup(replacing: .appTermination) {
                Button("Quit Prioritiser") {
                    saveApplicationState()
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button(model.isFocusMode ? "Exit Focus Mode" : "Enter Focus Mode") {
                    model.isFocusMode.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                ForEach(DockTab.allCases) { tab in
                    Toggle(tab.title, isOn: Binding(
                        get: { dockLayout.isVisible(tab) },
                        set: { isVisible in
                            dockLayout.setVisible(tab, isVisible)
                        }
                    ))
                }
            }
        }
        // Menu-bar item: always-available capture + the current shortcut.
        MenuBarExtra("Prioritiser", systemImage: "checklist") {
            Button("Quick Capture  (\(capture.shortcut.displayString))") { capture.showCapture() }
            Divider()
            Button("Open Prioritiser") { NSApp.activate(ignoringOtherApps: true) }
            Button("Quit Prioritiser") {
                saveApplicationState()
                NSApp.terminate(nil)
            }
        }

        // Settings (⌘,) mirrors the toolbar Tweaks popover.
        Settings {
            TweaksView()
                .environment(capture)
                .padding(.vertical, 8)
        }
    }

    private func saveApplicationState() {
        model.saveUIState()
        dockLayout.save()
        windowFrames.save()
    }
}
