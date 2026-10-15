// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The mixer as a desk: the output and microphone faders on the left, one fader per app
/// running sideways, pinned ones first. Every row action of the panel's list
/// is here: the app's menu pins, moves and routes it, Command-drag reorders,
/// a click on a level types a new one. The toolbar opens
/// the options: where sound effects and the microphone go, the switches the
/// panel keeps under Options, and the hidden rows.
struct NotchMixerView: View {
    let size: CGSize
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var input = AudioInputDeviceManager.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.mixerAppArrangement) private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerHideInactiveApps) private var hideInactiveApps = false
    @State private var showingOptions = false
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    private static let masterWidth: CGFloat = 72
    private static let columnWidth: CGFloat = 96
    private typealias Design = NotchDesign
    private var faderHeight: CGFloat { max(104, size.height - 40) }
    /// A microphone that reports no level has nothing to fade, as in the options.
    private var showsMicrophone: Bool { input.inputVolume != nil }
    private var leadingWidth: CGFloat { showsMicrophone ? Self.masterWidth * 2 + Design.Spacing.small : Self.masterWidth }

    private var arrangement: MixerAppArrangement { MixerAppArrangement(rawValue: arrangementValue) }

    /// The same order and the same hidden rows as the panel's list.
    private var apps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID }).filter { app in
            MixerRoutingSupport.shouldShowApp(isPlaying: app.isPlaying, volume: app.volume,
                                              selectedOutputDeviceUID: app.selectedOutputDeviceUID,
                                              hideInactiveApps: hideInactiveApps)
        }
    }

    var body: some View {
        VStack(spacing: Design.Spacing.section) {
            HStack(spacing: Design.Spacing.small) {
                NotchOutputDeviceMenu(width: size.width - 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NotchIconButton(symbol: showingOptions ? "xmark" : "slider.horizontal.3",
                                title: showingOptions ? l10n.s.menuClose : l10n.s.keepAwakeOptions,
                                selected: showingOptions, action: toggleOptions)
            }
            .frame(height: Design.Control.rowHeight)
            if showingOptions {
                NotchMixerOptions(editingVolumeID: $editingVolumeID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: Design.Spacing.small) {
                    NotchMasterFader(height: faderHeight, editingVolumeID: $editingVolumeID)
                        .frame(width: Self.masterWidth)
                    if showsMicrophone {
                        NotchMicrophoneFader(height: faderHeight, editingVolumeID: $editingVolumeID)
                            .frame(width: Self.masterWidth)
                    }
                    Rectangle().fill(Design.Stroke.keyLine).frame(width: Design.Stroke.hairline)
                        .accessibilityHidden(true)
                    desk.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { mixer.refreshApps() }
        // Escape closes the options before the island.
        .onChange(of: showingOptions) { _, showing in
            guard !preview else { return }
            NotchService.shared.setPageLayer(.mixer, close: showing ? closeOptions : nil)
        }
        .onDisappear { if !preview { NotchService.shared.setPageLayer(.mixer, close: nil) } }
    }

    private func toggleOptions() {
        editingVolumeID = nil
        withAnimation(Design.Motion.fade) { showingOptions.toggle() }
    }

    /// What Escape does: it only ever closes the options.
    private func closeOptions() {
        editingVolumeID = nil
        withAnimation(Design.Motion.fade) { showingOptions = false }
    }

    @ViewBuilder private var desk: some View {
        if !AppVolumeMixer.isSupported {
            NotchEmptyView(symbol: NotchModule.mixer.symbol, message: l10n.s.mixerUnavailable)
        } else if mixer.needsPermission {
            permission
        } else if apps.isEmpty {
            NotchEmptyView(symbol: NotchModule.mixer.symbol, message: l10n.s.mixerEmpty)
        } else {
            let apps = apps
            let ids = apps.compactMap(\.persistenceID)
            NotchRail(items: apps, rows: 1, itemWidth: Self.columnWidth,
                      width: size.width - leadingWidth - Design.Spacing.section - Design.Stroke.hairline) { app in
                NotchAppFader(app: app, height: faderHeight, editingVolumeID: $editingVolumeID,
                              isPinned: arrangement.isPinned(app.persistenceID),
                              togglePin: { updateArrangement { $0.togglePin(app.persistenceID ?? "") } },
                              moveBack: moveAction(for: app, offset: -1, ids: ids),
                              moveForward: moveAction(for: app, offset: 1, ids: ids))
                    .modifier(MixerAppReorderModifier(
                        id: app.persistenceID,
                        icon: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32),
                        draggingID: $draggingAppID,
                        target: $dropTarget,
                        dragChanged: { NotchService.shared.fileDragChanged($0, internalDrag: true) },
                        canMove: { source, target in
                            ids.contains(source) && ids.contains(target)
                                && arrangement.isPinned(source) == arrangement.isPinned(target)
                        },
                        move: { source, target, after in
                            updateArrangement { $0.move(source, to: target, after: after, visibleIDs: ids) }
                        },
                        sideways: true))
                    .help(app.name + "\n" + FeatureStrings.mixer(l10n.language).arrange)
            }
        }
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func moveAction(for app: MixerApp, offset: Int, ids: [String]) -> (() -> Void)? {
        guard let id = app.persistenceID,
              arrangement.neighbor(of: id, offset: offset, visibleIDs: ids) != nil else { return nil }
        return { updateArrangement { $0.move(id, offset: offset, visibleIDs: ids) } }
    }

    private var permission: some View {
        HStack(spacing: Design.Spacing.large) {
            Image(systemName: "waveform.badge.exclamationmark").font(Design.Icon.hero.font)
                .foregroundStyle(Design.Ink.secondary)
                .frame(width: Design.Control.heroGlyph, height: Design.Control.heroGlyph)
                .background(Design.Fill.card, in: RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                Text(l10n.s.mixerPermissionBody).font(Design.Typography.callout.font).foregroundStyle(Design.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Permissions.shared.openAudioCaptureSettings() } label: {
                    Text(l10n.s.permissionOpenSettings).font(Design.Typography.label.font)
                        .foregroundStyle(Design.Ink.primary)
                        .padding(.horizontal, Design.Spacing.medium)
                        .frame(minHeight: Design.Control.rowHeight)
                        .background(Design.Fill.control, in: Capsule(style: .continuous))
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
            }
        }
        .padding(.horizontal, Design.Spacing.small)
    }
}

/// A level that reads as text and, clicked, takes a typed one: the same
/// editor as the panel's rows, so the two agree on what a "150" means.
private struct NotchEditablePercent: View {
    let percent: Int
    let maximum: Int
    let editorID: String
    @Binding var editingID: String?
    let label: String
    var tint: Color = NotchDesign.Ink.secondary
    var boosting = false
    var width: CGFloat = 44
    var height: CGFloat = NotchDesign.Control.rowHeight
    let commit: (Double) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EditableVolumePercent(currentPercent: percent, maximumPercent: maximum, width: width, height: height,
                              editorID: editorID, editingID: $editingID, accessibilityLabel: label) {
            HStack(spacing: NotchDesign.Spacing.line) {
                if boosting {
                    Image(systemName: "bolt.fill").font(NotchDesign.Typography.caption.font).foregroundStyle(tint)
                }
                Text("\(percent)%")
                    .font(NotchDesign.Typography.readout.font).monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion), value: percent)
            }
            .frame(maxWidth: .infinity, minHeight: height)
        } onCommit: { commit($0) }
        .frame(height: height)
    }
}

/// One column's head: the mute toggle in a row, the column's name under it. The
/// output, the microphone and every app share it so the faders line up.
private struct NotchMixerColumnHead<Lead: View>: View {
    let name: String
    @ViewBuilder let lead: () -> Lead

    var body: some View {
        VStack(spacing: NotchDesign.Spacing.line) {
            lead().frame(height: NotchDesign.Control.rowHeight)
            Text(name).font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.primary)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: NotchMixerFaderLayout.nameHeight)
        }
    }
}

/// The system output: its device, level and mute, in the same column shape
/// as the apps beside it.
private struct NotchMasterFader: View {
    let height: CGFloat
    @Binding var editingVolumeID: String?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var level: Double? { mixer.systemOutputVolume.map { mixer.systemOutputMuted == true ? 0 : $0 } }
    private var muted: Bool { mixer.systemOutputMuted == true }

    /// The fader already shows the level it sets, so the open header keeps
    /// its title instead of repeating it.
    private func adjustOutput(volume: Double? = nil, muted: Bool? = nil) {
        NotchService.shared.noteOwnVolumeAdjustment()
        mixer.requestOutputAdjustment(volume: volume, muted: muted)
    }

    var body: some View {
        VStack(spacing: NotchDesign.Spacing.xSmall) {
            NotchMixerColumnHead(name: l10n.s.mixerSystemOutputTitle) {
                Toggle(l10n.s.actionMute,
                       isOn: Binding(get: { muted }, set: { adjustOutput(muted: $0) }))
                    .toggleStyle(NotchToggleStyle(on: "speaker.slash.fill", off: "speaker.wave.2.fill",
                                                  shape: .rounded(NotchDesign.Radius.control)))
                    .disabled(mixer.systemOutputMuted == nil)
            }
            if let level {
                NotchLevelSlider(value: Binding(get: { level }, set: { adjustOutput(volume: $0) }),
                                 label: l10n.s.mixerSystemOutputTitle, vertical: true, trackThickness: NotchMixerFaderLayout.trackThickness)
                    .frame(width: NotchMixerFaderLayout.sliderWidth, height: NotchMixerFaderLayout.trackHeight(in: height))
                NotchEditablePercent(percent: Int((level * 100).rounded()), maximum: 100,
                                     editorID: "notch-system-output", editingID: $editingVolumeID,
                                     label: l10n.s.mixerSystemOutputTitle) {
                    adjustOutput(volume: $0)
                }
            } else {
                Text(l10n.s.mixerOutputUnavailable).font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }
}

/// The microphone beside the output: the same column, its mute and level.
private struct NotchMicrophoneFader: View {
    let height: CGFloat
    @Binding var editingVolumeID: String?
    @ObservedObject private var input = AudioInputDeviceManager.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: NotchDesign.Spacing.xSmall) {
            NotchMixerColumnHead(name: l10n.s.mixerInputTitle) {
                // The mute is its own feature; without it the column keeps the
                // plain icon the options row shows.
                if AppFeature.micMute.isAvailable {
                    Toggle(l10n.s.micMuteName,
                           isOn: Binding(get: { micMute.isMuted }, set: { if $0 != micMute.isMuted { micMute.toggle() } }))
                        .toggleStyle(NotchToggleStyle(on: "mic.slash.fill", off: "mic.fill",
                                                      shape: .rounded(NotchDesign.Radius.control)))
                } else {
                    Image(systemName: (input.inputVolume ?? 0) <= 0.001 ? "mic.slash.fill" : "mic.fill")
                        .font(NotchDesign.Icon.button.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .accessibilityHidden(true)
                }
            }
            if let volume = input.inputVolume {
                NotchLevelSlider(value: Binding(get: { volume }, set: { input.setInputVolume($0) }),
                                 label: l10n.s.mixerInputTitle, vertical: true, trackThickness: NotchMixerFaderLayout.trackThickness)
                    .frame(width: NotchMixerFaderLayout.sliderWidth, height: NotchMixerFaderLayout.trackHeight(in: height))
                    .disabled(micMute.isMuted)
                NotchEditablePercent(percent: Int((volume * 100).rounded()), maximum: 100,
                                     editorID: "notch-microphone-fader", editingID: $editingVolumeID,
                                     label: l10n.s.mixerInputTitle) {
                    input.setInputVolume($0)
                }
                .disabled(micMute.isMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }
}

/// Every column reserves the same head, name, gaps and footer, so the faders line up.
private enum NotchMixerFaderLayout {
    static let nameHeight: CGFloat = 18
    static let sliderWidth: CGFloat = 40
    static let trackThickness: CGFloat = 28
    static func trackHeight(in height: CGFloat) -> CGFloat {
        let head = NotchDesign.Control.rowHeight + NotchDesign.Spacing.line + nameHeight
        let gaps = NotchDesign.Spacing.xSmall * 2
        return min(160, max(32, height - head - NotchDesign.Control.rowHeight - gaps))
    }
}

/// A chooser whose current choice reads in full, on the shared menu button: one line
/// cut in the middle, a chevron, a wash under the pointer.
private struct NotchMixerDeviceMenu: View {
    let title: String
    let current: String
    var width: CGFloat = 200
    let items: [NotchMenuItem]

    var body: some View {
        NotchPullDown(title: title, current: current, maxWidth: width, truncation: .middle, items: items)
    }
}

private struct NotchOutputDeviceMenu: View {
    var width: CGFloat = 150
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var deviceName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID })?.name ?? l10n.s.mixerOutputUnavailable
    }

    private var current: String { mixer.outputSwitchError ?? deviceName }
    private var items: [NotchMenuItem] {
        mixer.outputDevices.filter(\.canBeDefaultOutput).map { device in
            NotchMenuItem(title: device.name, checked: device.uid == mixer.currentOutputDeviceUID) {
                _ = mixer.setUniversalOutputDeviceUID(device.uid)
            }
        }
    }

    var body: some View {
        NotchMixerDeviceMenu(title: l10n.s.mixerSystemOutputTitle, current: current, width: width, items: items)
    }
}

/// Everything the desk leaves out, in one list that scrolls down: where the
/// output, sound effects and the microphone go, the microphone's level, and
/// the panel's options under them.
private struct NotchMixerOptions: View {
    @Binding var editingVolumeID: String?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var input = AudioInputDeviceManager.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var l10n = L10n.shared
    private typealias Design = NotchDesign
    private var outputDevices: [MixerOutputDevice] { mixer.outputDevices.filter(\.canBeDefaultOutput) }
    private var soundEffectsDevices: [MixerOutputDevice] { mixer.outputDevices.filter(\.canBeDefaultSystemOutput) }
    private var soundEffectsName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentSystemSoundOutputDeviceUID })?.name ?? l10n.s.mixerOutputUnavailable
    }
    private var microphoneName: String {
        guard let uid = selectedMicrophoneUID else { return l10n.s.mixerOutputDefault }
        return input.inputDevices.first(where: { $0.uid == uid })?.name ?? l10n.s.mixerInputUnavailable
    }
    private var selectedMicrophoneUID: String? {
        MixerRoutingSupport.selectedInputDeviceUID(
            preferredUID: input.preferredInputDeviceUID,
            currentUID: input.currentInputDeviceUID,
            priorityIsActive: false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.small) {
                VStack(alignment: .leading, spacing: Design.Spacing.xSmall) {
                    row(l10n.s.mixerSystemOutputTitle, symbol: "speaker.wave.2") { NotchOutputDeviceMenu(width: 200) }
                    if outputDevices.isEmpty {
                        message(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
                    }
                    if let error = mixer.outputSwitchError {
                        message(String(format: l10n.s.mixerSystemOutputErrorFormat, error),
                                systemImage: "exclamationmark.triangle")
                    }
                    row(l10n.s.mixerSoundEffectsOutputTitle, symbol: "bell") {
                        NotchMixerDeviceMenu(title: l10n.s.mixerSoundEffectsOutputTitle, current: soundEffectsName,
                                        items: soundEffectsDevices.map { device in
                                            NotchMenuItem(title: device.name,
                                                          checked: device.uid == mixer.currentSystemSoundOutputDeviceUID) {
                                                _ = mixer.setSystemSoundOutputDeviceUID(device.uid)
                                            }
                                        })
                    }
                    if soundEffectsDevices.isEmpty {
                        message(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
                    }
                    microphone
                }
                Rectangle().fill(Design.Stroke.keyLine).frame(height: Design.Stroke.hairline).accessibilityHidden(true)
                MixerOptionsControls()
            }
            .padding(.trailing, Design.Spacing.xxSmall)
            .padding(.bottom, Design.Spacing.xxSmall)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var microphone: some View {
        row(l10n.s.mixerInputTitle, symbol: micMute.isMuted ? "mic.slash" : "mic") {
            NotchMixerDeviceMenu(title: l10n.s.mixerInputTooltip, current: microphoneName,
                            items: [NotchMenuItem(title: l10n.s.mixerOutputDefault, checked: selectedMicrophoneUID == nil) {
                                guard !false else { return }
                                input.setPreferredInputDeviceUID(nil)
                            }] + input.inputDevices.map { device in
                                NotchMenuItem(title: device.name, checked: device.uid == selectedMicrophoneUID) {
                                    if false {
                                        input.setCurrentInputDeviceUID(device.uid)
                                    } else {
                                        input.setPreferredInputDeviceUID(device.uid)
                                    }
                                }
                            } + (!false
                                 && input.preferredUnavailable && input.preferredInputDeviceUID != nil
                                 ? [NotchMenuItem(title: l10n.s.mixerInputUnavailable, checked: true)] : []))
        }
        if let volume = input.inputVolume {
            HStack(spacing: Design.Spacing.small) {
                // The mute is its own feature; without it the row keeps the
                // plain icon the panel's row shows.
                if AppFeature.micMute.isAvailable {
                    Toggle(l10n.s.micMuteName,
                           isOn: Binding(get: { micMute.isMuted }, set: { if $0 != micMute.isMuted { micMute.toggle() } }))
                        .toggleStyle(NotchToggleStyle(on: "mic.slash.fill", off: "mic.fill",
                                                      shape: .rounded(Design.Radius.control)))
                } else {
                    Image(systemName: volume <= 0.001 ? "mic.slash.fill" : "mic.fill")
                        .font(Design.Icon.button.font)
                        .foregroundStyle(Design.Ink.secondary)
                        .frame(width: Design.Control.iconButton, height: Design.Control.iconButton)
                        .accessibilityHidden(true)
                }
                NotchLevelSlider(value: Binding(get: { volume }, set: { input.setInputVolume($0) }),
                                 label: l10n.s.mixerInputTitle)
                    .frame(height: Design.Control.rowHeight)
                    .disabled(micMute.isMuted)
                NotchEditablePercent(percent: Int((volume * 100).rounded()), maximum: 100,
                                     editorID: "notch-microphone-input", editingID: $editingVolumeID,
                                     label: l10n.s.mixerInputTitle) {
                    input.setInputVolume($0)
                }
                .disabled(micMute.isMuted)
            }
            .frame(height: Design.Control.rowHeight)
        }
        if input.inputDevices.isEmpty {
            message(l10n.s.mixerInputNoDevices, systemImage: "mic.slash")
        } else if !false, input.preferredUnavailable {
            message(l10n.s.mixerInputFallback, systemImage: "mic.badge.xmark")
        } else if let lastError = input.lastError {
            message(String(format: l10n.s.mixerInputErrorFormat, lastError), systemImage: "exclamationmark.triangle")
        }
    }

    private func row<Menu: View>(_ title: String, symbol: String, @ViewBuilder menu: () -> Menu) -> some View {
        HStack(spacing: Design.Spacing.small) {
            Image(systemName: symbol).font(Design.Icon.button.font).foregroundStyle(Design.Ink.secondary)
                .frame(width: Design.Control.iconButton)
            Text(title).font(Design.Typography.callout.font).foregroundStyle(Design.Ink.secondary).lineLimit(1)
            Spacer(minLength: Design.Spacing.xxSmall)
            menu()
        }
        .frame(height: Design.Control.rowHeight)
    }

    private func message(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(Design.Typography.caption.font)
            .foregroundStyle(Design.Ink.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One app: an icon with actions beside it, a fader and level. The track ticks at unity, and the
/// fader turns amber in the boost range the way the panel's slider does.
/// The panel row's menu, output picker and context menu fold into the
/// column's own menu, with the route shown as a badge on the icon.
private struct NotchAppFader: View {
    let app: MixerApp
    let height: CGFloat
    @Binding var editingVolumeID: String?
    let isPinned: Bool
    let togglePin: () -> Void
    let moveBack: (() -> Void)?
    let moveForward: (() -> Void)?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    private var strings: MixerFeatureStrings { FeatureStrings.mixer(l10n.language) }
    private var percent: Int { Int((app.volume * 100).rounded()) }
    private var boosting: Bool { percent > 100 }
    private var muted: Bool { app.volume <= 0.001 }
    private var routed: Bool { !app.isBypassed && app.selectedOutputDeviceUID != nil }
    private var routeDescription: String {
        if app.outputDeviceUnavailable { return l10n.s.mixerOutputFallback }
        return mixer.outputDevices.first(where: { $0.uid == app.selectedOutputDeviceUID })?.name
            ?? l10n.s.mixerOutputUnavailable
    }

    private typealias Design = NotchDesign

    var body: some View {
        VStack(spacing: Design.Spacing.xSmall) {
            NotchMixerColumnHead(name: app.name) {
                icon
                    .frame(maxWidth: .infinity)
                    .help(app.name)
                    .overlay(alignment: .trailing) {
                        if app.persistenceID != nil || !app.isBypassed { actionsMenu }
                    }
                    .overlay(alignment: .leading) {
                        if isPinned {
                            Image(systemName: "pin.fill").font(Design.Typography.caption.font)
                                .foregroundStyle(Design.Ink.secondary)
                                .accessibilityLabel(strings.pinFirst)
                        }
                    }
            }
            if app.isBypassed {
                // Conferencing and pro audio apps manage their own sound: listed so
                // their absence never reads as a bug, never tapped.
                Text(l10n.s.mixerBypassedCaption)
                    .font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotchLevelSlider(value: Binding(get: { app.volume }, set: { mixer.setVolume($0, for: app) }),
                                 label: app.name, range: 0...AppVolumeMixer.maxVolume,
                                 tint: boosting ? Design.Palette.warning : .white, vertical: true,
                                 trackThickness: NotchMixerFaderLayout.trackThickness, marker: 1,
                                 valueLabel: "\(percent)%")
                    .frame(width: NotchMixerFaderLayout.sliderWidth, height: NotchMixerFaderLayout.trackHeight(in: height))
                NotchEditablePercent(percent: percent, maximum: Int(AppVolumeMixer.maxVolume * 100),
                                     editorID: "notch-app:\(app.id)", editingID: $editingVolumeID,
                                     label: app.name, tint: boosting ? Design.Palette.warning : Design.Ink.secondary,
                                     boosting: boosting) {
                    mixer.setVolume($0, for: app)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button { mixer.setVolume(1, for: app) } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(Design.Icon.button.font)
                            .foregroundStyle(boosting ? Design.Palette.warning : Design.Ink.secondary)
                            .frame(width: Design.Control.minimumHit, height: Design.Control.minimumHit)
                            .contentShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
                    }
                    .buttonStyle(NotchPressStyle(shape: .rounded(Design.Radius.control)))
                    .opacity(percent == 100 ? 0 : 1)
                    .animation(Design.Motion.fade, value: percent == 100)
                    .disabled(percent == 100)
                    .help(l10n.s.mixerResetTooltip)
                    .accessibilityLabel(l10n.s.mixerResetTooltip)
                }
                .overlay(alignment: .trailing) {
                    Toggle(l10n.s.actionMute,
                           isOn: Binding(get: { muted }, set: { if $0 != muted { mixer.toggleMute(app) } }))
                        .toggleStyle(NotchToggleStyle(on: "speaker.slash.fill", off: "speaker.wave.2.fill",
                                                      shape: .rounded(Design.Radius.control)))
                }
                .frame(height: Design.Control.rowHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .notchContextMenu(menuItems)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(app.name)
        .accessibilityValue("\(percent)%")
        .accessibilityAction(named: Text(strings.moveLeft)) { moveBack?() }
        .accessibilityAction(named: Text(strings.moveRight)) { moveForward?() }
    }

    private var icon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32))
                .resizable()
                .frame(width: Design.Control.iconButton, height: Design.Control.iconButton)
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
            if app.isPlaying {
                Circle().fill(Design.Palette.positive).frame(width: 8, height: 8)
                    .overlay { Circle().stroke(.black, lineWidth: 1.5) }
                    .offset(x: 2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // An app sent to its own device wears the route on its icon; the
            // panel's row shows the picker itself, which the column has no
            // room for.
            if routed {
                Image(systemName: app.outputDeviceUnavailable ? "exclamationmark.triangle.fill" : "arrow.triangle.branch")
                    .font(Design.Typography.caption.font)
                    .foregroundStyle(app.outputDeviceUnavailable ? Design.Palette.warning : Design.Ink.primary)
                    .frame(width: 14, height: 14)
                    .background(.black, in: Circle())
                    .offset(x: -3, y: 2)
                    .help(routeDescription)
                    .accessibilityLabel(routeDescription)
            }
        }
    }

    /// The app's menu on the shared menu button: pin, move, route, reset, hide.
    private var actionsMenu: some View {
        NotchMoreMenu(title: "\(strings.actions): \(app.name)", items: menuItems)
            .help(strings.actions)
    }

    private var menuItems: [NotchMenuItem] {
        var items: [NotchMenuItem] = []
        if app.persistenceID != nil {
            items.append(NotchMenuItem(title: isPinned ? strings.unpin : strings.pinFirst,
                                       symbol: isPinned ? "pin.slash" : "pin", action: togglePin))
            items.append(NotchMenuItem(title: strings.moveLeft, symbol: "arrow.left",
                                       enabled: moveBack != nil) { moveBack?() })
            items.append(NotchMenuItem(title: strings.moveRight, symbol: "arrow.right",
                                       enabled: moveForward != nil) { moveForward?() })
        }
        if !app.isBypassed {
            if app.persistenceID != nil { items.append(.separator) }
            let current = app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID
            var routes: [NotchMenuItem] = []
            func route(_ title: String, _ id: String) {
                routes.append(NotchMenuItem(title: title, checked: current == id) { outputSelection.wrappedValue = id })
            }
            let systemOutput = mixer.outputDevices.first(where: \.isDefault)?.name
            route(systemOutput.map { "\(l10n.s.mixerOutputDefault): \($0)" } ?? l10n.s.mixerOutputDefault,
                  MixerRoutingSupport.systemDefaultSelectionID)
            for device in mixer.outputDevices {
                route(device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name, device.uid)
            }
            if let selected = app.selectedOutputDeviceUID,
               MixerRoutingSupport.needsUnavailableOutputRow(selectedUID: selected,
                                                             isUnavailable: app.outputDeviceUnavailable,
                                                             listedUIDs: mixer.outputDevices.map(\.uid)) {
                route(l10n.s.mixerOutputUnavailable, selected)
            }
            if mixer.outputDevices.contains(where: { MixerRoutingSupport.isAirPlaySentinel($0.uid) }) {
                routes.append(.separator)
                route(l10n.s.mixerAirPlayChooseSpeaker, MixerRoutingSupport.airPlaySpeakerChoiceID)
            }
            items.append(NotchMenuItem(title: l10n.s.mixerOutputTooltip, symbol: "speaker.wave.2", submenu: routes))
            items.append(.separator)
            items.append(NotchMenuItem(title: l10n.s.mixerResetTooltip, enabled: percent != 100) {
                mixer.setVolume(1, for: app)
            })
        }
        if app.persistenceID != nil {
            items.append(.separator)
            items.append(NotchMenuItem(title: l10n.s.mixerHideFromList) { mixer.hideFromList(app) })
        }
        return items
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                                         for: app)
            }
        )
    }
}
