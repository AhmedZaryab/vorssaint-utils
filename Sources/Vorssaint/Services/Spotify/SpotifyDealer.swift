// SPDX-License-Identifier: AGPL-3.0-only
//
//  SpotifyDealer.swift
//  The live Spotify Connect channel: the dealer websocket the web player keeps
//  open. Adapted from Sapphire's WebSocketManager (SpotifyNetwork.swift,
//  createWebSocketTask / handleMessage / schedulePing / disconnect).
//  Sapphire, created by Shariq Charolia on 2025-10-05.
//  Copyright (C) Shariq Charolia. Sapphire is licensed AGPL-3.0.
//  Combined into Vorssaint (GPL-3.0-or-later) under GPL-3 section 13.
//
//  Vorssaint is a notch, so this is deliberately lazy: the socket opens only
//  when a command is about to go out or the music page opens, sends one ping
//  every 30 s while open (the dealer drops silent sockets), and closes itself
//  after 60 s without use. Closed means no task, no timer, no socket.

import Foundation
import os

@MainActor
final class SpotifyDealer {
    static let idleTimeout: TimeInterval = 60
    static let pingInterval: TimeInterval = 30
    private static let connectTimeout: TimeInterval = 8

    enum Failure: Error { case timedOut, closed }

    /// The Spotify-Connection-Id of the open socket, nil while closed.
    private(set) var connectionID: String?
    /// Called with each cluster the dealer pushes (hm://connect-state/v1/cluster).
    var onCluster: (([String: Any]) -> Void)?
    /// Called when the socket closes, for any reason.
    var onClose: (() -> Void)?

    var isOpen: Bool { socket != nil }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint", category: "SpotifyConnect")
    private let session = URLSession(configuration: .ephemeral)
    private var socket: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var pingLoop: Task<Void, Never>?
    private var idleTimer: Task<Void, Never>?
    private var waiters: [CheckedContinuation<String, Error>] = []

    /// Opens the socket if needed and returns its connection id (the first
    /// message the dealer sends carries it in a Spotify-Connection-Id header).
    func open(token: String) async throws -> String {
        touch()
        if let connectionID, socket != nil { return connectionID }
        if socket == nil { start(token: token) }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Pushes the idle close back by another 60 s.
    func touch() {
        idleTimer?.cancel()
        idleTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.idleTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            Self.log.info("dealer idle \(Int(Self.idleTimeout), privacy: .public)s, closing")
            self?.close()
        }
    }

    func close() {
        idleTimer?.cancel(); idleTimer = nil
        pingLoop?.cancel(); pingLoop = nil
        receiveLoop?.cancel(); receiveLoop = nil
        socket?.cancel(with: .goingAway, reason: nil)
        let wasOpen = socket != nil
        socket = nil
        connectionID = nil
        failWaiters(Failure.closed)
        if wasOpen { onClose?() }
    }

    private func start(token: String) {
        var components = URLComponents(string: "wss://dealer.spotify.com/")!
        components.queryItems = [URLQueryItem(name: "access_token", value: token)]
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
        SpotifyPrivateAuth.webPlayerHeaders(&request, host: "dealer.spotify.com")
        let task = session.webSocketTask(with: request)
        socket = task
        task.resume()
        Self.log.info("dealer opening")

        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    self?.handle(message)
                } catch {
                    guard let self, self.socket === task else { return }
                    Self.log.info("dealer closed: \(error.localizedDescription, privacy: .public)")
                    self.close()
                    return
                }
            }
        }
        pingLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.pingInterval * 1_000_000_000))
                guard !Task.isCancelled, let socket = self?.socket else { return }
                try? await socket.send(.string("{\"type\":\"ping\"}"))
            }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.connectTimeout * 1_000_000_000))
            guard let self, self.socket === task, self.connectionID == nil else { return }
            Self.log.error("dealer gave no connection id in \(Int(Self.connectTimeout), privacy: .public)s")
            self.failWaiters(Failure.timedOut)
            self.close()
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: return
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let headers = json["headers"] as? [String: Any],
           let id = headers["Spotify-Connection-Id"] as? String, !id.isEmpty {
            connectionID = id
            Self.log.info("dealer connected")
            let pending = waiters
            waiters = []
            pending.forEach { $0.resume(returning: id) }
        }

        // Cluster pushes after our device is registered. Plain JSON payloads
        // only; anything else is skipped and the next command re-reads the cluster.
        if let uri = json["uri"] as? String, uri.hasPrefix("hm://connect-state/v1/cluster"),
           let payload = (json["payloads"] as? [[String: Any]])?.first,
           let cluster = payload["cluster"] as? [String: Any] {
            onCluster?(cluster)
        }
    }

    private func failWaiters(_ error: Error) {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume(throwing: error) }
    }
}
