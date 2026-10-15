// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchDownloadsSettingsControls: View {
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(text.downloadsTitle, isOn: $enabled)
                .disabled(!AppFeature.notchDownloads.isAvailable)
            Text(text.downloadsHint).font(.caption).foregroundStyle(.secondary)
            if downloads.folderUnavailable {
                Text(text.folderUnavailable).font(.caption).foregroundStyle(.orange)
            } else if let name = downloads.folderName {
                Label(name, systemImage: "folder").font(.caption).lineLimit(1).truncationMode(.middle)
            }
            HStack {
                Button(text.chooseFolder, action: downloads.chooseFolder)
                if downloads.folderName != nil || downloads.folderUnavailable {
                    Button(text.clearFolder, action: downloads.forgetFolder)
                }
            }.controlSize(.small)
        }
        .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
    }
}

/// Before a folder is chosen the page says what it will do and offers the one
/// step that starts it, in the same voice as the island's other empty pages.
private struct NotchDownloadsSetupView: View {
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: NotchDesign.Spacing.medium) {
                glyph
                copy.multilineTextAlignment(.center)
                actions
            }
            HStack(spacing: NotchDesign.Spacing.large) {
                glyph
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.medium) {
                    copy.multilineTextAlignment(.leading)
                    actions
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(NotchDesign.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var glyph: some View {
        Image(systemName: downloads.folderUnavailable ? "exclamationmark.triangle" : "arrow.down.circle")
            .font(NotchDesign.Icon.hero.font)
            .foregroundStyle(NotchDesign.Ink.secondary)
            .frame(width: NotchDesign.Control.heroGlyph, height: NotchDesign.Control.heroGlyph)
            .background(NotchDesign.Fill.card, in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
            .accessibilityHidden(true)
    }

    private var copy: some View {
        // Off, the page says what Downloads does beside its switch; on, which
        // folder to choose.
        Text(downloads.folderUnavailable ? text.folderUnavailable
             : offersSwitchOnly ? text.downloadsTitle : enabled ? text.downloadsHint : text.downloadsDescription)
            .font(NotchDesign.Typography.callout.font)
            .foregroundStyle(downloads.folderUnavailable ? NotchDesign.Palette.warning : NotchDesign.Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Off on a Mac without the feature: there is no folder to choose and
    /// nothing to switch, so the page only names itself.
    private var offersSwitchOnly: Bool { !enabled && !AppFeature.notchDownloads.isAvailable }

    @ViewBuilder private var actions: some View {
        if offersSwitchOnly {
            EmptyView()
        } else if !enabled {
            Toggle(text.downloadsTitle, isOn: $enabled)
                .toggleStyle(.switch)
                .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
        } else {
            chooseActions
        }
    }

    private var chooseActions: some View {
        HStack(spacing: NotchDesign.Spacing.small) {
            Button(action: downloads.chooseFolder) {
                Text(text.chooseFolder)
                    .font(NotchDesign.Typography.callout.font.weight(NotchDesign.Weight.semibold.font))
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .padding(.horizontal, NotchDesign.Spacing.medium)
                    .frame(height: NotchDesign.Control.rowHeight)
                    .background(NotchDesign.Fill.control, in: Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
            if downloads.folderUnavailable {
                Button(action: downloads.forgetFolder) {
                    Text(text.clearFolder)
                        .font(NotchDesign.Typography.callout.font.weight(NotchDesign.Weight.medium.font))
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .padding(.horizontal, NotchDesign.Spacing.medium)
                        .frame(height: NotchDesign.Control.rowHeight)
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(NotchPressStyle(shape: .capsule))
            }
        }
    }
}

/// A 28 pt icon plate for the header and the finished rows: press class, a wash
/// under the pointer, and an optional success morph for results that land in place.
private struct NotchDownloadsIconButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(NotchDesign.Icon.button.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control)))
        .help(title)
        .accessibilityLabel(title)
    }
}

struct NotchDownloadsView: View {
    let size: CGSize
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    @Environment(\.notchSettingsPreview) private var preview
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchLayout.rowSpacing) {
            if !enabled || downloads.folderName == nil || downloads.folderUnavailable {
                NotchDownloadsSetupView()
            } else {
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    Label(downloads.folderName ?? text.downloadsTitle, systemImage: "folder")
                        .font(NotchDesign.Typography.callout.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: NotchDesign.Spacing.small)
                    NotchDownloadsIconButton(symbol: "folder.badge.gearshape", title: text.chooseFolder,
                                             action: downloads.chooseFolder)
                    NotchFuseButton(text.clearFolder, symbol: "xmark.circle", doneAnnouncement: text.clearFolder,
                                    shape: .rounded(NotchDesign.Radius.control), onCommit: downloads.forgetFolder)
                }
                .frame(height: NotchDesign.Control.rowHeight)
                if downloads.items.isEmpty {
                    NotchEmptyView(symbol: "arrow.down.circle", message: text.waiting)
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: NotchDesign.Spacing.gutter) {
                            ForEach(downloads.items) { item in
                                downloadCard(item)
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Another section or a collapse takes the page away; its chooser
        // could no longer return the folder here. Settings keeps its own.
        .onDisappear { if !preview { downloads.cancelNotchFolderChoice() } }
    }

    /// A row in Safari's downloads shape: the file's plate, name over status,
    /// the reading at the trailing edge, progress as a meter while it runs.
    private func downloadCard(_ item: NotchDownloadItem) -> some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.xSmall) {
            HStack(spacing: NotchDesign.Spacing.small) {
                let fileLabel = HStack(spacing: NotchDesign.Spacing.small) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(NotchDesign.Icon.button.font)
                        .foregroundStyle(item.completed ? NotchDesign.Palette.positive : NotchDesign.Ink.primary)
                        .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                        .background(NotchDesign.Fill.control,
                                    in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                        Text(item.name).font(NotchDesign.Typography.title.font)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .lineLimit(1).truncationMode(.middle)
                        Text(item.completed ? text.saved : item.active ? text.inProgress : "")
                            .font(NotchDesign.Typography.callout.font)
                            .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if item.completed {
                    Button {
                        if !NSWorkspace.shared.open(item.url) { NSSound.beep() }
                    } label: {
                        fileLabel.frame(minHeight: NotchDesign.Control.minimumHit).contentShape(Rectangle())
                    }
                    .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
                    .help(l10n.s.shelfActionOpen)
                    .accessibilityHint(l10n.s.shelfActionOpen)
                    NotchDownloadsIconButton(symbol: "folder", title: l10n.s.mediaOpenInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    if AppFeature.shelf.isAvailable {
                        ShelfAddButton(url: item.url, title: FeatureStrings.notch(l10n.language).files)
                    }
                } else {
                    fileLabel
                    if let fraction = item.fraction {
                        Text(fraction, format: .percent.precision(.fractionLength(0)))
                            .font(NotchDesign.Typography.readout.font).monospacedDigit()
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .contentTransition(.numericText())
                    }
                }
            }
            if !item.completed {
                if let fraction = item.fraction {
                    NotchMeter(value: fraction, height: NotchDesign.Control.meter, tint: NotchDesign.Palette.accent)
                        .animation(NotchDesign.Motion.smooth.animation, value: fraction)
                } else if item.active {
                    ProgressView().controlSize(.small)
                }
                HStack {
                    Spacer()
                    if let bytes = item.receivedBytes, bytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    } else if item.fraction == nil {
                        Text(text.totalUnknown)
                    }
                }.font(NotchDesign.Typography.caption.font).monospacedDigit()
                    .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
            }
        }
        .padding(NotchDesign.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(NotchDesign.Fill.card,
                    in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
        .clipped()
        .accessibilityElement(children: .contain)
    }
}

/// Adds a finished download to the shelf; the glyph morphs to a check where it
/// stands, since the result lands in place.
private struct ShelfAddButton: View {
    let url: URL
    let title: String
    @State private var added = 0

    var body: some View {
        Button {
            if ShelfService.shared.addFiles([url]) { added += 1 }
        } label: {
            Image(systemName: "tray.and.arrow.down")
                .notchSuccessMorph(trigger: added)
                .font(NotchDesign.Icon.button.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control)))
        .help(title)
        .accessibilityLabel(title)
    }
}

struct NotchDownloadStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    /// The arrow keeps the shared gap from the top and bottom edges too.
    private var iconSize: CGFloat {
        min(17, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2)
    }
    private var iconInset: CGFloat {
        geometry.compactActivityEdgeInset(boxHeight: iconSize, radius: iconSize / 2)
    }

    var body: some View {
        let item = downloads.items.first { $0.active && !$0.completed }
        Button { service.openActivity(.downloads) } label: {
            HStack(spacing: 0) {
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    if geometry.compactActivityWingWidth >= 40 {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: iconSize))
                        if NotchDownloadSupport.showsCompactName(in: geometry) {
                            Text(item?.name ?? FeatureStrings.notchFiles(l10n.language).downloadsTitle)
                                .font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                .padding(.leading, geometry.compactActivityWingWidth >= 40 ? iconInset : 0)
                .padding(.trailing, NotchDesign.Spacing.xxSmall)
                // Each wing anchors to its own edge, so the silhouette's curve
                // decides the margin instead of the content's own width.
                .frame(width: geometry.compactActivityWingWidth, alignment: .leading).clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    // The name widens both wings; the bar fills the side the
                    // percentage alone would leave as a band of black.
                    if NotchDownloadSupport.showsCompactName(in: geometry), let fraction = item?.fraction {
                        NotchMeter(value: fraction, height: NotchDesign.Control.meter, tint: NotchDesign.Palette.accent)
                            .padding(.leading, NotchDesign.Spacing.xxSmall)
                    } else {
                        Spacer(minLength: 0)
                    }
                    if geometry.compactActivityWingWidth >= 36 {
                        if let fraction = item?.fraction {
                            Text(fraction, format: NotchDownloadSupport.percentFormat(l10n.language))
                                .font(.system(size: NotchDownloadSupport.percentSize, weight: .medium))
                                .monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(NotchDownloadSupport.percentMinimumScale)
                                .layoutPriority(1)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                    }
                }
                .padding(.trailing, geometry.compactActivityWingWidth >= 36
                                    ? NotchDownloadSupport.percentInset(in: geometry) : 0)
                .frame(width: geometry.compactActivityWingWidth, alignment: .trailing).clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item?.name ?? FeatureStrings.notchFiles(l10n.language).downloadsTitle)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
