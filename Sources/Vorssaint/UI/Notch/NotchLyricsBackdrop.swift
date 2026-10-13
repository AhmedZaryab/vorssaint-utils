// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreImage
import SwiftUI

/// The two colours a lyrics page is washed in: the average of the cover's top
/// half and of its bottom half, pushed toward a deep, saturated tone so white
/// verses stay readable on any cover and in either menu bar appearance.
struct NotchLyricsPalette: Equatable {
    let top: Color
    let bottom: Color

    /// A quiet graphite wash for covers that are missing or have no colour.
    static let neutral = NotchLyricsPalette(top: Color(white: 0.2), bottom: Color(white: 0.08))

    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .cacheIntermediates: false])
    private static var cache: (key: ObjectIdentifier, palette: NotchLyricsPalette)?

    /// Cached per cover image, so a track measures its colours once.
    static func of(_ image: NSImage?, tint: NotchArtworkTint?) -> NotchLyricsPalette {
        guard let image else { return tint.map { NotchLyricsPalette(top: deep($0.color), bottom: deep($0.color, darker: true)) } ?? neutral }
        let key = ObjectIdentifier(image)
        if let cache, cache.key == key { return cache.palette }
        let palette = measure(image) ?? tint.map { NotchLyricsPalette(top: deep($0.color), bottom: deep($0.color, darker: true)) } ?? neutral
        cache = (key, palette)
        return palette
    }

    private static func measure(_ image: NSImage) -> NotchLyricsPalette? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        let extent = input.extent
        guard extent.width >= 2, extent.height >= 2 else { return nil }
        // Core Image's origin is the bottom left, so the upper half is the high one.
        let upper = CGRect(x: extent.minX, y: extent.midY, width: extent.width, height: extent.height / 2)
        let lower = CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: extent.height / 2)
        guard let a = average(input, in: upper), let b = average(input, in: lower) else { return nil }
        // A pale cover averages to grey; its small colourful details carry
        // the mood instead, so the two most vivid distinct cells win.
        if let vivid = vivid(cg) { return NotchLyricsPalette(top: deep(vivid.0), bottom: deep(vivid.1, darker: true)) }
        return NotchLyricsPalette(top: deep(a), bottom: deep(b, darker: true))
    }

    private static func vivid(_ image: CGImage) -> (Color, Color)? {
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress, let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: base, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var cells: [(hue: CGFloat, score: CGFloat, color: NSColor)] = []
        for i in 0..<(side * side) {
            let color = NSColor(srgbRed: CGFloat(pixels[i * 4]) / 255, green: CGFloat(pixels[i * 4 + 1]) / 255,
                                blue: CGFloat(pixels[i * 4 + 2]) / 255, alpha: 1)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            guard s > 0.25, b > 0.2 else { continue }
            cells.append((h, s * (0.4 + b), color))
        }
        cells.sort { $0.score > $1.score }
        guard let first = cells.first else { return nil }
        let second = cells.first { min(abs($0.hue - first.hue), 1 - abs($0.hue - first.hue)) > 0.1 } ?? first
        return (Color(nsColor: first.color), Color(nsColor: second.color))
    }

    private static func average(_ image: CIImage, in rect: CGRect) -> Color? {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return Color(.sRGB, red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255,
                     blue: Double(pixel[2]) / 255, opacity: 1)
    }

    /// Keeps the hue, lifts a washed out colour's saturation a little and caps
    /// its brightness, so the wash reads as colour but never competes with text.
    private static func deep(_ color: Color, darker: Bool = false) -> Color {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .darkGray
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        ns.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let colourful = saturation > 0.08
        let s = colourful ? min(0.85, max(saturation * 1.25, 0.45)) : saturation
        let b = min(max(brightness, 0.22), darker ? 0.32 : 0.44)
        return Color(hue: Double(hue), saturation: Double(s), brightness: Double(b))
    }
}

/// The soft colour field the verses sit on: two overlapping blurred glows from
/// the cover's colours over a darkening floor, clipped to the island's corners.
struct NotchLyricsBackdrop: View {
    let palette: NotchLyricsPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [palette.top, palette.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(palette.top)
                    .frame(width: size.width * 0.8, height: size.width * 0.8)
                    .offset(x: -size.width * 0.28, y: -size.height * 0.45)
                    .blur(radius: 40)
                    .opacity(0.9)
                Circle().fill(palette.bottom)
                    .frame(width: size.width * 0.7, height: size.width * 0.7)
                    .offset(x: size.width * 0.3, y: size.height * 0.5)
                    .blur(radius: 46)
                    .opacity(0.85)
                // A floor that keeps white text above 4.5:1 on the brightest cover.
                LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: size.width, height: size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: palette)
        .accessibilityHidden(true)
    }
}
