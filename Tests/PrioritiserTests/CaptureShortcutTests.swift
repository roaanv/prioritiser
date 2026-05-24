// CaptureShortcutTests.swift
// Pure-logic coverage for the global capture shortcut: glyph display, Carbon
// modifier mapping, validity, and Codable persistence. (The Carbon registration
// and floating panel are exercised manually, not here.)

import Testing
import AppKit
import Carbon.HIToolbox
@testable import Prioritiser

@Suite("CaptureShortcut")
struct CaptureShortcutTests {
    @Test func defaultDisplaysModifierGlyphs() {
        #expect(CaptureShortcut.default.displayString == "⌃⌥⌘T")
    }

    @Test func carbonModifiersMapHeldKeys() {
        let carbon = CaptureShortcut.default.carbonModifiers
        #expect(carbon & UInt32(cmdKey) != 0)
        #expect(carbon & UInt32(optionKey) != 0)
        #expect(carbon & UInt32(controlKey) != 0)
        #expect(carbon & UInt32(shiftKey) == 0) // default has no shift
    }

    @Test func validityRequiresAModifier() {
        #expect(CaptureShortcut.default.isValid)
        let noModifier = CaptureShortcut(keyCode: 17, modifierFlagsRaw: 0, keyLabel: "T")
        #expect(noModifier.isValid == false)
    }

    @Test func persistsAndReloads() {
        let defaults = UserDefaults(suiteName: "shortcut-tests-\(UUID().uuidString)")!
        let shortcut = CaptureShortcut(
            keyCode: UInt16(kVK_Space),
            modifierFlagsRaw: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            keyLabel: "Space"
        )
        shortcut.save(to: defaults)
        #expect(CaptureShortcut.load(from: defaults) == shortcut)
        #expect(CaptureShortcut.load(from: defaults).displayString == "⇧⌘Space")
    }

    @Test func loadFallsBackToDefaultWhenUnset() {
        let empty = UserDefaults(suiteName: "shortcut-empty-\(UUID().uuidString)")!
        #expect(CaptureShortcut.load(from: empty) == .default)
    }
}
