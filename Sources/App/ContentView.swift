// ContentView.swift
// The main shell: focus mode or a dockable workspace. The full workspace keeps the
// task list central and lets supporting panes dock left, right, or bottom.
// accent, and priority-viz are user preferences (@AppStorage); a toolbar popover
// exposes them (the Settings window mirrors the same controls).

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("accent") private var accent: AppAccent = .blue
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Binding var dockLayout: DockLayout
    let windowFrames: WindowFrameStore
    @State private var showTweaks = false

    var body: some View {
        Group {
            if model.isFocusMode {
                FocusModeView()
            } else {
                fullView
            }
        }
        .tint(accent.color)
        .preferredColorScheme(appearance.colorScheme)
        .background(WindowConfigurator(isFocusMode: model.isFocusMode, frameStore: windowFrames))
    }

    private var fullView: some View {
        DockWorkspaceView(layout: $dockLayout)
        // Support Dynamic Type, clamped so the dense 3-pane layout stays usable.
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.isFocusMode = true } label: {
                    Image(systemName: "moon")
                }
                .help("Focus mode — Today only (⌘⇧F)")
                .accessibilityLabel("Focus mode")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTweaks.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Tweaks")
                .accessibilityLabel("Tweaks")
                .popover(isPresented: $showTweaks, arrowEdge: .bottom) {
                    TweaksView()
                }
            }
        }
        .overlay {
            if model.quickAddRequested {
                QuickAddSpotlight(
                    onClose: { model.quickAddRequested = false },
                    onCreate: { model.createTask(from: $0) }
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: model.quickAddRequested)
    }
}
