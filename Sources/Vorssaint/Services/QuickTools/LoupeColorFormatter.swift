// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// The capture loupe's color readout and its copy key. The standalone color
/// picker tool is parked in Legacy/capture; the loupe keeps the formatting.
enum LoupeColorFormatter {
    /// The string a copy would put on the pasteboard for this color.
    static func formattedValue(_ color: NSColor) -> String? {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        let format = ColorCopyFormat.sanitized(
            UserDefaults.standard.string(forKey: DefaultsKey.colorPickerFormat) ?? "hex"
        )
        return ColorValue.string(red: srgb.redComponent,
                                 green: srgb.greenComponent,
                                 blue: srgb.blueComponent,
                                 format: format,
                                 bareHex: UserDefaults.standard.bool(forKey: DefaultsKey.colorPickerBareHex))
    }

    /// Copies without the HUD: the capture panels sit above it.
    @discardableResult
    static func copyQuietly(_ color: NSColor) -> String? {
        guard let value = formattedValue(color) else { return nil }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareVorssaintSource()
        pasteboard.setString(value, forType: .string)
        return value
    }
}
