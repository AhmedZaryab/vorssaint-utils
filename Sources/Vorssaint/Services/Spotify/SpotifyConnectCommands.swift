// SPDX-License-Identifier: AGPL-3.0-only
//
//  SpotifyConnectCommands.swift
//  Player commands over Spotify Connect, the way the web player sends them:
//  register a hidden controller device (PUT connect-state/v1/devices/hobs_<id>)
//  on the dealer connection, then POST connect-state/v1/player/command from
//  that device to the active one. Adapted from Sapphire's SpotifyPrivateAPI.swift
//  (performDeviceRegistration, connectStateCapabilities, sendWebPlayerStyleSkip,
//  addToQueue, removeFromQueue, connectQueueTrackPayloads,
//  sendConnectCommandReturning, applyQueueRevision, pythonCompatiblePlay).
//  Sapphire, created by Shariq Charolia on 2025-10-05.
//  Copyright (C) Shariq Charolia. Sapphire is licensed AGPL-3.0.
//  Combined into Vorssaint (GPL-3.0-or-later) under GPL-3 section 13.
//
//  Lightweight on purpose: nothing runs until a command is sent or warmUp()
//  is called, the cluster is read on demand (never polled), and the dealer
//  closes itself after 60 s idle.

import Foundation
import os

@MainActor
final class SpotifyConnectCommands {
    static let shared = SpotifyConnectCommands()

    /// One entry of player_state.next_tracks / prev_tracks. Built from the
    /// cluster and sent back exactly as received (uid, provider, metadata),
    /// only the order changes. Never stamp every track "queue" (Sapphire's
    /// connectQueueTrackPayloads did, turning the whole playlist into queue).
    struct QueueTrack {
        let uri: String
        let uid: String
        private(set) var provider: String
        private(set) var metadata: [String: String]
        fileprivate var raw: [String: Any]

        init(uri: String, uid: String, provider: String = "queue", metadata: [String: String] = [:]) {
            self.uri = uri
            self.uid = uid
            self.provider = provider
            self.metadata = metadata
            self.raw = [:]
        }

        init?(json: [String: Any]) {
            guard let uri = json["uri"] as? String else { return nil }
            self.uri = uri
            self.uid = json["uid"] as? String ?? ""
            self.provider = json["provider"] as? String ?? "context"
            self.metadata = (json["metadata"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:]
            self.raw = json
        }

        var json: [String: Any] {
            var out = raw
            out["uri"] = uri
            if !uid.isEmpty { out["uid"] = uid }
            out["provider"] = provider
            if raw["metadata"] == nil { out["metadata"] = metadata }
            return out
        }

        /// A context track dragged into the queued block (librespot tracks.rs rule).
        mutating func promoteToQueue() {
            provider = "queue"
            metadata["is_queued"] = "true"
            var rawMetadata = raw["metadata"] as? [String: Any] ?? [:]
            rawMetadata["is_queued"] = "true"
            raw["metadata"] = rawMetadata
        }

        var isPlayable: Bool { uri.hasPrefix("spotify:track:") || uri.hasPrefix("spotify:episode:") }
    }

    struct Cluster {
        let activeDeviceID: String?
        let contextURI: String?
        let queueRevision: String?
        /// uid of the playing track (player_state.track), never part of a move.
        let currentUID: String?
        let next: [QueueTrack]
        let prev: [QueueTrack]

        init(json: [String: Any]) {
            let state = json["player_state"] as? [String: Any] ?? [:]
            activeDeviceID = (json["active_device_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            currentUID = ((state["track"] as? [String: Any])?["uid"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            contextURI = (state["context_uri"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            queueRevision = state["queue_revision"] as? String
            next = (state["next_tracks"] as? [[String: Any]] ?? []).compactMap(QueueTrack.init(json:))
            prev = (state["prev_tracks"] as? [[String: Any]] ?? []).compactMap(QueueTrack.init(json:))
        }
    }

    /// The last cluster seen (registration answer, dealer push or GET).
    private(set) var cluster: Cluster?

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint", category: "SpotifyConnect")
    private static let host = "https://spclient.wg.spotify.com"
    private static let clientVersion = "1.2.95.452.g5c9bdf32"
    private static let deviceIDKey = "spotifyConnectControllerDeviceID"

    private let dealer = SpotifyDealer()
    private var registeredConnectionID: String?

    private init() {
        dealer.onCluster = { [weak self] json in self?.cluster = Cluster(json: json) }
        dealer.onClose = { [weak self] in self?.registeredConnectionID = nil }
    }

    /// Our hidden controller's device id, 40 hex digits like the web player's.
    static var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIDKey) { return saved }
        let fresh = randomHex(40)
        UserDefaults.standard.set(fresh, forKey: deviceIDKey)
        return fresh
    }

    // MARK: Public API

    /// Opens the channel ahead of a command (call when the music page opens).
    func warmUp() {
        Task { _ = try? await session() }
    }

    @discardableResult
    func skipNext() async -> Bool { await send("skip_next") }

    @discardableResult
    func skipPrevious() async -> Bool { await send("skip_prev") }

    @discardableResult
    func addToQueue(uri: String) async -> Bool {
        var extra: [String: Any] = [
            "track": ["uri": uri, "uid": Self.randomHex(32),
                      "metadata": ["is_queued": "true"], "provider": "queue"] as [String: Any]
        ]
        if let revision = cluster?.queueRevision { extra["queue_revision"] = revision }
        let ok = await send("add_to_queue", extra)
        if ok { await refreshAfterChange() }
        return ok
    }

    /// Plays the current context starting at `index` (its position in the
    /// playlist or album, 0 based).
    @discardableResult
    func playFromContext(index: Int) async -> Bool {
        if cluster?.contextURI == nil { await refreshCluster() }
        guard let context = cluster?.contextURI else {
            Self.log.error("play from context skipped: nothing is playing from a context")
            return false
        }
        let command: [String: Any] = [
            "context": ["uri": context, "url": "context://\(context)", "metadata": [:] as [String: Any]],
            "play_origin": ["feature_identifier": "harmony", "referrer_identifier": "vorssaint"],
            "options": [
                "license": "premium",
                "skip_to": ["track_index": index],
                "player_options_override": [:] as [String: Any]
            ] as [String: Any]
        ]
        let ok = await send("play", command)
        if ok { await refreshAfterChange() }
        return ok
    }

    @discardableResult
    func remove(uid: String) async -> Bool {
        await refreshCluster()
        guard let next = cluster?.next else { return false }
        let remaining = next.filter { $0.uid != uid }
        guard remaining.count != next.count else { return false }
        return await sendSetQueue(remaining)
    }

    /// Replaces the up next list (fresh queue_revision is read first).
    @discardableResult
    func replaceQueue(_ nextTracks: [QueueTrack]) async -> Bool {
        await refreshCluster()
        return await sendSetQueue(nextTracks)
    }

    /// set_queue with next_tracks exactly as Spotify sent them (a no-op reorder, for probing).
    @discardableResult
    func resendQueueUnchanged() async -> Bool {
        await refreshCluster()
        guard let next = cluster?.next else { return false }
        return await sendSetQueue(next)
    }

    /// Moves a song in up next. `from` and `to` are positions in the list the
    /// notch shows (SpotifyQueueService.upNext, which never holds the playing
    /// track); each row is found in next_tracks by its uid and the full list is
    /// reordered around it. A context song moved above a queued one joins the
    /// queue; a queued song moved below the context is refused (Spotify does
    /// not keep that).
    @discardableResult
    func move(from: Int, to: Int) async -> Bool {
        guard from != to else { return true }
        let shown = SpotifyQueueService.shared.upNext.map(\.uid)
        guard shown.indices.contains(from), shown.indices.contains(to),
              !shown[from].isEmpty, !shown[to].isEmpty else {
            Self.log.error("move skipped: rows \(from, privacy: .public)->\(to, privacy: .public) not in the shown list")
            return false
        }
        await refreshCluster()
        guard var full = cluster?.next else { return false }
        let playing = cluster?.currentUID
        guard shown[from] != playing, shown[to] != playing,
              let source = full.firstIndex(where: { $0.uid == shown[from] }),
              let target = full.firstIndex(where: { $0.uid == shown[to] }) else {
            Self.log.error("move skipped: the shown rows are no longer in Spotify's up next")
            return false
        }
        let item = full.remove(at: source)
        let anchor = target > source ? target - 1 : target
        let insertAt = source < target ? anchor + 1 : anchor
        full.insert(item, at: insertAt)
        if item.provider == "queue" {
            guard full[..<insertAt].allSatisfy({ $0.provider == "queue" }) else {
                Self.log.info("move refused: a queued song cannot drop below the playlist")
                return false
            }
        } else if full[(insertAt + 1)...].contains(where: { $0.provider == "queue" }) {
            full[insertAt].promoteToQueue()
        }
        return await sendSetQueue(full)
    }

    // MARK: Session

    private struct Session { var token: String; let clientToken: String?; let connectionID: String }

    /// Token, client token and a registered device on an open dealer socket.
    private func session() async throws -> Session {
        let auth = SpotifyPrivateAuth.shared
        let token = try await auth.validAccessToken()
        let clientToken = await auth.validClientToken()
        let connectionID = try await dealer.open(token: token)
        var session = Session(token: token, clientToken: clientToken, connectionID: connectionID)
        if registeredConnectionID != connectionID {
            try await register(&session)
            registeredConnectionID = connectionID
        }
        return session
    }

    /// Sapphire's hidden controller: PUT hobs_<id>; the answer is the cluster.
    private func register(_ session: inout Session) async throws {
        let body: [String: Any] = [
            "member_type": "CONNECT_STATE",
            "device": ["device_info": ["capabilities": Self.capabilities]]
        ]
        let (data, status) = try await call("PUT", "/connect-state/v1/devices/hobs_\(Self.deviceID)",
                                            body: body, session: &session)
        Self.log.info("register device: HTTP \(status, privacy: .public)")
        guard (200...299).contains(status) else { throw SpotifyConnectState.Failure.status(status) }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            cluster = Cluster(json: json)
        }
    }

    private static let capabilities: [String: Any] = [
        "can_be_player": false,
        "hidden": true,
        "needs_full_player_state": true,
        "volume_steps": 64,
        "gaia_eq_connect_id": true,
        "supports_logout": true,
        "is_observable": true,
        "command_acks": true,
        "supports_rename": false,
        "supports_playlist_v2": true,
        "is_controllable": true,
        "supports_command_request": true,
        "supports_external_episodes": true,
        "supports_set_options_command": true,
        "supported_types": [] as [String]
    ]

    // MARK: Commands

    private func sendSetQueue(_ next: [QueueTrack]) async -> Bool {
        var extra: [String: Any] = [
            "next_tracks": next.map(\.json),
            "prev_tracks": (cluster?.prev ?? []).map(\.json)
        ]
        if let revision = cluster?.queueRevision { extra["queue_revision"] = revision }
        let ok = await send("set_queue", extra)
        await refreshAfterChange()
        return ok
    }

    private func send(_ endpoint: String, _ extra: [String: Any] = [:]) async -> Bool {
        do {
            var session = try await session()
            if cluster?.activeDeviceID == nil { await refreshCluster() }
            guard let target = cluster?.activeDeviceID, target != Self.deviceID else {
                Self.log.error("\(endpoint, privacy: .public) skipped: no active Spotify device")
                return false
            }
            var command: [String: Any] = [
                "endpoint": endpoint,
                "logging_params": ["command_id": Self.randomHex(32)]
            ]
            for (key, value) in extra { command[key] = value }
            let (_, status) = try await call(
                "POST", "/connect-state/v1/player/command/from/\(Self.deviceID)/to/\(target)",
                body: ["command": command], session: &session)
            Self.log.info("\(endpoint, privacy: .public): HTTP \(status, privacy: .public)")
            return (200...299).contains(status)
        } catch {
            Self.log.error("\(endpoint, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// On-demand GET connect-state/v1/cluster (the same read the queue uses).
    private func refreshCluster() async {
        do {
            var session = try await session()
            let (data, status) = try await call("GET", "/connect-state/v1/cluster", body: nil, session: &session)
            Self.log.info("cluster read: HTTP \(status, privacy: .public)")
            guard status == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            cluster = Cluster(json: json)
        } catch {
            Self.log.error("cluster read failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Re-reads the cluster and lets the notch queue redraw from it.
    private func refreshAfterChange() async {
        try? await Task.sleep(nanoseconds: 700_000_000)
        await refreshCluster()
        await SpotifyQueueService.shared.refresh()
    }

    /// One spclient call with the web player headers; a 401 refreshes the token once.
    private func call(_ method: String, _ path: String, body: [String: Any]?,
                      session: inout Session) async throws -> (Data, Int) {
        var result = try await rawCall(method, path, body: body, session: session)
        if result.1 == 401 {
            session.token = try await SpotifyPrivateAuth.shared.refreshAccessToken()
            result = try await rawCall(method, path, body: body, session: session)
        }
        return result
    }

    private func rawCall(_ method: String, _ path: String, body: [String: Any]?,
                         session: Session) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: Self.host + path)!)
        request.httpMethod = method
        SpotifyPrivateAuth.webPlayerHeaders(&request, host: "spclient.wg.spotify.com")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.clientVersion, forHTTPHeaderField: "spotify-app-version")
        request.setValue(session.connectionID, forHTTPHeaderField: "x-spotify-connection-id")
        if let clientToken = session.clientToken { request.setValue(clientToken, forHTTPHeaderField: "client-token") }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func randomHex(_ count: Int) -> String {
        String((0..<count).map { _ in "0123456789abcdef".randomElement()! })
    }
}

// MARK: - QueueCommanding

extension SpotifyConnectCommands: QueueCommanding {
    /// Spotify said no (non-2xx, no active device, or the rows moved under us).
    struct Rejected: Error { let command: String }

    func moveInQueue(from: Int, to: Int) async throws {
        guard await move(from: from, to: to) else { throw Rejected(command: "move") }
    }

    func removeFromQueue(uid: String) async throws {
        guard await remove(uid: uid) else { throw Rejected(command: "remove") }
    }

    /// `nextTracks` are uids from the cluster (a uri works too); every entry
    /// keeps its own uid, provider and metadata. An unknown uri goes in as queued.
    func setQueue(nextTracks: [String]) async throws {
        await refreshCluster()
        let known = cluster?.next ?? []
        let list = nextTracks.map { key in
            known.first { $0.uid == key } ?? known.first { $0.uri == key }
                ?? QueueTrack(uri: key, uid: Self.randomHex(32), metadata: ["is_queued": "true"])
        }
        guard await sendSetQueue(list) else { throw Rejected(command: "set_queue") }
    }
}
