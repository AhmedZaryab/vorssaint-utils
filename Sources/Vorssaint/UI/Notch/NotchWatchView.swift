// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchWatchSettingsControls: View {
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchWatchSound) private var sound = true
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(text.title, isOn: $enabled)
                .disabled(!AppFeature.notchWatch.isAvailable)
            Text(text.description).font(.caption).foregroundStyle(.secondary)
            if enabled {
                Toggle(text.sound, isOn: $sound)
                PermissionRow(kind: .screenRecording)
            }
        }
        .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
    }
}

/// The page: what to watch and the rule, the live area and its reading.
struct NotchWatchView: View {
    let size: CGSize
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    @Environment(\.notchSettingsPreview) private var preview
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        Group {
            if !enabled || watch.target == nil || preview {
                NotchWatchSetupView()
            } else {
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                    header
                    NotchWatchAreaCard()
                        .frame(maxHeight: .infinity)
                    NotchWatchRuleRow()
                    footer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if !preview { watch.pageVisible = true } }
        .onDisappear { if !preview { watch.pageVisible = false } }
    }

    private var header: some View {
        HStack(spacing: NotchDesign.Spacing.small) {
            if let icon = watch.target?.appIcon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16).accessibilityHidden(true)
            } else {
                Image(systemName: NotchModule.watch.symbol).foregroundStyle(NotchDesign.Ink.secondary)
            }
            Text(headerTitle).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            NotchIconButton(symbol: "viewfinder", title: text.chooseAgain) {
                NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
            }
            // Stopping discards the result, so it burns before it commits.
            NotchFuseButton(text.stop, symbol: "xmark", shape: .rounded(NotchDesign.Radius.control)) { watch.stop() }
        }
        .font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary)
        .frame(height: NotchDesign.Control.rowHeight)
    }

    private var headerTitle: String {
        guard let target = watch.target else { return text.title }
        guard let title = target.windowTitle, title != target.appName else { return target.appName }
        return "\(target.appName) · \(title)"
    }

    @ViewBuilder private var footer: some View {
        if case .finished = watch.state {
            HStack(spacing: NotchDesign.Spacing.medium) {
                if watch.canWatchAgain {
                    NotchWatchCommitRow(title: text.watchAgain, symbol: "arrow.clockwise") { watch.watchAgain() }
                }
                NotchWatchCommitRow(title: text.chooseAgain, symbol: "viewfinder") {
                    NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
                }
                Spacer(minLength: 0)
            }
        } else if let started = watch.startedAt {
            Text(text.since(started.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(l10n.language.formattingLocale()))))
                .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
        }
    }
}

/// A start action in the commit class: the round glyph and its word beside it.
private struct NotchWatchCommitRow: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.xxSmall) {
            NotchCommitButton(title, symbol: symbol, kick: .up, filled: true, action: action)
            // The word is part of the control: clicking it does what the glyph does.
            // VoiceOver already has the glyph's button under the same name, so the word is hidden from it.
            Button(action: action) {
                Text(title).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, NotchDesign.Spacing.xxSmall)
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
            .accessibilityHidden(true)
        }
    }
}

/// The live area with its reading below it, and what happened once the
/// watch ended.
private struct NotchWatchAreaCard: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    private var lines: [String] { NotchWatchSupport.lines(in: watch.text) }

    /// What the island shows, picked automatically or chosen line by line
    /// when the automatic pick lands on the wrong words.
    private var headlineMenu: some View {
        var items = [NotchMenuItem(title: text.automatic, checked: watch.headlineLine == nil) { watch.setHeadlineLine(nil) }]
        items += lines.prefix(12).enumerated().map { index, line in
            NotchMenuItem(title: line, checked: watch.headlineLine == index) { watch.setHeadlineLine(index) }
        }
        return NotchMenuButton(title: text.inIsland, items: items, cornerRadius: NotchDesign.Radius.control) {
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                Text(watch.headline.isEmpty ? text.noText : watch.headline)
                    .font(NotchDesign.Typography.title.font)
                    .monospacedDigit().lineLimit(1)
                Image(systemName: "chevron.down").font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
            }
            .padding(.horizontal, NotchDesign.Spacing.xxSmall)
            .frame(height: NotchDesign.Control.rowHeight)
        }
        .fixedSize()
        .help(text.inIsland)
        .accessibilityValue(watch.headline)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
            ZStack {
                if let image = watch.preview {
                    Image(decorative: image, scale: 2)
                        .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
                        .opacity(watch.state == .hidden ? 0.35 : 1)
                } else {
                    ProgressView().controlSize(.small)
                }
                if watch.state == .hidden {
                    Label(watch.permissionMissing ? text.permissionHint : text.hidden,
                          systemImage: watch.permissionMissing ? "lock" : "eye.slash")
                        .font(NotchDesign.Typography.label.font).multilineTextAlignment(.center)
                        .padding(NotchDesign.Spacing.small)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: NotchDesign.Spacing.small) {
                if case .finished(let outcome) = watch.state {
                    Image(systemName: outcome == .closed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(outcome == .closed ? NotchDesign.Ink.secondary : NotchDesign.Palette.positive)
                    Text(text.outcome(outcome)).font(NotchDesign.Typography.title.font).lineLimit(1)
                } else if lines.isEmpty {
                    Text(text.noText).font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.secondary)
                } else {
                    // What the menu controls, in words, as the Tell me row below has.
                    Text(text.inIsland).font(NotchDesign.Typography.callout.font)
                        .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
                    headlineMenu
                }
                Spacer(minLength: 0)
            }
            let full = watch.text.replacingOccurrences(of: "\n", with: " ")
            if !full.isEmpty, full != watch.headline {
                Text(full).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(NotchDesign.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NotchDesign.Fill.card, in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
                    .strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// When to speak up. A word or a number applies once Return is pressed or
/// the field is left, so typing never ends the watch halfway. After a watch
/// ends the rule can still change, for the next Watch Again.
private struct NotchWatchRuleRow: View {
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var draftText = ""
    @State private var draftNumber = ""
    @FocusState private var focused: Bool
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.xxSmall) {
            HStack(spacing: NotchDesign.Spacing.small) {
                Text(text.tellMe).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary)
                NotchMenuButton(title: text.tellMe, items: NotchWatchCondition.allCases.map { condition in
                    NotchMenuItem(title: text.condition(condition), checked: condition == watch.condition,
                                  symbol: condition.symbol) { watch.setCondition(condition) }
                }, cornerRadius: NotchDesign.Radius.control) {
                    HStack(spacing: NotchDesign.Spacing.xxSmall) {
                        Image(systemName: watch.condition.symbol)
                        Text(text.condition(watch.condition))
                        Image(systemName: "chevron.down").foregroundStyle(NotchDesign.Ink.secondary)
                    }
                    .font(NotchDesign.Typography.callout.font)
                    .padding(.horizontal, NotchDesign.Spacing.small)
                    .frame(height: NotchDesign.Control.rowHeight)
                }
                .fixedSize()
                if watch.condition == .contains || watch.condition == .reaches {
                    field
                }
                Spacer(minLength: 0)
            }
            if watch.condition == .settles {
                Text(text.settlesHint).font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(2)
            }
        }
        .onAppear {
            draftText = watch.matchText
            draftNumber = watch.matchNumber.map {
                NotchWatchSupport.formatted($0, locale: l10n.language.formattingLocale())
            } ?? ""
        }
    }

    private var field: some View {
        let number = watch.condition == .reaches
        return TextField(number ? text.numberPlaceholder : text.textPlaceholder,
                         text: number ? $draftNumber : $draftText)
            .textFieldStyle(.plain)
            .font(NotchDesign.Typography.callout.font)
            .focused($focused)
            .onSubmit(apply)
            .onChange(of: focused) { _, isFocused in if !isFocused { apply() } }
            .padding(.horizontal, NotchDesign.Spacing.small)
            .frame(height: NotchDesign.Control.rowHeight)
            .frame(maxWidth: 180)
            // Focus is a deeper plate, not a stroke.
            .background(focused ? NotchDesign.Fill.selected : NotchDesign.Fill.control,
                        in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
            .accessibilityLabel(text.condition(watch.condition))
    }

    private func apply() {
        if watch.condition == .reaches { watch.setMatchNumber(draftNumber) } else { watch.setMatchText(draftText) }
    }
}

/// Before anything is watched: what the page does, and the one step that
/// starts it, in the same voice as the island's other empty pages.
private struct NotchWatchSetupView: View {
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    /// The page follows a grant made in System Settings while it is shown;
    /// nothing checks for one while it is away.
    @State private var pollingDemandID = UUID()
    private var text: NotchWatchStrings { FeatureStrings.notchWatch(l10n.language) }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: NotchDesign.Spacing.medium) {
                glyph
                copy.multilineTextAlignment(.center)
                actions
            }
            HStack(spacing: NotchDesign.Spacing.large) {
                glyph
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                    copy.multilineTextAlignment(.leading)
                    actions
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(NotchDesign.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { permissions.setActivePermissionSurface(pollingDemandID, visible: true) }
        .onDisappear { permissions.setActivePermissionSurface(pollingDemandID, visible: false) }
    }

    private var glyph: some View {
        Image(systemName: NotchModule.watch.symbol)
            .font(NotchDesign.Icon.hero.font)
            .foregroundStyle(NotchDesign.Ink.secondary)
            .frame(width: NotchDesign.Control.heroGlyph, height: NotchDesign.Control.heroGlyph)
            .background(NotchDesign.Fill.card, in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
            .accessibilityHidden(true)
    }

    private var copy: some View {
        Text(!enabled ? text.description : permissions.screenRecording ? text.setupHint : text.permissionHint)
            .font(NotchDesign.Typography.callout.font)
            .foregroundStyle(NotchDesign.Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var actions: some View {
        if !enabled {
            if AppFeature.notchWatch.isAvailable {
                HStack(spacing: NotchDesign.Spacing.small) {
                    Toggle(text.title, isOn: $enabled)
                        .toggleStyle(NotchToggleStyle(on: "eye", off: "eye.slash"))
                        .labelsHidden()
                        .accessibilityLabel(text.title)
                        .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
                    Button { enabled.toggle() } label: {
                        Text(text.title).font(NotchDesign.Typography.callout.font)
                            .foregroundStyle(NotchDesign.Ink.secondary)
                            .padding(.horizontal, NotchDesign.Spacing.xxSmall)
                    }
                    .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
                    .accessibilityHidden(true)
                }
            }
        } else if !permissions.screenRecording {
            NotchWatchCommitRow(title: text.allowAccess, symbol: "lock.open") {
                Permissions.shared.requestScreenRecording()
            }
        } else {
            NotchWatchCommitRow(title: text.choose, symbol: "viewfinder") {
                NotchService.shared.perform { NotchWatchService.shared.chooseArea() }
            }
        }
    }
}

/// The area itself, small, where a reading would be when it holds no text.
struct NotchWatchThumbnail: View {
    let image: CGImage
    let height: CGFloat

    var body: some View {
        // Whole, so a bar shows how far it has filled.
        Image(decorative: image, scale: 2)
            .resizable().interpolation(.medium).aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.small, style: .continuous))
            .frame(width: NotchWatchSupport.thumbnailWidth, height: height)
            .accessibilityHidden(true)
    }
}

/// The watching eye, breathing like a working agent's mark while the area
/// is read, and still, crossed out, while its window is hidden. The motion
/// is stepped at a limited rate and stops whenever the island is not on screen.
struct NotchWatchEye: View {
    let size: CGFloat
    var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NotchWatchEyeBridge(size: size, hidden: hidden, animates: !hidden && !reduceMotion)
            .frame(width: size + 2, height: size + 2)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

private struct NotchWatchEyeBridge: NSViewRepresentable {
    let size: CGFloat
    let hidden: Bool
    let animates: Bool

    func makeNSView(context: Context) -> NotchAgentAnimationView { NotchAgentAnimationView() }
    func updateNSView(_ view: NotchAgentAnimationView, context: Context) {
        let image = NSImage(systemSymbolName: hidden ? "eye.slash" : "eye", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .medium))
        view.configureGlyph(image: image, size: size, tint: NotchWatchStrip.eyeTint, animates: animates)
    }
    static func dismantleNSView(_ view: NotchAgentAnimationView, coordinator: ()) { view.stop() }
}

/// The eye at the left end and what the area reads at the right, each
/// anchored to its own edge so the silhouette's curve decides the margin.
struct NotchWatchStrip: View {
    static let tint = NotchDesign.Ink.primary
    /// Softer than the reading, so the mark does not outshine it. White: the strip carries no colour of its own.
    static let eyeTint = NSColor.white.withAlphaComponent(0.75)

    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var watch = NotchWatchService.shared
    @ObservedObject private var l10n = L10n.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    /// The size of a working agent's mark, which breathes the same way.
    private var iconSize: CGFloat {
        NotchTimerSupport.stripAgentMarkSize(height: geometry.compactActivityContentHeight, working: 1)
    }
    private var textSize: CGFloat { NotchTimerSupport.stripTextSize(height: geometry.compactActivityContentHeight) }
    private var iconInset: CGFloat { geometry.compactActivityEdgeInset(boxHeight: iconSize, radius: iconSize / 2) }
    private var textInset: CGFloat { geometry.compactActivityEdgeInset(boxHeight: textSize * 0.72, radius: 0) }

    var body: some View {
        Button { service.openActivity(.watch) } label: {
            HStack(spacing: 0) {
                NotchWatchEye(size: iconSize, hidden: watch.state == .hidden)
                    .padding(.leading, iconInset)
                    .frame(width: geometry.compactActivityWingWidth, alignment: .leading)
                    .opacity(geometry.compactActivityWingWidth >= 28 ? 1 : 0)
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                reading
                    .padding(.trailing, textInset)
                    .frame(width: geometry.compactActivityWingWidth, alignment: .trailing)
                    .clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FeatureStrings.notchWatch(l10n.language).title)
        .accessibilityValue(watch.headline)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }

    @ViewBuilder private var reading: some View {
        if geometry.compactActivityWingWidth < 36 {
            EmptyView()
        } else if watch.showsThumbnail, let preview = watch.preview {
            NotchWatchThumbnail(image: preview, height: max(8, geometry.compactActivityContentHeight - 6))
        } else if watch.headline.isEmpty {
            // A hidden window's slashed eye says enough until it is read.
            if watch.state != .hidden { ProgressView().controlSize(.mini) }
        } else {
            // A reading can change on every pass; rolling each change would
            // keep the closed island animating.
            Text(watch.headline)
                .font(NotchDesign.Typography.stripPrimary.font).monospacedDigit()
                .foregroundStyle(Self.tint)
                .lineLimit(1)
                .minimumScaleFactor(NotchDesign.SpecTime.scale(NotchDesign.Typography.stripPrimary, preferred: 0.7))
                .truncationMode(.tail)
        }
    }
}
