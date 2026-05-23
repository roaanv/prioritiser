// AppAccent.swift
// The user-selectable accent color. Values match the prototype's ACCENT_MAP.
// Persisted via @AppStorage as the raw string.

import SwiftUI

/// Accent options offered in the prototype's Tweaks → Accent.
enum AppAccent: String, CaseIterable, Identifiable {
    case blue, orange, purple, green

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue:   return Color(.sRGB, red: 0x00 / 255, green: 0x7A / 255, blue: 0xFF / 255)
        case .orange: return Color(.sRGB, red: 0xE2 / 255, green: 0x58 / 255, blue: 0x22 / 255)
        case .purple: return Color(.sRGB, red: 0x7A / 255, green: 0x5A / 255, blue: 0xE0 / 255)
        case .green:  return Color(.sRGB, red: 0x1F / 255, green: 0x8A / 255, blue: 0x5B / 255)
        }
    }
}
