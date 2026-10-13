// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings row for the Spotify Web API link: Client ID, the exact redirect
/// URI Spotify must have on file, and connect or disconnect.
struct SpotifyConnectRow: View {
    @ObservedObject private var auth = SpotifyWebAuth.shared
    @AppStorage(SpotifyWebAuth.clientIDKey) private var clientID = ""
    private let text = SpotifyQueueStrings.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list").frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.featureTitle)
                    Text(text.featureDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if auth.isConnected {
                    Text(String(format: text.connectedAs, auth.accountName ?? "Spotify"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(text.disconnect) { auth.disconnect() }
                } else {
                    Button(auth.connecting ? text.connecting : text.connect) { auth.connect() }
                        .disabled(auth.connecting || clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if !auth.isConnected {
                HStack {
                    Text(text.clientID).frame(width: 90, alignment: .leading)
                    TextField(text.clientID, text: $clientID).textFieldStyle(.roundedBorder)
                }
                Text(text.clientIDHint).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(text.redirectLabel).frame(width: 90, alignment: .leading)
                Text(SpotifyWebAuth.redirectURI).font(.caption.monospaced()).textSelection(.enabled)
                Spacer()
                Button(text.copy) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(SpotifyWebAuth.redirectURI, forType: .string)
                }
            }
            if let error = auth.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
