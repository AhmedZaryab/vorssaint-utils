// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Settings destination for the screen capture tools. Screenshot, screen
/// text and the color picker are parked in Legacy/capture, so the recorder is
/// the one tool left; the page keeps the shape it had so they can return.
struct ScreenCaptureSettings: View {
    @ObservedObject private var l10n = L10n.shared

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        Form {
            if AppFeature.screenRecorder.isAvailable {
                Section {
                    ToolShortcutRows(tool: .recording, keys: ScreenCaptureTool.recording.dedicatedShortcut)
                    RecentCapturesShortcutRows()
                } header: {
                    Text(strings.screenCaptureTitle)
                }
                ScreenRecordingCaptureSettings()
            }
        }
        .formStyle(.grouped)
    }
}

/// Capture history shortcut, kept with the recorder it now serves.
private struct RecentCapturesShortcutRows: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = RecentCaptureService.shared
    @AppStorage(DefaultsKey.recentCapturesShortcutEnabled) private var enabled = false

    var body: some View {
        let role = GlobalShortcutRole.recentCaptures
        Toggle(role.title(l10n.s), isOn: $enabled)
            .onChange(of: enabled) { _, _ in
                service.syncWithPreferences()
            }
        ShortcutPreferenceRow(role: role, isEnabled: enabled) {
            service.syncWithPreferences()
        }
        if enabled, service.shortcutRegistrationFailed {
            Text(l10n.s.shortcutUnavailable)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

/// The shortcut that opens the chooser straight on one tool, shown in the
/// page's top section under the tool's own name while that tool is selected.
private struct ToolShortcutRows: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ScreenCaptureService.shared
    @AppStorage private var enabled: Bool
    @AppStorage private var showsCaptureMenu: Bool

    private let tool: ScreenCaptureTool
    private let keys: ScreenCaptureTool.DedicatedShortcut

    init(tool: ScreenCaptureTool, keys: ScreenCaptureTool.DedicatedShortcut) {
        self.tool = tool
        self.keys = keys
        _enabled = AppStorage(wrappedValue: false, keys.enabledKey)
        _showsCaptureMenu = AppStorage(wrappedValue: true, tool.showCaptureMenuOnShortcutKey)
    }

    var body: some View {
        Toggle(keys.role.title(l10n.s), isOn: $enabled)
            .onChange(of: enabled) { _, _ in
                service.syncWithPreferences()
            }
        ShortcutPreferenceRow(role: keys.role, isEnabled: enabled) {
            service.syncWithPreferences()
        }
        Toggle(FeatureStrings.screenshot(l10n.language).showCaptureMenuOnShortcut,
               isOn: $showsCaptureMenu)
            .disabled(!enabled)
        if enabled, service.toolShortcutRegistrationFailures.contains(tool) {
            Text(l10n.s.shortcutUnavailable)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

