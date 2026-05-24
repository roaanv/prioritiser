// ContentView.swift
// The three-pane shell: Sidebar · Task list · Detail. Uses a 3-column
// NavigationSplitView (the native Mail-style layout) so the sidebar gets real
// translucency and the columns resize like a standard macOS app. Appearance,
// accent, and priority-viz are user preferences (@AppStorage); a toolbar popover
// exposes them (the Settings window mirrors the same controls).

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("accent") private var accent: AppAccent = .blue
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showTweaks = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } content: {
            TaskListView()
                .navigationSplitViewColumnWidth(min: 420, ideal: 560)
        } detail: {
            VStack(spacing: 0) {
                DetailView()
                ProjectMatrixView() // pinned below; shows for folder selections only
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 440)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(accent.color)
        .preferredColorScheme(appearance.colorScheme)
        // Support Dynamic Type, clamped so the dense 3-pane layout stays usable.
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .toolbar {
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
