// Adapted from Sapphire (MusicUpNextView, LiveActivityComponents.swift)
// Copyright (C) Shariq Charolia, AGPL-3.0; used here under GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The next song peek, as the tall peek (docs/design/NOTCH-DESIGN.md 11.2 and
/// 12): the closed strip as it rests, and below it a band with the cover, the
/// title over "Up next · Artist", and a thin ring that fills clockwise over
/// the seconds the song has left. No eyebrow. The island grows by exactly `height` (see NotchService.surfaceSize).
struct NotchSongPeekBand: View {
    @ObservedObject var model: SongPeekModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var music = NotchMusicService.shared
    private let upNext = SpotifyQueueStrings.current.upNext

    /// What the closed notch grows by while the peek shows.
    static var height: CGFloat { NotchDesign.Peek.bandHeight }

    private var title: String { model.title.isEmpty ? "Unknown track" : model.title }
    private var secondary: String { [upNext, model.artist].filter { !$0.isEmpty }.joined(separator: " · ") }

    var body: some View {
        NotchTallPeekRow(primary: title, secondary: secondary) {
            cover
        } live: {
            NotchSongPeekRing(endsAt: model.endsAt, tint: music.artworkTint?.color ?? .white,
                              reduceMotion: reduceMotion)
                .accessibilityHidden(true)
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

/// The trailing live element: a 2 pt ring on a white 0.16 track that fills
/// clockwise from 12 o'clock over what is left of the song, with a forward
/// glyph inside. It reads the clock each frame, so it is always where the song
/// is and nothing needs interrupting when the track changes; Reduce Motion
/// steps it once a second.
private struct NotchSongPeekRing: View {
    let endsAt: Date
    let tint: Color
    let reduceMotion: Bool

    private static let stroke: CGFloat = 2

    var body: some View {
        Group {
            if reduceMotion {
                TimelineView(.periodic(from: .now, by: 1)) { ring(Self.fraction(endsAt, at: $0.date)) }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { ring(Self.fraction(endsAt, at: $0.date)) }
            }
        }
        .frame(width: NotchDesign.Peek.trailingSide, height: NotchDesign.Peek.trailingSide)
    }

    private func ring(_ value: CGFloat) -> some View {
        ZStack {
            Circle().inset(by: Self.stroke / 2)
                .stroke(.white.opacity(0.16), lineWidth: Self.stroke)
            Circle().inset(by: Self.stroke / 2)
                .trim(from: 0, to: value)
                .stroke(tint, style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "forward.fill")
                .font(NotchDesign.Icon.strip.font)
                .imageScale(.small)
                .foregroundStyle(NotchDesign.Ink.primary)
        }
    }

    private static func fraction(_ endsAt: Date, at date: Date) -> CGFloat {
        let remaining = endsAt.timeIntervalSince(date)
        guard remaining.isFinite, remaining > 0 else { return 1 }
        return CGFloat(max(0, min(1, (SongPeekPolicy.lead - remaining) / SongPeekPolicy.lead)))
    }
}
