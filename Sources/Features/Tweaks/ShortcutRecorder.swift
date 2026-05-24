// ShortcutRecorder.swift
// A small control for viewing and re-binding the global capture shortcut. Click to
// record, then press a combo (must include a modifier; Esc cancels). The captured
// shortcut is written straight to the shared CaptureController, which persists and
// re-registers it.

import SwiftUI
import Carbon.HIToolbox

struct ShortcutRecorder: View {
    @Bindable var controller: CaptureController
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                Text(recording ? "Press keys…" : controller.shortcut.displayString)
                    .font(.system(size: 12, weight: .medium))
                    .monospaced()
                    .frame(minWidth: 84)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(recording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Click, then press a key combination")

            if controller.shortcut != .default {
                Button("Reset") { controller.shortcut = .default }
                    .controlSize(.small)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            if let shortcut = CaptureShortcut.from(event: event) {
                controller.shortcut = shortcut
                stopRecording()
            }
            return nil // swallow keystrokes while recording
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
