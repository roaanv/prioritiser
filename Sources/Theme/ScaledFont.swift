// ScaledFont.swift
// Dynamic Type support for the design's fixed point sizes. SwiftUI's
// `.system(size:)` does not scale, so this wraps a `@ScaledMetric` size that
// tracks the environment's Dynamic Type setting relative to a text style.
// Apply with `.appFont(13.5, weight: .semibold)` instead of `.font(.system(...))`.

import SwiftUI

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// A system font of `size` (the design's point size) that scales with Dynamic Type.
    func appFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: textStyle, design: design))
    }
}
