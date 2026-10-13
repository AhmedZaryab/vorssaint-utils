import AppKit
import SwiftUI

/// The same output-switcher preferences in the menu panel and Settings.
struct SoundOutputSwitcherControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var outputSwitcher = SoundOutputSwitcher.shared
    @AppStorage(DefaultsKey.soundOutputSwitcherEnabled)
    private var enabled = false
    @State private var selectedUIDs: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(l10n.s.soundOutputSwitcherEnable, isOn: $enabled)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))
                .onChange(of: enabled) { _, isEnabled in
                    if isEnabled, selectedUIDs.isEmpty,
                       let current = mixer.currentOutputDeviceUID,
                       universalOutputDevices.contains(where: { $0.uid == current }) {
                        setSelectedUIDs([current])
                    }
                    outputSwitcher.syncWithPreferences()
                }

            Text(l10n.s.soundOutputSwitcherCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if enabled {
                ShortcutPreferenceRow(role: .soundOutputSwitcher,
                                      isEnabled: enabled,
                                      additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                    outputSwitcher.syncWithPreferences()
                }
                if outputSwitcher.registrationFailed {
                    inputMessage(l10n.s.shortcutUnavailable, systemImage: "keyboard.badge.ellipsis")
                }
                if outputSwitcher.lastSwitchFailed {
                    inputMessage(l10n.s.soundOutputSwitcherNoAvailableSelection,
                                 systemImage: "speaker.badge.exclamationmark")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.s.soundOutputSwitcherDevices)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    if universalOutputDevices.isEmpty {
                        inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
                    } else {
                        ForEach(universalOutputDevices) { device in
                            Toggle(isOn: selectionBinding(for: device.uid)) {
                                Text(outputDeviceTitle(device))
                                    .font(.system(size: 10.5))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .onAppear { selectedUIDs = outputSwitcher.selectedDeviceUIDs() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            selectedUIDs = outputSwitcher.selectedDeviceUIDs()
        }
    }

    private var universalOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultOutput)
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func selectionBinding(for uid: String) -> Binding<Bool> {
        Binding(
            get: { selectedUIDs.contains(uid) },
            set: { selected in
                var next = selectedUIDs
                if selected {
                    if !next.contains(uid) { next.append(uid) }
                } else {
                    next.removeAll { $0 == uid }
                }
                let visibleOrder = universalOutputDevices.map(\.uid)
                let visible = visibleOrder.filter { next.contains($0) }
                let unavailable = next.filter { !visibleOrder.contains($0) }
                setSelectedUIDs(visible + unavailable)
            }
        )
    }

    private func setSelectedUIDs(_ uids: [String]) {
        let sanitized = Defaults.sanitizedSoundOutputSwitcherDeviceUIDs(uids)
        selectedUIDs = sanitized
        outputSwitcher.setSelectedDeviceUIDs(sanitized)
    }
}
