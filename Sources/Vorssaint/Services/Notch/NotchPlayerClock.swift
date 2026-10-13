// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Keeps a playing song anchored to the player's own clock
/// (`NotchMusicAutomation.clock`), which lyrics need to land on the beat.
/// Reads it just after every reading, then once a second while the song plays.
/// Only players this app may already script are read; nothing asks for consent.
final class NotchPlayerClock {
    private let queue = DispatchQueue(label: "com.vorssaint.notch-player-clock", qos: .userInitiated)
    private var timer: Timer?
    private var target: NotchMusicAutomation.Target?
    private var availability: NotchMusicAutomation.Availability?
    private var token = UUID()

    /// Main thread. `anchor` runs on the main thread with the player's position
    /// and the moment it was true, for this playback only.
    func follow(_ playback: NotchPlayback?, anchor: @escaping (Double, Date) -> Void) {
        stop()
        guard let playback, playback.isPlaying, playback.hasPosition,
              let target = NotchMusicAutomation.Target(playback) else { return }
        if target != self.target { self.target = target; availability = nil }
        let token = token
        let read = { [weak self] in
            guard let self, self.token == token else { return }
            let cached = self.availability
            self.queue.async {
                guard let availability = cached ?? NotchMusicAutomation.inspect(target),
                      let clock = NotchMusicAutomation.clock(of: availability) else { return }
                DispatchQueue.main.async {
                    guard self.token == token else { return }
                    self.availability = availability
                    anchor(clock.seconds, clock.at)
                }
            }
        }
        // A player settles its clock a moment after a command.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { read() }
        let timer = Timer(timeInterval: 1, repeats: true) { _ in read() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        token = UUID()
    }
}
