// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchQueueView: View {
    let playback: NotchPlayback
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchMusicExtrasStrings { FeatureStrings.notchMusicExtras(l10n.language) }

    var body: some View {
        if SpotifyQueueService.isSpotify(playback), AppFeature.spotifyQueue.isAvailable {
            NotchSpotifyQueueSection()
        } else {
            playerQueue
        }
    }

    private var playerQueue: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                Text(text.queue).font(NotchDesign.Typography.title.font)
                Spacer()
                if service.queueLoading || service.queueActionPending { ProgressView().controlSize(.mini) }
                NotchIconButton(symbol: "arrow.clockwise", title: text.refresh) { service.refreshQueue() }
                    .disabled(service.queueLoading || service.queueActionPending)
            }
            if service.queueActionFailed {
                Text(text.actionFailed).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Palette.warning)
            }
            if let queue = service.upcoming, !service.upcomingRows.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.upcomingRows) { item in
                            queueRow(item, canPlay: queue.canPlay)
                        }
                    }
                }
                .notchScrollEdgeFade()
            } else if !service.queueLoading {
                NotchEmptyView(symbol: "list.bullet", message: service.upcoming == nil ? text.queueUnavailable : text.queueEmpty) {
                    NotchPillButton(title: text.openPlayer, prominent: true) { RadialNowPlayingApplication.open(playback.track) }
                }
            }
        }
        // The title sits as far below the player as the first verse would.
        .padding(.top, NotchDesign.Spacing.xSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// One row: the whole row plays the song (a press, with the wash under the pointer),
    /// and the play glyph stays as the visible, labelled way to say so.
    private func queueRow(_ item: NotchQueueItem, canPlay: Bool) -> some View {
        let busy = service.queueActionPending || service.upcomingIsHeld
        return ZStack(alignment: .trailing) {
            Button { if canPlay { service.playQueued(item) } } label: {
                NotchQueueRowLabel(image: service.upcomingArtwork[item.id], title: item.title, artist: item.artist)
                    .padding(.trailing, canPlay ? NotchDesign.Control.iconButton + NotchDesign.Spacing.xSmall : 0)
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
            .disabled(!canPlay || busy)
            .accessibilityLabel(item.artist.isEmpty ? item.title : "\(item.title), \(item.artist)")
            if canPlay {
                NotchIconButton(symbol: "play.fill", title: "\(text.playNow): \(item.title)") { service.playQueued(item) }
                    .disabled(busy)
                    .padding(.trailing, NotchDesign.Spacing.xSmall)
            }
        }
        .frame(height: NotchQueueMetrics.rowHeight)
    }
}

/// Queue rows, shared by the player's queue and Spotify's: one height, one inset,
/// a 28 pt cover at the control radius.
enum NotchQueueMetrics {
    /// Tall enough for a 28 pt cover with 8 pt above and below; the drag maths of the Spotify list counts in these.
    static let rowHeight: CGFloat = 44
    static let cover: CGFloat = NotchDesign.Control.minimumHit
}

/// The cover thumbnail of a queue row.
struct NotchQueueThumb: View {
    let image: NSImage?
    var side: CGFloat = NotchQueueMetrics.cover

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous)
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                NotchDesign.Fill.control.overlay {
                    Image(systemName: "music.note").font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(NotchDesign.Stroke.artworkEdge, lineWidth: NotchDesign.Stroke.hairline))
        .accessibilityHidden(true)
    }
}

/// Cover, title and artist, left aligned in a queue row with the standard insets.
struct NotchQueueRowLabel: View {
    let image: NSImage?
    let title: String
    let artist: String

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.small) {
            NotchQueueThumb(image: image)
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                Text(title).font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.primary).lineLimit(1)
                if !artist.isEmpty {
                    Text(artist).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NotchDesign.Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
