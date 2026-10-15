// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

extension NotchDesign {
    /// Values only the lock screen draws; everything else comes from the shared tokens.
    enum LockScreen {
        /** The player pane's corner: continuous, concentric with the 112 pt cover plus the pane's inset. */ static let paneRadius: CGFloat = 34
        /** The player pane's side inset: 24 plus the 2 pt line step, measured off the timeline's width. */ static let paneInset: CGFloat = 26
        /** Transport buttons' gap on the pane: Spacing.xxLarge plus Spacing.large. */ static let transportGap: CGFloat = 40
        /** Transport button hit width: the 44 pt circle plus Spacing.xSmall. */ static let transportHitWidth: CGFloat = 50
        /** The activities line's capsule inset, a line of 15 pt type with room to breathe. */ static let lineInset = EdgeInsets(top: NotchDesign.Spacing.xSmall, leading: NotchDesign.Spacing.large,
                                                                                                                              bottom: NotchDesign.Spacing.xSmall, trailing: NotchDesign.Spacing.large)
        /** Time readouts under the system clock: 15 pt rounded, a step below the clock, digits monospaced. */ static let readout = NotchDesign.TypeStyle(style: .title3, weight: .semibold, rounded: true)
        /** The padlock's glyph. */ static let padlock = NotchDesign.Icon.strip
    }
}

/// What the lock screen may show, settled when it appears: preferences cannot
/// change while the Mac is locked, so the views never read them again.
final class NotchLockScreenModel: ObservableObject {
    struct Gates: Equatable {
        var music = false
        var timer = false
        var agents = false
        var downloads = false
        var countdown = false
        var timeLeft = false
        var battery = false
        var keepAwake = false
    }

    @Published var gates = Gates()
    /// Kept for the whole time the Mac stays locked, across the display
    /// sleeping and waking, and cleared once it unlocks.
    @Published var playedWhileLocked = false
    @Published var padlockOpen = false

    func showsMusic(_ playback: NotchPlayback?) -> Bool {
        gates.music && playback.map {
            NotchLockScreenSupport.showsMusic(isPlaying: $0.isPlaying, playedWhileLocked: playedWhileLocked)
        } == true
    }
}

/// The island at rest with a padlock beside the camera, and the music's bars
/// on the other side while a song plays. The padlock closes as the Mac locks
/// and opens as it unlocks, before the island returns underneath.
struct NotchLockScreenIsland: View {
    @ObservedObject var model: NotchLockScreenModel
    let size: CGSize
    let cameraWidth: CGFloat
    /// The music strip's own geometry: the padlock takes the cover's place and
    /// the bars keep theirs, so locking changes what shows, not where.
    let geometry: NotchGeometry
    /// The window on whole points around the island, and the island's top
    /// left corner inside it; the rest of the window stays clear.
    var window: CGSize? = nil
    var origin: CGPoint = .zero
    @ObservedObject private var music = NotchMusicService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let wing = max(0, (size.width - cameraWidth) / 2)
        let padlockSide = min(geometry.compactMusicArtworkSide, wing)
        let playing = model.showsMusic(music.playback) && music.playback?.isPlaying == true
        NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: size.height))
            .fill(.black)
            .overlay {
                HStack(spacing: 0) {
                    Image(systemName: model.padlockOpen ? "lock.open.fill" : "lock.fill")
                        .font(NotchDesign.LockScreen.padlock.font)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, options: .speed(1.4), value: reduceMotion ? false : model.padlockOpen)
                        .animation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion), value: model.padlockOpen)
                        .frame(width: padlockSide, height: padlockSide)
                        .padding(.leading, max(0, min(geometry.compactMusicArtworkInset, wing - padlockSide)))
                        .frame(width: wing, height: size.height, alignment: .leading)
                    Spacer(minLength: 0)
                    NotchEqualizerBars(isPlaying: playing, bars: NotchLayout.compactMusicBarCount,
                                       barWidth: NotchLayout.compactMusicBarWidth, height: geometry.compactMusicBarHeight,
                                       tint: music.artworkTint?.color ?? .white)
                        .opacity(playing ? 1 : 0)
                        .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.smooth.animation, value: playing)
                        .padding(.trailing, max(0, min(geometry.compactMusicBarsInset, wing - NotchLayout.compactMusicBarsWidth)))
                        .frame(width: wing, height: size.height, alignment: .trailing)
                }
            }
            .frame(width: size.width, height: size.height)
            .padding(.leading, origin.x)
            .padding(.top, origin.y)
            .frame(width: window?.width ?? size.width, height: window?.height ?? size.height, alignment: .topLeading)
            .accessibilityHidden(true)
    }
}

/// The player's own Liquid Glass, clear so the wallpaper still reads through
/// it and bends at its edges, and smoked just enough for white type over any
/// photo: the glass the island itself takes when it is set to glass. Before
/// macOS 26 the frosted panel of the app's floating surfaces stands in, and
/// Reduce Transparency makes it solid.
private struct NotchLockScreenGlass: ViewModifier {
    let cornerRadius: CGFloat
    /// Black kept under the glass; Glass.textDim wherever type sits on it, so it holds 4.5 to 1 over a white photo.
    var dim: Double = NotchDesign.Glass.textDim
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color.black)
                } else {
                    ZStack {
                        glass(shape)
                        shape.fill(.black.opacity(contrast == .increased ? NotchDesign.Glass.increasedContrastDim : dim))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(contrast == .increased ? NotchDesign.Stroke.increasedContrast : NotchDesign.Stroke.glassEdge,
                                   lineWidth: contrast == .increased ? NotchDesign.Stroke.increasedContrastWidth : NotchDesign.Stroke.hairline)
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder private func glass(_ shape: RoundedRectangle) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(.clear, in: shape)
                .environment(\.appearsActive, true)
                .materialActiveAppearance(.active)
        } else {
            NotchLockScreenMaterial(cornerRadius: cornerRadius)
        }
#else
        NotchLockScreenMaterial(cornerRadius: cornerRadius)
#endif
    }
}

/// The frosted material has to round its own layer: SwiftUI clips what it
/// draws, not a material blurring what lies behind the window.
private struct NotchLockScreenMaterial: NSViewRepresentable {
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

/// The song in the middle of the lock screen, on one pane of Liquid Glass:
/// the cover, its title, a timeline that seeks and the player's own buttons.
/// A smaller display takes a smaller cover, then lays it beside the title.
struct NotchLockScreenPlayer: View {
    @ObservedObject var model: NotchLockScreenModel
    let size: CGSize
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What a tap on play or pause asked for, shown at once as the island's
    /// own player shows it, until the player says so.
    @State private var requestedPlaying: Bool?
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var accent: Color { music.artworkTint?.color ?? .white }

    var body: some View {
        let shown = model.showsMusic(music.playback)
        ZStack {
            if shown, let playback = music.playback {
                ViewThatFits(in: .vertical) {
                    player(playback, artwork: 112)
                    player(playback, artwork: 84)
                    compact(playback)
                }
                // Exits faster than it enters (Motion.exit), as the spec asks.
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                                                  removal: .opacity.animation(NotchDesign.Motion.exit)))
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.smooth.animation, value: shown)
        // A second tap before the player answers asks for the state after it,
        // so only the player reaching what was asked ends the early word.
        .onChange(of: music.playback?.isPlaying) {
            if music.playback?.isPlaying == requestedPlaying { requestedPlaying = nil }
        }
        .onChange(of: music.playback?.track) { requestedPlaying = nil }
        // A player that never answers leaves the button as it was.
        .task(id: requestedPlaying) {
            guard requestedPlaying != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { requestedPlaying = nil }
        }
    }

    private func player(_ playback: NotchPlayback, artwork: CGFloat) -> some View {
        VStack(spacing: 0) {
            cover(size: artwork, playback: playback)
                .padding(.bottom, NotchDesign.Spacing.medium)
            Text(playback.track.title ?? text.mediaNowPlaying)
                .font(NotchDesign.Typography.hero.font)
                .lineLimit(1)
            if let artist = playback.track.artist ?? playback.track.album {
                Text(artist)
                    .font(NotchDesign.Typography.callout.font)
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .lineLimit(1)
                    .padding(.top, NotchDesign.Spacing.line)
            }
            NotchMusicTimeline(playback: playback, service: music, tint: accent)
                .padding(.top, NotchDesign.Spacing.large)
            transport(playback)
        }
        .pane()
    }

    /// A short display lays the cover beside the title, as the island's own
    /// player does.
    private func compact(_ playback: NotchPlayback) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: NotchDesign.Spacing.medium) {
                cover(size: 52, playback: playback)
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                    Text(playback.track.title ?? text.mediaNowPlaying)
                        .font(NotchDesign.Typography.pageTitle.font)
                    if let artist = playback.track.artist ?? playback.track.album {
                        Text(artist).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.primary)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            NotchMusicTimeline(playback: playback, service: music, tint: accent)
                .padding(.top, NotchDesign.Spacing.medium)
            transport(playback)
        }
        .pane()
    }

    private func cover(size: CGFloat, playback: NotchPlayback) -> some View {
        NotchArtwork(image: music.artwork, size: size)
            .shadow(color: NotchDesign.Shadow.halo(music.artworkTint?.color ?? .black).color, radius: NotchDesign.Shadow.halo(.black).radius,
                    y: NotchDesign.Shadow.halo(.black).y)
            .scaleEffect(playback.isPlaying || reduceMotion ? 1 : 0.92)
            .animation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion), value: playback.isPlaying)
    }

    /// The player's own buttons, never a permission prompt: a request made
    /// here would open behind the lock screen, where no one can answer it.
    private func transport(_ playback: NotchPlayback) -> some View {
        HStack(spacing: NotchDesign.LockScreen.transportGap) {
            if !music.lacksTrackSkipping(.previous) {
                button("backward.fill", style: NotchDesign.Icon.transport, title: text.mediaPrevious, command: .previous, playback: playback)
            }
            button((requestedPlaying ?? playback.isPlaying) ? "pause.fill" : "play.fill", style: NotchDesign.Icon.transportPrimary,
                   title: text.mediaPlayPause, command: .toggle, playback: playback)
            if !music.lacksTrackSkipping(.next) {
                button("forward.fill", style: NotchDesign.Icon.transport, title: text.mediaNext, command: .next, playback: playback)
            }
        }
        .frame(height: NotchDesign.Control.transport)
    }

    private func button(_ symbol: String, style: NotchDesign.TypeStyle, title: String, command: NotchMusicService.Command,
                        playback: NotchPlayback) -> some View {
        Button {
            let playing = requestedPlaying ?? playback.isPlaying
            // Only a player the island writes to directly answers fast enough
            // to show its word early. A slower path waits for the player.
            if music.send(command, context: playback.commandContext), command == .toggle,
               playback.canSendCommandsDirectly { requestedPlaying = !playing }
        } label: {
            Image(systemName: symbol)
                .font(style.font)
                .foregroundStyle(.white)
                .notchSymbolReplace(reduceMotion: reduceMotion)
                .animation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion), value: symbol)
                .frame(width: NotchDesign.LockScreen.transportHitWidth, height: NotchDesign.Control.transport)
                .contentShape(Circle())
        }
        // Tap class: it lands on mouse down, and the glyph swaps at once.
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Control.transport / 2)))
        .disabled(!music.canPerform(command))
        .accessibilityLabel(title)
    }
}

private extension View {
    /// The player's pane, as wide as the timeline needs and no wider.
    func pane() -> some View {
        foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, NotchDesign.LockScreen.paneInset)
            .padding(.vertical, NotchDesign.Spacing.xLarge)
            .frame(width: NotchLockScreenLayout.paneWidth)
            .modifier(NotchLockScreenGlass(cornerRadius: NotchDesign.LockScreen.paneRadius))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The activities as one line under the clock, where a phone keeps the
/// widgets of its lock screen: a mark and a reading each, with no card. A
/// line too long for the display gives up its last activities first.
struct NotchLockScreenActivities: View {
    @ObservedObject var model: NotchLockScreenModel
    let size: CGSize
    @ObservedObject private var timer = NotchTimerService.shared
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchAgentsReadout) private var readout = NotchAgentReadout.elapsed.rawValue
    @AppStorage(DefaultsKey.notchAgentsLimitDisplay) private var display = NotchAgentLimitDisplay.remaining.rawValue
    @AppStorage(DefaultsKey.notchAgentsLimitFocus) private var focus = NotchAgentLimitFocus.mostUsed.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let items = available(at: context.date)
            ViewThatFits(in: .horizontal) {
                line(items, at: context.date)
                line(Array(items.prefix(3)), at: context.date)
                line(Array(items.prefix(2)), at: context.date)
                line(Array(items.prefix(1)), at: context.date)
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.smooth.animation, value: items)
        }
        .allowsHitTesting(false)
    }

    private func available(at date: Date) -> [NotchLockScreenActivity] {
        let gates = model.gates
        return NotchLockScreenSupport.activities(
            timer: gates.timer && timer.session.hasSession,
            calendar: calendar.countdown.map {
                ($0.ongoing ? gates.timeLeft : gates.countdown || calendar.isChosen($0.event)) && $0.isShown(at: date)
            } == true,
            agents: gates.agents && !usage.snapshot.live.isEmpty,
            downloads: gates.downloads && downloads.items.contains { $0.active && !$0.completed },
            battery: gates.battery && CachedBattery.snapshot() != nil,
            keepAwake: gates.keepAwake && awake.isActive)
    }

    private func line(_ items: [NotchLockScreenActivity], at date: Date) -> some View {
        HStack(spacing: NotchDesign.Spacing.xxLarge) {
            ForEach(items) { item in
                entry(item, at: date)
                    .transition(.opacity)
            }
        }
        .font(NotchDesign.LockScreen.readout.font)
        .monospacedDigit()
        .foregroundStyle(NotchDesign.Ink.primary)
        .lineLimit(1)
        .fixedSize()
        .padding(NotchDesign.LockScreen.lineInset)
        // Vibrant like Apple's clock widgets, but on the player's dimmed glass: every reading holds 4.5 to 1 over any wallpaper.
        .modifier(NotchLockScreenGlass(cornerRadius: .infinity))
    }

    @ViewBuilder private func entry(_ item: NotchLockScreenActivity, at date: Date) -> some View {
        switch item {
        case .timer:
            let session = timer.session
            let now = timer.now
            let finished = NotchLockScreenSupport.timerFinished(session, at: now)
            let text = FeatureStrings.notchActivities(l10n.language)
            let clock = finished ? text.finished : NotchTimerSupport.clockText(for: session, at: now)
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                Image(systemName: finished ? "checkmark.circle" : session.isPaused ? "pause.circle"
                      : session.countsUp ? "stopwatch" : "timer")
                    .contentTransition(.symbolEffect(.replace))
                Text(session.mode == .pomodoro && !finished ? text.phase(session.phase) + " " + clock : clock)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text.phase(session.phase))
            .accessibilityValue(clock)
        case .calendar:
            if let countdown = calendar.countdown {
                let text = FeatureStrings.notchCalendar(l10n.language)
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    Image(systemName: "calendar")
                    Text(NotchCalendarStrip.displayTitle(countdown.event, untitled: text.untitled))
                        .frame(maxWidth: 240, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NotchCalendarSupport.countdownText(until: countdown.target, now: date))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(countdown.ongoing ? text.ongoing : text.next)
                .accessibilityValue(NotchCalendarStrip.displayTitle(countdown.event, untitled: text.untitled) + ", "
                                    + NotchCalendarSupport.countdownText(until: countdown.target, now: date))
            }
        case .agents:
            let working = AgentProvider.allCases.filter { provider in usage.snapshot.live.contains { $0.provider == provider } }
            let reading = NotchAgentSupport.stripReading(usage.snapshot, readout: NotchAgentReadout(rawValue: readout) ?? .elapsed,
                                                         display: NotchAgentLimitDisplay(rawValue: display) ?? .remaining,
                                                         focus: NotchAgentLimitFocus(rawValue: focus) ?? .mostUsed, now: date)
            // The agents and their reading only: a project's name stays off
            // a screen anyone can walk up to.
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                HStack(spacing: 1) {
                    ForEach(working) { NotchAgentGlyph(provider: $0, size: 13) }
                }
                Text(working.map(\.displayName).joined(separator: " · ") + " " + reading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(working.map(\.displayName).joined(separator: ", ") + ", "
                                + FeatureStrings.notchLockScreen(l10n.language).working)
            .accessibilityValue(reading)
        case .battery:
            if let info = CachedBattery.snapshot() {
                let text = FeatureStrings.notchLockStatus(l10n.language)
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    Image(systemName: info.isCharging ? "battery.100percent.bolt" : info.percent <= 20 ? "battery.25percent" : "battery.75percent")
                        .foregroundStyle(info.percent <= 20 && !info.isCharging ? NotchDesign.Palette.critical : NotchDesign.Ink.primary)
                    Text(Double(info.percent) / 100, format: .percent.precision(.fractionLength(0)))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(text.battery)
                .accessibilityValue((Double(info.percent) / 100).formatted(.percent.precision(.fractionLength(0))))
            }
        case .keepAwake:
            let text = FeatureStrings.notchLockStatus(l10n.language)
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                Image(systemName: "cup.and.saucer")
                if let end = awake.endDate {
                    Text(NotchKeepAwakeSupport.compactText(until: end, now: date, locale: Locale(identifier: l10n.language.rawValue)))
                } else {
                    Image(systemName: NotchKeepAwakeSupport.openSymbol)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text.keepAwake)
            .accessibilityValue(awake.endDate.map {
                NotchKeepAwakeSupport.compactText(until: $0, now: date, locale: Locale(identifier: l10n.language.rawValue))
            } ?? "")
        case .downloads:
            // Progress without the file's name, which stays off the lock screen.
            let fraction = downloads.items.first(where: { $0.active && !$0.completed })?.fraction
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                Image(systemName: "arrow.down.circle")
                if let fraction {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                } else {
                    Text(FeatureStrings.notchFiles(l10n.language).inProgress)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? FeatureStrings.notchFiles(l10n.language).inProgress)
        }
    }
}

/// Lock screen redraws every second; IOKit is polled at most every 30 seconds.
enum CachedBattery {
    private static var stamp = Date.distantPast
    private static var value: BatteryInfo?
    static func snapshot() -> BatteryInfo? {
#if VORSSAINT_DEVELOPMENT
        if NotchRenderHarness.isActive {
            return BatteryInfo(percent: 82, isCharging: false, isOnBattery: true, isOnExternalPower: false)
        }
#endif
        if Date().timeIntervalSince(stamp) > 30 { value = SystemInfo.batterySnapshot(); stamp = Date() }
        return value
    }
}
