// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The scratchpad's document inside the island: its tabs in a row, the
/// editor or its formatted reading filling the rest, and the pad's actions
/// behind one menu. Everything the floating pad does, at the island's size:
/// tabs close from their own cross, Command-T and Command-W work, a new or
/// chosen pad puts the caret in its text, and a cleared pad comes back with
/// one undo.
struct NotchScratchpadView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var pad = ScratchpadService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var loadFailed = false
    @State private var copied = false
    @State private var copyCount = 0
    @State private var hoveredPadID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editor = EditorHandle()
    @AppStorage(DefaultsKey.scratchpadTextSize) private var storedTextSize = ScratchpadSupport.defaultTextSize
    private var text: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }
    private var textSize: CGFloat { CGFloat(ScratchpadSupport.sanitizedTextSize(storedTextSize)) }
    private static let editorInset = NSSize(width: NotchDesign.Spacing.cardPadding - PlainTextEditor.lineFragmentPadding,
                                                  height: NotchDesign.Spacing.cardPadding)

    /// Holds the editor's text view so a tab change can aim the caret at it
    /// and a clear can go through its undo. Weak, since the view belongs to
    /// the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    private var selectedPad: ScratchpadPad? { pad.pads.first { $0.id == pad.selectedPadID } }

    var body: some View {
        Group {
            if loadFailed {
                NotchEmptyView(symbol: "exclamationmark.triangle", message: text.loadFailed)
            } else {
                VStack(spacing: NotchDesign.Spacing.xSmall) {
                    toolbar
                    if pad.saveFailed {
                        Label(text.saveFailed, systemImage: "exclamationmark.triangle")
                            .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ZStack(alignment: .topLeading) {
                        PlainTextEditor(text: $pad.text, fontSize: textSize,
                                        textColor: NSColor(NotchDesign.Ink.primary),
                                        textContainerInset: Self.editorInset,
                                        usesFindBar: true) { view in
                            view.insertionPointColor = NSColor(NotchDesign.Palette.accent)
                            editor.view = view
                            DispatchQueue.main.async { focusEditor() }
                        }
                        .opacity(pad.isPreviewing ? 0 : 1)
                        .allowsHitTesting(!pad.isPreviewing)
                        .accessibilityHidden(pad.isPreviewing)
                        if pad.isPreviewing {
                            MarkdownPreview(blocks: ScratchpadSupport.markdownPreview(pad.text),
                                            baseSize: textSize)
                        } else if pad.text.isEmpty {
                            Text(text.placeholder)
                                .font(.system(size: textSize))
                                .foregroundStyle(NotchDesign.Ink.tertiary)
                                .padding(.leading, Self.editorInset.width + PlainTextEditor.lineFragmentPadding)
                                .padding(.top, Self.editorInset.height)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(NotchControlSurface(cornerRadius: NotchDesign.Radius.card, interactive: false))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadFailed = !pad.loadForEmbedding() }
        .onDisappear { pad.commitEdits() }
        .onChange(of: pad.selectedPadID) { _, _ in
            DispatchQueue.main.async { focusEditor() }
        }
        .onChange(of: pad.isPreviewing) { _, previewing in
            guard let view = editor.view else { return }
            if previewing {
                pad.hideFindBar(in: view)
                if view.window?.firstResponder === view || PlainTextEditor.findBarHasKeyboard(in: view.window) {
                    view.window?.makeFirstResponder(nil)
                }
            } else {
                DispatchQueue.main.async {
                    // Preview closed the bar and took the keyboard, so a bar
                    // up now was opened by Command-F and a focused text was
                    // given the keyboard by Command-G, both on their way out
                    // of preview. Either keeps its focus and the match.
                    guard view.enclosingScrollView?.isFindBarVisible != true,
                          view.window?.firstResponder !== view else { return }
                    focusEditor()
                }
            }
        }
        .onChange(of: service.scratchpadCloseSerial) { _, _ in
            guard let selectedPad else { return }
            requestClose(selectedPad)
        }
        .onChange(of: service.scratchpadFindSerial) { _, _ in
            pad.performFind(service.scratchpadFindAction, in: editor.view)
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: NotchDesign.Spacing.xxSmall) {
                    ForEach(pad.pads) { entry in tab(entry).id(entry.id) }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard let selected = pad.selectedPadID else { return }
                proxy.scrollTo(selected, anchor: .center)
            }
            .onChange(of: pad.selectedPadID) { _, selected in
                guard let selected else { return }
                // A key (Command-T, Command-W, a shortcut) lands at once; the
                // pointer keeps the spring, and Reduce Motion drops it.
                let fromKeyboard = NSApp.currentEvent?.type == .keyDown
                let animation = fromKeyboard ? nil
                    : NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion)
                withAnimation(animation) { proxy.scrollTo(selected, anchor: .center) }
            }
        }
    }

    private var markRow: some View {
        ScratchpadFormatBar(style: .island, editor: editor.view)
    }

    private var toolbar: some View {
        HStack(spacing: NotchDesign.Spacing.xSmall) {
            // The island has one row to spend. The marks take the tab strip's
            // place while they are up rather than squeezing in beside it, and
            // the chip stays put so the same click puts the tabs back.
            if pad.marksExpanded {
                markRow
            } else {
                tabStrip
            }
            ToolbarButton(symbol: "textformat", title: text.formatMarks, selected: pad.marksExpanded) {
                withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion)) {
                    pad.toggleMarks()
                }
            }
            .disabled(pad.isPreviewing)
            ToolbarButton(symbol: "plus",
                          title: pad.canCreatePad
                              ? text.newPad
                              : String(format: text.padLimitFormat, ScratchpadDocument.maximumPadCount)) {
                pad.createPad(defaultName: text.pageTitle)
            }
            .disabled(!pad.canCreatePad)
            ToolbarButton(symbol: pad.isPreviewing ? "pencil" : "eye",
                          title: pad.isPreviewing ? text.editText : text.previewFormatting,
                          selected: pad.isPreviewing, action: pad.togglePreview)
                .disabled(pad.text.isEmpty)
            ToolbarButton(symbol: "doc.on.doc", title: copied ? text.copied : text.copyAll,
                          morphTrigger: copyCount, announcement: text.copied) {
                pad.copyAll()
                copied = true
                copyCount += 1
            }
            .disabled(pad.text.isEmpty)
            NotchMoreMenu(title: text.padActions, symbol: "doc.badge.ellipsis", items: padMenuItems)
        }
        .frame(height: NotchDesign.Control.rowHeight)
    }

    /// The pad's actions as a native menu, so the button sits on the header's column.
    private var padMenuItems: [NotchMenuItem] {
        var items: [NotchMenuItem] = []
        if let selectedPad {
            items.append(NotchMenuItem(title: text.renamePad) { presentRename(selectedPad) })
            items.append(.separator)
        }
        items.append(NotchMenuItem(title: text.exportAction, enabled: !pad.text.isEmpty) {
            if let window = service.presentationWindow {
                pad.exportText(suggestedName: ScratchpadSupport.exportFileName(title: pad.selectedPadName, date: Date()),
                               from: window)
            }
        })
        items.append(NotchMenuItem(title: text.openButton) { service.perform { pad.show(allowsIsland: false) } })
        // Destructive entries go last, after a line, in red.
        items.append(.separator)
        items.append(NotchMenuItem(title: text.clearAction, enabled: !pad.text.isEmpty, destructive: true) {
            pad.clear(through: editor.view)
        })
        if let selectedPad {
            items.append(NotchMenuItem(title: text.closePad, enabled: pad.canClosePad, destructive: true) { requestClose(selectedPad) })
        }
        return items
    }

    /// The cross shows on the selected tab and under the pointer, as in the
    /// floating pad; it needs the tab strip to keep two pads or more.
    private func tab(_ entry: ScratchpadPad) -> some View {
        let selected = entry.id == pad.selectedPadID
        let showsClose = pad.canClosePad && (selected || hoveredPadID == entry.id)
        let shape = RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous)
        return ZStack(alignment: .trailing) {
            Button { pad.selectPad(entry.id) } label: {
                Text(entry.name)
                    .font(NotchDesign.Typography.label.font)
                    .lineLimit(1)
                    .foregroundStyle(selected ? NotchDesign.Ink.primary : NotchDesign.Ink.secondary)
                    .padding(.leading, NotchDesign.Spacing.small)
                    // Room for the cross, which is its own control on top.
                    .padding(.trailing, showsClose ? NotchDesign.Control.minimumHit - NotchDesign.Spacing.xxSmall
                                                   : NotchDesign.Spacing.small)
                    .frame(height: NotchDesign.Control.rowHeight - NotchDesign.Spacing.xxSmall)
                    .background(selected ? NotchDesign.Fill.selected : NotchDesign.Fill.card, in: shape)
                    .contentShape(shape)
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false, washes: false))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help(entry.name)
            if showsClose {
                // Outside the tab's label so it is reachable on its own, with
                // the full minimum hit area around the small cross.
                Button { requestClose(entry) } label: {
                    Image(systemName: "xmark")
                        .font(NotchDesign.Typography.caption.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .frame(width: NotchDesign.Control.minimumHit, height: NotchDesign.Control.minimumHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
                .help(text.closePad)
                .accessibilityLabel(text.closePad)
            }
        }
        .onHover { hovering in
            if hovering { hoveredPadID = entry.id } else if hoveredPadID == entry.id { hoveredPadID = nil }
        }
        .contextMenu {
            Button(text.renamePad) { presentRename(entry) }
            Button(text.closePad, role: .destructive) { requestClose(entry) }
                .disabled(!pad.canClosePad)
        }
    }

    /// The caret lands at the end of the pad's text, as the floating pad
    /// puts it after a tab change.
    private func focusEditor() {
        guard !pad.isPreviewing, let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
        let end = NSRange(location: (view.string as NSString).length, length: 0)
        view.setSelectedRange(end)
        view.scrollRangeToVisible(end)
    }

    private func presentRename(_ entry: ScratchpadPad) {
        DispatchQueue.main.async {
            let field = NSTextField(string: entry.name)
            field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
            let alert = NSAlert()
            alert.messageText = text.renamePad
            alert.accessoryView = field
            alert.addButton(withTitle: text.saveName)
            alert.addButton(withTitle: text.cancel)
            alert.window.initialFirstResponder = field
            guard NotchIslandAlert.run(alert, above: service.presentationWindow) == .alertFirstButtonReturn else { return }
            pad.renamePad(entry.id, to: field.stringValue)
        }
    }

    /// An empty pad goes without asking, like in the floating pad.
    private func requestClose(_ entry: ScratchpadPad) {
        guard pad.canClosePad else { return }
        guard ScratchpadSupport.requiresCloseConfirmation(entry) else { _ = pad.closePad(entry.id); return }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = text.closePad
            alert.informativeText = String(format: text.deletePadMessageFormat, entry.name)
            alert.addButton(withTitle: text.closePad).hasDestructiveAction = true
            alert.addButton(withTitle: text.cancel)
            guard NotchIslandAlert.run(alert, above: service.presentationWindow) == .alertFirstButtonReturn else { return }
            _ = pad.closePad(entry.id)
        }
    }

    /// A 28 pt toolbar plate on the press class: a wash under the pointer, the
    /// press settling on mouse down, the chosen state on Fill.selected. A copy
    /// button passes `morphTrigger` and its glyph becomes a check where it stands.
    private struct ToolbarButton: View {
        let symbol: String
        let title: String
        var selected = false
        var morphTrigger: Int?
        var announcement: String?
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                glyph
                    .font(NotchDesign.Icon.button.font)
                    .foregroundStyle(selected ? NotchDesign.Ink.primary : NotchDesign.Ink.secondary)
                    .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                    .background(selected ? NotchDesign.Fill.selected : .clear,
                                in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
            }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control)))
            .help(title)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        @ViewBuilder private var glyph: some View {
            if let morphTrigger {
                Image(systemName: symbol).notchSuccessMorph(trigger: morphTrigger, announcement: announcement)
            } else {
                Image(systemName: symbol).contentTransition(.symbolEffect(.replace))
            }
        }
    }
}
