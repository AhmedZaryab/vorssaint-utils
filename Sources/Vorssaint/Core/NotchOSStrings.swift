// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchOSStrings {
    /// The page's name, and the title until the OS names its own HQ.
    let title: String
    let summary: String
    let off: String
    let noMessages: String
    let dutyFormat: String
    let doorFormat: String
    let p0Format: String
    let open: String

    func duty(_ count: Int) -> String { String(format: dutyFormat, count) }
    func door(_ count: Int) -> String { String(format: doorFormat, count) }
    func p0(_ count: Int) -> String { String(format: p0Format, count) }
}

extension FeatureStrings {
    /// One reading of the OS page for every language until it is translated.
    static func notchOS(_ language: AppLanguage) -> NotchOSStrings {
        NotchOSStrings(
            title: "OS",
            summary: "Who is on duty in the OS, the last HQ line and the P0 count. One tap opens it.",
            off: "OS is off",
            noMessages: "No HQ messages yet",
            dutyFormat: "%d on duty",
            doorFormat: "%d at the door",
            p0Format: "P0 %d",
            open: "Open the OS"
        )
    }
}
