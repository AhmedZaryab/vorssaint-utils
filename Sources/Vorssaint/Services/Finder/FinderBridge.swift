// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// Reads the current Finder selection and the folder a paste would land in,
/// sending the Apple Events IN-PROCESS (see `AppleScriptRunner`) so the Finder
/// Automation consent is attributed to this app — stable across updates and
/// re-requested if it was lost — which is why the cut HUD had stopped appearing
/// for some users. Same Finder Automation permission as before; nothing new.
/// Callers run this off the main thread so a slow Finder never blocks the UI or
/// the event taps.
enum FinderBridge {
    private static let finderBundleID = "com.apple.finder"

    static func selectionURLs(requestPermission: Bool = true) -> [URL] {
        let allowed = requestPermission
            ? AppleScriptRunner.consentToAutomate(bundleID: finderBundleID)
            : Permissions.automationStatus(for: .finder) == .granted
        guard allowed else { return [] }
        let script = """
        tell application "Finder"
            set out to ""
            repeat with f in (get selection)
                set out to out & (POSIX path of (f as alias)) & linefeed
            end repeat
            return out
        end tell
        """
        let result = AppleScriptRunner.run(script)
        guard result.ok else { return [] }
        return result.output.split(whereSeparator: \.isNewline)
            .map { URL(fileURLWithPath: String($0)) }
    }

    static func move(_ urls: [URL], into dir: URL) -> (ok: Bool, canceled: Bool) {
        guard AppleScriptRunner.consentToAutomate(bundleID: finderBundleID) else {
            return (false, false)
        }
        let targets = urls
            .map { "set end of targets to (POSIX file \(AppleScriptRunner.literal($0.path)) as alias)" }
            .joined(separator: "\n")
        let script = """
        with timeout of 600 seconds
            tell application "Finder"
                set targets to {}
                \(targets)
                move targets to folder (POSIX file \(AppleScriptRunner.literal(dir.path)) as alias) without replacing
            end tell
        end timeout
        """
        let result = AppleScriptRunner.runDetailed(script)
        return (result.ok, result.errorNumber == -128)
    }

    static func insertionLocationPath() -> String? {
        guard AppleScriptRunner.consentToAutomate(bundleID: finderBundleID) else { return nil }
        let script = """
        tell application "Finder"
            return POSIX path of (insertion location as alias)
        end tell
        """
        let result = AppleScriptRunner.run(script)
        guard result.ok else { return nil }
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
