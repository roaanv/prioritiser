// TweaksView.swift
// The preferences controls, mirroring the prototype's Tweaks panel but pared to
// the decisions we landed on: appearance (System/Light/Dark), accent color, and
// priority visualization (cards/bars/heat). Backed by @AppStorage so it stays in
// sync wherever it's shown — a toolbar popover and the Settings (⌘,) window.

import SwiftUI

struct TweaksView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @AppStorage("accent") private var accent: AppAccent = .blue
    @AppStorage("priorityViz") private var viz: PriorityVizMode = .cards
    @Environment(CaptureController.self) private var capture

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("Accent") {
                    AccentSwatches(accent: $accent)
                }
            }

            Section("Priority visualization") {
                Picker("Top view", selection: $viz) {
                    ForEach(PriorityVizMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Quick Capture") {
                LabeledContent("Global shortcut") {
                    ShortcutRecorder(controller: capture)
                }
                Text("Press this shortcut from any app to capture a task.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(accent.color)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A row of accent-color swatches; the selected one is ringed and checked.
private struct AccentSwatches: View {
    @Binding var accent: AppAccent

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppAccent.allCases) { option in
                Button {
                    accent = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                        .overlay {
                            if accent == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            if accent == option {
                                Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 2).padding(-3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(option.label)
            }
        }
    }
}
