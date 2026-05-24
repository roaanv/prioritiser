// CaptureShortcut.swift
// A user-configurable key combination for the global quick-capture hotkey: a
// virtual key code plus modifier flags, with a symbolic display label and Codable
// UserDefaults persistence. Pure value type; the Carbon registration lives in
// GlobalHotKey and the recording UI in ShortcutRecorder.

import AppKit
import Carbon.HIToolbox

struct CaptureShortcut: Codable, Equatable {
    /// Virtual key code (kVK_*), used to register the Carbon hotkey.
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value (device-independent subset).
    var modifierFlagsRaw: UInt
    /// Human label for the main key, e.g. "T" or "Space".
    var keyLabel: String

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw).intersection(.deviceIndependentFlagsMask)
    }

    /// Carbon modifier mask for `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { flags |= UInt32(shiftKey) }
        return flags
    }

    /// Symbolic display, e.g. "⌃⌥⌘T".
    var displayString: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option)  { symbols += "⌥" }
        if modifiers.contains(.shift)   { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols + keyLabel
    }

    /// At least one modifier plus a key — a sane (un-hijacking) global shortcut.
    var isValid: Bool { !modifiers.isEmpty && !keyLabel.isEmpty }

    /// ⌃⌥⌘T — unlikely to collide with common app or system shortcuts.
    static let `default` = CaptureShortcut(
        keyCode: UInt16(kVK_ANSI_T),
        modifierFlagsRaw: NSEvent.ModifierFlags([.control, .option, .command]).rawValue,
        keyLabel: "T"
    )

    // MARK: - Persistence

    private static let defaultsKey = "captureShortcut"

    static func load(from defaults: UserDefaults = .standard) -> CaptureShortcut {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(CaptureShortcut.self, from: data)
        else { return .default }
        return decoded
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    // MARK: - Recording

    /// Build a shortcut from a recorded key-down event; nil if it has no modifier
    /// (a global hotkey without one would hijack a normal key everywhere).
    static func from(event: NSEvent) -> CaptureShortcut? {
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return nil }
        return CaptureShortcut(keyCode: event.keyCode,
                               modifierFlagsRaw: mods.rawValue,
                               keyLabel: label(for: event))
    }

    private static func label(for event: NSEvent) -> String {
        if let special = specialKeys[Int(event.keyCode)] { return special }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty, chars != " " {
            return chars.uppercased()
        }
        return "Key\(event.keyCode)"
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]
}
