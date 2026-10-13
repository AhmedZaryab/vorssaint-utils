// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The "Menu bar tidy" card on the Quick Tools page.
struct MenuBarTidySettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.menuBarTidyEnabled) private var enabled = false
    @AppStorage(DefaultsKey.menuBarTidyAutoHideSeconds) private var autoHideSeconds = 10

    private static let delayChoices = [5, 10, 15, 30, 60, 0]

    var body: some View {
        let text = FeatureStrings.menuBarTidy(l10n.language)
        Section {
            Toggle(text.enable, isOn: $enabled)
                .onChange(of: enabled) { _, _ in
                    MenuBarTidyManager.shared.syncWithPreferences()
                }
            Text(text.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
            if enabled {
                Picker(text.autoHide, selection: $autoHideSeconds) {
                    ForEach(Self.delayChoices, id: \.self) { seconds in
                        Text(seconds == 0 ? text.never : String(format: text.seconds, seconds))
                            .tag(seconds)
                    }
                }
                Button {
                    MenuBarTidyManager.shared.showNow()
                } label: {
                    Label(text.showNow, systemImage: "chevron.left.2")
                }
            }
        } header: {
            Text(text.title)
        } footer: {
            Text(text.enableHint)
        }
    }
}
