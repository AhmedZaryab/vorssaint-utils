// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the updater's administrator install body with the authorization, the
/// main queue and quitting replaced by doubles that log what ran.
enum UpdateAdminInstallContract {
    static var events: [String] = []

    enum AdminShell {
        static var answer: ((Bool) -> Void)?
        static func runInProcess(_ command: String, prompt: String,
                                 completion: @escaping (Bool) -> Void) {
            events.append("prompt")
            answer = completion
        }
    }
    enum DispatchQueue {
        static let main = Queue()
        final class Queue {
            var pending: [() -> Void] = []
            func async(execute: @escaping () -> Void) { pending.append(execute) }
            func flush() {
                while !pending.isEmpty { pending.removeFirst()() }
            }
        }
    }
    final class Application {
        func terminate(_ sender: Any?) { events.append("quit") }
    }
    static let NSApp = Application()
    struct L10n {
        struct Text { let adminPromptUpdate = "update" }
        static let shared = L10n()
        let s = Text()
    }
    class Fixture {
        func abortInstall(dmgPath: String, offered: String?) { events.append("offer \(offered ?? "")") }
    }

    static func run(_ suite: TestSuite) {
        for granted in [false, true] {
            events = []
            AdminShell.answer = nil
            let service = Service()
            service.launchAdminInstaller(appPath: "/Applications/Vorssaint.app", dmgPath: "/tmp/update.dmg",
                                         pid: 42, resultPath: "/tmp/update-result", expectedVersion: "9.9.9")
            suite.expect(events == ["prompt"],
                         "the administrator prompt is requested for the install")
            AdminShell.answer?(granted)
            DispatchQueue.main.flush()
            if granted {
                suite.expect(events == ["prompt", "quit"],
                             "an approved install quits")
            } else {
                suite.expect(events == ["prompt", "offer 9.9.9"],
                             "a declined prompt keeps the update offer")
            }
            withExtendedLifetime(service) {}
        }
    }
}
