// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchLyricsView: View {
    let playback: NotchPlayback
    @ObservedObject private var service = NotchLyricsService.shared
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLyricsOnline) private var online = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Set while the reader scrolls through the verses by hand; auto-follow
    /// waits until about four seconds after the last input.
    @State private var browsing = false
    @State private var resume: DispatchWorkItem?
    @State private var followTick = 0
    private var text: NotchMusicExtrasStrings { FeatureStrings.notchMusicExtras(l10n.language) }

    private var palette: NotchLyricsPalette { NotchLyricsPalette.of(music.artwork, tint: music.artworkTint) }

    // The verses sit on a wash of the cover's own colours, as a player's own
    // lyrics do, and a song without them says so on the same wash.
    var body: some View {
        ZStack(alignment: .topLeading) {
            NotchLyricsBackdrop(palette: palette)
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: online) { update() }
    }

    @ViewBuilder private var content: some View {
        if let lyrics = service.lyrics {
            if lyrics.instrumental {
                NotchEmptyView(symbol: "music.note", message: text.instrumental) {
                    NotchPillButton(title: text.importLyrics, action: service.importLyrics)
                }
            } else if !lyrics.lines.isEmpty, playback.hasPosition {
                synced(lyrics)
                    .overlay(alignment: .topTrailing) { importButton }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if !playback.hasPosition {
                        Text(text.noPosition).font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    ScrollView {
                        Text(lyrics.plain.isEmpty ? lyrics.lines.map(\.text).joined(separator: "\n") : lyrics.plain)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineSpacing(7)
                            .foregroundStyle(.white.opacity(0.88))
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 1)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                    .notchScrollEdgeFade(length: 24)
                }
                .overlay(alignment: .topTrailing) { importButton }
            }
        } else if service.state == .loading {
            // A slow lookup leaves importing within reach while it waits.
            VStack(spacing: 12) {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text.loading) }
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                NotchPillButton(title: text.importLyrics, action: service.importLyrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NotchEmptyView(symbol: service.state == .failed ? "exclamationmark.triangle" : "quote.bubble",
                           message: emptyMessage) {
                // A short island keeps importing as a glyph beside the
                // next step rather than cutting either name short.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        nextStep
                        NotchPillButton(title: text.importLyrics, action: service.importLyrics)
                    }
                    HStack(spacing: 8) {
                        nextStep
                        NotchIconButton(symbol: "doc.badge.plus", title: text.importLyrics, action: service.importLyrics)
                    }
                }
            }
        }
    }

    private func update() { service.update(playback: playback, visible: true) }

    /// An import that read no timed lines fails even with online lookup off,
    /// so the failure stays above the disclosure the next step needs.
    private var emptyMessage: String {
        let reason: String? = service.state == .failed ? text.failed : online ? text.unavailable : nil
        return [reason, online ? nil : text.onlineHint].compactMap { $0 }.joined(separator: "\n")
    }

    @ViewBuilder private var nextStep: some View {
        if online {
            NotchPillButton(title: text.retry, prominent: true, action: service.retry)
        } else {
            NotchPillButton(title: text.online, prominent: true) { online = true }
        }
    }

    private var importButton: some View {
        // A file being added, not the usual download arrow, which reads as saving.
        Button { service.importLyrics() } label: {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
            .buttonStyle(NotchButtonStyle(cornerRadius: 12))
            .help(text.importLyrics)
            .accessibilityLabel(text.importLyrics)
    }

    private func synced(_ lyrics: NotchLyrics) -> some View {
        TimelineView(.explicit(lyrics.changeDates(for: playback, offset: service.offset, from: .now))) { context in
            let active = lyrics.activeIndex(at: playback.position(at: context.date), offset: service.offset)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if active == nil {
                            Text(text.waiting).font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6)).id("start")
                        }
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            verse(line, index: index, active: active, lyrics: lyrics)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 28)
                }
                .notchScrollEdgeFade(length: 28)
                .modifier(NotchLyricsBrowseTracker(onInput: beginBrowsing))
                .onChange(of: active, initial: true) { _, index in
                    // A reader looking back keeps their place; the sung line
                    // still lights up wherever it sits.
                    guard !browsing else { return }
                    follow(index, proxy: proxy)
                }
                .onChange(of: followTick) { follow(active, proxy: proxy) }
            }
        }
    }

    private func follow(_ index: Int?, proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86)) {
            if let index { proxy.scrollTo(index, anchor: UnitPoint(x: 0, y: 0.3)) }
            else { proxy.scrollTo("start", anchor: .top) }
        }
    }

    private func beginBrowsing() {
        browsing = true
        resume?.cancel()
        let work = DispatchWorkItem {
            browsing = false
            followTick &+= 1
        }
        resume = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    /// Every verse keeps one font size so lines never rewrap as the song
    /// moves; distance from the sung line sets its scale and brightness.
    private func verse(_ line: NotchLyricLine, index: Int, active: Int?, lyrics: NotchLyrics) -> some View {
        let distance = active.map { index - $0 } ?? (index + 1)
        let current = distance == 0
        let opacity: Double = switch distance {
        case 0: 1
        case 1: 0.55
        case 2: 0.34
        case ..<0: distance == -1 ? 0.3 : 0.16
        default: 0.18
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(line.text.isEmpty ? "♪" : line.text)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(opacity))
                .shadow(color: .white.opacity(current ? 0.45 : 0), radius: current ? 8 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if current {
                NotchLyricProgress(start: line.time + service.offset,
                                   end: lyrics.lines.indices.contains(index + 1)
                                       ? lyrics.lines[index + 1].time + service.offset : playback.duration,
                                   playback: playback)
                    .transition(.opacity)
            }
        }
        .scaleEffect(current ? 1 : 0.86, anchor: .leading)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: current)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: opacity)
        .id(index)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap a verse to jump the player there, when it can seek.
            guard music.canSeek else { return }
            music.seek(to: line.time + service.offset, in: playback.track, context: playback.commandContext)
            // The tapped line becomes the sung one, so follow it right away.
            resume?.cancel()
            browsing = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(current ? [.isButton, .isSelected] : .isButton)
    }
}

/// A hairline under the sung verse that fills across the verse's length.
private struct NotchLyricProgress: View {
    let start: Double
    let end: Double
    let playback: NotchPlayback

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playback.isPlaying)) { context in
            let span = max(end - start, 0.1)
            let fraction = min(max((playback.position(at: context.date) - start) / span, 0), 1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: proxy.size.width * fraction)
                        .shadow(color: .white.opacity(0.5), radius: 3)
                }
            }
            .frame(width: 120, height: 2)
        }
        .accessibilityHidden(true)
    }
}

/// Reports a hand scroll (trackpad or wheel) so auto-follow can step aside.
/// Programmatic scrolls to the sung line do not count as input.
private struct NotchLyricsBrowseTracker: ViewModifier {
    let onInput: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.onScrollPhaseChange { _, phase in
                if phase == .interacting || phase == .decelerating { onInput() }
            }
        } else {
            content
        }
    }
}
