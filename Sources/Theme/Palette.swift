// Palette.swift
// Color tokens for the colored chips (due / effort) and their overdue/today
// variants, ported from the prototype's OKLCH chip palette. Light and dark
// values track the system appearance (Vibrant ≈ light, Midnight ≈ dark). Neutral
// surfaces lean on system colors so they adapt automatically.

import SwiftUI

/// Background / foreground / border for a chip.
struct ChipColors {
    var background: Color
    var foreground: Color
    var border: Color
}

enum Palette {
    /// Neutral chip (used as the folder chip base) — adapts to appearance.
    static func neutralChip() -> ChipColors {
        ChipColors(
            background: Color.primary.opacity(0.05),
            foreground: Color.primary.opacity(0.72),
            border: Color.primary.opacity(0.08)
        )
    }

    /// Due-date chip, with overdue and due-today variants.
    static func due(overdue: Bool, today: Bool, scheme: ColorScheme) -> ChipColors {
        if overdue { return chip(hue: 28, scheme: scheme, accentForeground: true) }
        if today { return chip(hue: 252, scheme: scheme, accentForeground: true) }
        return chip(hue: 60, scheme: scheme)
    }

    /// Effort chip (cool blue, matching the prototype's hue ~200/220).
    static func effort(scheme: ColorScheme) -> ChipColors {
        chip(hue: 200, scheme: scheme)
    }

    /// Impact chip (magenta, prototype hue 340).
    static func impact(scheme: ColorScheme) -> ChipColors {
        chip(hue: 340, scheme: scheme)
    }

    /// Priority chip (warm red, prototype hue 30).
    static func priority(scheme: ColorScheme) -> ChipColors {
        chip(hue: 30, scheme: scheme)
    }

    /// Folder chip in the quick-add preview — accent-tinted (prototype chip-folder).
    static func folder(scheme: ColorScheme) -> ChipColors {
        ChipColors(
            background: Color.accentColor.opacity(scheme == .dark ? 0.25 : 0.14),
            foreground: Color.accentColor,
            border: Color.accentColor.opacity(0.25)
        )
    }

    /// Build a chip palette at a given hue. `accentForeground` darkens/lightens
    /// the text more (used for the alerting overdue/today states).
    private static func chip(hue: Double, scheme: ColorScheme, accentForeground: Bool = false) -> ChipColors {
        switch scheme {
        case .dark:
            return ChipColors(
                background: OKLCH(0.30, 0.06, hue).color,
                foreground: OKLCH(accentForeground ? 0.78 : 0.85, accentForeground ? 0.13 : 0.08, hue).color,
                border: OKLCH(0.40, 0.08, hue).color
            )
        default:
            return ChipColors(
                background: OKLCH(0.95, 0.04, hue).color,
                foreground: OKLCH(accentForeground ? 0.52 : 0.42, accentForeground ? 0.16 : 0.10, hue).color,
                border: OKLCH(0.88, 0.06, hue).color
            )
        }
    }

    /// Heatmap tint for a 0...1 intensity: cool blue (low) → warm red (high),
    /// built in OKLCH so the ramp stays an even, light tint. Callers pass a positive
    /// fraction; a zero-count cell should use no tint (clear) rather than the cold end.
    static func heat(_ fraction: Double, scheme: ColorScheme) -> Color {
        let t = min(max(fraction, 0), 1)
        let hue = 250 - t * 225 // 250° (blue) → 25° (red), via the thermal path
        switch scheme {
        case .dark: return OKLCH(0.34, 0.08, hue).color
        default: return OKLCH(0.93, 0.06, hue).color
        }
    }

    /// Foreground color for an overdue due-date label in the detail pane.
    static func overdueText(scheme: ColorScheme) -> Color {
        scheme == .dark ? OKLCH(0.75, 0.15, 28).color : OKLCH(0.55, 0.18, 28).color
    }
}
