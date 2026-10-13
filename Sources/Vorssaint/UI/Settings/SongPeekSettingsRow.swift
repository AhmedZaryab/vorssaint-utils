// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// "Next song peek" switch, on by default. Lives beside the Spotify connect row.
struct SongPeekSettingsRow: View {
    @AppStorage(SongPeekController.enabledKey) private var enabled = true

    var body: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next song peek")
                Text("Five seconds before a Spotify song ends, a small card under the notch shows what plays next.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
