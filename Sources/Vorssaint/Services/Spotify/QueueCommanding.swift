// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the queue list needs from Spotify to reorder and remove. SpotifyConnectCommands conforms;
/// until the integrator points `QueueCommandsProvider.current` at it, the stub reports failure.
protocol QueueCommanding {
    func moveInQueue(from: Int, to: Int) async throws
    func removeFromQueue(uid: String) async throws
    func setQueue(nextTracks: [String]) async throws
}

enum QueueCommandsProvider {
    /// Integrator: set this to SpotifyConnectCommands.shared.
    static var current: QueueCommanding = UnwiredQueueCommands()
}

private struct UnwiredQueueCommands: QueueCommanding {
    struct Unwired: Error {}
    func moveInQueue(from: Int, to: Int) async throws { throw Unwired() }
    func removeFromQueue(uid: String) async throws { throw Unwired() }
    func setQueue(nextTracks: [String]) async throws { throw Unwired() }
}

extension SpotifyQueueService.Track {
    /// Integrator: replace with the real connect-state uid once Track carries one.
    var queueUID: String { id }
}
