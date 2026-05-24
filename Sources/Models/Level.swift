// Level.swift
// The shared 3-step scale used for both Impact and Priority.
// Ported from the prototype's LEVEL map: h=3, m=2, l=1.

import Foundation

/// A low / medium / high rating, stored as 1...3 to match the design's scoring math.
enum Level: Int, CaseIterable, Codable, Identifiable, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    /// Human label shown in the UI ("Low" / "Medium" / "High").
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Parse the single-letter token used by the quick-add grammar (`i:h`, `p:l`).
    init?(token: String) {
        switch token.lowercased() {
        case "h": self = .high
        case "m": self = .medium
        case "l": self = .low
        default: return nil
        }
    }

    /// The single-letter quick-add token ("h" / "m" / "l").
    var token: String {
        switch self {
        case .low: return "l"
        case .medium: return "m"
        case .high: return "h"
        }
    }

    /// High → Low: the order shown in the quick-add value picker.
    static let pickerOrder: [Level] = [.high, .medium, .low]

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
}
