// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Spotify's own queue on the music page, read from the Web API.
struct NotchSpotifyQueueSection: View {
    @ObservedObject private var auth = SpotifyWebAuth.shared
    @ObservedObject private var privateAuth = SpotifyPrivateAuth.shared
    @ObservedObject private var service = SpotifyQueueService.shared
    @State private var searchText = ""
    @State private var showsSearch = false
    private let text = SpotifyQueueStrings.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !connected {
                connectPrompt
            } else {
                if showsSearch { searchArea }
                if service.actionThrottled {
                    Text(text.throttled).font(.caption).foregroundStyle(.orange)
                }
                if service.actionFailed {
                    Text(text.actionFailed).font(.caption).foregroundStyle(.orange)
                }
                if let code = service.failureCode {
                    HStack(spacing: 8) {
                        Text(String(format: text.noAnswer, code)).font(.caption).foregroundStyle(.orange).lineLimit(2)
                        Spacer(minLength: 0)
                        Button(text.retry) { service.retryNow() }.buttonStyle(.borderless).font(.caption)
                    }
                }
                if service.upNext.isEmpty, !service.loading, service.failureCode == nil {
                    Text(text.nothingQueued).font(.callout).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(service.upNext) { track in
                                row(track) {
                                    Button { service.playNow(track) } label: {
                                        Image(systemName: "play.fill").font(.system(size: 11))
                                            .frame(width: 28, height: 28).contentShape(Circle())
                                    }
                                    .buttonStyle(NotchButtonStyle(cornerRadius: 14))
                                    .disabled(service.actionPending)
                                    .help(text.playNow).accessibilityLabel("\(text.playNow): \(track.title)")
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { service.playNow(track) }
                                .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                                    if value.translation.width < -40 { service.skipNext() }
                                    if value.translation.width > 40 { service.skipPrevious() }
                                })
                            }
                        }
                    }
                    .notchScrollEdgeFade()
                }
                Text(text.reorderLimit).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { service.setVisible(true) }
        .onDisappear { service.setVisible(false) }
        .onChange(of: connected) { _, connected in service.setVisible(connected) }
    }

    private var title: String {
        switch service.contextKind {
        case "playlist": return text.fromPlaylist
        case "album": return text.fromAlbum
        default: return text.upNext
        }
    }

    /// Either login works: the Spotify login first, the developer app second.
    private var connected: Bool { privateAuth.isConnected || auth.isConnected }

    private var header: some View {
        HStack(spacing: 6) {
            Text(title).font(.callout.weight(.semibold))
            Spacer()
            if service.loading || service.actionPending || service.searching { ProgressView().controlSize(.mini) }
            if connected {
                iconButton("backward.end.fill", text.skipPrevious) { service.skipPrevious() }
                iconButton("forward.end.fill", text.skipNext) { service.skipNext() }
                iconButton(showsSearch ? "xmark" : "plus", text.addToQueue) {
                    showsSearch.toggle()
                    if !showsSearch { searchText = ""; service.clearSearch() }
                }
            }
        }
    }

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.connectPrompt).font(.callout).foregroundStyle(.secondary)
            NotchPillButton(title: text.connect, prominent: true) { privateAuth.login() }
            if let error = privateAuth.lastError ?? auth.lastError {
                Text(error).font(.caption).foregroundStyle(.orange).lineLimit(3)
            }
        }
    }

    private var searchArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(text.searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { service.search(searchText) }
            ForEach(service.searchResults) { track in
                row(track) {
                    Button { service.addToQueue(track) } label: {
                        Image(systemName: "plus").font(.system(size: 11))
                            .frame(width: 28, height: 28).contentShape(Circle())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 14))
                    .disabled(service.actionPending)
                    .help(text.addToQueue).accessibilityLabel("\(text.addToQueue): \(track.title)")
                }
            }
        }
    }

    private func row<Trailing: View>(_ track: SpotifyQueueService.Track,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            NotchArtwork(image: track.artworkURL.flatMap { service.artwork[$0] }, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.callout.weight(.medium)).lineLimit(1)
                if !track.artist.isEmpty {
                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 6)
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)) }
            .buttonStyle(.borderless)
            .disabled(service.actionPending)
            .help(label).accessibilityLabel(label)
    }
}
