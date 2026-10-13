// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The next song peek: cover, title, artist, and a ring that fills as the
/// playing song runs out. Fades in; Reduce Motion drops the scale, never the ring.
struct SongPeekCardView: View {
    static let size = CGSize(width: 280, height: 64)
    /// Space between the island's bottom edge and the card.
    static let gap: CGFloat = 8
    private static let radius: CGFloat = 18

    @ObservedObject var model: SongPeekModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let upNext = SpotifyQueueStrings.current.upNext

    var body: some View {
        HStack(spacing: 10) {
            cover
            VStack(alignment: .leading, spacing: 1) {
                Text(upNext.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .kerning(1.1)
                    .foregroundStyle(.white.opacity(0.55))
                Text(model.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !model.artist.isEmpty {
                    Text(model.artist)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ring.frame(width: 20, height: 20)
        }
        .padding(.horizontal, 12)
        .frame(width: Self.size.width - 8, height: Self.size.height - 8)
        .modifier(SongPeekGlass(cornerRadius: Self.radius))
        .frame(width: Self.size.width, height: Self.size.height)
        .opacity(model.visible ? 1 : 0)
        .scaleEffect(model.visible || reduceMotion ? 1 : 0.92, anchor: .top)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8),
                   value: model.visible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(upNext): \(model.title), \(model.artist)")
    }

    private var cover: some View {
        Group {
            if let artwork = model.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55)))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Filled from the moment the card appears to the song's last second.
    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let total = max(0.1, model.endsAt.timeIntervalSince(model.startedAt))
            let progress = min(1, max(0, context.date.timeIntervalSince(model.startedAt) / total))
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Liquid Glass on macOS 26, smoked for white type; the HUD material before,
/// and solid under Reduce Transparency. Matches the lock screen player.
private struct SongPeekGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(white: 0.12))
                } else {
                    ZStack {
                        glass(shape)
                        shape.fill(.black.opacity(contrast == .increased ? 0.5 : 0.28))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(.white.opacity(contrast == .increased ? 0.45 : 0.1), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }

    @ViewBuilder private func glass(_ shape: RoundedRectangle) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(.clear, in: shape)
                .environment(\.appearsActive, true)
        } else {
            SongPeekMaterial(cornerRadius: cornerRadius)
        }
#else
        SongPeekMaterial(cornerRadius: cornerRadius)
#endif
    }
}

private struct SongPeekMaterial: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }
}
