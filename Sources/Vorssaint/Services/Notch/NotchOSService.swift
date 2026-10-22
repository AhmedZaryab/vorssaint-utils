// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the OS reports about itself at `/api/notch`. Every field but `ok` may
/// be missing: a newer or older OS never breaks the page.
struct NotchOSSnapshot: Decodable, Equatable {
    enum Status: String, Decodable {
        case duty, off, door

        init(from decoder: Decoder) throws {
            self = Status(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .off
        }
    }

    struct Agent: Decodable, Equatable {
        let name: String
        let status: Status
    }

    struct Message: Decodable, Equatable {
        let name: String
        let body: String
    }

    struct HQ: Decodable, Equatable {
        let title: String?
        let unread: Int?
        let last: Message?
    }

    struct Board: Decodable, Equatable {
        let p0: Int?
    }

    let ok: Bool
    let owner: String?
    let agents: [Agent]?
    let onDuty: Int?
    let atDoor: Int?
    let hq: HQ?
    let board: Board?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case ok, owner, agents, hq, board, url
        case onDuty = "on_duty"
        case atDoor = "at_door"
    }

    var dots: [Status] { (agents ?? []).map(\.status) }
    var dutyCount: Int { onDuty ?? dots.filter { $0 == .duty }.count }
    var doorCount: Int { atDoor ?? dots.filter { $0 == .door }.count }
}

enum NotchOSState: Equatable {
    /// Before the first answer: the page draws nothing rather than flash "off".
    case waiting
    case off
    case live(NotchOSSnapshot)
}

/// Reads the OS on this Mac while the island is open, and never otherwise:
/// the page runs `run()` as a task, so closing the island cancels it.
@MainActor
final class NotchOSService: ObservableObject {
    static let shared = NotchOSService()
    nonisolated static let endpoint = URL(string: "http://localhost:7777/api/notch")!
    nonisolated static let home = URL(string: "http://localhost:7777/board/#pods")!
    nonisolated static let interval: Duration = .seconds(10)
    nonisolated static let timeout: TimeInterval = 2

    @Published private(set) var state: NotchOSState = .waiting

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = NotchOSService.timeout
        configuration.timeoutIntervalForResource = NotchOSService.timeout
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        // One answer per request: no socket is left open between reads.
        configuration.httpAdditionalHeaders = ["Connection": "close"]
        return URLSession(configuration: configuration)
    }()

    /// Reads now, then every ten seconds until the calling task is cancelled.
    func run() async {
        while !Task.isCancelled {
            state = await read()
            do { try await Task.sleep(for: Self.interval) } catch { return }
        }
    }

    private func read() async -> NotchOSState {
        do {
            let (data, response) = try await session.data(from: Self.endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .off }
            return Self.state(from: data)
        } catch {
            return .off
        }
    }

    nonisolated static func state(from data: Data) -> NotchOSState {
        guard let snapshot = try? JSONDecoder().decode(NotchOSSnapshot.self, from: data), snapshot.ok else { return .off }
        return .live(snapshot)
    }

    /// The page the tap opens: the OS's own address when it names a local
    /// http one, otherwise the default. The island never opens a remote page
    /// on the strength of a reply.
    nonisolated static func destination(for snapshot: NotchOSSnapshot?) -> URL {
        guard let text = snapshot?.url, let url = URL(string: text), url.scheme == "http",
              ["localhost", "127.0.0.1"].contains(url.host) else { return home }
        return url
    }
}
