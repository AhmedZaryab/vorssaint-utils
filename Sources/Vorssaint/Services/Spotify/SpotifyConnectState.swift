// SPDX-License-Identifier: AGPL-3.0-only
//
//  SpotifyConnectState.swift
//  The queue as the web player sees it: GET connect-state/v1/cluster on
//  spclient (Sapphire's fetchConnectCluster in SpotifyPrivateAPI.swift), with
//  names and covers from spclient's metadata/4 endpoint.
//  Sapphire, created by Shariq Charolia on 2025-10-05.
//  Copyright (C) Shariq Charolia. Sapphire is licensed AGPL-3.0.
//  Combined into Vorssaint (GPL-3.0-or-later) under GPL-3 section 13.
//
//  Why not api.spotify.com: Spotify answers 429 "API rate limit exceeded" to
//  every Web API call made with a web player token, so the queue came back
//  empty. spclient serves the same token without that limit.

import Foundation

enum SpotifyConnectState {
    struct Entry { let uri: String; let provider: String }

    struct Cluster {
        let currentURI: String?
        let contextURI: String?
        let next: [Entry]
    }

    struct Metadata { let title: String; let artist: String; let artworkURL: URL? }

    enum Failure: Error { case status(Int) }

    private static let host = "https://spclient.wg.spotify.com"
    private static let clientVersion = "1.2.95.452.g5c9bdf32"

    /// The player state of the active device, the same JSON the web player reads.
    static func cluster(token: String, clientToken: String?) async throws -> Cluster {
        let (data, status) = try await get("/connect-state/v1/cluster", token: token, clientToken: clientToken)
        guard status == 200 else { throw Failure.status(status) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let state = json?["player_state"] as? [String: Any] ?? [:]
        let next = (state["next_tracks"] as? [[String: Any]] ?? []).compactMap { item -> Entry? in
            guard let uri = item["uri"] as? String, isPlayable(uri) else { return nil }
            return Entry(uri: uri, provider: item["provider"] as? String ?? "context")
        }
        let current = (state["track"] as? [String: Any])?["uri"] as? String
        let context = (state["context_uri"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return Cluster(currentURI: current, contextURI: context, next: next)
    }

    /// Title, artists and the small cover for a track or episode URI.
    static func metadata(uri: String, token: String, clientToken: String?) async -> Metadata? {
        let parts = uri.split(separator: ":")
        guard parts.count == 3, let gid = gid(fromBase62: String(parts[2])) else { return nil }
        let kind = parts[1] == "episode" ? "episode" : "track"
        guard let (data, status) = try? await get("/metadata/4/\(kind)/\(gid)?market=from_token",
                                                  token: token, clientToken: clientToken),
              status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else { return nil }
        let artists = (json["artist"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let show = (json["show"] as? [String: Any])?["name"] as? String
        let covers = ((json["album"] as? [String: Any])?["cover_group"] as? [String: Any])?["image"] as? [[String: Any]]
            ?? (json["cover_image"] as? [String: Any])?["image"] as? [[String: Any]] ?? []
        let small = covers.first { $0["size"] as? String == "SMALL" } ?? covers.first
        let artwork = (small?["file_id"] as? String).flatMap { URL(string: "https://i.scdn.co/image/\($0)") }
        return Metadata(title: name, artist: artists.isEmpty ? (show ?? "") : artists.joined(separator: ", "),
                        artworkURL: artwork)
    }

    private static func isPlayable(_ uri: String) -> Bool {
        uri.hasPrefix("spotify:track:") || uri.hasPrefix("spotify:episode:")
    }

    private static func get(_ path: String, token: String, clientToken: String?) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: host + path)!)
        SpotifyPrivateAuth.webPlayerHeaders(&request, host: "spclient.wg.spotify.com")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientVersion, forHTTPHeaderField: "spotify-app-version")
        if let clientToken { request.setValue(clientToken, forHTTPHeaderField: "client-token") }
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Spotify's base62 id as the 32 hex digit gid the metadata endpoint wants.
    static func gid(fromBase62 id: String) -> String? {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var value = [UInt8](repeating: 0, count: 16)
        for char in id {
            guard let digit = alphabet.firstIndex(of: char) else { return nil }
            var carry = digit
            for index in stride(from: 15, through: 0, by: -1) {
                let total = Int(value[index]) * 62 + carry
                value[index] = UInt8(total & 0xFF)
                carry = total >> 8
            }
            guard carry == 0 else { return nil }
        }
        return value.map { String(format: "%02x", $0) }.joined()
    }
}
