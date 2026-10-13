// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import IOKit.pwr_mgt

/// Quick subsystem check, run with `Vorssaint --selftest`.
/// Core capabilities fail the test; hardware-dependent readings only warn.
enum SelfTest {
    static func runAndExit() -> Never {
        var failures: [String] = []
        var warnings: [String] = []

        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName("PreventUserIdleSystemSleep" as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Vorssaint selftest" as CFString,
                                                 &assertionID)
        if result == kIOReturnSuccess {
            IOPMAssertionRelease(assertionID)
        } else {
            failures.append("power assertion (\(result))")
        }

        _ = SystemInfo.batterySnapshot() // may be nil on desktops

        if SystemInfo.wallClockUptimeSeconds() == nil {
            failures.append("uptime reading")
        }

        // The recorder's macOS-conflict check reads the WindowServer's live
        // shortcut table through private calls; when they are gone it falls
        // back to the preferences plist and loses factory keys such as ⌘⇧4.
        if SymbolicHotKeys.liveEntries()?.isEmpty != false {
            warnings.append("symbolic hotkey table unavailable; shortcut conflicts fall back to the plist")
        }

        // Per-app AirPlay drives private AVFoundation routing objects (the
        // default shared output context and the picker and renderer bindings).
        // When an update removes one, the mixer quietly stops offering AirPlay
        // on the systems it is offered on.
        if #available(macOS 27, *), !AirPlayRouteManager.shared.isAvailable {
            warnings.append("AirPlay routing unavailable; the mixer does not offer AirPlay")
        }

        // Power: laptops report the battery; desktops report nothing.
        if PowerSampler.hasInternalBattery, !PowerSampler().sample().hasBattery {
            warnings.append("battery reading unavailable on this Mac")
        }

        UserDefaults.standard.set("ok", forKey: "selftest")
        if UserDefaults.standard.string(forKey: "selftest") != "ok" {
            failures.append("UserDefaults")
        }
        UserDefaults.standard.removeObject(forKey: "selftest")

        for style in KeepAwakeActiveIcon.allCases {
            guard let image = BlackHoleGlyph.activeImage(style: style, tint: .orange) else {
                failures.append("Keep Awake icon \(style.rawValue)")
                continue
            }
            if image.size != BlackHoleGlyph.pointSize {
                failures.append("Keep Awake icon size \(style.rawValue)")
            }
            // image.size stays correct even when the symbol inside it is scaled
            // too large, so an overflow only shows as ink clipped by the canvas.
            if inkTouchesEdge(of: image) {
                failures.append("Keep Awake icon \(style.rawValue) is clipped by its canvas")
            }
        }

        // A symbol chosen for the menu bar shares the active symbols' canvas,
        // so every one the gallery offers must fit it; a name this Mac lacks
        // must leave the mark, never an empty item.
        for name in Defaults.menuBarIconGallery {
            guard let symbol = BlackHoleGlyph.customMark(named: name) else {
                failures.append("menu bar gallery symbol \(name)")
                continue
            }
            if symbol.size != BlackHoleGlyph.pointSize || inkTouchesEdge(of: symbol) {
                failures.append("menu bar gallery symbol \(name) does not fit its canvas")
            }
        }
        let missingSymbol = "vorssaint.missing.symbol"
        if BlackHoleGlyph.customMark(named: missingSymbol) != nil
            || BlackHoleGlyph.mark(symbolName: missingSymbol) !== BlackHoleGlyph.mark(symbolName: "") {
            failures.append("unknown menu bar symbol does not fall back to the glyph")
        }

        // Tools/MakeIcon.swift writes the glyph PNGs at BlackHoleGlyph.pointSize.
        // Changing the canvas in one and not the other would squash the glyph.
        // Asked for with no symbol name, since the glyph in use may be a
        // symbol chosen in the menu bar settings.
        if Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") == nil {
            warnings.append("menu bar glyph asset not bundled")
        } else if let rep = BlackHoleGlyph.mark(symbolName: "")?
            .representations.min(by: { $0.pixelsWide < $1.pixelsWide }) {
            if rep.pixelsWide != Int(BlackHoleGlyph.pointSize.width)
                || rep.pixelsHigh != Int(BlackHoleGlyph.pointSize.height) {
                failures.append("menu bar glyph is \(rep.pixelsWide)×\(rep.pixelsHigh) px at 1x, "
                                + "expected \(Int(BlackHoleGlyph.pointSize.width))×"
                                + "\(Int(BlackHoleGlyph.pointSize.height))")
            }
        } else {
            failures.append("menu bar glyph representations")
        }

        for warning in warnings {
            print("SELFTEST WARNING: \(warning)")
        }
        if failures.isEmpty {
            print("SELFTEST OK")
            exit(0)
        } else {
            print("SELFTEST FAILED: \(failures.joined(separator: ", "))")
            exit(1)
        }
    }

    /// Whether any visible pixel of `image` sits on its outermost row or column.
    /// Every menu bar glyph is drawn with a margin, so touching an edge means
    /// the artwork outgrew its canvas and is being cropped.
    private static func inkTouchesEdge(of image: NSImage) -> Bool {
        let sampling = 2
        let wide = Int(image.size.width) * sampling
        let high = Int(image.size.height) * sampling
        guard wide > 0, high > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: wide, pixelsHigh: high,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // The context draws in pixels, so fill the whole bitmap.
        image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(wide), height: CGFloat(high)))
        NSGraphicsContext.restoreGraphicsState()

        func visible(_ x: Int, _ y: Int) -> Bool {
            (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
        }
        for x in 0..<wide where visible(x, 0) || visible(x, high - 1) { return true }
        for y in 0..<high where visible(0, y) || visible(wide - 1, y) { return true }
        return false
    }
}

