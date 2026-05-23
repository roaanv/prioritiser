// OKLCH.swift
// The design prototype authors every color in the OKLCH color space
// (e.g. `oklch(0.68 0.13 250)`). Rather than eyeball hex equivalents, we store
// colors as OKLCH and convert to sRGB for SwiftUI. Conversion uses the standard
// OKLab → linear-sRGB matrix (Björn Ottosson) followed by sRGB gamma encoding.

import SwiftUI

/// A color in the OKLCH (cylindrical OKLab) space: lightness, chroma, hue°.
struct OKLCH: Hashable, Codable {
    /// Perceptual lightness, 0...1.
    var l: Double
    /// Chroma (colorfulness), typically 0...0.4.
    var c: Double
    /// Hue angle in degrees, 0...360.
    var h: Double

    init(_ l: Double, _ c: Double, _ h: Double) {
        self.l = l
        self.c = c
        self.h = h
    }
}

extension OKLCH {
    /// sRGB components in 0...1, gamma-encoded and clamped to gamut.
    var srgb: (r: Double, g: Double, b: Double) {
        // OKLCH → OKLab.
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        // OKLab → LMS (cube-rooted), then cube to linear LMS.
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let lLin = l_ * l_ * l_
        let mLin = m_ * m_ * m_
        let sLin = s_ * s_ * s_

        // Linear LMS → linear sRGB.
        let rLin = 4.0767416621 * lLin - 3.3077115913 * mLin + 0.2309699292 * sLin
        let gLin = -1.2684380046 * lLin + 2.6097574011 * mLin - 0.3413193965 * sLin
        let bLin = -0.0041960863 * lLin - 0.7034186147 * mLin + 1.7076147010 * sLin

        return (gammaEncode(rLin), gammaEncode(gLin), gammaEncode(bLin))
    }

    /// SwiftUI color for this OKLCH value.
    var color: Color {
        let (r, g, b) = srgb
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// sRGB gamma transfer function with gamut clamping.
    private func gammaEncode(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
}

extension Folder {
    /// The folder's color as a SwiftUI `Color` (its stored OKLCH, converted).
    var tint: Color { color.color }
}
