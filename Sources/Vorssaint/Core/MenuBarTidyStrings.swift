// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarTidyStrings {
    let title: String
    let hubDescription: String
    let enable: String
    let enableHint: String
    let hint: String
    let autoHide: String
    let seconds: String
    let never: String
    let showNow: String
    let dividerHelp: String
    let toggleShowHelp: String
    let toggleHideHelp: String

    var searchKeywords: [String] { [title, "menu bar", "hide icons", "hidden bar", "divider"] }
}

extension FeatureStrings {
    /// English only for now; every language falls back to it.
    static func menuBarTidy(_ language: AppLanguage) -> MenuBarTidyStrings {
        MenuBarTidyStrings(
            title: "Menu bar tidy",
            hubDescription: "Hide the menu bar icons you rarely use behind a divider, and show them with one click.",
            enable: "Hide icons behind a divider",
            enableHint: "Adds a divider and an arrow to the menu bar. Icons left of the divider tuck away.",
            hint: "Hold Cmd and drag icons to the left of the divider to hide them",
            autoHide: "Hide again after",
            seconds: "%d s",
            never: "Never",
            showNow: "Show hidden icons now",
            dividerHelp: "Icons left of this divider are hidden",
            toggleShowHelp: "Show hidden menu bar icons",
            toggleHideHelp: "Hide menu bar icons again"
        )
    }
}
