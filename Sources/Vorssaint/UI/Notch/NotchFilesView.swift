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
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            if shelf.items.isEmpty {
                NotchEmptyView(symbol: "tray.and.arrow.down", message: FeatureStrings.notch(l10n.language).dropHint)
                    .frame(maxHeight: .infinity)
                    .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 0.75, dash: [4, 5])) }
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
                HStack {
                    Text(shelf.selection.isEmpty ? l10n.s.shelfHint
                         : String(format: l10n.s.shelfSelectedFormat, shelf.selection.count))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    NotchIconButton(symbol: "doc.zipper", title: text.archive) {
                        actionInputs = shelf.fileURLsForActions()
                        chooseArchiveDestination()
                    }
                    .disabled(!shelf.hasFilesForActions || archives.isRunning)
                    NotchIconButton(symbol: "square.and.arrow.up", title: l10n.s.shelfActionShare) {
                        shareAnchor.present(shelf.fileURLsForActions())
                    }
                    .background(ShelfSharePickerAnchor(anchor: shareAnchor))
                    .disabled(!shelf.hasFilesForActions)
                    // The shelf's trash takes the selection first, the whole
                    // shelf only when nothing is selected.
                    if shelf.selection.isEmpty {
                        clearMenu
                    } else {
                        NotchIconButton(symbol: "trash.fill", title: l10n.s.shelfRemoveSelected) {
                            shelf.removeItems(Array(shelf.selection))
                        }
                        .disabled(archives.isRunning)
                    }
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

    // A sheet dims the window's transparent margins. A native menu keeps the
    // explicit confirmation beside its trigger and uses the existing menu tracking.
    private var clearMenu: some View {
        Menu {
            Button(l10n.s.shelfClearAll, role: .destructive) { shelf.clear() }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(archives.isRunning)
        .help(l10n.s.shelfClearAll)
        .accessibilityLabel(l10n.s.shelfClearAll)
    }

    @ViewBuilder private var archiveStatus: some View {
        if archives.isRunning {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("\(text.archive) · \(archives.completed)/\(archives.total)")
                    .font(.caption).monospacedDigit()
                Spacer()
                Button(l10n.s.uninstallerCancel, action: archives.cancel)
                    .controlSize(.small).disabled(archives.wasCancelled)
            }
        } else if let failure = archives.failure {
            Text(failure).font(.caption).foregroundStyle(.orange).lineLimit(3)
        } else if !archives.outputURLs.isEmpty {
            HStack {
                Label(text.saved, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Spacer()
                Button(l10n.s.mediaOpenInFinder) {
                    NSWorkspace.shared.activateFileViewerSelecting(archives.outputURLs)
                }
            }.font(.caption).controlSize(.small)
        } else if archives.wasCancelled {
            Text(l10n.s.mediaCancelled).font(.caption).foregroundStyle(.secondary)
        }
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
