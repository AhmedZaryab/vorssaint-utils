// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Hides other apps' menu bar icons behind a divider. Two status items of our
/// own: a thin divider and an arrow. Whatever the user Cmd-drags to the left
/// of the divider is the hidden group. Hiding widens the divider far past any
/// screen, so macOS has no room left for the items beyond it and drops them,
/// on every display (each display's menu bar mirrors the same items) and past
/// the notch rather than into it. Showing gives the divider its normal width.
/// The same approach as the MIT licensed Hidden Bar and Ice.
final class MenuBarTidyManager: NSObject {
    static let shared = MenuBarTidyManager()

    /// Wider than any display, alone or side by side.
    static let hiddenLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 12
    static let toggleAutosaveName = "VorssaintMenuBarTidyToggle"
    static let dividerAutosaveName = "VorssaintMenuBarTidyDivider"

    private var toggle: NSStatusItem?
    private var divider: NSStatusItem?
    private var hoverTarget: MenuBarTidyHoverTarget?
    private var autoHideTimer: Timer?
    private var clickMonitor: Any?
    private(set) var isHidden = false

    private override init() { super.init() }

    var isRunning: Bool { toggle != nil }

    private var wantsRunning: Bool {
        AppFeature.menuBarTidy.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.menuBarTidyEnabled)
    }

    private var autoHideSeconds: Int {
        max(0, UserDefaults.standard.integer(forKey: DefaultsKey.menuBarTidyAutoHideSeconds))
    }

    func syncWithPreferences() {
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async { self.apply() } }
    }

    private func apply() {
        if wantsRunning { install() } else { uninstall() }
    }

    // MARK: Lifecycle

    /// Idempotent: the items are created once per run. Their autosave names
    /// mean macOS restores the same two slots on relaunch instead of adding
    /// a second divider.
    private func install() {
        guard toggle == nil, divider == nil else { return }
        let defaults = UserDefaults.standard
        seedPosition(Self.toggleAutosaveName, 0, in: defaults)
        seedPosition(Self.dividerAutosaveName, 1, in: defaults)

        // Created first so it sits rightmost; the divider lands to its left.
        let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = Self.toggleAutosaveName
        toggle.isVisible = true
        if let button = toggle.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let hover = MenuBarTidyHoverTarget { [weak self] in self?.show() }
            button.addTrackingArea(NSTrackingArea(rect: .zero,
                                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                                  owner: hover, userInfo: nil))
            hoverTarget = hover
        }

        let divider = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        divider.autosaveName = Self.dividerAutosaveName
        divider.isVisible = true
        if let button = divider.button {
            button.title = "|"
            button.font = NSFont.menuBarFont(ofSize: 0)
            button.alphaValue = 0.55
            button.toolTip = FeatureStrings.menuBarTidy(L10n.shared.language).dividerHelp
            button.appearsDisabled = false
        }

        self.toggle = toggle
        self.divider = divider
        isHidden = false
        refreshToggle()
        // Frames settle a moment after the items appear; hide once they do.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.hide() }
    }

    private func uninstall() {
        cancelAutoHide()
        stopClickMonitor()
        if let divider { NSStatusBar.system.removeStatusItem(divider) }
        if let toggle { NSStatusBar.system.removeStatusItem(toggle) }
        divider = nil
        toggle = nil
        hoverTarget = nil
        isHidden = false
    }

    /// Hidden Bar's seeding: the arrow at the right end of the third party
    /// items, the divider just left of it. Only when macOS has no saved spot.
    private func seedPosition(_ name: String, _ position: CGFloat, in defaults: UserDefaults) {
        let key = "NSStatusItem Preferred Position \(name)"
        if defaults.object(forKey: key) == nil { defaults.set(position, forKey: key) }
    }

    // MARK: Show and hide

    func show() {
        guard let divider else { return }
        if isHidden {
            divider.length = Self.dividerLength
            isHidden = false
            refreshToggle()
        }
        scheduleAutoHide()
        startClickMonitor()
    }

    func hide() {
        guard let divider, !isHidden else { return }
        // If the divider was dragged right of the arrow, hiding would take the
        // arrow with it and leave no way back. Stay shown instead.
        guard dividerIsLeftOfToggle else { return }
        cancelAutoHide()
        stopClickMonitor()
        divider.length = Self.hiddenLength
        isHidden = true
        refreshToggle()
    }

    /// For the Settings button: reveal now, re-hide on the usual timer.
    func showNow() {
        if !isRunning { return }
        show()
    }

    @objc private func toggleClicked(_ sender: Any?) {
        if isHidden { show() } else { hide() }
    }

    private var dividerIsLeftOfToggle: Bool {
        guard let dividerFrame = divider?.button?.window?.frame,
              let toggleFrame = toggle?.button?.window?.frame else { return true }
        return dividerFrame.minX <= toggleFrame.minX
    }

    private func refreshToggle() {
        guard let button = toggle?.button else { return }
        let text = FeatureStrings.menuBarTidy(L10n.shared.language)
        let symbol = isHidden ? "chevron.left" : "chevron.right"
        let image = NSImage(systemSymbolName: symbol,
                            accessibilityDescription: isHidden ? text.toggleShowHelp : text.toggleHideHelp)
        image?.isTemplate = true
        button.image = image
        button.toolTip = isHidden ? text.toggleShowHelp : text.toggleHideHelp
    }

    // MARK: Auto hide

    private func scheduleAutoHide() {
        cancelAutoHide()
        let seconds = autoHideSeconds
        guard seconds > 0 else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            guard let self else { return }
            // A revealed icon's menu may be open: wait while the pointer is
            // still in the menu bar rather than shift it under the user.
            if Self.pointerIsInMenuBar() { self.scheduleAutoHide() } else { self.hide() }
        }
    }

    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    /// A click anywhere below the menu bar tucks the icons away again. Mouse
    /// monitors need no Accessibility permission.
    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !Self.pointerIsInMenuBar() else { return }
            self.hide()
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    private static func pointerIsInMenuBar() -> Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else {
            return false
        }
        let barHeight = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        return point.y >= screen.frame.maxY - barHeight
    }
}

/// Owner of the arrow's tracking area, so hovering it reveals the icons.
private final class MenuBarTidyHoverTarget: NSResponder {
    private let onEnter: () -> Void

    init(onEnter: @escaping () -> Void) {
        self.onEnter = onEnter
        super.init()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseEntered(with event: NSEvent) { onEnter() }
}
