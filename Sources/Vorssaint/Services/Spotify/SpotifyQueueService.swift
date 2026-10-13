// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import os

/// Spotify's real queue. With the Spotify login it reads the web player's own
/// player state (connect-state on spclient), because the Web API answers 429 to
/// web player tokens; with the developer login it reads the Web API queue.
/// Polls every 5 s only while the notch music page is open on Spotify, caches
/// the last answer, and backs off when Spotify answers 429.
@MainActor
final class SpotifyQueueService: ObservableObject {
    static let shared = SpotifyQueueService()
    static let pollInterval: TimeInterval = 5
    static let visibleCount = 8

    struct Track: Identifiable, Equatable {
        let id: String
        let uri: String
        let title: String
        let artist: String
        let artworkURL: URL?
    }

    @Published private(set) var current: Track?
    @Published private(set) var upNext: [Track] = []
    @Published private(set) var contextURI: String?
    @Published private(set) var loading = false
    @Published private(set) var actionPending = false
    @Published private(set) var actionFailed = false
    @Published private(set) var actionThrottled = false
    @Published private(set) var searchResults: [Track] = []
    @Published private(set) var searching = false
    @Published private(set) var artwork: [URL: NSImage] = [:]
    /// The HTTP status of the last failed queue read (0 = no answer), nil when it worked.
    @Published private(set) var failureCode: Int?
    /// "playlist" or "album" when the songs shown come from what is playing,
    /// not from songs the user queued; nil otherwise.
    @Published private(set) var contextKind: String?

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint", category: "SpotifyQueue")
    private var pollTask: Task<Void, Never>?
    private var backoffUntil: Date?
    private var spclientBackoffUntil: Date?
    private var lastStatus = 0
    private var lastCurrentURI: String?
    private var metadata: [String: SpotifyConnectState.Metadata] = [:]

    static func isSpotify(_ playback: NotchPlayback?) -> Bool {
        playback?.track.appBundleIdentifier?.lowercased().contains("spotify") == true
    }

    static var isAvailable: Bool { AppFeature.spotifyQueue.isAvailable }

    /// Where the Web API token comes from: the Spotify login first (no developer
    /// setup), the developer app's PKCE login second, nothing third.
    enum Provider { case privateLogin, pkce, none }

    static var provider: Provider {
        if SpotifyPrivateAuth.shared.isConnected { return .privateLogin }
        if SpotifyWebAuth.shared.isConnected { return .pkce }
        return .none
    }

    static var isConnected: Bool { provider != .none }

    // MARK: Polling

    func setVisible(_ visible: Bool) {
        pollTask?.cancel()
        pollTask = nil
        guard visible, Self.isAvailable, Self.isConnected else { return }
        if Self.provider == .privateLogin { SpotifyConnectCommands.shared.warmUp() }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let wait = max(Self.pollInterval, self?.activeBackoff?.timeIntervalSinceNow ?? 0)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    private var activeBackoff: Date? {
        Self.provider == .privateLogin ? spclientBackoffUntil : backoffUntil
    }

    func refresh() async {
        guard Self.isConnected else { return }
        if let activeBackoff, activeBackoff > Date() { return }
        if upNext.isEmpty { loading = true }
        defer { loading = false }
        if Self.provider == .privateLogin {
            await refreshFromConnectState()
        } else {
            await refreshFromWebAPI()
        }
        loadArtwork(for: upNext + searchResults)
    }

    /// The retry button: forget any back-off and ask again now.
    func retryNow() {
        backoffUntil = nil
        spclientBackoffUntil = nil
        Task { await refresh() }
    }

    private func refreshFromConnectState() async {
        let auth = SpotifyPrivateAuth.shared
        do {
            var token = try await auth.validAccessToken()
            let clientToken = await auth.validClientToken()
            let cluster: SpotifyConnectState.Cluster
            do {
                cluster = try await SpotifyConnectState.cluster(token: token, clientToken: clientToken)
            } catch SpotifyConnectState.Failure.status(401) {
                token = try await auth.refreshAccessToken()
                cluster = try await SpotifyConnectState.cluster(token: token, clientToken: clientToken)
            }
            let shown = Array(cluster.next.prefix(Self.visibleCount))
            await loadMetadata(for: [cluster.currentURI].compactMap { $0 } + shown.map(\.uri),
                               token: token, clientToken: clientToken)
            current = cluster.currentURI.flatMap { track(uri: $0, index: -1) }
            upNext = shown.enumerated().compactMap { track(uri: $0.element.uri, index: $0.offset) }
            contextURI = cluster.contextURI
            let kind = cluster.contextURI?.split(separator: ":").dropFirst().first.map(String.init)
            contextKind = shown.contains { $0.provider == "queue" } ? nil
                : (kind == "playlist" || kind == "album" ? kind : nil)
            failureCode = nil
            Self.log.info("queue read: connect-state 200, \(self.upNext.count, privacy: .public) items, from \(self.contextKind ?? "queue", privacy: .public)")
        } catch SpotifyConnectState.Failure.status(let status) {
            if status == 429 { spclientBackoffUntil = Date().addingTimeInterval(30) }
            fail(status, source: "connect-state")
        } catch {
            fail(0, source: "connect-state")
        }
    }

    private func refreshFromWebAPI() async {
        guard let (data, status) = try? await call("GET", "/me/player/queue") else {
            fail(0, source: "web-api")
            return
        }
        guard status == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fail(status, source: "web-api")
            return
        }
        let playing = (json["currently_playing"] as? [String: Any]).flatMap { Self.track($0, index: -1) }
        let queue = (json["queue"] as? [[String: Any]] ?? []).enumerated()
            .compactMap { Self.track($0.element, index: $0.offset) }
        current = playing
        upNext = Array(queue.prefix(Self.visibleCount))
        contextKind = nil
        failureCode = nil
        Self.log.info("queue read: web-api 200, \(self.upNext.count, privacy: .public) items")
        if playing?.uri != lastCurrentURI {
            lastCurrentURI = playing?.uri
            await loadContext()
        }
    }

    /// A failed read never looks like an empty queue: keep the last list and say why.
    private func fail(_ status: Int, source: String) {
        failureCode = status
        Self.log.error("queue read failed: \(source, privacy: .public) status \(status, privacy: .public)")
    }

    private func loadMetadata(for uris: [String], token: String, clientToken: String?) async {
        let missing = Array(Set(uris.filter { metadata[$0] == nil }))
        guard !missing.isEmpty else { return }
        let found = await withTaskGroup(of: (String, SpotifyConnectState.Metadata?).self) { group in
            for uri in missing {
                group.addTask { (uri, await SpotifyConnectState.metadata(uri: uri, token: token, clientToken: clientToken)) }
            }
            var result: [(String, SpotifyConnectState.Metadata)] = []
            for await (uri, meta) in group { if let meta { result.append((uri, meta)) } }
            return result
        }
        if metadata.count > 200 { metadata.removeAll() }
        for (uri, meta) in found { metadata[uri] = meta }
    }

    private func track(uri: String, index: Int) -> Track? {
        guard let meta = metadata[uri] else { return nil }
        return Track(id: "\(index)-\(uri)", uri: uri, title: meta.title, artist: meta.artist, artworkURL: meta.artworkURL)
    }

    private func loadContext() async {
        guard let (data, status) = try? await call("GET", "/me/player"), status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            contextURI = nil
            return
        }
        contextURI = (json["context"] as? [String: Any])?["uri"] as? String
    }

    // MARK: Controls

    /// Plays a queued song now through the local Spotify app, never the Web API.
    /// Near the front (or with no URI) it skips forward, which keeps the playlist;
    /// further down it plays the track by URI, which drops the playlist context.
    func playNow(_ track: Track) {
        let position = (upNext.firstIndex(of: track) ?? 0) + 1
        if Self.spotifyRunning {
            let skips = min(position, Self.visibleCount)
            performLocal {
                if track.uri.isEmpty || position <= 3 {
                    return Self.runSpotify(Array(repeating: "next track", count: skips).joined(separator: "\n"))
                }
                return Self.runSpotify("play track \"\(track.uri)\"")
            }
            return
        }
        perform {
            if let context = self.contextURI {
                let body: [String: Any] = ["context_uri": context, "offset": ["uri": track.uri]]
                let data = try JSONSerialization.data(withJSONObject: body)
                if let (_, status) = try? await self.call("PUT", "/me/player/play", body: data), (200..<300).contains(status) {
                    return true
                }
            }
            let added = try await self.call("POST", "/me/player/queue", query: [URLQueryItem(name: "uri", value: track.uri)])
            guard (200..<300).contains(added.1) else { return false }
            let skipped = try await self.call("POST", "/me/player/next")
            return (200..<300).contains(skipped.1)
        }
    }

    func skipNext() { skip(forward: true) }

    func skipPrevious() { skip(forward: false) }

    private func skip(forward: Bool) {
        performLocal {
            if NotchMusicService.shared.send(forward ? .next : .previous) { return true }
            return Self.runSpotify(forward ? "next track" : "previous track")
        }
    }

    private static var spotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }

    private static func runSpotify(_ commands: String) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"Spotify\"\n\(commands)\nend tell")?.executeAndReturnError(&error)
        return error == nil
    }

    func addToQueue(_ track: Track) {
        perform {
            let result = try await self.call("POST", "/me/player/queue", query: [URLQueryItem(name: "uri", value: track.uri)])
            return (200..<300).contains(result.1)
        }
    }

    func search(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { searchResults = []; return }
        searching = true
        Task {
            defer { searching = false }
            let items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "track"),
                         URLQueryItem(name: "limit", value: "6")]
            actionThrottled = false
            lastStatus = 0
            let reply = try? await call("GET", "/search", query: items)
            actionThrottled = reply?.1 == 429
            guard let (data, status) = reply, status == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let found = (json["tracks"] as? [String: Any])?["items"] as? [[String: Any]] else {
                searchResults = []
                return
            }
            searchResults = found.enumerated().compactMap { Self.track($0.element, index: 1000 + $0.offset) }
            loadArtwork(for: searchResults)
        }
    }

    func clearSearch() { searchResults = [] }

    private func perform(_ action: @escaping () async throws -> Bool) {
        guard !actionPending else { return }
        actionPending = true
        actionFailed = false
        actionThrottled = false
        lastStatus = 0
        Task {
            let ok = (try? await action()) ?? false
            actionThrottled = !ok && lastStatus == 429
            actionFailed = !ok && !actionThrottled
            actionPending = false
            // Spotify takes a moment to settle the new queue.
            try? await Task.sleep(nanoseconds: 700_000_000)
            await refresh()
        }
    }

    /// Actions that went through the local Spotify app: no Web API, no generic failure.
    private func performLocal(_ action: @escaping () -> Bool) {
        guard !actionPending else { return }
        actionPending = true
        actionFailed = false
        actionThrottled = false
        Task {
            _ = action()
            try? await Task.sleep(nanoseconds: 700_000_000)
            actionPending = false
            await refresh()
        }
    }

    // MARK: HTTP

    private func call(_ method: String, _ path: String, query: [URLQueryItem] = [],
                      body: Data? = nil, retried: Bool = false) async throws -> (Data, Int) {
        var components = URLComponents(string: "https://api.spotify.com/v1" + path)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        let provider = Self.provider
        let token = try await Self.accessToken(provider, refresh: false)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method != "GET" {
            request.setValue("0", forHTTPHeaderField: "Content-Length")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        lastStatus = status
        if status == 401, !retried {
            _ = try await Self.accessToken(provider, refresh: true)
            return try await call(method, path, query: query, body: body, retried: true)
        }
        if status == 429 {
            let wait = Double(http?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
            backoffUntil = Date().addingTimeInterval(max(wait, Self.pollInterval))
        }
        return (data, status)
    }

    private static func accessToken(_ provider: Provider, refresh: Bool) async throws -> String {
        switch provider {
        case .privateLogin:
            let auth = SpotifyPrivateAuth.shared
            return refresh ? try await auth.refreshAccessToken() : try await auth.validAccessToken()
        case .pkce:
            let auth = SpotifyWebAuth.shared
            return refresh ? try await auth.refreshAccessToken() : try await auth.validAccessToken()
        case .none:
            throw SpotifyWebAuth.AuthError.notConnected
        }
    }

    private static func track(_ json: [String: Any], index: Int) -> Track? {
        guard let uri = json["uri"] as? String, let name = json["name"] as? String else { return nil }
        let artists = (json["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        let show = (json["show"] as? [String: Any])?["name"] as? String
        let images = ((json["album"] as? [String: Any])?["images"] as? [[String: Any]]) ?? (json["images"] as? [[String: Any]]) ?? []
        let small = images.last?["url"] as? String
        return Track(id: "\(index)-\(uri)", uri: uri, title: name,
                     artist: artists?.joined(separator: ", ") ?? show ?? "",
                     artworkURL: small.flatMap(URL.init(string:)))
    }

    private func loadArtwork(for tracks: [Track]) {
        for url in Set(tracks.compactMap(\.artworkURL)) where artwork[url] == nil {
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else { return }
                if artwork.count > 64 { artwork.removeAll() }
                artwork[url] = image
            }
        }
    }
}
