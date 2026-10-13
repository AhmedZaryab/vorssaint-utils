// Adapted from Sapphire (MusicUpNextView, LiveActivityComponents.swift)
// Copyright (C) Shariq Charolia, AGPL-3.0; used here under GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The next song peek: one row under the closed notch, cover left, an
/// "UP NEXT" eyebrow with title and artist in the middle, and a ring on the
/// right that fills clockwise over the last 10 seconds. Its height is measured
/// from the fonts below, and the notch grows by exactly that much (see
/// NotchService.surfaceSize).
struct NotchSongPeekBand: View {
    @ObservedObject var model: SongPeekModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let upNext = SpotifyQueueStrings.current.upNext

    // MARK: Layout

    static let horizontalPadding: CGFloat = 12
    /// Clear space above the row, so it sits below the notch's own strip.
    static let topPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 10
    static let coverSize: CGFloat = 28
    static let coverRadius: CGFloat = 6
    static let ringSize: CGFloat = 18
    static let ringStroke: CGFloat = 2
    static let columnSpacing: CGFloat = 10
    static let lineSpacing: CGFloat = 1

    static let eyebrowFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
    static let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let artistFont = NSFont.systemFont(ofSize: 10.5, weight: .regular)

    /// One line of `font`, as the text system lays it out.
    static func lineHeight(_ font: NSFont) -> CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: font))
    }

    static var textHeight: CGFloat {
        lineHeight(eyebrowFont) + lineHeight(titleFont) + lineHeight(artistFont) + lineSpacing * 2
    }

    static var rowHeight: CGFloat { max(coverSize, ringSize, textHeight) }

    /// What the closed notch grows by while the peek shows.
    static var height: CGFloat { topPadding + rowHeight + bottomPadding }

    /// The ring's fill: pine, bright enough to read on the notch's black.
    private static let ringFill = Color(red: 0.42, green: 0.71, blue: 0.56)

    // MARK: Body

    var body: some View {
        HStack(alignment: .center, spacing: Self.columnSpacing) {
            cover
            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                line(upNext.uppercased(), font: Self.eyebrowFont, color: .white.opacity(0.55),
                     kerning: 9 * 0.08)
                line(model.title.isEmpty ? "Unknown track" : model.title, font: Self.titleFont,
                     color: .white)
                line(model.artist, font: Self.artistFont, color: .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ring.frame(width: Self.ringSize, height: Self.ringSize)
        }
        .frame(height: Self.rowHeight)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding)
        .transition(.opacity.animation(reduceMotion ? nil : .easeOut(duration: 0.18)))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(upNext): \(model.title), \(model.artist)")
    }

    private func line(_ text: String, font: NSFont, color: Color, kerning: CGFloat = 0) -> some View {
        Text(text)
            .font(Font(font))
            .kerning(kerning)
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.lineHeight(font), alignment: .leading)
    }

    private var cover: some View {
        Group {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.12)
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5)))
            }
        }
        .frame(width: Self.coverSize, height: Self.coverSize)
        .clipShape(RoundedRectangle(cornerRadius: Self.coverRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Self.coverRadius, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    /// Progress is (10 - remaining) / 10, floored at 0.03 so the ring always
    /// shows a start. Reduce Motion steps it once a second instead of sweeping.
    private var ring: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { context in
            let remaining = model.endsAt.timeIntervalSince(context.date)
            let progress = remaining.isFinite && remaining >= 0
                ? max(0.03, min(1.0, (SongPeekPolicy.lead - remaining) / SongPeekPolicy.lead)) : 0
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: Self.ringStroke)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Self.ringFill, style: StrokeStyle(lineWidth: Self.ringStroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(Self.ringStroke / 2)
        }
        .accessibilityHidden(true)
    }
}
