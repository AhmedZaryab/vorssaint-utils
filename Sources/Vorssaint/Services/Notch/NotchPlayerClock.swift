// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Keeps a playing song anchored to the player's own clock
/// (`NotchMusicAutomation.clock`), which lyrics need to land on the beat.
/// Reads it just after every reading, then once a second while the song plays,
/// but only while something shows a live position: the open notch (lyrics live
/// there), the song peek band, or the last seconds before a Spotify song ends
/// when the peek may appear. Otherwise the adapter's own re-anchor is enough.
/// Only players this app may already script are read; nothing asks for consent.
final class NotchPlayerClock {
    /// How long before a song ends the song peek wants a live clock.
    static let peekLead: TimeInterval = 15

    private let queue = DispatchQueue(label: "com.vorssaint.notch-player-clock", qos: .utility)
    private var timer: Timer?
    private var wake: Timer?
    private var target: NotchMusicAutomation.Target?
    private var availability: NotchMusicAutomation.Availability?
    private var token = UUID()
    private var playback: NotchPlayback?
    private var anchor: ((Double, Date) -> Void)?
    private var nearEnd = false
    private var settleRead: DispatchWorkItem?

    /// Main thread. True while a visible surface needs the live position.
    var live = false {
        didSet { if live != oldValue, let anchor { follow(playback, anchor: anchor) } }
    }

    /// Main thread. `anchor` runs on the main thread with the player's position
    /// and the moment it was true, for this playback only.
    func follow(_ playback: NotchPlayback?, anchor: @escaping (Double, Date) -> Void) {
        halt()
        self.playback = playback
        self.anchor = anchor
        guard let playback, playback.isPlaying, playback.hasPosition,
              let target = NotchMusicAutomation.Target(playback) else { return }
        if target != self.target { self.target = target; availability = nil }
        guard live || nearEnd || scheduleNearEnd(playback) else { return }
        let token = token
        let read = { [weak self] in
            guard let self, self.token == token else { return }
            let cached = self.availability
            DispatchQueue.global(qos: .utility).async {
                guard let availability = cached ?? NotchMusicAutomation.inspect(target),
                      let clock = NotchMusicAutomation.clock(of: availability) else { return }
                DispatchQueue.main.async {
                    guard self.token == token else { return }
                    self.availability = availability
                    anchor(clock.seconds, clock.at)
                }
            }
        }
        // Debounce: every new reading halts this and restarts it, so while a
        // scrub streams changes no read happens; one read after 400 ms of quiet.
        let settle = DispatchWorkItem { read() }
        settleRead = settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: settle)
        let timer = Timer(timeInterval: 1, repeats: true) { _ in read() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Only Spotify songs get a peek. True when the song is already inside the
    /// peek lead; otherwise arms one wake-up at the lead and returns false.
    private func scheduleNearEnd(_ playback: NotchPlayback) -> Bool {
        let peeks = MainActor.assumeIsolated { SpotifyQueueService.isSpotify(playback) && SongPeekController.isEnabled }
        guard peeks, playback.duration > 0 else { return false }
        let remaining = playback.duration - playback.position(at: Date())
        guard remaining > 0 else { return false }
        if remaining <= Self.peekLead { return true }
        let wake = Timer(timeInterval: (remaining - Self.peekLead) / max(playback.rate, 0.1), repeats: false) { [weak self] _ in
            guard let self, let anchor = self.anchor else { return }
            self.nearEnd = true
            self.follow(self.playback, anchor: anchor)
            self.nearEnd = false
        }
        wake.tolerance = 0.5
        RunLoop.main.add(wake, forMode: .common)
        self.wake = wake
        return false
    }

    func stop() {
        halt()
        playback = nil
        anchor = nil
    }

    private func halt() {
        settleRead?.cancel()
        settleRead = nil
        timer?.invalidate()
        timer = nil
        wake?.invalidate()
        wake = nil
        token = UUID()
    }
}
