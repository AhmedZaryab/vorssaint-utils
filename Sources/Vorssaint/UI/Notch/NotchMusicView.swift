// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Values only the music page uses. Everything else comes from NotchDesign.
extension NotchDesign {
    enum Music {
        /** A paused cover rests a little smaller than a playing one. */ static let pausedArtworkScale: CGFloat = 0.94
        /** From this player height up the page is roomy: two title lines, a 44 pt transport. */ static let roomyHeight: CGFloat = 140
        /** The scrubber's row beside the times; its hit area overflows into the gaps around it. */ static let timelineRow: CGFloat = 20
        /** The play and pause plate beside the shuffle plate, smaller than the transport it sits by. */ static let sidePlate: CGFloat = 28
    }
}

/// Artwork with Radius.artwork corners and the hairline edge. The shared NotchArtwork rounds by a
/// fixed share of its side; this page rounds like the spec, and Increase Contrast gets its 1 pt edge.
private struct NotchMusicPageCover: View {
    let image: NSImage?
    let size: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchDesign.Radius.artwork(side: size), style: .continuous)
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.black.overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.3, weight: .medium))
                        .foregroundStyle(NotchDesign.Ink.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(contrast == .increased ? NotchDesign.Stroke.increasedContrast : NotchDesign.Stroke.artworkEdge,
                               lineWidth: contrast == .increased ? NotchDesign.Stroke.increasedContrastWidth : NotchDesign.Stroke.hairline)
        }
        .accessibilityHidden(true)
    }
}

struct NotchMusicView: View {
    let size: CGSize
    /// Room lyrics or the queue may add below the player.
    let extrasHeight: CGFloat
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var shuffle = NotchShuffleService.shared
    @AppStorage(DefaultsKey.notchLyricsEnabled) private var lyricsEnabled = true
    @AppStorage(DefaultsKey.notchQueueEnabled) private var queueEnabled = true
#if VORSSAINT_DEVELOPMENT
    // The render harness can open the page with lyrics or the queue showing.
    @State private var extra: MusicExtra? = NotchRenderHarness.subpage == .lyrics ? .lyrics
        : NotchRenderHarness.subpage == .queue ? .queue : nil
#else
    @State private var extra: MusicExtra?
#endif
    private enum MusicExtra { case lyrics, queue }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    /// The cover's own colour, used for its halo and for the moving parts that
    /// belong to this track. Neutral covers keep the panel white.
    private var accent: Color { service.artworkTint?.color ?? .white }
    private var halo: Color { service.artworkTint?.color ?? .clear }
    /// A toggle's plate takes the cover's colour, or the accent where the cover is neutral so its white glyph stays seen.
    private var toggleTint: Color { service.artworkTint?.color ?? NotchDesign.Palette.accent }
    private var showsLyrics: Bool { lyricsEnabled && AppFeature.notchLyrics.isAvailable }
    private var showsQueue: Bool { queueEnabled && AppFeature.notchQueue.isAvailable }
    private var hasControlsRow: Bool { AppFeature.mixer.isAvailable || showsLyrics || showsQueue }
    private var openExtra: MusicExtra? {
        guard service.playback != nil else { return nil }
        switch extra {
        case .lyrics: return showsLyrics ? .lyrics : nil
        case .queue: return showsQueue ? .queue : nil
        case nil: return nil
        }
    }

    var body: some View {
        let controlsRow = hasControlsRow ? NotchLayout.musicControlsRowHeight + NotchLayout.rowSpacing : 0
        // A custom size can be too short to hold both, and the player yields
        // there; elsewhere the island grows by the extra and the player keeps
        // the height the island reserves for it at rest. That height comes
        // from the geometry, not from this page, which is still the idle
        // page when music starts with lyrics already chosen.
        let geometry = NotchService.shared.geometry
        let split = NotchLayout.musicSplit(
            height: size.height, controlsRow: controlsRow, extras: extrasHeight, resting: geometry.musicPlayerHeight,
            keepsPlayer: !preview && geometry.layout != .custom, extraOpen: openExtra != nil)
        let extraHeight = split.extra, showsPlayer = split.showsPlayer, playerHeight = split.player
        VStack(spacing: NotchLayout.rowSpacing) {
            if showsPlayer {
                if let playback = service.playback {
                    player(playback, height: playerHeight)
                } else if !service.awaitingPlayback {
                    idle(height: playerHeight)
                } else {
                    Color.clear.frame(height: playerHeight)
                }
            }
            if let openExtra, let playback = service.playback {
                Group {
                    switch openExtra {
                    case .lyrics: NotchLyricsView(playback: playback)
                    case .queue: NotchQueueView(playback: playback)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: extraHeight, alignment: .top)
                .clipped()
                // Clipping hides what spills over; this keeps it from taking
                // clicks too, so the transport above always answers.
                .contentShape(Rectangle())
            }
            if hasControlsRow {
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    if AppFeature.mixer.isAvailable { NotchAudioControls(style: .inline) }
                    Spacer(minLength: NotchDesign.Spacing.large)
                    if showsLyrics {
                        extraButton(.lyrics, title: FeatureStrings.notchMusicExtras(l10n.language).lyrics, symbol: "quote.bubble")
                    }
                    if showsQueue {
                        extraButton(.queue, title: FeatureStrings.notchMusicExtras(l10n.language).queue, symbol: "list.bullet")
                    }
                }
                .frame(height: NotchLayout.musicControlsRowHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            // A preview in Settings leaves the island's size and extras alone.
            guard !preview else { return }
            syncExtras()
            service.refreshAutomation()
            shuffle.refresh(for: service.playback)
        }
        .onChange(of: extra) { syncExtras() }
        .onChange(of: service.playback.map(NotchMusicIdentity.init)) {
            syncExtras()
            if !preview { shuffle.refresh(for: service.playback) }
        }
        // Shuffle and the playback buttons share one consent, so a grant
        // through the playback buttons also shows on shuffle.
        .onChange(of: service.automationAvailability?.access) { old, new in
            if !preview, old != nil, new != nil { shuffle.refresh(for: service.playback) }
        }
        .onChange(of: features.revision) { syncExtras() }
        .onChange(of: lyricsEnabled) { syncExtras() }
        .onChange(of: queueEnabled) { syncExtras() }
        .onDisappear {
            guard !preview else { return }
            NotchService.shared.setMusicDetailsVisible(false)
            NotchService.shared.setPageLayer(.music, close: nil)
            NotchLyricsService.shared.hide()
            service.setQueueVisible(false)
            shuffle.stop()
        }
    }

    private func syncExtras() {
        guard !preview else { return }
        NotchService.shared.setMusicDetailsVisible(openExtra != nil)
        // Escape closes lyrics or the queue before the island.
        NotchService.shared.setPageLayer(.music, close: openExtra == nil ? nil : { extra = nil })
        NotchLyricsService.shared.update(playback: service.playback, visible: extra == .lyrics)
        service.setQueueVisible(extra == .queue)
    }

    private func idle(height: CGFloat) -> some View {
        let player = preview ? nil : NotchPreferredPlayer.current()
        let opens = player != nil
        let openTitle = player.map { NotchPreferredPlayer.openTitle(for: $0) } ?? ""
        let plateShape = RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
        return HStack(spacing: NotchDesign.Spacing.large) {
            // With a music app to open, the cover and the button beside it open it.
            Button { NotchPreferredPlayer.open() } label: {
                Image(systemName: "music.note")
                    .font(NotchDesign.Icon.hero.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .frame(width: NotchDesign.Control.heroGlyph, height: NotchDesign.Control.heroGlyph)
                    .background(NotchDesign.Fill.card, in: plateShape)
                    .contentShape(plateShape)
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.card)))
            .disabled(!opens)
            .help(openTitle)
            .accessibilityLabel(opens ? openTitle : text.mediaNothingPlaying)
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                if !service.sources.isEmpty || !service.sourceIsAutomatic {
                    sourcePicker(nil)
                } else {
                    Text(text.mediaNothingPlaying)
                        .font(NotchDesign.Typography.hero.font)
                        .foregroundStyle(NotchDesign.Ink.primary)
                }
                if opens {
                    Button { NotchPreferredPlayer.open() } label: {
                        Text(openTitle)
                            .font(NotchDesign.Typography.label.font)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .lineLimit(1)
                            .padding(.horizontal, NotchDesign.Spacing.medium)
                            .frame(height: NotchDesign.Control.rowHeight)
                            .background(NotchDesign.Fill.control, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
                } else {
                    Text(FeatureStrings.notch(l10n.language).musicHint)
                        .font(NotchDesign.Typography.callout.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
    }

    /// Lyrics and the queue are toggles beside the volume, named by their
    /// glyphs as a player's own are.
    private func extraButton(_ target: MusicExtra, title: String, symbol: String) -> some View {
        Toggle(isOn: Binding(get: { extra == target }, set: { extra = $0 ? target : nil })) { Text(title) }
            .toggleStyle(NotchToggleStyle(symbol: symbol, shape: .rounded(NotchDesign.Radius.control),
                                          size: NotchDesign.Control.iconButton, symbolSize: 13))
            .help(title)
    }

    /// The player's own shuffle switch. A player not yet allowed to be
    /// controlled asks for that first, as the playback buttons do.
    private func shuffleButton() -> some View {
        let strings = FeatureStrings.notchMusicExtras(l10n.language)
        let consent = shuffle.availability?.access == .consent
        return Toggle(isOn: Binding(get: { shuffle.enabled == true }, set: { _ in shuffle.toggle() })) { Text(strings.shuffle) }
            .toggleStyle(NotchToggleStyle(symbol: "shuffle", shape: .capsule, size: NotchDesign.Music.sidePlate,
                                          symbolSize: 15, tint: toggleTint))
            .disabled(shuffle.requestingAccess || !shuffle.allowed)
            .help(consent ? strings.allowPlayback : strings.shuffle)
            .accessibilityHint(consent ? strings.allowPlayback : "")
    }

    /// The artwork fills the row; the details beside it drop their artist
    /// line, then the timeline, before they would overflow a short island.
    private func player(_ playback: NotchPlayback, height: CGFloat) -> some View {
        let roomy = height >= NotchDesign.Music.roomyHeight
        let haloShadow = NotchDesign.Shadow.halo(halo)
        return HStack(spacing: roomy ? NotchDesign.Spacing.xLarge : NotchDesign.Spacing.large) {
            Button { RadialNowPlayingApplication.open(playback.track) } label: {
                NotchMusicPageCover(image: service.artwork, size: height)
                    .scaleEffect(playback.isPlaying || reduceMotion ? 1 : NotchDesign.Music.pausedArtworkScale)
                    .shadow(color: haloShadow.color, radius: haloShadow.radius, y: haloShadow.y)
                    .animation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion),
                               value: playback.isPlaying)
                    .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.smooth.animation,
                               value: halo)
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.artwork(side: height)), washes: false))
            .help(text.mediaNowPlaying)
            .accessibilityLabel(text.mediaNowPlaying)
            ViewThatFits(in: .vertical) {
                if roomy { details(playback, titleLines: 2, artist: true, timeline: true, roomy: roomy) }
                details(playback, titleLines: 1, artist: true, timeline: true, roomy: roomy)
                details(playback, titleLines: 1, artist: false, timeline: true, roomy: roomy)
                details(playback, titleLines: 1, artist: false, timeline: false, roomy: roomy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .modifier(NotchMusicSwipeFeedback())
    }

    private func details(_ playback: NotchPlayback, titleLines: Int, artist: Bool, timeline: Bool, roomy: Bool) -> some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                HStack(alignment: .firstTextBaseline, spacing: NotchDesign.Spacing.small) {
                    Text(playback.track.title ?? text.mediaNowPlaying)
                        .font(NotchDesign.Typography.hero.font)
                        .foregroundStyle(NotchDesign.Ink.primary)
                        .lineLimit(titleLines).help(playback.track.title ?? text.mediaNowPlaying)
                    Spacer(minLength: 0)
                    if service.sources.count > 1 || !service.sourceIsAutomatic {
                        sourcePicker(playback)
                    }
                    if playback.isPlaying {
                        NotchLiveEqualizerBars(height: 14, tint: accent)
                            .transition(.opacity)
                    }
                }
                if artist {
                    Text(service.commandFailed ? FeatureStrings.notchMusicExtras(l10n.language).playbackFailed
                         : playback.track.artist ?? playback.track.album ?? text.mediaNowPlaying)
                        .font(NotchDesign.Typography.callout.font)
                        .foregroundStyle(service.commandFailed ? NotchDesign.Palette.warning : NotchDesign.Ink.secondary)
                        .lineLimit(1)
                }
            }
            if timeline { NotchMusicTimeline(playback: playback, service: service, tint: accent, timesBeside: true) }
            if !preview && shuffle.isOffered {
                // Shuffle sits beside the transport as one more of its buttons,
                // spaced like them. The other side keeps its room while it
                // shows, so the transport stays centred. A column too narrow
                // for the row keeps the plain transport.
                let side: CGFloat = roomy ? NotchDesign.Control.transport : NotchDesign.Control.transportCompact
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: NotchDesign.Spacing.large) {
                        shuffleButton().frame(width: side, height: side)
                        NotchMusicTransport(playback: playback, compact: !roomy).fixedSize()
                        Color.clear.frame(width: side, height: side)
                    }
                    NotchMusicTransport(playback: playback, compact: !roomy)
                }
                .frame(maxWidth: .infinity)
            } else {
                NotchMusicTransport(playback: playback, compact: !roomy).frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sourcePicker(_ playback: NotchPlayback?) -> some View {
        let extras = FeatureStrings.notchMusicExtras(l10n.language)
        let pid = playback?.track.appPID
        let name = service.sources.first(where: { $0.pid == pid })?.displayName
            ?? pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName }
            ?? playback?.track.appBundleIdentifier ?? extras.playbackSource
        var items = [NotchSourceMenuItem(title: extras.automaticSource, checked: service.sourceIsAutomatic,
                                         action: { service.selectSource(nil) }), .separator]
        for source in service.sources {
            let title = source.displayName ?? NSRunningApplication(processIdentifier: source.pid)?.localizedName ?? source.bundleIdentifier
            // The chosen row, even while the automatic player fills its gap.
            items.append(NotchSourceMenuItem(title: title, checked: source.pid == service.selectedSourcePID,
                                             icon: NotchSourceMenuAnchor.icon(bundleIdentifier: source.bundleIdentifier),
                                             action: { service.selectSource(source.selection) }))
        }
        return NotchSourceMenuButton(items: items) {
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                Text(name).lineLimit(1).truncationMode(.tail)
                    .font(NotchDesign.Typography.callout.font)
                Image(systemName: "chevron.down").font(NotchDesign.Icon.strip.font)
            }
            .foregroundStyle(NotchDesign.Ink.secondary)
            .frame(maxWidth: 140, minHeight: NotchDesign.Control.minimumHit)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(extras.playbackSource)
        .accessibilityValue([service.sourceIsAutomatic ? extras.automaticSource : nil,
                             playback == nil ? nil : name].compactMap { $0 }.joined(separator: ", "))
        .help(extras.playbackSource)
    }
}

/// The transport as it looks with nothing playing. Every button opens the
/// music app, since there is no player to send a command to yet.
struct NotchMusicIdleTransport: View {
    var compact = false
    let openTitle: String
    @ObservedObject private var l10n = L10n.shared
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var height: CGFloat { compact ? NotchDesign.Control.transportCompact : NotchDesign.Control.transport }

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.large) {
            button("backward.fill", title: text.mediaPrevious, style: NotchDesign.Icon.transport)
            button("play.fill", title: text.mediaPlayPause, style: NotchDesign.Icon.transportPrimary)
            button("forward.fill", title: text.mediaNext, style: NotchDesign.Icon.transport)
        }
        .frame(height: height)
    }

    private func button(_ symbol: String, title: String, style: NotchDesign.TypeStyle) -> some View {
        Button { NotchPreferredPlayer.open() } label: {
            Image(systemName: symbol)
                .font(style.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
        .accessibilityLabel(title)
        // VoiceOver says what the press does: it opens the app, not a skip.
        .accessibilityHint(openTitle)
        .help(openTitle)
    }
}

private struct NotchMusicTransport: View {
    let playback: NotchPlayback
    /// The home card and a short player use the smaller buttons.
    var compact = false
    // Automation discovery and consent finish after the first render while the
    // track stays the same, so this row must observe the service itself.
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    /// What a tap on play or pause asked for, shown at once while the player
    /// takes its round trip to say so. It gives way to the player's word.
    @State private var requestedPlaying: Bool?
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var height: CGFloat { compact ? NotchDesign.Control.transportCompact : NotchDesign.Control.transport }
    private var showsPlaying: Bool { requestedPlaying ?? playback.isPlaying }

    var body: some View {
        if !playback.canSendCommandsDirectly, service.automationAvailability?.access != .granted {
            HStack(spacing: NotchDesign.Spacing.small) {
                toggleButton
                if service.automationAvailability?.access == .consent {
                    pill(FeatureStrings.notchMusicExtras(l10n.language).allowPlayback) { service.requestAutomationAccess() }
                        .disabled(service.requestingAutomation)
                    if service.requestingAutomation { ProgressView().controlSize(.small) }
                } else if service.automationAvailability?.access == .denied {
                    pill(l10n.s.permissionOpenSettings) { Permissions.shared.openAutomationSettings() }
                    Button { service.refreshAutomation() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(NotchDesign.Icon.button.font)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                    }
                    .buttonStyle(NotchPressStyle(shape: .capsule))
                    .accessibilityLabel(FeatureStrings.notchMusicExtras(l10n.language).refresh)
                } else {
                    pill(FeatureStrings.notchMusicExtras(l10n.language).openPlayer) { RadialNowPlayingApplication.open(playback.track) }
                }
            }
            .frame(height: height)
        } else {
            transportButtons
        }
    }

    /// A word on a plate for the step that gets playback going.
    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(NotchDesign.Typography.label.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .lineLimit(1)
                .padding(.horizontal, NotchDesign.Spacing.medium)
                .frame(height: NotchDesign.Control.rowHeight)
                .background(NotchDesign.Fill.control, in: Capsule(style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
    }

    /// The player's own glyphs, white on the island with no plate behind
    /// them, as on the lock screen. Play and pause stand out by size.
    private var transportButtons: some View {
        HStack(spacing: NotchDesign.Spacing.large) {
            if !service.lacksTrackSkipping(.previous) {
                playbackButton("backward.fill", title: text.mediaPrevious, command: .previous)
            }
            toggleButton
            if !service.lacksTrackSkipping(.next) {
                playbackButton("forward.fill", title: text.mediaNext, command: .next)
            }
        }
        .frame(height: height)
    }

    private var toggleButton: some View {
        Button {
            if service.canPerform(.toggle) {
                // Only a player the island writes to directly answers fast enough
                // to show its word early; a slower path waits for the player.
                let direct = playback.canSendCommandsDirectly
                if service.send(.toggle, context: playback.commandContext), direct { requestedPlaying = !showsPlaying }
            } else { service.requestAutomationAccess() }
        } label: {
            Image(systemName: showsPlaying ? "pause.fill" : "play.fill")
                .font(NotchDesign.Icon.transportPrimary.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .notchSymbolReplace(reduceMotion: reduceMotion)
                .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.snappy.animation, value: showsPlaying)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
        // A second tap before the player answers asks for the state after it,
        // so only the player reaching what was asked ends the early word.
        .onChange(of: playback.isPlaying) { if playback.isPlaying == requestedPlaying { requestedPlaying = nil } }
        .onChange(of: playback.track) { requestedPlaying = nil }
        // A player that never answers leaves the button as it was.
        .task(id: requestedPlaying) {
            guard requestedPlaying != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { requestedPlaying = nil }
        }
        .disabled(!service.canPerform(.toggle)
                  && (service.automationAvailability?.access != .consent || service.requestingAutomation))
        // A preview in Settings must not take Space from the window it sits in.
        .keyboardShortcut(preview ? nil : KeyboardShortcut(.space, modifiers: []))
        .accessibilityLabel(text.mediaPlayPause)
        .help(service.automationAvailability?.access == .consent
              ? FeatureStrings.notchMusicExtras(l10n.language).allowPlayback : text.mediaPlayPause)
    }

    private func playbackButton(_ symbol: String, title: String, command: NotchMusicService.Command) -> some View {
        Button { service.send(command, context: playback.commandContext) } label: {
            Image(systemName: symbol)
                .font(NotchDesign.Icon.transport.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
        .disabled(!service.canPerform(command))
        .accessibilityLabel(title)
        .help(title)
    }
}

struct NotchMusicTimeline: View {
    let playback: NotchPlayback
    @ObservedObject var service: NotchMusicService
    var tint: Color = .white
    /// The island's player sets the times beside the bar, as a phone's
    /// island does, which leaves its short row room for the artist.
    var timesBeside = false
    @ObservedObject private var l10n = L10n.shared
    @State private var scrubPosition: Double?
    @State private var scrubTrack: RadialNowPlayingSnapshot?
    @State private var scrubContext: NotchPlaybackContext?
    @State private var pendingSeek: UUID?

    var body: some View {
        if playback.duration > 0 {
            TimelineView(.animation(minimumInterval: 1, paused: !playback.isPlaying)) { context in
                let position = scrubPosition ?? playback.position(at: context.date)
                Group {
                    if timesBeside {
                        HStack(spacing: NotchDesign.Spacing.small) {
                            // The song's longest reading holds each side's
                            // width, so the bar keeps its length as it plays.
                            ZStack(alignment: .leading) {
                                Text(timestamp(playback.duration)).hidden()
                                Text(timestamp(position))
                            }
                            bar(position)
                            ZStack(alignment: .trailing) {
                                Text("−" + timestamp(playback.duration)).hidden()
                                Text("−" + timestamp(playback.duration - position))
                            }
                        }
                    } else {
                        VStack(spacing: NotchDesign.Spacing.line) {
                            bar(position)
                            HStack {
                                Text(timestamp(position))
                                Spacer()
                                Text("−" + timestamp(playback.duration - position))
                            }
                        }
                    }
                }
                .font(NotchDesign.Typography.caption.font)
                .monospacedDigit()
                .foregroundStyle(NotchDesign.Ink.secondary)
            }
            .frame(height: timesBeside ? NotchDesign.Music.timelineRow : 30)
            .onChange(of: playback.track) { clearScrub() }
            .onChange(of: playback.commandContext) { clearScrub() }
            .onChange(of: playback.sampledAt) {
                if pendingSeek != nil, let scrubPosition,
                   abs(playback.position(at: Date()) - scrubPosition) <= 2 { clearScrub() }
            }
            .task(id: pendingSeek) {
                guard pendingSeek != nil else { return }
                // Keep the released thumb still while the player responds,
                // but always return to observed playback if it ignores seeking.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                clearScrub()
            }
        }
    }

    @ViewBuilder private func bar(_ position: TimeInterval) -> some View {
        if service.canSeek {
            NotchSlider(
                value: Binding(get: { position }, set: {
                    if scrubTrack == nil {
                        scrubTrack = playback.track
                        scrubContext = playback.commandContext
                    }
                    scrubPosition = $0
                }),
                label: FeatureStrings.notch(l10n.language).playbackPosition,
                range: 0...playback.duration,
                tint: tint,
                valueText: timestamp(position),
                onEditingChanged: { editing in
                    if editing {
                        pendingSeek = nil
                    } else if let scrubPosition, let scrubTrack {
                        service.seek(to: scrubPosition, in: scrubTrack, context: scrubContext)
                        pendingSeek = UUID()
                    }
                })
                .frame(height: 10)
                .disabled(service.commandPending)
        } else {
            NotchMeter(value: position / playback.duration, height: NotchDesign.Control.sliderTrack, tint: tint)
        }
    }

    private func clearScrub() {
        pendingSeek = nil
        scrubPosition = nil
        scrubTrack = nil
        scrubContext = nil
    }

    private func timestamp(_ interval: TimeInterval) -> String {
        let seconds = Int(min(604_800, max(0, interval)))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The home surface shares playback actions without opening lyrics or queue readers.
struct NotchMusicControlsView: View {
    @ObservedObject var notch: NotchService
    var height: CGFloat = NotchLayout.cardHeight
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var preview
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var isIdle: Bool {
        !preview && music.playback == nil && !music.awaitingPlayback
    }

    var body: some View {
        let player = isIdle ? NotchPreferredPlayer.current() : nil
        let idleOpens = player != nil
        let openTitle = player.map { NotchPreferredPlayer.openTitle(for: $0) } ?? ""
        HStack(spacing: NotchDesign.Spacing.medium) {
            // With nothing playing, the cover opens the music app instead.
            Button {
                if isIdle, NotchPreferredPlayer.open() { return }
                notch.select(.music)
            } label: {
                NotchMusicPageCover(image: music.artwork, size: max(40, height - 2 * NotchDesign.Spacing.cardPadding))
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), washes: false))
            .accessibilityLabel(idleOpens ? openTitle : text.mediaNowPlaying)
            .help(idleOpens ? openTitle : text.mediaNowPlaying)
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.xxSmall) {
                Button { notch.select(.music) } label: {
                    VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                        Text(music.playback?.track.title ?? (music.awaitingPlayback ? text.mediaNowPlaying : text.mediaNothingPlaying))
                            .font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.primary).lineLimit(1)
                        // A shortened card keeps the title and the transport.
                        if height >= 84 {
                            Text(music.commandFailed ? FeatureStrings.notchMusicExtras(l10n.language).playbackFailed
                                 : music.playback?.track.artist ?? music.playback?.track.album
                                    ?? (music.awaitingPlayback ? "" : FeatureStrings.notch(l10n.language).musicHint))
                                .font(NotchDesign.Typography.callout.font)
                                .foregroundStyle(music.commandFailed ? NotchDesign.Palette.warning : NotchDesign.Ink.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.small), lifts: false, washes: false))
                if let playback = music.playback {
                    NotchMusicTransport(playback: playback, compact: true).frame(maxWidth: .infinity)
                } else if idleOpens {
                    NotchMusicIdleTransport(compact: true, openTitle: openTitle).frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NotchDesign.Spacing.cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .modifier(NotchControlSurface(cornerRadius: NotchDesign.Radius.card))
        .onAppear { if !preview { music.refreshAutomation() } }
    }
}

private struct NotchSourceMenuItem {
    let title: String
    var checked = false
    var icon: NSImage? = nil
    var action: () -> Void = {}
    static let separator = NotchSourceMenuItem(title: "")
    var isSeparator: Bool { title.isEmpty }
}

/// A pull-down for the playback source: the menu hangs under the button with
/// its leading edge on the button's, and swings to the trailing edge when the
/// button sits in the island's right half, so it never leaves the island.
/// NotchMenuAnchor cannot place a menu sideways or carry app icons, hence this.
private struct NotchSourceMenuButton<Label: View>: View {
    let items: [NotchSourceMenuItem]
    @ViewBuilder let label: () -> Label
    @State private var anchor = NotchSourceMenuAnchor()

    var body: some View {
        Button { anchor.popUp(items) } label: { label() }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
            .background(NotchSourceMenuAnchorView(anchor: anchor))
    }
}

private final class NotchSourceMenuAnchor: NSObject {
    weak var view: NSView?
    private var actions: [() -> Void] = []

    /// The app's own icon at menu size, nil when the app cannot be found.
    static func icon(bundleIdentifier: String?) -> NSImage? {
        guard let id = bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    func popUp(_ items: [NotchSourceMenuItem]) {
        guard let view else { return }
        actions = items.map(\.action)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: 13)
        // The island is dark whatever the system is, so its menus are too.
        menu.appearance = NSAppearance(named: .darkAqua)
        for (index, item) in items.enumerated() {
            guard !item.isSeparator else { menu.addItem(.separator()); continue }
            let entry = NSMenuItem(title: item.title, action: #selector(choose(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = index
            entry.state = item.checked ? .on : .off
            entry.image = item.icon
            menu.addItem(entry)
        }
        var x: CGFloat = 0
        if let window = view.window {
            let centre = view.convert(NSPoint(x: view.bounds.midX, y: 0), to: nil).x
            if centre > window.frame.width / 2 { x = view.bounds.width - menu.size.width }
        }
        // The view is not flipped: y 0 is its bottom edge, so the menu opens under it.
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: view.isFlipped ? view.bounds.height : 0), in: view)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}

private struct NotchSourceMenuAnchorView: NSViewRepresentable {
    let anchor: NotchSourceMenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { anchor.view = nsView }
}
