// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Byte counts formatted the way the rest of the app writes them. The system
/// monitor's helpers that used to live here (memory math, rates, temperatures,
/// history, network and disk counters) are parked with it in
/// Legacy/systemMonitor/split/MetricFormat.swift.
///
/// Everything here depends only on Foundation, so it compiles and runs
/// standalone in the unit-test target (`./build.sh --test`).
enum MetricFormat {
    /// Numbers follow the reader's region, not the app's language: macOS keeps
    /// those two settings apart, and nine of the fifteen languages here are
    /// spoken where a decimal is written with a comma. Held in one place so a
    /// test can pin it and stay honest on a machine set to any region.
    static var locale: Locale = .current

    // MARK: Byte sizes

    /// Splits a byte count into a human value + unit, base-1024.
    static func scale(_ bytes: Double) -> (value: Double, unit: String) {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = max(0, bytes)
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        // A value that only crosses 1024 once the number is rounded still reads
        // as the larger unit, so promoting only before rounding labelled a
        // megabyte "1,024 KB". Under ten the decimal is kept and can never reach 1024, and at the
        // last unit there is nothing left to promote into.
        while index < units.count - 1, value.rounded() >= 1024, index == 0 || value >= 10 {
            value /= 1024
            index += 1
        }
        return (value, units[index])
    }

    /// Bytes (raw) → "0", "8" for B; one decimal under 10, none at or above.
    private static func number(_ value: Double, unit: String) -> String {
        if unit == "B" { return String(format: "%.0f", locale: Self.locale, value) }
        return value < 10 ? String(format: "%.1f", locale: Self.locale, value) : String(format: "%.0f", locale: Self.locale, value)
    }

    /// A whole quantity of bytes, e.g. "1.2 GB". Used for session totals.
    static func bytes(_ bytes: UInt64) -> String {
        let (value, unit) = scale(Double(bytes))
        return "\(number(value, unit: unit)) \(unit)"
    }

    static func diskBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = max(0, Double(bytes))
        var index = 0
        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        if units[index] == "B" {
            return String(format: "%.0f B", locale: Self.locale, value)
        }
        return value < 10 ? String(format: "%.1f %@", locale: Self.locale, value, units[index])
            : String(format: "%.0f %@", locale: Self.locale, value, units[index])
    }
}
