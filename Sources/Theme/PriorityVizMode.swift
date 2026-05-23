// PriorityVizMode.swift
// How priority is visualized in the task list, ported from the prototype's
// "Priority visualization" tweak: ranked cards, score bars, or heat tint.

import Foundation

enum PriorityVizMode: String, CaseIterable, Identifiable {
    /// Top-5 as ranked, elevated cards with a "NOW" badge (the default).
    case cards
    /// A thin score bar along the bottom of each row.
    case bars
    /// Each row tinted by score intensity.
    case heat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cards: return "Ranked cards"
        case .bars: return "Score bars"
        case .heat: return "Heat tint"
        }
    }
}
