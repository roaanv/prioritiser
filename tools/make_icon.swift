// make_icon.swift
// Renders the Prioritiser app icon (1024×1024) with CoreGraphics: a blue-gradient
// macOS squircle with three descending rounded bars (a ranked-priorities motif).
// Run: swift tools/make_icon.swift <output.png>   (see Makefile `icon` target).

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let canvas = 1024.0

// macOS icon grid: rounded tile inset ~100px in a 1024 canvas, corner ≈ 22.37%.
let inset = 100.0
let tile = canvas - inset * 2          // 824
let corner = tile * 0.2237             // ≈ 184

func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("Could not create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Rounded-rect tile path.
let tileRect = CGRect(x: inset, y: inset, width: tile, height: tile)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

// Soft drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: srgb(0, 0.15, 0.4, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(srgb(0, 0.45, 1))
ctx.fillPath()
ctx.restoreGState()

// Clip to the tile and paint a top-to-bottom blue gradient.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [srgb(0.28, 0.62, 1.0), srgb(0.0, 0.42, 0.96), srgb(0.0, 0.30, 0.84)] as CFArray,
    locations: [0, 0.55, 1]
)!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: inset, y: canvas - inset),
                       end: CGPoint(x: canvas - inset, y: inset),
                       options: [])

// Subtle highlight sheen across the top.
let sheen = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [srgb(1, 1, 1, 0.22), srgb(1, 1, 1, 0)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(sheen,
                       start: CGPoint(x: inset, y: canvas - inset),
                       end: CGPoint(x: inset, y: canvas - inset - tile * 0.55),
                       options: [])
ctx.restoreGState()

// Three descending rounded bars (ranked priorities). CG origin is bottom-left, so
// the visually-top bar has the largest y.
let barX = inset + 168.0
let barH = 96.0
let gap = 78.0
let barCorner = 46.0
let widths = [432.0, 330.0, 228.0]
let alphas = [1.0, 0.92, 0.80]

let groupHeight = barH * 3 + gap * 2
var topY = inset + (tile - groupHeight) / 2 + groupHeight - barH  // top bar's y origin

for (index, width) in widths.enumerated() {
    let rect = CGRect(x: barX, y: topY, width: width, height: barH)
    let path = CGPath(roundedRect: rect, cornerWidth: barCorner, cornerHeight: barCorner, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(srgb(1, 1, 1, alphas[index]))
    ctx.fillPath()
    topY -= (barH + gap)
}

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try! data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
