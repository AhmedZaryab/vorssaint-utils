// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings row for Spotify: one Connect button that opens Spotify's own login.
/// The developer app login (Client ID, redirect URI, PKCE) sits under Advanced.
struct SpotifyConnectRow: View {
    @ObservedObject private var privateAuth = SpotifyPrivateAuth.shared
    @ObservedObject private var auth = SpotifyWebAuth.shared
    @AppStorage(SpotifyWebAuth.clientIDKey) private var clientID = ""
    @State private var showsAdvanced = false
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
                if privateAuth.isConnected {
                    Text(String(format: text.connectedAs, privateAuth.accountName ?? "Spotify"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(text.disconnect) { privateAuth.disconnect() }
                } else if auth.isConnected {
                    Text(String(format: text.connectedAs, auth.accountName ?? "Spotify"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(text.disconnect) { auth.disconnect() }
                } else {
                    Button(text.connect) { privateAuth.login() }
                }
            }
            if let error = privateAuth.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            if !privateAuth.isConnected {
                DisclosureGroup(text.advanced, isExpanded: $showsAdvanced) { advanced }
                    .font(.caption)
            }
        }
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.advancedHint).font(.caption).foregroundStyle(.secondary)
            if !auth.isConnected {
                HStack {
                    Text(text.clientID).frame(width: 90, alignment: .leading)
                    TextField(text.clientID, text: $clientID).textFieldStyle(.roundedBorder)
                    Button(auth.connecting ? text.connecting : text.connect) { auth.connect() }
                        .disabled(auth.connecting || clientID.trimmingCharacters(in: .whitespaces).isEmpty)
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
        .padding(.top, 4)
    }
}
