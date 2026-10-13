// Adapted from Sapphire (MusicUpNextView, LiveActivityComponents.swift)
// Copyright (C) Shariq Charolia, AGPL-3.0; used here under GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The next song peek, as Sapphire draws it: "UP NEXT", a 20 pt cover, title,
/// artist and a 16 pt ring that fills over the last 10 seconds. It sits in the
/// band the closed notch grows by (see NotchService.songPeekBandHeight).
struct NotchSongPeekBand: View {
    @ObservedObject var model: SongPeekModel
    private let upNext = SpotifyQueueStrings.current.upNext

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(upNext.uppercased())
                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                .kerning(1.3)
                .foregroundColor(.gray.opacity(0.9))

            HStack(spacing: 7) {
                Group {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderArtwork
                    }
                }
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.title.isEmpty ? "Unknown track" : model.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !model.artist.isEmpty {
                        Text(model.artist)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                ring
                    .frame(width: 16, height: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, NotchSongPeekBand.horizontalPadding)
        .padding(.bottom, NotchSongPeekBand.bottomPadding)
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(upNext): \(model.title), \(model.artist)")
    }

    /// Sapphire's activityContentBottomPadding and the band it makes.
    static let bottomPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 18
    static let height: CGFloat = 7.5 + 3 + 20 + bottomPadding + 4

    /// Sapphire's ring: progress is (10 - remaining) / 10, floored at 0.03.
    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let remaining = model.endsAt.timeIntervalSince(context.date)
            let progress = remaining.isFinite && remaining >= 0
                ? max(0.03, min(1.0, (SongPeekPolicy.lead - remaining) / SongPeekPolicy.lead)) : 0
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .overlay(Image(systemName: "music.note")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.5)))
    }
}
