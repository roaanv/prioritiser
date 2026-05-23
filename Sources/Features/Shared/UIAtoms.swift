// UIAtoms.swift
// Small reusable view atoms shared across panes: keyboard-cap hints, metadata
// chips (folder / due / effort), and the 3-step impact pips. These mirror the
// prototype's .kbd, .t-chip and .t-pips treatments.

import SwiftUI

/// A small keyboard-cap label, e.g. ⌘ or N, matching the prototype's <kbd>.
struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 4)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

/// A metadata chip: optional leading dot or SF Symbol, then a label.
struct MetaChip: View {
    var systemImage: String?
    var dotColor: Color?
    var text: String
    var colors: ChipColors

    var body: some View {
        HStack(spacing: 4) {
            if let dotColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
            }
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
        }
        .font(.system(size: 11.5, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(colors.foreground)
        .padding(.leading, dotColor != nil ? 6 : 7)
        .padding(.trailing, 7)
        .padding(.vertical, 1.5)
        .background(colors.background, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(colors.border, lineWidth: 0.5))
    }
}

/// Three pips that fill according to a `Level` (impact), per the prototype's t-pips.
struct ImpactPips: View {
    let level: Level
    var activeColor: Color = .secondary

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i <= level.rawValue ? activeColor : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: 11)
            }
        }
        .accessibilityLabel("Impact \(level.label)")
    }
}
