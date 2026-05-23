// VisualEffectView.swift
// Bridges NSVisualEffectView into SwiftUI so the sidebar and detail pane get the
// genuine macOS translucency/vibrancy the prototype faked with CSS backdrop blur.

import SwiftUI

/// A SwiftUI wrapper around `NSVisualEffectView` for native window materials.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
