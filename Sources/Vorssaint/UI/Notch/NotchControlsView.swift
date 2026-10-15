// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

private typealias Design = NotchDesign

/// Values the level cards share, so volume, brightness and the keyboard light
/// start and end their sliders on the same lines. The row is the 28 pt level
/// row; the glyph column is the hit target of the mute button.
private enum NotchLevelMetrics {
    /** A level row, and the glyph column every level leads with. */ static let row = Design.Control.rowHeight
    /** The card's title row; the 28 pt mute button overflows it into the card's padding. */ static let titleRow: CGFloat = 20
    /** The width reserved for "100%" in the readout, so sliders end on one line. */ static let readoutWidth: CGFloat = 36
    /** Card padding when the device row is shown: the three lines fit the 96 pt card. */ static let detailPadding = Design.Spacing.small
    /** Card padding on a folded card: title row, slider and the 68 pt minimum height. */ static let foldedPadding = Design.Spacing.xxSmall
}

/// How a level control draws: a full card with its device menu, one slim row
/// inside a shared card, or the inline strip under the player.
enum NotchLevelStyle {
    case card, row, inline
}

struct NotchControlsView: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessEnabled = false

    var body: some View {
        let items = NotchSupport.controls()
        let levels = items.filter(\.isLevel)
        let shortcuts = items.filter { !$0.isLevel && $0 != .music }
        let layout = NotchLayout.controls(hasCards: items.contains(.music) || !levels.isEmpty,
                                          shortcutCount: shortcuts.count, width: size.width, height: size.height)
        if items.isEmpty {
            NotchEmptyView(symbol: "slider.horizontal.3", message: FeatureStrings.notch(l10n.language).empty)
        } else {
            VStack(spacing: NotchLayout.rowSpacing) {
                if layout.cardRow > 0 {
                    cards(levels: levels, music: items.contains(.music), height: layout.cardRow)
                }
                if layout.shortcutRows > 0 {
                    NotchRail(items: shortcuts, rows: layout.shortcutRows, itemWidth: NotchLayout.shortcutWidth,
                              width: size.width, spacing: NotchLayout.shortcutSpacing, rowSpacing: NotchLayout.shortcutSpacing) { item in
                        shortcut(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Playback shares the row with the levels: two or three of them fold
    /// into one slim card beside it, a single one keeps its full card.
    @ViewBuilder private func cards(levels: [NotchControlItem], music: Bool, height: CGFloat) -> some View {
        let musicWidth = NotchLayout.musicCardMinimumWidth(height: height)
        let required = music ? musicWidth + (levels.isEmpty ? 0 : 160 + NotchLayout.rowSpacing) : 0
        if required > size.width {
            ScrollView(.horizontal) {
                cardRow(levels: levels, music: music, height: height).frame(width: required)
            }
            .scrollIndicators(.never)
            .frame(height: height)
        } else {
            cardRow(levels: levels, music: music, height: height)
        }
    }

    private func cardRow(levels: [NotchControlItem], music: Bool, height: CGFloat) -> some View {
        HStack(spacing: NotchLayout.rowSpacing) {
            if music {
                NotchMusicControlsView(notch: service, height: height)
                if levels.count > 1 {
                    levelRows(levels, height: height)
                        .padding(.horizontal, Design.Spacing.cardPadding)
                        .frame(width: 160, height: height)
                        .modifier(NotchControlSurface(cornerRadius: Design.Radius.card))
                } else if let single = levels.first {
                    level(single, style: .card, showsDevice: height >= 88).frame(width: 160, height: height)
                }
            } else {
                let details = NotchLayout.levelCardsShowDetails(levels, height: height)
                ForEach(levels) { item in
                    level(item, style: .card, showsDevice: details).frame(maxWidth: .infinity).frame(height: height)
                }
            }
        }
        .frame(height: height)
    }

    /// Three rows need the card's full height; a shortened card scrolls
    /// them rather than letting the last one spill out of it.
    @ViewBuilder private func levelRows(_ levels: [NotchControlItem], height: CGFloat) -> some View {
        let rows = VStack(spacing: Design.Spacing.xSmall) {
            ForEach(levels) { level($0, style: .row, showsDevice: false) }
        }
        if CGFloat(levels.count) * NotchLevelMetrics.row + CGFloat(levels.count - 1) * Design.Spacing.xSmall > height {
            ScrollView { rows }.scrollIndicators(.never)
        } else {
            rows
        }
    }

    @ViewBuilder private func level(_ item: NotchControlItem, style: NotchLevelStyle, showsDevice: Bool) -> some View {
        if item == .volume {
            NotchAudioControls(notch: service, style: style, showsDevice: showsDevice)
        } else if item == .keyboardLight {
            NotchKeyboardLightControls(style: style, showsTitle: showsDevice)
        } else if brightnessEnabled {
            NotchBrightnessControls(style: style, showsDevice: showsDevice)
        } else {
            brightnessSetup(style)
        }
    }

    private func brightnessSetup(_ style: NotchLevelStyle) -> some View {
        let settings = Button(l10n.s.menuSettings) {
            service.perform {
                SettingsRouter.shared.request(AppFeature.brightness.settingsDestination)
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
            }
        }.buttonStyle(NotchPressStyle()).foregroundStyle(Design.Ink.secondary).font(Design.Typography.label.font)
        return Group {
            if style == .row {
                HStack(spacing: Design.Spacing.xxSmall) {
                    Image(systemName: "sun.max.fill").font(Design.Icon.button.font)
                        .frame(width: NotchLevelMetrics.row)
                        .accessibilityHidden(true)
                    Text(FeatureStrings.notch(l10n.language).brightness).font(Design.Typography.title.font).lineLimit(1)
                    Spacer(minLength: Design.Spacing.xxSmall)
                    settings
                }
                .frame(height: NotchLevelMetrics.row)
            } else {
                VStack(alignment: .leading, spacing: Design.Spacing.medium) {
                    Label(FeatureStrings.notch(l10n.language).brightness, systemImage: "sun.max.fill")
                        .font(Design.Typography.title.font)
                    settings
                }
                .padding(Design.Spacing.cardPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .modifier(NotchControlSurface(cornerRadius: Design.Radius.card))
            }
        }
    }

    @ViewBuilder private func shortcut(_ item: NotchControlItem) -> some View {
        switch item {
        case .keepAwake: NotchAwakeButton()
        case .microphone: NotchMicButton()
        case .recording: NotchRecorderButton(service: service)
        case .panel:
            NotchActionTile(symbol: item.symbol, title: item.title(l10n)) { service.openAppPanel() }
        case .mixer:
            NotchActionTile(symbol: item.symbol, title: item.title(l10n)) { service.select(.mixer) }
        case .scratchpad:
            NotchActionTile(symbol: item.symbol, title: item.title(l10n), action: service.openScratchpad)
        case .timer: NotchTimerTile(service: service)
        case .calendar: NotchCalendarTile(service: service)
        case .volume, .brightness, .keyboardLight, .music: EmptyView()
        }
    }
}

extension NotchControlItem {
    func title(_ l10n: L10n) -> String {
        switch self {
        case .volume: return FeatureStrings.notch(l10n.language).volume
        case .brightness: return FeatureStrings.notch(l10n.language).brightness
        case .keyboardLight: return FeatureStrings.brightness(l10n.language).keyboardLight
        case .keepAwake: return l10n.s.keepAwakeTitle
        case .microphone: return l10n.s.micMuteName
        case .recording: return FeatureStrings.recorder(l10n.language).pageTitle
        case .panel: return FeatureStrings.notch(l10n.language).panel
        case .mixer: return l10n.s.mixerSection
        case .scratchpad: return FeatureStrings.scratchpad(l10n.language).pageTitle
        case .music: return NotchModule.music.title(l10n.language)
        case .timer: return NotchModule.timer.title(l10n.language)
        case .calendar: return NotchModule.calendar.title(l10n.language)
        }
    }
}

struct NotchAudioControls: View {
    @ObservedObject var notch: NotchService = .shared
    var style: NotchLevelStyle = .card
    var showsDevice = true
    /// The inline volume's fill, taken from the cover; nil keeps it flat.
    var fillStops: [Color]?
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var level: Double? { mixer.systemOutputVolume.map { mixer.systemOutputMuted == true ? 0 : $0 } }
    private var deviceName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID })?.name ?? l10n.s.mixerSystemOutputTitle
    }

    var body: some View {
        switch style {
        case .inline:
            HStack(spacing: Design.Spacing.small) {
                mute
                slider
                inlineOutputMenu
            }
            .frame(height: NotchLayout.musicControlsRowHeight)
            .help(mixer.outputSwitchError ?? deviceName)
        case .row:
            HStack(spacing: Design.Spacing.xxSmall) {
                mute
                slider
                readoutMenu
            }
            .frame(height: NotchLevelMetrics.row)
            .help(mixer.outputSwitchError ?? deviceName)
        case .card:
            VStack(spacing: Design.Spacing.xSmall) {
                HStack(spacing: Design.Spacing.xxSmall) {
                    mute
                    if showsDevice {
                        Text(FeatureStrings.notch(l10n.language).volume).lineLimit(1)
                        Spacer(minLength: 0)
                        percent
                    } else {
                        Spacer(minLength: 0)
                        readoutMenu
                    }
                }
                .font(Design.Typography.title.font)
                .frame(height: NotchLevelMetrics.titleRow)
                slider
                if showsDevice {
                    Group {
                        if let error = mixer.outputSwitchError {
                            Text(error).font(Design.Typography.caption.font).foregroundStyle(Design.Palette.warning).lineLimit(1).help(error)
                        } else {
                            NotchDeviceMenu(title: l10n.s.mixerSystemOutputTitle, current: deviceName,
                                            width: 154, lines: 1, alignment: .leading, items: outputItems)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Design.Spacing.cardPadding)
            // A short card folds its padding so the title row, the slider and
            // their gap fit NotchLayout.minimumCardHeight without spilling past the surface.
            .padding(.vertical, showsDevice ? NotchLevelMetrics.detailPadding : NotchLevelMetrics.foldedPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(NotchControlSurface(cornerRadius: Design.Radius.card))
        }
    }

    @ViewBuilder private var percent: some View {
        if let level {
            Text("\(Int((level * 100).rounded()))%")
                .font(Design.Typography.readout.font)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Design.Motion.animation(Design.Motion.snappy, reduceMotion: reduceMotion), value: level)
        }
    }

    /// The level this control sets is already on screen, so the open
    /// header keeps its title instead of repeating it.
    private func adjustOutput(volume: Double? = nil, muted: Bool? = nil) {
        notch.noteOwnVolumeAdjustment()
        mixer.requestOutputAdjustment(volume: volume, muted: muted)
    }

    /// The mute toggle: on means muted, so the plate fills with the accent and the glyph morphs.
    private var mute: some View {
        Toggle(isOn: Binding(get: { mixer.systemOutputMuted == true },
                             set: { adjustOutput(muted: $0) })) {
            Text(l10n.s.actionMute)
        }
        .toggleStyle(NotchToggleStyle(on: "speaker.slash.fill", off: "speaker.wave.2.fill"))
        .labelsHidden()
        .disabled(mixer.systemOutputMuted == nil)
        .help(mixer.systemOutputMuted == true ? l10n.s.actionUnmute : l10n.s.actionMute)
    }

    @ViewBuilder private var slider: some View {
        if let level {
            // Under the song's position bar the volume draws as slim as that
            // bar, keeping the full height to grab it by.
            NotchLevelSlider(value: Binding(get: { level }, set: { adjustOutput(volume: $0) }),
                             label: FeatureStrings.notch(l10n.language).volume,
                             tint: Design.Ink.primary, fillStops: fillStops)
                .frame(height: NotchLevelMetrics.row)
        } else {
            Text(l10n.s.mixerOutputUnavailable).font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: NotchLevelMetrics.row, alignment: .leading)
        }
    }

    private var outputItems: [NotchMenuItem] {
        var items = mixer.outputDevices.filter(\.canBeDefaultOutput).map { device in
            NotchMenuItem(title: device.name, checked: device.uid == mixer.currentOutputDeviceUID) {
                _ = mixer.setUniversalOutputDeviceUID(device.uid)
            }
        }
        if notch.modules.contains(.mixer) {
            items.append(.separator)
            items.append(NotchMenuItem(title: l10n.s.mixerSection, symbol: NotchModule.mixer.symbol) { notch.select(.mixer) })
        }
        return items
    }

    private var readoutMenu: some View {
        NotchLevelReadoutMenu(title: l10n.s.mixerSystemOutputTitle, symbol: "airplay.audio", items: outputItems) { percent }
            .help(mixer.outputSwitchError ?? deviceName)
            .accessibilityValue(deviceName)
    }

    /// Under the player the readout is the slider itself; a glyph opens the chooser.
    private var inlineOutputMenu: some View {
        NotchMenuButton(title: l10n.s.mixerSystemOutputTitle, items: outputItems) {
            Image(systemName: "airplay.audio")
                .font(Design.Icon.button.font)
                .foregroundStyle(Design.Ink.secondary)
                .padding(.horizontal, Design.Spacing.xxSmall)
                .frame(height: NotchLevelMetrics.row)
                .contentShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
        }
        .help(deviceName)
        .accessibilityValue(deviceName)
    }
}

/// Where a row or a short card folds its chooser: the whole percent at the
/// width of "100%" as a plain readout, then a glyph menu that names the kind
/// of list it opens (output devices, displays). The device lives in the help
/// and the accessibility value. Volume and brightness end on this same
/// column, so their sliders line up.
private struct NotchLevelReadoutMenu<Readout: View>: View {
    let title: String
    let symbol: String
    let items: [NotchMenuItem]
    @ViewBuilder let readout: () -> Readout

    var body: some View {
        HStack(spacing: Design.Spacing.xxSmall) {
            readout().frame(width: NotchLevelMetrics.readoutWidth, alignment: .trailing)
            NotchMenuButton(title: title, items: items) {
                Image(systemName: symbol)
                    .font(Design.Icon.button.font)
                    .foregroundStyle(Design.Ink.secondary)
                    .padding(.horizontal, Design.Spacing.xxSmall)
                    .frame(height: NotchLevelMetrics.row)
                    .contentShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
            }
        }
        .frame(height: NotchLevelMetrics.row)
    }
}

private struct NotchBrightnessControls: View {
    var style: NotchLevelStyle = .card
    var showsDevice = true
    @ObservedObject private var service = BrightnessService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID: CGDirectDisplayID?
    private var displays: [BrightnessDisplay] { service.displays.filter { $0.isActive && $0.method != nil } }
    private var display: BrightnessDisplay? {
        displays.first(where: { $0.id == selectedID }) ?? displays.first(where: \.isBuiltIn) ?? displays.first
    }

    var body: some View {
        Group {
            if style == .row {
                HStack(spacing: Design.Spacing.xxSmall) {
                    glyph
                    slider
                    readoutMenu
                }
                .frame(height: NotchLevelMetrics.row)
                .help(display?.name ?? FeatureStrings.brightness(l10n.language).noDisplays)
            } else {
                VStack(spacing: Design.Spacing.xSmall) {
                    HStack(spacing: Design.Spacing.xxSmall) {
                        glyph
                        if showsDevice {
                            Text(FeatureStrings.notch(l10n.language).brightness).lineLimit(1)
                            Spacer(minLength: 0)
                            percent
                        } else {
                            Spacer(minLength: 0)
                            readoutMenu
                        }
                    }
                    .font(Design.Typography.title.font)
                    .frame(height: NotchLevelMetrics.titleRow)
                    slider
                    if showsDevice, let display {
                        NotchDeviceMenu(title: FeatureStrings.notch(l10n.language).brightness, current: display.name,
                                        width: 154, lines: 1, alignment: .leading, items: displayItems(current: display))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Design.Spacing.cardPadding)
                // Folds like the audio card above, for the same minimum card height.
                .padding(.vertical, showsDevice ? NotchLevelMetrics.detailPadding : NotchLevelMetrics.foldedPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(NotchControlSurface(cornerRadius: Design.Radius.card))
            }
        }
        .onAppear { service.refresh() }
    }

    /// Volume leads with its mute button; the sun keeps that button's width
    /// so both sliders start on the same line.
    private var glyph: some View {
        Image(systemName: "sun.max.fill").font(Design.Icon.button.font)
            .foregroundStyle(Design.Ink.primary)
            .frame(width: NotchLevelMetrics.row, height: NotchLevelMetrics.row)
            .accessibilityHidden(true)
    }

    private func displayItems(current: BrightnessDisplay) -> [NotchMenuItem] {
        displays.map { item in
            NotchMenuItem(title: item.name, checked: item.id == current.id) { selectedID = item.id }
        }
    }

    @ViewBuilder private var readoutMenu: some View {
        if let display {
            NotchLevelReadoutMenu(title: FeatureStrings.notch(l10n.language).brightness, symbol: "display",
                                  items: displayItems(current: display)) { percent }
                .help(display.name)
                .accessibilityValue(display.name)
        }
    }

    @ViewBuilder private var percent: some View {
        if let display {
            Text("\(BrightnessSupport.wholePercent(display.brightness))%")
                .font(Design.Typography.readout.font)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Design.Motion.animation(Design.Motion.snappy, reduceMotion: reduceMotion), value: display.brightness)
        }
    }

    @ViewBuilder private var slider: some View {
        if let display {
            NotchLevelSlider(value: Binding(get: { display.brightness }, set: {
                service.setBrightness($0, for: display.id, showOSD: true)
            }), label: FeatureStrings.notch(l10n.language).brightness)
                .frame(height: NotchLevelMetrics.row)
        } else {
            Text(FeatureStrings.brightness(l10n.language).noDisplays)
                .font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: NotchLevelMetrics.row, alignment: .leading)
        }
    }
}

/// The keyboard light as a level beside volume and brightness. It has no
/// device to choose, so it ends on the bare percent, in the room the others
/// give their readout menu.
private struct NotchKeyboardLightControls: View {
    var style: NotchLevelStyle = .card
    var showsTitle = true
    @ObservedObject private var service = BrightnessService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var title: String { FeatureStrings.brightness(l10n.language).keyboardLight }

    var body: some View {
        Group {
            if style == .row {
                HStack(spacing: Design.Spacing.xxSmall) {
                    glyph
                    slider
                    readout
                }
                .frame(height: NotchLevelMetrics.row)
                .help(title)
            } else {
                VStack(spacing: Design.Spacing.xSmall) {
                    HStack(spacing: Design.Spacing.xxSmall) {
                        glyph
                        if showsTitle {
                            Text(title).lineLimit(1)
                            Spacer(minLength: 0)
                            percent
                        } else {
                            Spacer(minLength: 0)
                            readout
                        }
                    }
                    .font(Design.Typography.title.font)
                    .frame(height: NotchLevelMetrics.titleRow)
                    slider
                }
                .padding(.horizontal, Design.Spacing.cardPadding)
                .padding(.vertical, showsTitle ? NotchLevelMetrics.detailPadding : NotchLevelMetrics.foldedPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(NotchControlSurface(cornerRadius: Design.Radius.card))
            }
        }
        .onAppear { service.refreshKeyboardLight() }
    }

    /// The switch the panel has, where volume keeps its mute button: off,
    /// or back on at the level the light last had.
    private var glyph: some View {
        Toggle(isOn: Binding(get: { service.keyboardLightEnabled != false },
                             set: { service.setKeyboardLightEnabled($0) })) {
            Text(title)
        }
        .toggleStyle(NotchToggleStyle(on: "light.max", off: "light.min", tint: Design.Fill.selected))
        .labelsHidden()
        .disabled(service.keyboardLightEnabled == nil)
        .help(title)
    }

    /// The readout menu's layout with its chevron hidden, so this slider
    /// starts and ends where the volume and brightness ones do.
    private var readout: some View {
        HStack(spacing: Design.Spacing.xxSmall) {
            percent.frame(width: NotchLevelMetrics.readoutWidth, alignment: .trailing)
            Image(systemName: "chevron.down").font(Design.Icon.strip.font).hidden()
        }
        .padding(.horizontal, Design.Spacing.xxSmall)
        .frame(height: NotchLevelMetrics.row)
    }

    @ViewBuilder private var percent: some View {
        if let level = service.keyboardLightLevel {
            Text("\(BrightnessSupport.wholePercent(Double(level)))%")
                .font(Design.Typography.readout.font)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Design.Motion.animation(Design.Motion.snappy, reduceMotion: reduceMotion), value: level)
        }
    }

    @ViewBuilder private var slider: some View {
        if let level = service.keyboardLightLevel {
            NotchLevelSlider(value: Binding(get: { Double(level) }, set: {
                service.setKeyboardLightLevel(Float($0))
            }), label: title, onEditingChanged: service.keyboardLightDragChanged)
                .frame(height: NotchLevelMetrics.row)
        } else {
            Text(FeatureStrings.notchEditor(l10n.language).keyboardLightUnavailable)
                .font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: NotchLevelMetrics.row, alignment: .leading)
        }
    }
}

/// How an active tile reads. Recording and a muted microphone are states the
/// person has to notice, so they take the critical signal; every other active
/// tile, the timer and keep awake included, fills with the one accent, as
/// Control Center's tiles do. `awake` and `timer` stay so callers compile and
/// resolve to the same accent as `selection`.
enum NotchTileAccent {
    case selection, alert, awake, timer

    var fill: Color {
        switch self {
        case .selection, .awake, .timer: return Design.Palette.accent
        case .alert: return Design.Palette.critical
        }
    }

    /// Ink on the filled circle: white always, like Control Center's on tiles. White on the
    /// system accent is 3:1 or better for a glyph (accessibility.md, bold and glyph threshold).
    var glyph: Color { Design.Ink.primary }
}

/// The group inside a tile: circle, gap, two reserved label lines, with equal
/// air above and below, so every label in a row starts on one line.
private enum NotchActionTileMetrics {
    /** Two lines of the 11 pt label; one-line labels sit at the top of it. */ static let labelBlock: CGFloat = 28
}

/// A glyph in its own circle over a two-line label, the shape every shortcut
/// rail in the island shares. A live reading, such as a running timer's
/// clock, takes the first line and leaves the title one line below it.
/// The whole tile presses (`NotchPressStyle`); a tile that holds a state
/// fills its circle on `Motion.snappy`; the press is `NotchPressStyle`'s alone.
struct NotchActionTile: View {
    let symbol: String
    let title: String
    var reading: String?
    /// A timer's reading rolls down toward zero; a stopwatch's rolls up.
    var readingCountsDown = false
    /// A shorter title for the line under a reading when `title` does not
    /// fit whole; help and VoiceOver keep `title`.
    var compactTitle: String?
    /// Spoken after the reading, such as the event a calendar tile counts down to.
    var detail: String?
    var active = false
    var accent: NotchTileAccent = .selection
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        Button(action: action) {
            VStack(spacing: Design.Spacing.xSmall) {
                Image(systemName: symbol).font(Design.Icon.tile.font)
                    .foregroundStyle(active ? accent.glyph : Design.Ink.primary.opacity(0.85))
                    .notchSymbolReplace(reduceMotion: reduceMotion)
                    .animation(reduceMotion ? Design.Motion.fade : Design.Motion.snappy.animation, value: symbol)
                    .frame(width: Design.Control.tileGlyph, height: Design.Control.tileGlyph)
                    .background(active ? accent.fill : Design.Fill.control, in: Circle())
                    .overlay {
                        if contrast == .increased {
                            Circle().strokeBorder(Design.Stroke.increasedContrast, lineWidth: Design.Stroke.increasedContrastWidth)
                        }
                    }
                    .animation(reduceMotion ? Design.Motion.fade : Design.Motion.snappy.animation, value: active)
                label
                    .frame(maxWidth: .infinity)
                    .frame(height: NotchActionTileMetrics.labelBlock, alignment: .top)
            }
            .padding(.horizontal, Design.Spacing.xxSmall)
            .padding(.vertical, Design.Spacing.xxSmall)
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.shortcutHeight)
            .contentShape(RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(Design.Radius.card)))
        .accessibilityLabel(title)
        .accessibilityValue([reading, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(active ? .isSelected : [])
        .help(detail.map { "\(title): \($0)" } ?? title)
    }

    @ViewBuilder private var label: some View {
        if let reading {
            VStack(spacing: Design.Spacing.line) {
                ViewThatFits(in: .horizontal) {
                    readingTitle(title)
                    if let compactTitle { readingTitle(compactTitle) }
                }
                // A later day's start with a 12-hour clock, such as Spanish
                // "dom, 10:45 p. m.", needs up to 91 pt on a 68 pt line. The
                // smaller optical size spaces its letters wider, so scaling
                // alone would still cut it off.
                Text(reading).font(Design.Typography.readout.font).monospacedDigit()
                    .foregroundStyle(Design.Ink.secondary)
                    .allowsTightening(true)
                    .minimumScaleFactor(Design.SpecTime.scale(Design.Typography.readout, preferred: 0.7))
                    .modifier(NotchRollingDigits(value: reading, countsDown: readingCountsDown))
            }
            .lineLimit(1)
            .minimumScaleFactor(Design.SpecTime.scale(Design.Typography.label, preferred: 0.85))
        } else {
            Text(title).font(Design.Typography.label.font)
                .foregroundStyle(Design.Ink.primary)
                .lineLimit(2).multilineTextAlignment(.center)
                .minimumScaleFactor(Design.SpecTime.scale(Design.Typography.label, preferred: 0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readingTitle(_ text: String) -> some View {
        Text(text).font(Design.Typography.label.font)
            .foregroundStyle(Design.Ink.primary)
    }
}

/// A running timer, focus cycle or stopwatch keeps its clock on the tile:
/// opening the island covers the reading the closed island showed, and a
/// countdown hidden from the closed island can still be read here.
private struct NotchTimerTile: View {
    let service: NotchService
    @ObservedObject private var timer = NotchTimerService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if timer.session.isRunning {
            TimelineView(.periodic(from: Date(timeIntervalSinceNow: NotchTimerSupport.tickScheduleOffset(
                for: timer.session, at: timer.now)), by: 1)) { _ in tile }
        } else {
            tile
        }
    }

    private var tile: some View {
        let session = timer.session
        let active = session.hasSession
        return NotchActionTile(
            symbol: active ? symbol(session) : NotchControlItem.timer.symbol,
            title: active ? FeatureStrings.notchActivities(l10n.language).phase(session.phase)
                : NotchControlItem.timer.title(l10n),
            reading: active ? NotchTimerSupport.clockText(for: session, at: timer.now) : nil,
            readingCountsDown: !session.countsUp,
            // A long phase name, such as a Russian short break, would be cut
            // off on a narrow tile; the module's own title stands in.
            compactTitle: active ? NotchControlItem.timer.title(l10n) : nil,
            active: active, accent: .timer) { service.select(.timer) }
    }

    /// The compact strip's marks, without the circle the tile already draws.
    private func symbol(_ session: NotchTimerSession) -> String {
        if session.completed { return "checkmark" }
        if session.isPaused { return "pause.fill" }
        return session.countsUp ? "stopwatch" : "timer"
    }
}

/// The next appointment's start and title, so the week's agenda is a click
/// away rather than the only way to see what comes next.
private struct NotchCalendarTile: View {
    let service: NotchService
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        TimelineView(.everyMinute) { context in tile(now: context.date) }
    }

    private func tile(now: Date) -> some View {
        let event = NotchCalendarSupport.tileEvent(calendar.events, now: now)
        let title = event?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return NotchActionTile(
            symbol: NotchControlItem.calendar.symbol,
            title: NotchControlItem.calendar.title(l10n),
            reading: event.map {
                NotchCalendarSupport.tileStartText($0.start, now: now, locale: l10n.language.formattingLocale())
            },
            detail: title.map { $0.isEmpty ? FeatureStrings.notchCalendar(l10n.language).untitled : $0 }) { service.select(.calendar) }
    }
}

private struct NotchAwakeButton: View {
    @ObservedObject private var service = KeepAwakeManager.shared
    @ObservedObject private var l10n = L10n.shared
    var body: some View {
        NotchActionTile(symbol: service.isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                        title: l10n.s.keepAwakeTitle, active: service.isActive,
                        accent: .awake, action: service.toggle)
    }
}

private struct NotchMicButton: View {
    @ObservedObject private var service = MicMuteService.shared
    @ObservedObject private var l10n = L10n.shared
    var body: some View {
        NotchActionTile(symbol: service.isMuted ? "mic.slash.fill" : "mic.fill",
                        title: service.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName,
                        active: service.isMuted, accent: .alert, action: service.toggle)
    }
}

private struct NotchRecorderButton: View {
    let service: NotchService
    @ObservedObject private var recorder = ScreenRecorderService.shared
    @ObservedObject private var l10n = L10n.shared
    var body: some View {
        NotchActionTile(symbol: recorder.isRecording ? "stop.circle.fill" : "record.circle",
                        title: FeatureStrings.recorder(l10n.language).pageTitle,
                        active: recorder.isRecording, accent: .alert) {
            service.perform { recorder.toggle() }
        }
    }
}
