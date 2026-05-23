// AppAppearance.swift
// The user's appearance preference. Maps the prototype's light (Vibrant) / dark
// (Midnight) aesthetics onto native macOS appearance, plus a "follow system"
// default. Persisted via @AppStorage.

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The `preferredColorScheme` value; nil means follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
