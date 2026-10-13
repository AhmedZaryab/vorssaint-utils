// SPDX-License-Identifier: AGPL-3.0-only
//
//  SpotifyPrivateAuth.swift
//  Token exchange, client token and color-lyrics are copied from Sapphire's
//  SpotifyPrivateAPI.swift (getAccessToken, getClientToken, fetchColorLyrics,
//  decodeColorLyrics) and SpotifyNetwork.swift (SpotifyWebPlayerIdentity, the
//  web player request headers), and MusicModels.swift (AccessTokenResponse,
//  ClientTokenResponse).
//  Sapphire, created by Shariq Charolia on 2025-10-05.
//  Copyright (C) Shariq Charolia. Sapphire is licensed AGPL-3.0.
//  Copied into Vorssaint (GPL-3.0-or-later, combined under GPL-3 section 13).
//  Changes: plain URLSession instead of CustomTLSClient, cookies in the
//  Keychain instead of UserDefaults, no websocket or device registration.

import AppKit
import Foundation
import Security

/// Spotify sign-in the way the web player does it: a normal Spotify login in a
/// window, the session cookie kept in the Keychain, and short-lived web player
/// tokens minted from it. No developer app, no Client ID.
@MainActor
final class SpotifyPrivateAuth: ObservableObject {
    static let shared = SpotifyPrivateAuth()
    static let accountNameKey = "spotifyPrivateAccountName"
    private static let deviceIDKey = "spotifyPrivateDeviceID"
    private static let webPlayerClientID = "d8a5ed958d274c2e8ee717e6a4b0971d"
    private static let clientVersion = "1.2.95.452.g5c9bdf32"

    enum AuthError: Error { case notConnected, rejected(Int), anonymous }

    struct StoredCookie: Codable { let name: String; let value: String; let domain: String }

    @Published private(set) var isConnected = false
    @Published private(set) var accountName: String?
    @Published private(set) var lastError: String?

    private var cookies: [StoredCookie]
    private var accessToken: String?
    private var accessExpiresAt: Date?
    private var clientToken: String?
    private var clientTokenRefreshAt: Date?
    private var tokenTask: Task<String, Error>?

    private init() {
        cookies = SpotifyCookieKeychain.load() ?? []
        isConnected = cookies.contains { $0.name == "sp_dc" }
        accountName = UserDefaults.standard.string(forKey: Self.accountNameKey)
    }

    // MARK: Sign in

    func login() {
        lastError = nil
        SpotifyLoginWindow.present { [weak self] captured in
            guard let self else { return }
            let kept = captured.compactMap { cookie -> StoredCookie? in
                guard ["sp_dc", "sp_key", "sp_t"].contains(cookie.name) else { return nil }
                return StoredCookie(name: cookie.name, value: cookie.value, domain: cookie.domain)
            }
            guard kept.contains(where: { $0.name == "sp_dc" }) else {
                self.lastError = SpotifyQueueStrings.current.signInFailed
                return
            }
            self.cookies = kept
            SpotifyCookieKeychain.save(kept)
            self.resetTokens()
            self.isConnected = true
            Task { await self.loadAccountName() }
        }
    }

    func disconnect() {
        cookies = []
        SpotifyCookieKeychain.delete()
        resetTokens()
        UserDefaults.standard.removeObject(forKey: Self.accountNameKey)
        accountName = nil
        isConnected = false
    }

    private func resetTokens() {
        accessToken = nil
        accessExpiresAt = nil
        clientToken = nil
        clientTokenRefreshAt = nil
        tokenTask = nil
    }

    // MARK: Tokens

    /// A web player token good for at least another minute.
    func validAccessToken() async throws -> String {
        if let accessToken, let accessExpiresAt, accessExpiresAt.timeIntervalSinceNow > 60 { return accessToken }
        return try await refreshAccessToken()
    }

    /// Mints a new token from the session cookie (after a 401 or on expiry).
    func refreshAccessToken() async throws -> String {
        if let tokenTask { return try await tokenTask.value }
        guard isConnected else { throw AuthError.notConnected }
        let cookieHeader = self.cookieHeader
        let task = Task<String, Error> { () throws -> String in
            let response = try await Self.getAccessToken(cookieHeader: cookieHeader)
            guard let token = response.accessToken else { throw AuthError.rejected(0) }
            if response.isAnonymous == true { throw AuthError.anonymous }
            self.accessToken = token
            self.accessExpiresAt = response.accessTokenExpirationTimestampMs
                .map { Date(timeIntervalSince1970: Double($0) / 1000) } ?? Date().addingTimeInterval(3600)
            return token
        }
        tokenTask = task
        defer { tokenTask = nil }
        do {
            return try await task.value
        } catch AuthError.anonymous {
            // Spotify answered with an anonymous token: the cookie was revoked.
            disconnect()
            lastError = SpotifyQueueStrings.current.signInFailed
            throw AuthError.notConnected
        }
    }

    private var cookieHeader: String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    struct AccessTokenResponse: Codable {
        let clientId: String?
        let accessToken: String?
        let accessTokenExpirationTimestampMs: Int?
        let isAnonymous: Bool?
    }

    /// Sapphire's getAccessToken: GET open.spotify.com/api/token with a TOTP
    /// for the current and adjacent 30 s windows.
    private nonisolated static func getAccessToken(cookieHeader: String) async throws -> AccessTokenResponse {
        let candidates = await SpotifyTotpGenerator.generateTotpCandidates()
        var lastError: Error = AuthError.rejected(0)
        for (totp, totpVer) in candidates {
            var components = URLComponents(string: "https://open.spotify.com/api/token")!
            components.queryItems = [
                URLQueryItem(name: "reason", value: "transport"),
                URLQueryItem(name: "productType", value: "web-player"),
                URLQueryItem(name: "totp", value: totp),
                URLQueryItem(name: "totpVer", value: String(totpVer)),
                URLQueryItem(name: "totpServer", value: totp)
            ]
            var request = URLRequest(url: components.url!)
            webPlayerHeaders(&request, host: "open.spotify.com")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200...299).contains(status), !data.isEmpty else { lastError = AuthError.rejected(status); continue }
                return try JSONDecoder().decode(AccessTokenResponse.self, from: data)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Sapphire's getClientToken: POST clienttoken.spotify.com/v1/clienttoken.
    func validClientToken() async -> String? {
        if let clientToken, let clientTokenRefreshAt, clientTokenRefreshAt > Date() { return clientToken }
        var request = URLRequest(url: URL(string: "https://clienttoken.spotify.com/v1/clienttoken")!)
        request.httpMethod = "POST"
        Self.webPlayerHeaders(&request, host: "clienttoken.spotify.com")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_data": [
                "client_version": Self.clientVersion,
                "client_id": Self.webPlayerClientID,
                "js_sdk_data": [
                    "device_brand": "Apple",
                    "device_model": "unknown",
                    "os": "macos",
                    "os_version": "10.15.7",
                    "device_id": Self.deviceID,
                    "device_type": "computer"
                ]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let granted = json["granted_token"] as? [String: Any],
              let token = granted["token"] as? String else { return nil }
        let refreshAfter = granted["refresh_after_seconds"] as? Double ?? 1200
        clientToken = token
        clientTokenRefreshAt = Date().addingTimeInterval(max(60, refreshAfter))
        return token
    }

    private static var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIDKey) { return saved }
        let fresh = (0..<32).map { _ in String("0123456789abcdef".randomElement()!) }.joined()
        UserDefaults.standard.set(fresh, forKey: deviceIDKey)
        return fresh
    }

    /// Sapphire's SpotifyWebPlayerIdentity + webPlayerHeaders.
    nonisolated static func webPlayerHeaders(_ request: inout URLRequest, host: String) {
        let chrome = "131"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chrome).0.0.0 Safari/537.36",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
        request.setValue("\"Not;A=Brand\";v=\"99\", \"Google Chrome\";v=\"\(chrome)\", \"Chromium\";v=\"\(chrome)\"",
                         forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        if !host.hasPrefix("clienttoken.") {
            request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
            request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        }
    }

    private func loadAccountName() async {
        guard let token = try? await validAccessToken() else { return }
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let name = json["display_name"] as? String ?? json["id"] as? String
        accountName = name
        UserDefaults.standard.set(name, forKey: Self.accountNameKey)
    }

    // MARK: Lyrics

    /// Spotify's own synced lyrics for what Spotify is playing now, or nil.
    /// The title must match so a lagging Web API answer never shows the wrong song.
    func syncedLyrics(title: String) async -> [NotchLyricLine]? {
        guard isConnected, let token = try? await validAccessToken() else { return nil }
        var now = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        now.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: now),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["item"] as? [String: Any], let id = item["id"] as? String,
              let name = item["name"] as? String,
              name.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        else { return nil }
        return await colorLyrics(trackID: id, token: token)
    }

    /// Sapphire's fetchColorLyrics: spclient.wg.spotify.com/color-lyrics/v2/track/<id>.
    private func colorLyrics(trackID: String, token: String) async -> [NotchLyricLine]? {
        var components = URLComponents(string: "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackID)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "vocalRemoval", value: "false"),
            URLQueryItem(name: "market", value: "from_token")
        ]
        var request = URLRequest(url: components.url!)
        Self.webPlayerHeaders(&request, host: "spclient.wg.spotify.com")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.clientVersion, forHTTPHeaderField: "spotify-app-version")
        if let clientToken = await validClientToken() {
            request.setValue(clientToken, forHTTPHeaderField: "client-token")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ColorLyrics.self, from: data),
              let block = decoded.lyrics, block.syncType == "LINE_SYNCED" else { return nil }
        let lines = block.lines.compactMap { line -> NotchLyricLine? in
            guard let ms = Double(line.startTimeMs) else { return nil }
            let text = line.words.trimmingCharacters(in: .whitespacesAndNewlines)
            return NotchLyricLine(time: ms / 1000, text: text == "♪" ? "" : text)
        }
        return lines.isEmpty ? nil : lines
    }

    private struct ColorLyrics: Decodable {
        let lyrics: Block?
        struct Block: Decodable {
            let syncType: String?
            let lines: [Line]
            struct Line: Decodable { let startTimeMs: String; let words: String }
        }
    }
}

/// One 0600 file holding the Spotify session cookies as JSON.
enum SpotifyCookieKeychain {
    private static let account = "web-player-session"
    private static let file = "spotify.session"

    static func load() -> [SpotifyPrivateAuth.StoredCookie]? {
        guard let data = SpotifySecretFile.load(file, legacyAccount: account) else { return nil }
        return try? JSONDecoder().decode([SpotifyPrivateAuth.StoredCookie].self, from: data)
    }

    static func save(_ value: [SpotifyPrivateAuth.StoredCookie]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        SpotifySecretFile.save(data, file)
    }

    static func delete() {
        SpotifySecretFile.delete(file, legacyAccount: account)
    }
}
