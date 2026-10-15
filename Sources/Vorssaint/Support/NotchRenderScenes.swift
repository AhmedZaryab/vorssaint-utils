// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// One picture the render harness draws.
struct NotchRenderScene {
    enum Content {
        /// The island, with its presentation set from the fixture at the time drawn.
        case island((Date) -> NotchService.RenderFixture)
        /// Any other surface, with its size; nil leaves the scene out.
        case view((Date) -> (AnyView, CGSize)?)
        /// One frame of the island opening onto the music page.
        case grow(Int)
    }

    let name: String
    let summary: String
    var activities: NotchRenderFixtures.Activities = .all
    var music = true
    var subpage: NotchRenderHarness.Subpage?
    var mayBeEmpty = false
    /// A ground of the scene's own, where black would hide what it shows.
    var background: NSColor?
    var skipReason: String?
    /// Confirms the island is showing what the scene is about.
    var check: (() throws -> Void)?
    let content: Content
}

@MainActor
enum NotchRenderScenes {
    static var all: [NotchRenderScene] { closed + pages + peeks + growth + lockScreens + extras }

    private static var language: AppLanguage { L10n.shared.language }

    // MARK: Closed

    private static var closed: [NotchRenderScene] {
        [
            NotchRenderScene(name: "01-closed-idle", summary: "closed island at rest: a black outline, empty by default",
                             activities: [], music: false, mayBeEmpty: true,
                             check: expecting(nil), content: .island { _ in resting() }),
            NotchRenderScene(name: "02-closed-music", summary: "closed island with a song playing",
                             activities: [.music], check: expecting(.music), content: .island { _ in resting() }),
            NotchRenderScene(name: "03-song-peek", summary: "next song peek band under the closed strip",
                             activities: [.music], content: .island { now in
                                 var fixture = resting()
                                 fixture.songPeek = NotchRenderFixtures.songPeek(now: now)
                                 return fixture
                             }),
        ]
    }

    // MARK: Pages

    private static var pages: [NotchRenderScene] {
        [
            page("04-music", "music page, song playing", .music),
            page("05-lyrics", "music page with synced lyrics open", .music, subpage: .lyrics),
            page("06-queue", "music page with the queue open", .music, subpage: .queue),
            page("07-controls", "controls page", .controls),
            page("08-mixer", "mixer page, three apps", .mixer),
            page("09-calendar", "calendar page, today's events", .calendar),
            page("10-calendar-month", "calendar page on its month grid", .calendar, subpage: .month),
            page("11-timer", "timer page, 25 minute timer running", .timer),
            page("12-watch", "watch page following a terminal window", .watch),
            page("13-agents", "AI agents page, Claude and Codex", .agents),
            page("14-files", "files shelf, three items", .files),
            page("15-clipboard", "clipboard history, five entries", .clipboard),
            page("16-downloads", "downloads, one active and two finished", .downloads),
            page("17-scratchpad", "scratchpad, two pads", .scratchpad),
            page("18-camera", "camera page before the camera starts (no camera is used)", .camera),
            page("19-notifications", "notifications page, three messages", .notifications),
            NotchRenderScene(name: "20-notice-low-battery", summary: "closed island alert: low battery",
                             activities: [], music: false, content: .island { _ in
                                 notice(NotchNotice(event: .battery, title: FeatureStrings.notch(language).lowBattery,
                                                    detail: "19%", symbol: "battery.25percent"))
                             }),
            NotchRenderScene(name: "21-quick-access", summary: "open island with its floating quick access buttons",
                             content: .view(quickAccess)),
            NotchRenderScene(name: "22-update-control", summary: "open island header offering an update",
                             content: .island { _ in
                                 UpdateService.shared.applyRenderFixture(.available(version: "9.9.0"))
                                 return open(.controls)
                             }),
        ]
    }

    // MARK: Peeks

    private static var peeks: [NotchRenderScene] {
        let activity = FeatureStrings.notchActivities(language)
        let agents = FeatureStrings.notchAgents(language)
        let locale = language.formattingLocale()
        let content = NotchRenderFixtures.notifications(now: Date())[0].content
        return [
            NotchRenderScene(name: "30-peek-track", summary: "next song peek, ring part way round",
                             activities: [.music], content: .island { now in
                                 var fixture = resting()
                                 let model = NotchRenderFixtures.songPeek(now: now)
                                 model.endsAt = Date().addingTimeInterval(4)
                                 fixture.songPeek = model
                                 return fixture
                             }),
            peek("30-peek-agent-finished", "an agent finished, with its time and spend", NotchNotice(
                event: .agents, title: agents.finished(AgentProvider.claude.displayName),
                detail: NotchNotice.wrapUpDuration(754, locale: locale) + " · " + AgentFormat.cost(1.84),
                symbol: AgentProvider.claude.symbol, agent: .claude, tall: true)),
            peek("30-peek-notification", "a message mirrored from Notification Center", NotchNotice(
                event: .systemNotification, title: content.title, detail: content.body, symbol: "bell.fill",
                notification: content, notificationID: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000D1"),
                tall: true)),
            peek("30-peek-track-change", "the track changed, compact: cover and title in the wings", NotchNotice(
                event: .track, title: "Blinding Lights", detail: "The Weeknd", symbol: "music.note"),
                 activities: [.music], music: true),
            peek("30-peek-agent-finished-music", "an agent finished while a song plays: the band under the music strip", NotchNotice(
                event: .agents, title: agents.finished(AgentProvider.claude.displayName),
                detail: NotchNotice.wrapUpDuration(754, locale: locale) + " · " + AgentFormat.cost(1.84),
                symbol: AgentProvider.claude.symbol, agent: .claude, tall: true),
                 activities: [.music], music: true),
            peek("30-peek-watch-strip", "a watch fired over the watch strip", NotchNotice(
                event: .watch, title: FeatureStrings.notchWatch(language).outcome(.settled), detail: "Xcode",
                symbol: NotchModule.watch.symbol, tall: true),
                 activities: [.watch]),
            peek("30-peek-agent-limit", "an agent is close to its limit", NotchNotice(
                event: .agents, title: AgentProvider.claude.displayName + " · " + agents.session,
                detail: agents.usedShare("92%"), symbol: "exclamationmark.triangle.fill", agent: .claude, tall: true)),
            peek("30-peek-watch", "a watch fired", NotchNotice(
                event: .watch, title: FeatureStrings.notchWatch(language).outcome(.settled), detail: "Xcode",
                symbol: NotchModule.watch.symbol, tall: true)),
            peek("30-peek-download-finished", "a download finished", NotchNotice(
                event: .download, title: FeatureStrings.notchFiles(language).completed, detail: "Quarterly report.pdf",
                symbol: "arrow.down.circle.fill", tall: true)),
            peek("30-peek-device-connected", "AirPods connected", NotchNotice(
                event: .accessory, title: activity.connected, detail: "AirPods Pro",
                symbol: NotchAccessorySupport.symbol(name: "AirPods Pro", majorClass: 0x04, minorClass: 0x06))),
            peek("30-peek-timer-ended", "the timer ended", NotchNotice(
                event: .timer, title: activity.finished, detail: activity.phase(.timer), symbol: "timer")),
            peek("30-peek-volume", "volume HUD at 62%", NotchNotice(
                event: .volume, title: FeatureStrings.notch(language).volume, detail: "62%",
                symbol: "speaker.wave.2.fill", level: 0.62)),
            peek("30-peek-brightness", "brightness HUD at 70%", NotchNotice(
                event: .brightness, title: FeatureStrings.notch(language).brightness, detail: "70%",
                symbol: "sun.max.fill", level: 0.7)),
            NotchRenderScene(name: "30-peek-keep-awake", summary: "keep awake strip, 1h35 left",
                             activities: [.keepAwake], music: false, check: expecting(.keepAwake),
                             content: .island { _ in resting() }),
            NotchRenderScene(name: "30-peek-calendar-soon", summary: "calendar strip, next meeting in 12 minutes",
                             activities: [.countdown], music: false, check: expecting(.calendar),
                             content: .island { _ in resting() }),
            NotchRenderScene(name: "30-peek-timer", summary: "timer strip, 18 minutes left",
                             activities: [.timer], music: false, check: expecting(.timer),
                             content: .island { _ in resting() }),
            NotchRenderScene(name: "30-peek-agent-working", summary: "agent strip while Claude works",
                             activities: [.agents], music: false, check: expecting(.agents),
                             content: .island { _ in resting() }),
            NotchRenderScene(name: "30-peek-download-progress", summary: "download strip at 42%",
                             activities: [.downloads], music: false, check: expecting(.downloads),
                             content: .island { _ in resting() }),
        ]
    }

    // MARK: Growth and extras

    private static var growth: [NotchRenderScene] {
        (1...3).map { step in
            NotchRenderScene(name: "40-grow-\(step)", summary: NotchRenderGrowth.summary(step: step),
                             activities: [.music], background: NotchRenderGrowth.ground, content: .grow(step))
        }
    }

    /// The lock screen as Vorssaint draws over it, on the fixture display.
    private static var lockScreens: [NotchRenderScene] {
        typealias Gates = NotchLockScreenModel.Gates
        func scene(_ name: String, _ summary: String, _ activities: NotchRenderFixtures.Activities, music: Bool = false,
                   gates: Gates) -> NotchRenderScene {
            NotchRenderScene(name: "lockscreen-" + name, summary: summary, activities: activities, music: music,
                             content: .view { now in lockScreen(now: now, gates: gates) })
        }
        return [
            scene("1-idle", "locked, nothing playing: the padlock island alone", [], gates: Gates(music: true)),
            scene("2-music", "locked with a song playing: island and player", [.music], music: true, gates: Gates(music: true)),
            scene("3-timer", "timer running, 18:00 left", [.timer], gates: Gates(timer: true)),
            scene("4-stopwatch", "stopwatch running, 12:34", [.stopwatch], gates: Gates(timer: true)),
            scene("5-timer-finished", "timer finished", [.timerFinished], gates: Gates(timer: true)),
            scene("6-status", "battery and keep awake lines", [.keepAwake], gates: Gates(battery: true, keepAwake: true)),
            scene("7-countdown", "calendar countdown, 1:1 in 12 minutes", [.countdown], gates: Gates(countdown: true)),
            scene("8-agents", "Claude working", [.agents], gates: Gates(agents: true)),
        ]
    }

    private static var extras: [NotchRenderScene] {
        [NotchRenderScene(name: "interactions-gallery", summary: "every button and slider in every state",
                          content: .view { _ in gallery() })]
    }

    // MARK: Builders

    private static func resting() -> NotchService.RenderFixture {
        NotchService.RenderFixture(geometry: NotchRenderFixtures.geometry, modules: NotchSupport.modules(),
                                   power: NotchRenderFixtures.power)
    }

    private static func open(_ module: NotchModule, extras: Bool = false) -> NotchService.RenderFixture {
        var fixture = resting()
        fixture.expanded = true
        fixture.selected = module
        fixture.musicDetailVisible = extras
        return fixture
    }

    private static func notice(_ notice: NotchNotice) -> NotchService.RenderFixture {
        var fixture = resting()
        fixture.notice = notice
        return fixture
    }

    private static func page(_ name: String, _ summary: String, _ module: NotchModule,
                             subpage: NotchRenderHarness.Subpage? = nil) -> NotchRenderScene {
        NotchRenderScene(name: name, summary: summary, subpage: subpage, check: {
            guard NotchService.shared.modules.contains(module) else {
                throw RenderError("the \(module.rawValue) page is not among the island's sections")
            }
        }, content: .island { _ in open(module, extras: subpage == .lyrics || subpage == .queue) })
    }

    private static func peek(_ name: String, _ summary: String, _ notice: NotchNotice,
                             activities: NotchRenderFixtures.Activities = [], music: Bool = false) -> NotchRenderScene {
        NotchRenderScene(name: name, summary: summary, activities: activities, music: music,
                         content: .island { _ in self.notice(notice) })
    }

    private static func expecting(_ activity: NotchCompactActivity?) -> () throws -> Void {
        {
            let shown = NotchService.shared.compactActivity
            guard shown == activity else {
                throw RenderError("expected the closed island to show \(activity.map { "\($0)" } ?? "no activity"), "
                                  + "found \(shown.map { "\($0)" } ?? "none")")
            }
        }
    }

    /// The open controls page with the floating buttons beside it, laid out
    /// as the island's window places them.
    private static func quickAccess(now: Date) -> (AnyView, CGSize)? {
        let service = NotchService.shared
        service.applyRenderFixture(open(.controls))
        let size = service.surfaceSize
        let geometry = service.geometry
        var configuration = NotchQuickAccessConfiguration.current()
        if configuration.buttons.isEmpty { configuration = .initial }
        let layout = NotchQuickAccessLayout.self
        let sideCount = max(configuration.buttons.filter { $0.side == .left }.count,
                            configuration.buttons.filter { $0.side == .right }.count)
        let sideBottom = sideCount > 0 ? geometry.quickAccessCenterY + CGFloat(sideCount - 1) * layout.rowSpacing
            + layout.diameter / 2 + layout.hoverMargin : 0
        let bottom = max(configuration.hasBottom ? layout.gutter : 0, sideBottom - size.height)
        let canvas = CGSize(width: size.width + layout.gutter * 2, height: size.height + bottom)
        let shoulder = NotchLayout.shoulder(height: size.height)
        let motion = NotchQuickAccessMotion()
        motion.configure(configuration, body: CGRect(x: layout.gutter + shoulder, y: 0, width: size.width - shoulder * 2,
                                                     height: size.height),
                         headerTop: geometry.quickAccessCenterY, animated: false)
        motion.setVisible(true, animated: false)
        let view = ZStack(alignment: .topLeading) {
            NotchQuickAccessView(service: service, motion: motion, backdrop: NotchBackdropPresentation())
                .frame(width: canvas.width, height: canvas.height)
            NotchRenderHarness.islandView(size: size, shift: 0)
                .frame(width: size.width, height: size.height)
                .offset(x: layout.gutter)
        }
        return (AnyView(view.frame(width: canvas.width, height: canvas.height, alignment: .topLeading)), canvas)
    }

    /// The parts the lock screen shows, placed as its windows are on the
    /// fixture display, over a mid grey stand-in for a photo. The system's
    /// own clock and password field are not Vorssaint's and are not drawn.
    private static func lockScreen(now: Date, gates: NotchLockScreenModel.Gates) -> (AnyView, CGSize)? {
        let service = NotchService.shared
        service.applyRenderFixture(resting())
        let geometry = service.geometry
        let screen = geometry.screen
        let model = NotchLockScreenModel()
        model.gates = gates
        model.playedWhileLocked = true
        func place<V: View>(_ view: V, _ frame: CGRect) -> some View {
            view.frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX - screen.minX, y: screen.maxY - frame.maxY)
        }
        let wallpaper = ZStack {
            LinearGradient(colors: [Color(white: 0.38), Color(white: 0.52), Color(white: 0.44)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(white: 0.72).opacity(0.55), .clear], center: UnitPoint(x: 0.3, y: 0.62),
                           startRadius: 0, endRadius: screen.width * 0.45)
            RadialGradient(colors: [Color(white: 0.18).opacity(0.5), .clear], center: UnitPoint(x: 0.82, y: 0.2),
                           startRadius: 0, endRadius: screen.width * 0.35)
        }
        var layers: [AnyView] = [AnyView(wallpaper.frame(width: screen.width, height: screen.height))]
        let rowHeight = model.gates.timer ? NotchLockScreenLayout.paneRowHeight : NotchLockScreenLayout.rowHeight
        if let frame = NotchLockScreenLayout.rowFrame(in: screen, height: rowHeight) {
            layers.append(AnyView(place(NotchLockScreenActivities(model: model, size: frame.size), frame)))
        }
        if let frame = NotchLockScreenLayout.playerFrame(in: screen, rowHeight: rowHeight) {
            layers.append(AnyView(place(NotchLockScreenPlayer(model: model, size: frame.size), frame)))
        }
        if let surface = NotchLockScreenLayout.islandSurface(
            in: screen, cameraWidth: geometry.bareCamera.width, cameraHeight: geometry.bareCamera.height,
            wing: geometry.lockScreenMusicGeometry.compactActivityWingWidth) {
            layers.append(AnyView(place(NotchLockScreenIsland(model: model, size: surface.size,
                                                              cameraWidth: geometry.bareCamera.width,
                                                              geometry: geometry.lockScreenMusicGeometry), surface)))
        }
        let view = ZStack(alignment: .topLeading) { ForEach(layers.indices, id: \.self) { layers[$0] } }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        return (AnyView(view), screen.size)
    }

    /// The interaction library's gallery, at the width it lays itself out at.
    private static func gallery() -> (AnyView, CGSize)? {
        let gallery = NotchInteractionsGallery()
        return (AnyView(gallery), NSHostingView(rootView: gallery).fittingSize)
    }
}
#endif
