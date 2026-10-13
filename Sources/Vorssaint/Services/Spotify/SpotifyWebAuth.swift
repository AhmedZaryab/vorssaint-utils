// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CryptoKit
import Foundation
import Network
import Security

/// Spotify Web API sign-in with PKCE: no client secret, a loopback redirect
/// on 127.0.0.1, tokens kept in the Keychain and refreshed before they expire.
@MainActor
final class SpotifyWebAuth: ObservableObject {
    static let shared = SpotifyWebAuth()

    static let port: UInt16 = 43821
    /// Must match the Redirect URI saved on the Spotify developer app exactly.
    static let redirectURI = "http://127.0.0.1:43821/callback"
    static let clientIDKey = "spotifyClientID"
    static let accountNameKey = "spotifyAccountName"
    private static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

    struct Tokens: Codable {
        var access: String
        var refresh: String
        var expiresAt: Date
    }

    enum AuthError: Error { case notConnected, noClientID, rejected(Int) }

    @Published private(set) var isConnected = false
    @Published private(set) var accountName: String?
    @Published private(set) var connecting = false
    @Published private(set) var lastError: String?

    private var tokens: Tokens?
    private var listener: NWListener?
    private var verifier = ""
    private var state = ""
    private var refreshTask: Task<String, Error>?

    var clientID: String {
        (UserDefaults.standard.string(forKey: Self.clientIDKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private init() {
        tokens = SpotifyKeychain.load()
        isConnected = tokens != nil
        accountName = UserDefaults.standard.string(forKey: Self.accountNameKey)
    }

    // MARK: Sign in

    func connect() {
        lastError = nil
        guard !clientID.isEmpty else {
            lastError = SpotifyQueueStrings.current.needsClientID
            return
        }
        verifier = Self.randomString(length: 64)
        state = Self.randomString(length: 16)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        guard startListener() else {
            lastError = SpotifyQueueStrings.current.portBusy
            return
        }
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components.url else { stopListener(); return }
        connecting = true
        NSWorkspace.shared.open(url)
    }

    func disconnect() {
        stopListener()
        tokens = nil
        SpotifyKeychain.delete()
        UserDefaults.standard.removeObject(forKey: Self.accountNameKey)
        accountName = nil
        isConnected = false
        connecting = false
    }

    // MARK: Tokens

    /// A token that is good for at least another minute, refreshing if needed.
    func validAccessToken() async throws -> String {
        guard let tokens else { throw AuthError.notConnected }
        if tokens.expiresAt.timeIntervalSinceNow > 60 { return tokens.access }
        return try await refreshAccessToken()
    }

    /// Called after a 401: the stored token is stale even if its clock says otherwise.
    func refreshAccessToken() async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        guard let current = tokens else { throw AuthError.notConnected }
        let task = Task<String, Error> { [clientID] in
            let fresh = try await Self.tokenRequest([
                "grant_type": "refresh_token",
                "refresh_token": current.refresh,
                "client_id": clientID
            ], keepingRefresh: current.refresh)
            return fresh.access
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let access = try await task.value
            return access
        } catch AuthError.rejected(let status) where status == 400 || status == 401 {
            disconnect()
            throw AuthError.notConnected
        }
    }

    private func store(_ fresh: Tokens) {
        tokens = fresh
        SpotifyKeychain.save(fresh)
        isConnected = true
    }

    private static func tokenRequest(_ form: [String: String], keepingRefresh: String?) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = body.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { throw AuthError.rejected(status) }
        let refresh = json["refresh_token"] as? String ?? keepingRefresh ?? ""
        let expiresIn = json["expires_in"] as? Double ?? 3600
        let fresh = Tokens(access: access, refresh: refresh, expiresAt: Date().addingTimeInterval(expiresIn))
        await MainActor.run { SpotifyWebAuth.shared.store(fresh) }
        return fresh
    }

    private func finish(code: String?, returnedState: String?, error: String?) {
        stopListener()
        guard connecting else { return }
        guard error == nil, let code, returnedState == state else {
            connecting = false
            lastError = SpotifyQueueStrings.current.signInFailed
            return
        }
        let form = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": clientID,
            "code_verifier": verifier
        ]
        Task {
            do {
                _ = try await Self.tokenRequest(form, keepingRefresh: nil)
                await loadAccountName()
            } catch {
                lastError = SpotifyQueueStrings.current.signInFailed
            }
            connecting = false
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

    // MARK: Loopback listener

    private func startListener() -> Bool {
        stopListener()
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: Self.port)!)
        guard let listener = try? NWListener(using: parameters) else { return false }
        listener.newConnectionHandler = { connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
                let requestLine = data.flatMap { String(data: $0, encoding: .utf8) }?
                    .components(separatedBy: "\r\n").first ?? ""
                let parts = requestLine.split(separator: " ")
                let target = parts.count > 1 ? String(parts[1]) : ""
                let items = URLComponents(string: "http://127.0.0.1\(target)")?.queryItems ?? []
                let isCallback = target.hasPrefix("/callback")
                let page = isCallback ? SpotifyQueueStrings.current.browserDone : "Not found"
                let html = "<!doctype html><meta charset=utf-8><title>Vorssaint</title>"
                    + "<body style=\"font:15px -apple-system;padding:40px\">\(page)</body>"
                let reply = "HTTP/1.1 \(isCallback ? "200 OK" : "404 Not Found")\r\nContent-Type: text/html; charset=utf-8\r\n"
                    + "Content-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
                guard isCallback else { return }
                let value = { (name: String) in items.first(where: { $0.name == name })?.value }
                Task { @MainActor in
                    SpotifyWebAuth.shared.finish(code: value("code"), returnedState: value("state"), error: value("error"))
                }
            }
        }
        listener.stateUpdateHandler = { state in
            if case .failed = state {
                Task { @MainActor in
                    SpotifyWebAuth.shared.connecting = false
                    SpotifyWebAuth.shared.lastError = SpotifyQueueStrings.current.portBusy
                    SpotifyWebAuth.shared.stopListener()
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        return true
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    // MARK: Helpers

    private static func randomString(length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// One Keychain item holding the Spotify tokens as JSON.
enum SpotifyKeychain {
    private static let service = "com.vorssaint.spotify"
    private static let account = "web-api-tokens"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> SpotifyWebAuth.Tokens? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyWebAuth.Tokens.self, from: data)
    }

    static func save(_ tokens: SpotifyWebAuth.Tokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
