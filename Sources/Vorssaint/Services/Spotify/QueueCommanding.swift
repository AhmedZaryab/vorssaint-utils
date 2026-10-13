// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the queue list needs from Spotify to reorder and remove. SpotifyConnectCommands conforms
/// and AppDelegate points `QueueCommandsProvider.current` at it on launch; before that the stub fails.
protocol QueueCommanding {
    func moveInQueue(from: Int, to: Int) async throws
    func removeFromQueue(uid: String) async throws
    func setQueue(nextTracks: [String]) async throws
}

enum QueueCommandsProvider {
    /// Set to SpotifyConnectCommands.shared in applicationDidFinishLaunching.
    static var current: QueueCommanding = UnwiredQueueCommands()
}

private struct UnwiredQueueCommands: QueueCommanding {
    struct Unwired: Error {}
    func moveInQueue(from: Int, to: Int) async throws { throw Unwired() }
    func removeFromQueue(uid: String) async throws { throw Unwired() }
    func setQueue(nextTracks: [String]) async throws { throw Unwired() }
}

extension SpotifyQueueService.Track {
    /// The connect-state uid of the row (next_tracks[i].uid), what set_queue keys on.
    var queueUID: String { uid }
}
