// PrioritiserApp.swift
// App entry point. Boots the SQLite-backed store, constructs the observable
// AppModel, and hosts the three-pane window.

import SwiftUI

@main
struct PrioritiserApp: App {
    @State private var model: AppModel

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
        _model = State(initialValue: AppModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Add Task") { model.requestQuickAdd() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }

        // Settings (⌘,) mirrors the toolbar Tweaks popover.
        Settings {
            TweaksView()
                .padding(.vertical, 8)
        }
    }
}
