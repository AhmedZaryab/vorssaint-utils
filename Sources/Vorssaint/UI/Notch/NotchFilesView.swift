// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchFilesView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var shareAnchor = ShelfSharePickerAnchor.Anchor()
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var archives = NotchFileToolsService.shared
    @State private var actionInputs: [URL] = []
    @State private var outputPanel: NSSavePanel?
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            if shelf.items.isEmpty {
                let targeted = shelf.dropTargeted
                let zone = RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
                NotchEmptyView(symbol: "tray.and.arrow.down", message: FeatureStrings.notch(l10n.language).dropHint)
                    .frame(maxHeight: .infinity)
                    .background(targeted ? NotchDesign.Fill.hover : .clear, in: zone)
                    .overlay {
                        zone.strokeBorder(targeted ? NotchDesign.Palette.accent : NotchDesign.Ink.tertiary,
                                          style: NotchDesign.Stroke.dropTarget)
                            .allowsHitTesting(false)
                    }
                    .animation(NotchDesign.Motion.fade, value: targeted)
            } else {
                ShelfTilesView(items: shelf.visibleItems,
                               contentRevision: shelf.contentRevision,
                               selection: shelf.selection,
                               expandedBatches: shelf.expandedBatches,
                               pinnedIDs: shelf.pinnedIDs,
                               revealID: shelf.revealTargetID,
                               revealSerial: shelf.addSerial,
                               sideways: true)
                    .frame(maxHeight: .infinity)
                HStack(spacing: NotchDesign.Spacing.xSmall) {
                    Text(shelf.selection.isEmpty ? l10n.s.shelfHint
                         : String(format: l10n.s.shelfSelectedFormat, shelf.selection.count))
                        .font(NotchDesign.Typography.caption.font)
                        .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(2)
                        .contentTransition(.numericText())
                        .animation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion),
                                   value: shelf.selection.count)
                    Spacer()
                    NotchPlainIconButton(symbol: "doc.zipper", title: text.archive) {
                        actionInputs = shelf.fileURLsForActions()
                        chooseArchiveDestination()
                    }
                    .disabled(!shelf.hasFilesForActions || archives.isRunning)
                    NotchPlainIconButton(symbol: "square.and.arrow.up", title: l10n.s.shelfActionShare) {
                        shareAnchor.present(shelf.fileURLsForActions())
                    }
                    .background(ShelfSharePickerAnchor(anchor: shareAnchor))
                    .disabled(!shelf.hasFilesForActions)
                    // The shelf's trash takes the selection first, the whole
                    // shelf only when nothing is selected. Both burn down on a
                    // fuse, so a slip is one press from undone.
                    // One control for both, so selecting during a burn keeps
                    // the burning fuse and its Undo on screen. The payload is
                    // read when the fuse is lit, never when it burns out.
                    let chosen = Array(shelf.selection)
                    let removesSelection = !chosen.isEmpty
                    NotchFuseButton(removesSelection ? l10n.s.shelfRemoveSelected : l10n.s.shelfClearAll,
                                    symbol: removesSelection ? "trash.fill" : "trash",
                                    doneAnnouncement: removesSelection ? l10n.s.shelfRemoveSelected : l10n.s.shelfClearAll,
                                    shape: .rounded(NotchDesign.Radius.control)) {
                        if removesSelection { shelf.removeItems(chosen) } else { shelf.clear() }
                    }
                    .disabled(archives.isRunning)
                }
            }
            archiveStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: outputPanel != nil) { _, active in service.keepFileInteractionOpen(active) }
        .onDisappear {
            outputPanel?.cancel(nil)
            outputPanel = nil
            // Only the island's own page holds the island open.
            if !preview { service.keepFileInteractionOpen(false) }
        }
        .onChange(of: features.revision) {
            if !AppFeature.shelf.isAvailable {
                archives.syncWithPreferences()
                outputPanel?.cancel(nil)
            }
        }
    }

    @ViewBuilder private var archiveStatus: some View {
        if archives.isRunning {
            HStack(spacing: NotchDesign.Spacing.small) {
                ProgressView().controlSize(.small)
                Text("\(text.archive) · \(archives.completed)/\(archives.total)")
                    .font(NotchDesign.Typography.caption.font).monospacedDigit()
                    .foregroundStyle(NotchDesign.Ink.secondary)
                Spacer()
                statusButton(l10n.s.uninstallerCancel, action: archives.cancel)
                    .disabled(archives.wasCancelled)
            }
        } else if let failure = archives.failure {
            Text(failure).font(NotchDesign.Typography.caption.font)
                .foregroundStyle(NotchDesign.Palette.warning).lineLimit(3)
        } else if !archives.outputURLs.isEmpty {
            HStack(spacing: NotchDesign.Spacing.small) {
                Label(text.saved, systemImage: "checkmark.circle.fill").foregroundStyle(NotchDesign.Palette.positive)
                Spacer()
                statusButton(l10n.s.mediaOpenInFinder) {
                    NSWorkspace.shared.activateFileViewerSelecting(archives.outputURLs)
                }
            }.font(NotchDesign.Typography.caption.font)
        } else if archives.wasCancelled {
            Text(l10n.s.mediaCancelled).font(NotchDesign.Typography.caption.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
        }
    }

    /// A text button in the status row: a capsule plate on the tap class.
    private func statusButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(NotchDesign.Typography.caption.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .padding(.horizontal, NotchDesign.Spacing.small)
                .frame(minHeight: NotchDesign.Control.minimumHit)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
    }

    private func chooseArchiveDestination() {
        guard outputPanel == nil, !actionInputs.isEmpty, AppFeature.shelf.isAvailable else { return }
        let inputs = actionInputs
        let multiple = inputs.count > 1
        let panel: NSSavePanel
        if multiple {
            let folder = NSOpenPanel()
            folder.canChooseFiles = false
            folder.canChooseDirectories = true
            folder.allowsMultipleSelection = false
            panel = folder
        } else {
            panel = NSSavePanel()
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = MediaSupport.uniqueOutputURL(
                in: inputs[0].deletingLastPathComponent(), baseName: inputs[0].lastPathComponent,
                fileExtension: "zip").lastPathComponent
        }
        panel.directoryURL = inputs[0].deletingLastPathComponent()
        panel.message = text.archiveHint
        outputPanel = panel
        let completed: (NSApplication.ModalResponse) -> Void = { response in
            outputPanel = nil
            guard response == .OK, let destination = panel.url,
                  AppFeature.shelf.isAvailable, NotchSupport.isEnabled() else { return }
            archives.archive(inputs, destination: destination, directory: multiple)
            service.open(.files)
        }
        guard let island = service.presentationWindow, island.isVisible else {
            NSApp.activate(ignoringOtherApps: true)
            panel.begin(completionHandler: completed)
            return
        }
        // The island floats above ordinary windows, and a sheet would move and
        // reskin it. The panel opens on its own just above it instead, and the
        // pending outputPanel keeps the island open meanwhile.
        panel.level = NSWindow.Level(rawValue: island.level.rawValue + 1)
        // Like the island's other dialogs, it stays up while another app is active.
        panel.hidesOnDeactivate = false
        panel.begin { response in
            completed(response)
            // Dismissal restores the previous key window after this callback.
            DispatchQueue.main.async { if service.expanded { island.makeKey() } }
        }
        NSApp.activate(ignoringOtherApps: true)
        // Activation alone can leave the nonactivating island holding focus.
        panel.makeKeyAndOrderFront(nil)
    }

}
