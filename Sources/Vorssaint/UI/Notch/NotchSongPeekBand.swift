// Adapted from Sapphire (MusicUpNextView, LiveActivityComponents.swift)
// Copyright (C) Shariq Charolia, AGPL-3.0; used here under GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The next song peek, as the tall peek (docs/design/NOTCH-DESIGN.md 11.2 and
/// 12): the closed strip as it rests, and below it a band with the cover, the
/// title over "Up next · Artist", and a small live equaliser. No ring, no
/// eyebrow. The island grows by exactly `height` (see NotchService.surfaceSize).
struct NotchSongPeekBand: View {
    @ObservedObject var model: SongPeekModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let upNext = SpotifyQueueStrings.current.upNext

    /// What the closed notch grows by while the peek shows.
    static var height: CGFloat { NotchDesign.Peek.bandHeight }

    private var title: String { model.title.isEmpty ? "Unknown track" : model.title }
    private var secondary: String { [upNext, model.artist].filter { !$0.isEmpty }.joined(separator: " · ") }

    var body: some View {
        NotchTallPeekRow(primary: title, secondary: secondary) {
            cover
        } live: {
            // Static bars under Reduce Motion.
            NotchLiveEqualizerBars(isPlaying: !reduceMotion, bars: 3, barWidth: 2, height: 12)
        }
        .frame(height: Self.height)
        .transition(.opacity.animation(reduceMotion ? nil : NotchDesign.Motion.fade))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(upNext): \(model.title), \(model.artist)")
    }

    /// The cover, or a note in a card plate until it lands; the real cover
    /// cross-fades in.
    private var cover: some View {
        let radius = NotchDesign.Radius.card
        return ZStack {
            NotchDesign.Fill.card
            Image(systemName: "music.note")
                .font(NotchDesign.Icon.strip.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : NotchDesign.Motion.fade, value: model.artwork != nil)
        .frame(width: NotchDesign.Peek.artwork, height: NotchDesign.Peek.artwork)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(NotchDesign.Stroke.artworkEdge, lineWidth: NotchDesign.Stroke.hairline))
        .accessibilityHidden(true)
    }
}
