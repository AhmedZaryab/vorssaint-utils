// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import os

/// Off unless `defaults write com.vorssaint.utils spotifyQueueDebugHook -bool YES`.
/// Lets a terminal drive the shipped reorder path without the notch UI:
///   post distributed notification "com.vorssaint.debug.spotifyQueue" with object
///   "move <from> <to>" (QueueCommandsProvider.current.moveInQueue, the UI's call),
///   "noop" (set_queue with the order unchanged), or "read" (log the order).
/// Every step logs to subsystem com.vorssaint.utils, category SpotifyQueueDebug.
@MainActor
enum SpotifyQueueDebugHook {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint", category: "SpotifyQueueDebug")
    private static var observer: NSObjectProtocol?

    static func installIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "spotifyQueueDebugHook"), observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.vorssaint.debug.spotifyQueue"), object: nil, queue: .main
        ) { note in
            let words = ((note.object as? String) ?? "read").split(separator: " ").map(String.init)
            Task { @MainActor in await run(words) }
        }
        log.info("debug hook on")
    }

    private static func run(_ words: [String]) async {
        let service = SpotifyQueueService.shared
        await service.refresh()
        logOrder("before \(words.joined(separator: " "))", service.upNext)
        do {
            switch words.first {
            case "move" where words.count == 3:
                try await QueueCommandsProvider.current.moveInQueue(from: Int(words[1]) ?? 0, to: Int(words[2]) ?? 0)
            case "noop":
                guard await SpotifyConnectCommands.shared.resendQueueUnchanged() else {
                    throw SpotifyConnectCommands.Rejected(command: "set_queue (no-op)")
                }
            default:
                break
            }
            log.info("result: ok")
        } catch {
            log.error("result: \(String(describing: error), privacy: .public)")
        }
        await service.refresh()
        logOrder("after", service.upNext)
    }

    private static func logOrder(_ label: String, _ rows: [SpotifyQueueService.Track]) {
        let playing = SpotifyQueueService.shared.current?.title ?? "nothing"
        let order = rows.enumerated().map { "\($0.offset):\($0.element.title)[\($0.element.uid)]" }
            .joined(separator: " | ")
        log.info("\(label, privacy: .public): playing \(playing, privacy: .public); up next \(order, privacy: .public)")
    }
}
