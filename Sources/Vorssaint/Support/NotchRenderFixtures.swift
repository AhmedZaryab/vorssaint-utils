// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The made-up world the render harness draws the island in: one song, a
/// day of events, a timer, two coding agents, a few files and messages. None
/// of it comes from this Mac's user, and every value is fixed or measured
/// from the moment a scene is drawn, so two runs draw the same pictures.
@MainActor
enum NotchRenderFixtures {
    /// Which live activities the closed island has to choose from. Open
    /// pages show every service populated; closed states turn on only the
    /// activity they are about, so the island shows that one.
    struct Activities: OptionSet {
        let rawValue: Int
        static let music = Activities(rawValue: 1 << 0)
        static let timer = Activities(rawValue: 1 << 1)
        static let downloads = Activities(rawValue: 1 << 2)
        static let agents = Activities(rawValue: 1 << 3)
        static let countdown = Activities(rawValue: 1 << 4)
        static let keepAwake = Activities(rawValue: 1 << 5)
        /// The timer as a stopwatch, counting up, instead of the countdown.
        static let stopwatch = Activities(rawValue: 1 << 6)
        /// The countdown, run out.
        static let timerFinished = Activities(rawValue: 1 << 7)
        static let watch = Activities(rawValue: 1 << 8)
        static let all: Activities = [.music, .timer, .downloads, .agents, .countdown, .keepAwake, .watch]
    }

    /// A 14-inch MacBook Pro at its default resolution, with a camera housing.
    static var geometry: NotchGeometry {
        let defaults = UserDefaults.standard
        return NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, cameraWidth: 185,
                             layout: NotchSize(rawValue: defaults.string(forKey: DefaultsKey.notchSize) ?? "") ?? .spacious,
                             menuBarHeight: 32, compactSideRoom: 240,
                             hideMenuBarGap: defaults.bool(forKey: DefaultsKey.notchHideMenuBarGap), barEdge: 0.5)
    }

    static let power = PowerReading(chargePercent: 82, isCharging: false, externalConnected: false, hasBattery: true)

    // MARK: Music

    static let trackPID: Int32 = 4242
    private static let trackID = "render-track-1"
    private static let context = NotchPlaybackContext(pid: trackPID, revision: UUID(uuidString: "6F1C2A3B-0000-4000-8000-000000000001")!)

    static func playback(playing: Bool, now: Date) -> NotchPlayback {
        let track = RadialNowPlayingSnapshot(title: "Golden Hour Drive", artist: "The Midnight Arcade", album: "Neon Coast",
                                             artworkData: artworkPNG(hue: 0.04), appBundleIdentifier: "com.apple.Music",
                                             appPID: trackPID)
        // Sampled an hour ahead, so the position holds at 1:14 however long
        // the scene takes to draw; the song still reads as playing.
        return NotchPlayback(track: track, isPlaying: playing, elapsed: 74, duration: 212, rate: playing ? 1 : 0,
                             sampledAt: now.addingTimeInterval(3600), canSeek: true, hasPosition: true, itemIdentifier: trackID,
                             commandContext: context, canSendCommandsDirectly: true, canSkipNext: true, canSkipPrevious: true)
    }

    static let tint = NotchArtworkTint(red: 0.96, green: 0.48, blue: 0.29)

    static var lyrics: NotchLyrics {
        let lines = [(56.0, "Streetlights hum a borrowed tune"), (62.0, "We chase the edge of afternoon"),
                     (68.0, "Windows down and nowhere due"), (73.0, "The whole sky turning gold for you"),
                     (79.0, "Hold the wheel and let it glow"), (85.0, "Every mile a softer echo"),
                     (91.0, "Golden hour, take it slow")]
        return NotchLyrics(lines: lines.map { NotchLyricLine(time: $0.0, text: $0.1) }, plain: "", instrumental: false)
    }

    static var queue: NotchQueueSnapshot {
        let songs = [("Afterglow Avenue", "Lumen Drive", 0.58), ("Paper Satellites", "Low Tide Choir", 0.33),
                     ("Velvet Static", "Mira Sol", 0.83), ("Northbound", "The Quiet Hours", 0.12)]
        let items = songs.enumerated().map { index, song in
            NotchQueueItem(id: "render-queue-\(index)", offset: index + 1, title: song.0, artist: song.1,
                           duration: 180 + Double(index * 23), artwork: artworkPNG(hue: song.2))
        }
        return NotchQueueSnapshot(requestID: UUID(uuidString: "6F1C2A3B-0000-4000-8000-000000000002")!,
                                  currentIdentifier: trackID, pid: trackPID, items: items, canPlay: true)
    }

    static func songPeek(now: Date) -> SongPeekModel {
        let model = SongPeekModel()
        model.title = "Afterglow Avenue"
        model.artist = "Lumen Drive"
        model.artwork = artwork(hue: 0.58)
        model.startedAt = now
        // Already past, so the ring rests full instead of animating.
        model.endsAt = .distantPast
        return model
    }

    /// Album art drawn here: a warm gradient with a sun and two hills, so
    /// covers read as covers without shipping or downloading anyone's art.
    static func artwork(hue: CGFloat) -> NSImage {
        let side: CGFloat = 300
        let image = NSImage(size: CGSize(width: side, height: side))
        image.lockFocus()
        let top = NSColor(hue: hue, saturation: 0.72, brightness: 0.95, alpha: 1)
        let bottom = NSColor(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 0.45, alpha: 1)
        NSGradient(starting: top, ending: bottom)?.draw(in: CGRect(x: 0, y: 0, width: side, height: side), angle: -90)
        NSColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.35, brightness: 1, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: CGRect(x: side * 0.32, y: side * 0.42, width: side * 0.36, height: side * 0.36)).fill()
        NSColor(white: 0, alpha: 0.35).setFill()
        let hills = NSBezierPath()
        hills.move(to: .zero)
        hills.curve(to: CGPoint(x: side, y: side * 0.22), controlPoint1: CGPoint(x: side * 0.35, y: side * 0.48),
                    controlPoint2: CGPoint(x: side * 0.6, y: side * 0.05))
        hills.line(to: CGPoint(x: side, y: 0))
        hills.close()
        hills.fill()
        image.unlockFocus()
        return image
    }

    static func artworkPNG(hue: CGFloat) -> Data? {
        guard let tiff = artwork(hue: hue).tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: Calendar

    /// Today's events around the pinned 09:41 clock.
    static func events(now: Date) -> [NotchCalendarEvent] {
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }
        let work = NotchCalendarColor(red: 0.27, green: 0.55, blue: 1)
        let home = NotchCalendarColor(red: 0.35, green: 0.8, blue: 0.45)
        let team = NotchCalendarColor(red: 0.72, green: 0.45, blue: 0.98)
        return [
            NotchCalendarEvent(id: "render-standup", title: "Design review", calendar: "Work", start: at(-11), end: at(34),
                               allDay: false, location: "Studio 2", color: work),
            NotchCalendarEvent(id: "render-one-on-one", title: "1:1 with Maya", calendar: "Work", start: at(12), end: at(42),
                               allDay: false, location: "", color: work, countdownKey: "render-one-on-one"),
            NotchCalendarEvent(id: "render-lunch", title: "Lunch with Sam", calendar: "Personal", start: at(169), end: at(229),
                               allDay: false, location: "Corner Bistro", color: home),
            NotchCalendarEvent(id: "render-planning", title: "Sprint planning", calendar: "Team", start: at(319), end: at(379),
                               allDay: false, location: "", color: team),
            NotchCalendarEvent(id: "render-dentist", title: "Dentist", calendar: "Personal", start: at(1459), end: at(1504),
                               allDay: false, location: "", color: home),
        ]
    }

    // MARK: Agents

    static func agents(now: Date, live: Bool) -> (AgentUsageSnapshot, AgentCodexResetSummary) {
        let hour: TimeInterval = 3600
        var records: [AgentUsageRecord] = []
        let models: [(AgentProvider, String, String)] = [(.claude, "claude-opus-5-5", "vorssaint"),
                                                         (.claude, "claude-sonnet-5-5", "bedside"),
                                                         (.codex, "gpt-5.5-codex", "vorssaint")]
        // A steady pattern over two weeks: more on weekdays, a little every day.
        for day in 0..<14 {
            for (index, model) in models.enumerated() {
                let requests = 6 + (day * 7 + index * 5) % 11
                let date = now.addingTimeInterval(-Double(day) * 24 * hour - Double(index + 1) * hour)
                let tokens = AgentTokens(input: 4_000 * requests, cacheWrite: 1_500 * requests, cacheRead: 22_000 * requests,
                                         output: 900 * requests)
                records.append(AgentUsageRecord(provider: model.0, date: date, model: model.1, project: model.2,
                                                session: "render-\(day)-\(index)", requests: requests, tokens: tokens,
                                                cost: Double(requests) * (model.0 == .claude ? 0.21 : 0.12), savings: 0.4))
            }
        }
        let limits: [AgentProvider: AgentLimits] = [
            .claude: AgentLimits(provider: .claude, windows: [
                AgentLimitWindow(id: "session", kind: .session, minutes: 300, scope: nil, usedPercent: 42,
                                 resetsAt: now.addingTimeInterval(2.5 * hour)),
                AgentLimitWindow(id: "weekly", kind: .weekly, minutes: 10_080, scope: nil, usedPercent: 63,
                                 resetsAt: now.addingTimeInterval(3 * 24 * hour)),
            ], observedAt: now.addingTimeInterval(-120), source: .sessionLog),
            .codex: AgentLimits(provider: .codex, windows: [
                AgentLimitWindow(id: "session", kind: .session, minutes: 300, scope: nil, usedPercent: 18,
                                 resetsAt: now.addingTimeInterval(3.25 * hour)),
                AgentLimitWindow(id: "weekly", kind: .weekly, minutes: 10_080, scope: nil, usedPercent: 37,
                                 resetsAt: now.addingTimeInterval(4 * 24 * hour)),
            ], observedAt: now.addingTimeInterval(-120), source: .sessionLog),
        ]
        let session = AgentLiveSession(id: "render-live", provider: .claude, started: now.addingTimeInterval(-754),
                                       lastActivity: now.addingTimeInterval(-4), model: "claude-opus-5-5", project: "vorssaint",
                                       tokens: AgentTokens(input: 48_000, cacheWrite: 12_000, cacheRead: 310_000, output: 9_400),
                                       cost: 1.84)
        let plans = [AgentProvider.claude: AgentPlan(name: "Max 5x", monthlyPrice: 100),
                     .codex: AgentPlan(name: "Plus", monthlyPrice: 20)]
        let snapshot = AgentUsageSummary.snapshot(records: records, limits: limits, live: live ? [session] : [],
                                                  plans: plans, providers: [.claude, .codex], now: now)
        let resets = AgentCodexResetSummary(available: 1, resets: [AgentCodexReset(id: "render-reset",
                                                                                   expiresAt: now.addingTimeInterval(5 * 24 * hour))],
                                            limits: nil, checkedAt: now)
        return (snapshot, resets)
    }

    // MARK: Files, downloads, clipboard, notes, messages

    static func downloads(now: Date, active: Bool) -> [NotchDownloadItem] {
        let folder = URL(fileURLWithPath: "/tmp/vorssaint-render/Downloads", isDirectory: true)
        var items = [
            NotchDownloadItem(id: "render-dl-2", url: folder.appendingPathComponent("Quarterly report.pdf"),
                              name: "Quarterly report.pdf", receivedBytes: 2_400_000, fraction: 1, completed: true,
                              active: false, date: now.addingTimeInterval(-600)),
            NotchDownloadItem(id: "render-dl-3", url: folder.appendingPathComponent("Brand assets.zip"),
                              name: "Brand assets.zip", receivedBytes: 86_000_000, fraction: 1, completed: true,
                              active: false, date: now.addingTimeInterval(-3_600)),
        ]
        if active {
            items.insert(NotchDownloadItem(id: "render-dl-1", url: folder.appendingPathComponent("Xcode_27_beta.xip"),
                                           name: "Xcode_27_beta.xip", receivedBytes: 1_930_000_000, fraction: 0.42,
                                           completed: false, active: true, date: now), at: 0)
        }
        return items
    }

    static func clipboard(now: Date) -> [ClipboardHistoryEntry] {
        func entry(_ minutesAgo: Double, _ text: String, kind: ClipboardHistoryEntryKind = .text, paths: [String] = [],
                   width: Int? = nil, height: Int? = nil) -> ClipboardHistoryEntry {
            ClipboardHistoryEntry(id: UUID(uuidString: String(format: "6F1C2A3B-0000-4000-8000-%012d", Int(minutesAgo * 10)))!,
                                  text: text, copiedAt: now.addingTimeInterval(-minutesAgo * 60), pinnedAt: nil, kind: kind,
                                  filePaths: paths, imageFile: nil, imageHash: nil, imageWidth: width, imageHeight: height)
        }
        return [
            entry(1, "Ship the island redesign behind the new flag, then compare the before and after sheets."),
            entry(4, "https://developer.apple.com/design/human-interface-guidelines"),
            entry(9, "#FF7A45"),
            entry(15, "", kind: .image, width: 1280, height: 800),
            entry(32, "", kind: .files, paths: ["/tmp/vorssaint-render/Moodboard.key", "/tmp/vorssaint-render/Notes.md"]),
        ]
    }

    static var scratchpad: [ScratchpadPad] {
        [ScratchpadPad(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000A1")!, name: "Island ideas",
                       text: "Island redesign\n\n- Softer shoulders on the closed strip\n- One accent colour per activity\n"
                           + "- Music page: bigger cover, calmer controls\n- Peeks should breathe, not bounce",
                       modifiedAt: nil),
         ScratchpadPad(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000A2")!, name: "Groceries",
                       text: "Oat milk\nLemons\nSourdough", modifiedAt: nil)]
    }

    static var shelf: [ShelfService.Item] {
        let folder = URL(fileURLWithPath: "/tmp/vorssaint-render", isDirectory: true)
        func icon(_ type: String) -> NSImage { NSWorkspace.shared.icon(for: .init(filenameExtension: type) ?? .data) }
        return [
            ShelfService.Item(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000B1")!,
                              payload: .file(folder.appendingPathComponent("Island spec.pdf")), title: "Island spec.pdf",
                              icon: icon("pdf"), isImage: false),
            ShelfService.Item(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000B2")!,
                              payload: .file(folder.appendingPathComponent("Cover art.png")), title: "Cover art.png",
                              icon: artwork(hue: 0.9), isImage: true),
            ShelfService.Item(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000B3")!,
                              payload: .text("Remember to compare the peeks at 2x."), title: "Remember to compare the peeks at 2x.",
                              icon: icon("txt"), isImage: false),
        ]
    }

    static func notifications(now: Date) -> [NotchSystemNotification] {
        let messages = [("Messages", "Maya", "Are we still on for 10? I booked the small room."),
                        ("Mail", "Design Weekly", "Ten island layouts worth stealing this week"),
                        ("Calendar", "Sprint planning", "Starts at 3:00 PM in the Team room")]
        return messages.enumerated().map { index, message in
            NotchSystemNotification(id: UUID(uuidString: "6F1C2A3B-0000-4000-8000-0000000000C\(index)")!,
                                    content: NotchNotificationContent(app: message.0, title: message.1, subtitle: "",
                                                                      body: message.2),
                                    received: now.addingTimeInterval(-Double(index * 7 + 2) * 60), canOpen: true)
        }
    }

    /// A captured terminal window for the watch: a few lines of build output.
    static func watchPreview() -> CGImage? {
        let size = CGSize(width: 640, height: 220)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(NSColor(white: 0.1, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let font = NSFont.monospacedSystemFont(ofSize: 22, weight: .regular)
        for (index, line) in watchText.split(separator: "\n").enumerated() {
            let color = line.hasPrefix("Build") ? NSColor.systemGreen : NSColor(white: 0.85, alpha: 1)
            (String(line) as NSString).draw(at: CGPoint(x: 20, y: size.height - 44 - CGFloat(index) * 34),
                                            withAttributes: [.font: font, .foregroundColor: color])
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    static let watchText = "Compiling 412 of 640 files\nLinking VorssaintDeveloper\nSigning bundle\nBuild succeeded in 52.3s"

    // MARK: Install

    /// Puts the whole world in place for a scene drawn at `now`.
    static func install(now: Date, activities: Activities, music: Bool = true) {
        let playing = activities.contains(.music)
        let playback = music ? self.playback(playing: playing, now: now) : nil
        NotchMusicService.shared.applyRenderFixture(playback: playback, artwork: music ? artwork(hue: 0.04) : nil,
                                                    tint: music ? tint : nil, upcoming: music ? queue : nil)
        NotchLyricsService.shared.applyRenderFixture(playback: playback, lyrics: music ? lyrics : nil)

        // A 25 minute timer with 18 minutes left on the frozen clock, a
        // stopwatch at 12:34, or a timer that has just run out.
        let clock: TimeInterval = 10_000
        NotchRenderHarness.timerNow = clock
        var session = NotchTimerSession()
        if activities.contains(.stopwatch) {
            session.start(mode: .stopwatch, minutes: 0, now: clock - 754)
        } else if activities.contains(.timerFinished) {
            session.start(mode: .timer, minutes: 25, now: clock - 25 * 60 - 5)
            session.finishIfDue(at: clock)
        } else if activities.contains(.timer) {
            session.start(mode: .timer, minutes: 25, now: clock - 7 * 60)
        }
        NotchTimerService.shared.applyRenderFixture(session)

        let events = events(now: now)
        NotchCalendarService.shared.applyRenderFixture(
            events: events, countdown: activities.contains(.countdown) ? NotchCalendarCountdown(event: events[1], ongoing: false) : nil)

        NotchDownloadService.shared.applyRenderFixture(items: downloads(now: now, active: activities.contains(.downloads)),
                                                       folderName: "Downloads")
        let (usage, resets) = agents(now: now, live: activities.contains(.agents))
        AgentUsageService.shared.applyRenderFixture(usage)
        AgentCodexResetService.shared.applyRenderFixture(resets)
        NotchNotificationService.shared.applyRenderFixture(notifications(now: now))
        KeepAwakeManager.shared.applyRenderFixture(endDate: now.addingTimeInterval(95 * 60 - 20),
                                                   active: activities.contains(.keepAwake))
        let watching = activities.contains(.watch)
        NotchWatchService.shared.applyRenderFixture(
            target: watching ? NotchWatchTarget(windowID: nil, displayID: 0, crop: CGRect(x: 0, y: 0, width: 320, height: 110),
                                                appName: "Terminal", processID: nil, windowTitle: "vorssaint: build") : nil,
            state: watching ? .watching : .idle, preview: watching ? watchPreview() : nil, text: watching ? watchText : "",
            startedAt: watching ? now.addingTimeInterval(-6 * 60) : nil)
        ClipboardHistoryService.shared.applyRenderFixture(clipboard(now: now))
        let pads = scratchpad
        ScratchpadService.shared.applyRenderFixture(pads: pads, selected: pads.first?.id)
        ShelfService.shared.applyRenderFixture(shelf)
        AppVolumeMixer.shared.applyRenderFixture(apps: [
            .init(name: "Music", bundleID: "com.apple.Music", volume: 0.8, isPlaying: true),
            .init(name: "Safari", bundleID: "com.apple.Safari", volume: 0.55, isPlaying: false),
            .init(name: "FaceTime", bundleID: "com.apple.FaceTime", volume: 1, isPlaying: false),
        ], outputs: [("MacBook Pro Speakers", false), ("AirPods Pro", true)], volume: 0.62)
        BrightnessService.shared.applyRenderFixture(level: 0.7)
        Permissions.shared.applyRenderFixture()
        UpdateService.shared.applyRenderFixture(.idle)
    }
}
#endif
