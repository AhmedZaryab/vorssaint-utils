// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the menu bar item needs to stay correct. The live metric layout that
/// used to live here (spacing, bars, separate items) is parked with the
/// system monitor in Legacy/systemMonitor/split/MenuBarSpacingSupport.swift.
enum MenuBarSpacingSupport {
    /// A finite Keep Awake countdown is the only menu-bar content whose text
    /// changes just because time passed. Everything else refreshes from its
    /// publisher or preference change, so no timer should live at rest.
    static func needsTitleRefreshTimer(keepAwakeActive: Bool,
                                       showsCountdown: Bool,
                                       hasEndDate: Bool) -> Bool {
        keepAwakeActive && showsCountdown && hasEndDate
    }

    /// Whether Dynamic Island takes the glyph's place (user request). The
    /// island itself opens Settings and the panel, so the glyph may go for as
    /// long as the island runs. If the island hides in fullscreen, the icon
    /// returns for access to the app even when both options were saved before
    /// this behavior existed. Signals also bring it back, and text the main
    /// item carries (a countdown) keeps the item.
    static func islandHidesStatusIcon(in defaults: UserDefaults, hiddenInFullscreen: Bool = false) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchHidesMenuBarIcon)
            && NotchSupport.isEnabled(in: defaults)
            && !hiddenInFullscreen
    }
}

enum StatusItemPlacementSupport {
    static let mainAutosaveName = "VorssaintMenuBarItem"
    static let maxPlacementGeneration = 10_000

    static func placementGeneration(in defaults: UserDefaults) -> Int {
        min(max(defaults.integer(forKey: DefaultsKey.statusItemPlacementGeneration), 0),
            maxPlacementGeneration)
    }

    static func mainAutosaveName(in defaults: UserDefaults) -> String {
        autosaveName(forGeneration: placementGeneration(in: defaults))
    }

    static func autosaveName(forGeneration generation: Int) -> String {
        let generation = min(max(generation, 0), maxPlacementGeneration)
        guard generation > 0 else { return mainAutosaveName }
        return "\(mainAutosaveName).\(generation)"
    }

    static func preferredPositionKey(for autosaveName: String) -> String {
        "NSStatusItem Preferred Position \(autosaveName)"
    }

    /// The visibility macOS remembers for one item identity, in both the
    /// spellings it has used. Left behind, either keeps the item marked as
    /// hidden, which is the state the recovery exists to undo.
    private static func clearRememberedVisibility(of name: String, in defaults: UserDefaults) {
        defaults.removeObject(forKey: "NSStatusItem Visible \(name)")
        defaults.removeObject(forKey: "NSStatusItem VisibleCC \(name)")
    }

    private static func clearPreferredPosition(of name: String, in defaults: UserDefaults) {
        defaults.removeObject(forKey: preferredPositionKey(for: name))
    }

    private static func clearAllRememberedState(of name: String, in defaults: UserDefaults) {
        clearRememberedVisibility(of: name, in: defaults)
        clearPreferredPosition(of: name, in: defaults)
    }

    /// Undoes a remembered hidden state while leaving the arranged position
    /// alone. An item that starts over with no saved position is born at the
    /// left end of the status area, against the notch, which is the first
    /// zone macOS drops from a crowded bar (issue #167) — so the spot the
    /// person already arranged is worth far more than a fresh identity, and
    /// is only given up when keeping it demonstrably fails.
    static func clearRememberedVisibility(in defaults: UserDefaults) {
        clearRememberedVisibility(of: mainAutosaveName(in: defaults), in: defaults)
    }

    static func bumpPlacementGeneration(in defaults: UserDefaults) {
        let previousGeneration = placementGeneration(in: defaults)
        // Sweep every identity this install may have minted. Leaving Visible /
        // Preferred keys behind for older generations is how recovery quietly
        // accumulates junk without helping the next attempt (#1394).
        for generation in 0...previousGeneration {
            clearAllRememberedState(of: autosaveName(forGeneration: generation), in: defaults)
        }
        let nextGen = (previousGeneration % maxPlacementGeneration) + 1
        defaults.set(nextGen, forKey: DefaultsKey.statusItemPlacementGeneration)
        let nextName = mainAutosaveName(in: defaults)
        clearAllRememberedState(of: nextName, in: defaults)
    }

    /// Whether a status item's window frame says the icon is actually in a
    /// menu bar. Intersecting a screen is not enough: an item macOS declines
    /// to place at all (macOS 26 with the app switched off under System
    /// Settings > Menu Bar > "Allow in the Menu Bar") keeps its window at the
    /// bottom-left origin of the main display, sized like a real item, which
    /// intersects that screen and used to pass for "appeared" (#1394). Only a
    /// frame sitting in the menu bar band of an attached screen counts.
    static func isPlacedStatusFrame(_ frame: CGRect, screenFrames: [CGRect]) -> Bool {
        StatusItemAnchorSupport.isTrustworthyStatusFrame(frame, screenFrames: screenFrames)
    }

    /// While macOS is still settling a newborn status window, recovery must
    /// keep waiting instead of escalating to an identity reset or the
    /// "still hidden" alert (#1394).
    static func shouldKeepWaitingForSettlement(isOnScreen: Bool,
                                               isSettling: Bool,
                                               settlingGraceLeft: Int) -> Bool {
        !isOnScreen && isSettling && settlingGraceLeft > 0
    }
}
