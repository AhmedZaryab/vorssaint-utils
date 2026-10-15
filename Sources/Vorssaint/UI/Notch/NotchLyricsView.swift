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
                .padding(.horizontal, NotchDesign.Spacing.large)
                .padding(.vertical, NotchDesign.Spacing.small)
        }
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: online) { update() }
        // A new song starts in follow mode; a hand scroll from the last one
        // must not hold the page or fire its resume on the new verses.
        .onChange(of: NotchMusicIdentity(playback)) { stopBrowsing(follow: true) }
        .onDisappear { stopBrowsing(follow: false) }
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
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.xSmall) {
                    if !playback.hasPosition {
                        Text(text.noPosition).font(NotchDesign.Typography.label.font)
                            .foregroundStyle(NotchDesign.Ink.secondary)
                    }
                    ScrollView {
                        Text(lyrics.plain.isEmpty ? lyrics.lines.map(\.text).joined(separator: "\n") : lyrics.plain)
                            .font(NotchDesign.Typography.pageTitle.font)
                            .lineSpacing(NotchDesign.Spacing.xSmall)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, NotchDesign.Spacing.xSmall)
                            // Room for the import button, as the synced page keeps.
                            .padding(.trailing, NotchDesign.Control.minimumHit)
                    }
                    .notchScrollEdgeFade(length: 24)
                }
                .overlay(alignment: .topTrailing) { importButton }
            }
        } else if service.state == .loading {
            // A slow lookup leaves importing within reach while it waits.
            VStack(spacing: NotchDesign.Spacing.medium) {
                HStack(spacing: NotchDesign.Spacing.small) { ProgressView().controlSize(.small); Text(text.loading) }
                    .font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.secondary)
                NotchPillButton(title: text.importLyrics, action: service.importLyrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NotchEmptyView(symbol: service.state == .failed ? "exclamationmark.triangle" : "quote.bubble",
                           message: emptyMessage) {
                // A short island keeps importing as a glyph beside the
                // next step rather than cutting either name short.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: NotchDesign.Spacing.small) {
                        nextStep
                        NotchPillButton(title: text.importLyrics, action: service.importLyrics)
                    }
                    HStack(spacing: NotchDesign.Spacing.small) {
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
                .font(NotchDesign.Icon.button.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                .background(NotchDesign.Fill.control, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
        .help(text.importLyrics)
        .accessibilityLabel(text.importLyrics)
    }

    private func synced(_ lyrics: NotchLyrics) -> some View {
        TimelineView(.explicit(lyrics.changeDates(for: playback, offset: service.offset, from: .now))) { context in
            let active = lyrics.activeIndex(at: playback.position(at: context.date), offset: service.offset)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                        if active == nil {
                            Text(text.waiting).font(NotchDesign.Typography.callout.font)
                                .foregroundStyle(NotchDesign.Ink.secondary).id("start")
                        }
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            verse(line, index: index, active: active, lyrics: lyrics)
                        }
                    }
                    .padding(.vertical, NotchDesign.Spacing.small)
                    .padding(.trailing, NotchDesign.Control.minimumHit)
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
        withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion)) {
            if let index { proxy.scrollTo(index, anchor: UnitPoint(x: 0, y: 0.3)) }
            else { proxy.scrollTo("start", anchor: .top) }
        }
    }

    private func stopBrowsing(follow: Bool) {
        resume?.cancel()
        resume = nil
        browsing = false
        if follow { followTick &+= 1 }
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

    /// Every verse is laid out in the hero face so lines never rewrap as the song moves;
    /// the others scale down to the body size, anchored at the leading edge. The sung
    /// line is primary, the next ones secondary, what is already sung tertiary.
    private func verse(_ line: NotchLyricLine, index: Int, active: Int?, lyrics: NotchLyrics) -> some View {
        let distance = active.map { index - $0 } ?? (index + 1)
        let current = distance == 0
        let opacity: Double = distance == 0 ? NotchDesign.Opacity.primary
            : distance < 0 ? NotchDesign.Opacity.tertiary : NotchDesign.Opacity.secondary
        let label = VStack(alignment: .leading, spacing: NotchDesign.Spacing.xxSmall) {
            Text(line.text.isEmpty ? "\u{266A}" : line.text)
                .font(NotchDesign.Typography.hero.font)
                .lineSpacing(NotchDesign.Spacing.line)
                .foregroundStyle(.white.opacity(opacity))
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
        .scaleEffect(current ? 1 : Self.bodyScale, anchor: .leading)
        .animation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion), value: current)
        .animation(NotchDesign.Motion.fade, value: opacity)
        .contentShape(Rectangle())
        // A Button, so the press answers on mouse down with a wash; tapping a verse jumps the player there when it can seek.
        return Button {
            guard music.canSeek else { return }
            music.seek(to: line.time + service.offset, in: playback.track, context: playback.commandContext)
            // The tapped line becomes the sung one, so follow it right away.
            stopBrowsing(follow: false)
        } label: { label }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
        .id(index)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(current ? [.isButton, .isSelected] : .isButton)
    }

    /// Body over hero: 13 pt over 17 pt.
    private static let bodyScale: CGFloat = 13.0 / 17.0
}

/// A hairline under the sung verse that fills across the verse's length.
/// It reads the playback clock on every display frame (no state writes, no
/// per tick animation), pauses with playback, and under Reduce Motion steps
/// once a second.
private struct NotchLyricProgress: View {
    let start: Double
    let end: Double
    let playback: NotchPlayback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let width: CGFloat = 120

    var body: some View {
        Group {
            if reduceMotion {
                TimelineView(.periodic(from: .now, by: 1)) { bar(at: $0.date) }
            } else {
                TimelineView(.animation(paused: !playback.isPlaying)) { bar(at: $0.date) }
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(at date: Date) -> some View {
        let span = max(end - start, 0.1)
        let fraction = min(max((playback.position(at: date) - start) / span, 0), 1)
        return ZStack(alignment: .leading) {
            Capsule().fill(NotchDesign.Fill.track)
            Capsule().fill(NotchDesign.Ink.primary)
                .frame(width: Self.width * fraction)
        }
        .frame(width: Self.width, height: NotchDesign.Stroke.hairline * 4)
        .transaction { $0.animation = nil }
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
