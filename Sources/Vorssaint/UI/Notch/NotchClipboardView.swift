// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The history as a vertical list of cards, with everything the panel's list
/// and the quick panel offer on each: paste or copy, pin, move, delete, and
/// the recent ones cleared in one go from the search row.
struct NotchClipboardView: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var enabled = false
    @State private var query = ""
    @State private var copiedID: UUID?
    /// One tick per copy, per entry: the success morph plays on each change.
    @State private var copyTicks: [UUID: Int] = [:]
    @State private var pinnedOnly = false
    /// The card the arrow keys chose from the search field, or the top result
    /// of a typed search; Return uses it the way a click would.
    @State private var highlightedID: UUID?
    @FocusState private var searching: Bool
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: ClipboardFeatureStrings { FeatureStrings.clipboard(l10n.language) }

    private var entries: [ClipboardHistoryEntry] {
        history.filteredEntries(matching: query).filter { !pinnedOnly || $0.isPinned }
    }

    /// Moving swaps neighbours in the list, which a search would misreport.
    private var canReorder: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var searchTokens: [String] {
        ClipboardHistorySearch.searchTokens(for: query)
    }

    /// The island draws its text in white and never in the accent color, so a
    /// match stands out by weight alone.
    private func searchText(_ string: String, matching tokens: [String]) -> Text {
        SearchHighlightText.text(string, tokens: tokens, fontSize: 13, highlightColor: nil)
    }

    var body: some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            let recent = history.recentEntriesSnapshot
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                HStack(spacing: NotchDesign.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .font(NotchDesign.Icon.button.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .accessibilityHidden(true)
                    TextField(text.search, text: $query).textFieldStyle(.plain)
                        .font(NotchDesign.Typography.body.font)
                        .focused($searching)
                        .accessibilityLabel(text.search)
                }
                .padding(.horizontal, NotchDesign.Spacing.medium)
                .frame(height: NotchLayout.clipboardSearchHeight)
                .modifier(ClipboardPlate(radius: NotchDesign.Radius.control,
                                         fill: searching ? NotchDesign.Fill.selected : NotchDesign.Fill.control))
                .animation(NotchDesign.Motion.fade, value: searching)
                .background {
                    if !preview {
                        ClipboardSearchKeyMonitor(active: searching) { handleSearchKey($0) }
                            .frame(width: 0, height: 0)
                    }
                }
                // The actions sit beside the field, not inside its plate, so a
                // destructive one never reads as part of the text.
                Toggle(text.pinned, isOn: $pinnedOnly)
                    .toggleStyle(NotchToggleStyle(on: "pin.fill", off: "pin",
                                                  shape: .rounded(NotchDesign.Radius.control)))
                    .help(text.pinned)
                // The payload is read when the fuse is lit; entries copied while
                // it burns are not cleared with it.
                NotchFuseButton(text.clearRecent, symbol: "trash", doneAnnouncement: text.clearRecent,
                                shape: .rounded(NotchDesign.Radius.control)) {
                    history.clearRecent(recent)
                    copiedID = nil
                }
                .disabled(recent.isEmpty)
                NotchPlainIconButton(symbol: "arrow.up.forward.app", title: text.title) {
                    service.perform { history.showHistoryWindow(preferNotch: false) }
                }
            }
            // Typing filters the history as soon as the page opens, as in Explore.
            .onAppear { if !preview { searching = true } }
            if !enabled, history.entries.isEmpty {
                // The panel offers the switch beside its caption; the page
                // says why it is empty and turns the history on from here.
                VStack(spacing: NotchDesign.Spacing.medium) {
                    NotchEmptyView(symbol: "doc.on.clipboard", message: text.disabled)
                    Button {
                        enabled = true
                        history.syncWithPreferences()
                    } label: {
                        Text(text.enable)
                            .font(NotchDesign.Typography.callout.font)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .padding(.horizontal, NotchDesign.Spacing.medium)
                            .frame(minHeight: NotchDesign.Control.rowHeight)
                            .background(NotchDesign.Palette.accent, in: Capsule(style: .continuous))
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
                }
                .frame(maxHeight: .infinity)
            } else if entries.isEmpty {
                NotchEmptyView(symbol: pinnedOnly ? "pin" : "doc.on.clipboard",
                               message: query.isEmpty && !pinnedOnly ? text.empty : text.noResults)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: NotchDesign.Spacing.gutter) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                card(entry, place: index).frame(height: NotchLayout.clipboardCardHeight)
                                    .id(entry.id)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .notchScrollEdgeFade()
                    .onChange(of: highlightedID) { _, id in
                        // Arrow keys land at once; nothing animates on a keyboard action.
                        guard let id else { return }
                        proxy.scrollTo(id)
                    }
                    // A copied recent entry moves to the top, so the list
                    // follows it and the tick stays in view.
                    .onChange(of: copiedID) { _, id in
                        guard let id else { return }
                        withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion)) {
                            proxy.scrollTo(id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A new search starts from its top result instead of a row it hid,
        // and a row that leaves the list hands the highlight on the same way.
        .onChange(of: query) { _, _ in highlightedID = searchHighlight(keeping: nil) }
        .onChange(of: pinnedOnly) { _, _ in highlightedID = searchHighlight(keeping: nil) }
        .onChange(of: entries.map(\.id)) { _, _ in highlightedID = searchHighlight(keeping: highlightedID) }
        .onChange(of: service.clipboardPastePress) { _, press in
            guard let press, !preview else { return }
            guard entries.indices.contains(press.index) else {
                NSSound.beep()
                return
            }
            activate(entries[press.index])
        }
        .task(id: copiedID) {
            // The tick confirms one copy; leaving it on the row forever would
            // read as a permanent state instead of an answer.
            guard copiedID != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copiedID = nil
        }
    }

    /// The entry fills the card; its actions sit in the bottom row.
    private func card(_ entry: ClipboardHistoryEntry, place: Int) -> some View {
        let radius = NotchDesign.Radius.card
        let highlighted = highlightedID == entry.id
        return VStack(alignment: .leading, spacing: NotchDesign.Spacing.xxSmall) {
            Button { activate(entry) } label: {
                preview(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
            .help(permissions.accessibility ? text.clickRowShortcut : text.copy)
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                Image(systemName: entry.kind == .image ? "photo" : entry.kind == .files ? "doc" : "text.alignleft")
                    .font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .accessibilityHidden(true)
                Text(entry.copiedAt, style: .time)
                    .environment(\.locale, l10n.language.formattingLocale())
                    .font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if place < 9, service.panelIsKey {
                    Text("⌘\(place + 1)")
                        .font(NotchDesign.Typography.caption.font).monospacedDigit()
                        .foregroundStyle(NotchDesign.Ink.tertiary)
                        .accessibilityHidden(true)
                }
                NotchPlainIconButton(symbol: "doc.on.doc", title: copiedID == entry.id ? text.copied : text.copy,
                                     successTrigger: copyTicks[entry.id, default: 0]) { copy(entry) }
                Toggle(entry.isPinned ? text.unpin : text.pin,
                       isOn: Binding(get: { entry.isPinned }, set: { _ in history.togglePin(entry) }))
                    .toggleStyle(NotchToggleStyle(on: "pin.fill", off: "pin",
                                                  shape: .rounded(NotchDesign.Radius.control)))
                    .help(entry.isPinned ? text.unpin : text.pin)
                NotchFuseButton(text.delete, symbol: "trash", doneAnnouncement: text.delete,
                                shape: .rounded(NotchDesign.Radius.control)) { remove(entry) }
            }
            .frame(height: NotchDesign.Control.iconButton)
            // The bezels sit Spacing.xSmall from the card's edge (concentric
            // with Radius.control), so the row reaches past the text inset.
            .padding(.trailing, -(NotchDesign.Spacing.cardPadding - NotchDesign.Spacing.xSmall))
        }
        .padding(.horizontal, NotchDesign.Spacing.cardPadding)
        .padding(.top, NotchDesign.Spacing.cardPadding)
        .padding(.bottom, NotchDesign.Spacing.xSmall)
        .modifier(ClipboardPlate(radius: radius,
                                 fill: highlighted ? NotchDesign.Fill.selected : NotchDesign.Fill.card,
                                 keyboardFocus: highlighted))
        // The highlight only ever moves from the keyboard or a new search
        // result, and nothing animates on a keyboard action.
        .transaction(value: highlighted) { $0.animation = nil }
        .clipped()
        .contextMenu { actions(entry) }
        .accessibilityAction(named: Text(text.moveUp)) { move(entry, .up) }
        .accessibilityAction(named: Text(text.moveDown)) { move(entry, .down) }
    }

    /// The quick panel's row menu: paste when the app may type, copy, pin,
    /// move within the list and delete.
    @ViewBuilder private func actions(_ entry: ClipboardHistoryEntry) -> some View {
        if permissions.accessibility {
            Button(l10n.s.menuPaste) { paste(entry) }
        }
        Button(text.copy) { copy(entry) }
        Divider()
        Button(entry.isPinned ? text.unpin : text.pin) { history.togglePin(entry) }
        Button(text.moveUp) { move(entry, .up) }
            .disabled(!canReorder || !history.canMove(entry, .up))
        Button(text.moveDown) { move(entry, .down) }
            .disabled(!canReorder || !history.canMove(entry, .down))
        Divider()
        Button(text.delete, role: .destructive) { remove(entry) }
    }

    private func searchHighlight(keeping current: UUID?) -> UUID? {
        NotchSupport.searchHighlight(keeping: current, in: entries.map(\.id), query: query)
    }

    /// Up and Down move the highlight while the search field keeps typing;
    /// Return pastes or copies it like a click.
    private func handleSearchKey(_ keyCode: UInt16) -> Bool {
        let ids = entries.map(\.id)
        switch keyCode {
        case 125, 126:
            guard !ids.isEmpty else { return false }
            highlightedID = NotchSupport.steppedItem(from: highlightedID, in: ids, backwards: keyCode == 126)
            return true
        case 36, 76:
            guard let id = NotchSupport.clipboardPasteTarget(highlighted: highlightedID, in: ids),
                  let entry = entries.first(where: { $0.id == id }) else { return false }
            activate(entry)
            return true
        default:
            return false
        }
    }

    private func activate(_ entry: ClipboardHistoryEntry) {
        if permissions.accessibility { paste(entry) } else { copy(entry) }
    }

    private func paste(_ entry: ClipboardHistoryEntry) {
        service.collapse()
        history.copyQuickEntry(entry)
    }

    private func copy(_ entry: ClipboardHistoryEntry) {
        // A copied recent entry moves to the top, so the second click of a
        // double click would copy whichever entry took its place.
        if let event = NSApp.currentEvent, [.leftMouseDown, .leftMouseUp].contains(event.type),
           event.clickCount > 1 { return }
        history.copy(entry) { copied in
            if copied {
                copiedID = entry.id
                copyTicks[entry.id, default: 0] += 1
            } else {
                NSSound.beep()
            }
        }
    }

    private func move(_ entry: ClipboardHistoryEntry, _ direction: ClipboardHistoryMoveDirection) {
        guard canReorder, history.canMove(entry, direction) else { return }
        history.move(entry, direction)
    }

    private func remove(_ entry: ClipboardHistoryEntry) {
        if copiedID == entry.id { copiedID = nil }
        history.remove(entry)
    }

    @ViewBuilder private func preview(_ entry: ClipboardHistoryEntry) -> some View {
        switch entry.kind {
        case .image:
            if let name = entry.imageFile {
                ClipboardThumbnailImage(source: .stored(name: name),
                                        aspectRatio: entry.imageAspectRatio,
                                        failureText: "\(text.imageEntryLabel) · \(entry.imageDimensionsLabel)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
                    .help("\(text.imageEntryLabel) · \(entry.imageDimensionsLabel)")
            } else {
                searchText("\(text.imageEntryLabel) · \(entry.imageDimensionsLabel)", matching: searchTokens)
                    .font(NotchDesign.Typography.body.font)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .files:
            // One image file shows itself; anything else reads as its name
            // or its count, the way the panel lists files.
            if entry.filePaths.count == 1, let path = entry.filePaths.first,
               ClipboardImageStore.isImageFile(atPath: path) {
                ClipboardThumbnailImage(source: .file(path: path),
                                        failureText: entry.fileNames.first ?? entry.preview)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
                    .help(path)
            } else {
                // A count of several files is no text the search reads.
                Label {
                    searchText(entry.filePaths.count == 1
                                   ? (entry.fileNames.first ?? entry.preview)
                                   : String(format: text.fileCountFormat, entry.filePaths.count),
                               matching: entry.filePaths.count == 1 ? searchTokens : [])
                } icon: {
                    Image(systemName: "folder")
                }
                .font(NotchDesign.Typography.body.font)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .help(entry.filePaths.joined(separator: "\n"))
            }
        case .text:
            HStack(alignment: .firstTextBaseline, spacing: NotchDesign.Spacing.xSmall) {
                if let color = entry.color {
                    ColorSwatch(color: color, size: 12)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                }
                searchText(entry.preview, matching: searchTokens)
                    .font(NotchDesign.Typography.body.font)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// Reads the arrow keys and Return before the search field's editor does,
/// which would otherwise spend them moving the caret.
private struct ClipboardSearchKeyMonitor: NSViewRepresentable {
    var active: Bool
    var handleKey: (UInt16) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.active = active
        context.coordinator.handleKey = handleKey
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(active: active, handleKey: handleKey)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var active: Bool
        var handleKey: (UInt16) -> Bool
        private var monitor: Any?

        init(active: Bool, handleKey: @escaping (UInt16) -> Bool) {
            self.active = active
            self.handleKey = handleKey
        }

        func install(for view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak view] event in
                guard let self, self.active, let window = view?.window, event.window === window,
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                      [UInt16(125), 126, 36, 76].contains(event.keyCode),
                      let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
                      !editor.hasMarkedText() else { return event }
                return self.handleKey(event.keyCode) ? nil : event
            }
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// A card or field plate: a flat fill at the token's radius, a hairline on
/// glass, and the Increase Contrast edge.
private struct ClipboardPlate: ViewModifier {
    let radius: CGFloat
    let fill: Color
    /// The keyboard's choice: the system focus ring on top of the fill, since
    /// a fill step alone is 1.3:1 against its neighbours.
    var keyboardFocus = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.notchGlassSurface) private var glassSurface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(fill, in: shape)
            .overlay {
                if keyboardFocus {
                    shape.strokeBorder(Color(nsColor: .keyboardFocusIndicatorColor),
                                       lineWidth: NotchDesign.Stroke.increasedContrastWidth * 2)
                        .allowsHitTesting(false)
                } else if contrast == .increased {
                    shape.strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
                        .allowsHitTesting(false)
                } else if glassSurface {
                    shape.strokeBorder(NotchDesign.Stroke.glassEdge, lineWidth: NotchDesign.Stroke.hairline)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// The tap class for an icon in a plate row: a 28 pt target on NotchPressStyle.
/// With a `successTrigger`, each change morphs the glyph to a checkmark.
struct NotchPlainIconButton: View {
    let symbol: String
    let title: String
    var successTrigger: Int?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            glyph
                .font(NotchDesign.Icon.button.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control)))
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var glyph: some View {
        if let successTrigger {
            Image(systemName: symbol).notchSuccessMorph(trigger: successTrigger, announcement: title)
        } else {
            Image(systemName: symbol)
        }
    }
}
