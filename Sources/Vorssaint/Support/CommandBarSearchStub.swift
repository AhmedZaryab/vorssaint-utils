// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Minimal stand-in for the parked Command Bar's search type. The island's
/// module filter and the notch layout editor's action search still fold text
/// with `normalized`, so only that survives here. The full matcher lives in
/// Legacy/commandBar/Services/CommandBar/CommandBarSupport.swift; restoring
/// the Command Bar means deleting this file (see Legacy/commandBar/RESTORE.md).
enum CommandBarSearch {
    /// Case, accent and width differences never matter. Folded without a
    /// locale on purpose: Turkish lowercases a capital I to a dotless one.
    static func normalized(_ value: String) -> String {
        let folded = strippingInvisibles(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
            .lowercased()
        return folded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func strippingInvisibles(_ value: String) -> String {
        guard value.unicodeScalars.contains(where: isInvisible) else { return value }
        return String(String.UnicodeScalarView(value.unicodeScalars.filter { !isInvisible($0) }))
    }

    private static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x00AD && scalar.properties.generalCategory == .format
    }
}
