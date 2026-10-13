// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import SwiftUI

/// Pure timing rules for the next song peek, kept free of app state so tests
/// can drive them directly.
enum SongPeekPolicy {
    /// The band appears this long before the playing song ends.
    static let lead: TimeInterval = 10
    /// The queue is read once per song, this long before it ends.
    static let prefetchLead: TimeInterval = 15

    static func isInWindow(remaining: TimeInterval) -> Bool {
        remaining.isFinite && remaining > 0.2 && remaining <= lead
    }

    static func wantsPrefetch(remaining: TimeInterval) -> Bool {
        remaining.isFinite && remaining > 0 && remaining <= prefetchLead
    }

    /// The cached queue belongs to the song playing now only when its current
    /// song carries the same title.
    static func cacheMatches(cachedTitle: String?, playingTitle: String?) -> Bool {
        guard let cachedTitle, let playingTitle else { return false }
        let a = cachedTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = playingTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !a.isEmpty && a == b
    }
}

/// Grows the closed notch downward about five seconds before a Spotify
/// song ends: the next song's cover, title and artist, and a ring that fills
/// as the current song runs out. Reads the music service's position as it
/// is; the next song comes from SpotifyQueueService.
@MainActor
final class SongPeekController {
    static let shared = SongPeekController()
    static let enabledKey = "notch.songPeek.enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    private let model = SongPeekModel()
    private var cancellables: Set<AnyCancellable> = []
    private var timer: Timer?
    private var started = false
    /// The song whose ending was already peeked, so one transition shows once.
    private var shownKey: String?
    /// The song whose queue was already read ahead of its ending.
    private var prefetchedKey: String?
    private var visibleKey: String?
    private var hideWork: DispatchWorkItem?

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        let music = NotchMusicService.shared
        music.$playback
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playback in self?.playbackChanged(playback) }
            .store(in: &cancellables)
        // Manual skips and natural changes both arrive here first.
        music.trackChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dismiss() }
            .store(in: &cancellables)
        music.trackEnds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dismiss() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !Self.isEnabled else { return }
                self.dismiss()
            }
            .store(in: &cancellables)
    }

    // MARK: Watching the song

    private func playbackChanged(_ playback: NotchPlayback?) {
        guard let playback, playback.isPlaying, playback.hasPosition, playback.duration > 0,
              SpotifyQueueService.isSpotify(playback), Self.isEnabled else {
            stopTimer()
            dismiss()
            return
        }
        if let visibleKey, visibleKey != Self.key(for: playback) { dismiss() }
        if timer == nil {
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        tick()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let playback = NotchMusicService.shared.playback, playback.isPlaying,
              SpotifyQueueService.isSpotify(playback), Self.isEnabled else {
            stopTimer()
            dismiss()
            return
        }
        let key = Self.key(for: playback)
        let remaining = playback.duration - playback.position(at: Date())
        if SongPeekPolicy.wantsPrefetch(remaining: remaining), prefetchedKey != key,
           SpotifyQueueService.isAvailable, SpotifyQueueService.isConnected {
            prefetchedKey = key
            Task { await SpotifyQueueService.shared.refresh() }
        }
        if visibleKey == key {
            // A seek back out of the last seconds puts the card away.
            if remaining > SongPeekPolicy.lead + 1 { dismiss() }
            else if abs(model.endsAt.timeIntervalSinceNow - remaining) > 0.3 {
                // Only a real drift re-anchors the ring's animation.
                model.endsAt = Date().addingTimeInterval(max(0, remaining))
            }
            return
        }
        guard SongPeekPolicy.isInWindow(remaining: remaining), shownKey != key,
              !NotchService.shared.expanded,
              let next = nextTrack(playingTitle: playback.track.title) else { return }
        shownKey = key
        show(next, endsAt: Date().addingTimeInterval(remaining), key: key)
    }

    /// The next song, from the live queue when Spotify is connected, or from
    /// the queue page's last answer when that answer still matches the song.
    private func nextTrack(playingTitle: String?) -> SpotifyQueueService.Track? {
        guard SpotifyQueueService.isAvailable else { return nil }
        let queue = SpotifyQueueService.shared
        guard SongPeekPolicy.cacheMatches(cachedTitle: queue.current?.title, playingTitle: playingTitle) else {
            return nil
        }
        return queue.upNext.first
    }

    private static func key(for playback: NotchPlayback) -> String {
        if let id = playback.itemIdentifier, !id.isEmpty { return id }
        return [String(playback.track.appPID ?? 0), playback.track.title ?? "",
                playback.track.artist ?? "", String(Int(playback.duration))].joined(separator: "|")
    }

    // MARK: The band

    /// The closed notch grows down by the band's measured height and shows it.
    private func show(_ track: SpotifyQueueService.Track, endsAt: Date, key: String) {
        hideWork?.cancel()
        model.title = track.title
        model.artist = track.artist
        model.artwork = track.artworkURL.flatMap { SpotifyQueueService.shared.artwork[$0] }
        model.startedAt = Date()
        model.endsAt = endsAt
        visibleKey = key
        NotchService.shared.setSongPeek(model)
        // A song that never reports its change still lets the band go.
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, endsAt.timeIntervalSinceNow) + 3, execute: work)
    }

    private func dismiss() {
        hideWork?.cancel()
        hideWork = nil
        guard visibleKey != nil else { return }
        visibleKey = nil
        NotchService.shared.setSongPeek(nil)
    }
}

/// What the card shows; the controller fills it, the view reads it.
@MainActor
final class SongPeekModel: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var artwork: NSImage?
    @Published var startedAt = Date()
    @Published var endsAt = Date()
}
