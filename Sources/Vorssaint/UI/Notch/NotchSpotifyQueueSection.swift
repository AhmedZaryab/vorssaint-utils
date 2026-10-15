// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Spotify's own queue on the music page, read from the Web API.
struct NotchSpotifyQueueSection: View {
    @ObservedObject private var auth = SpotifyWebAuth.shared
    @ObservedObject private var privateAuth = SpotifyPrivateAuth.shared
    @ObservedObject private var service = SpotifyQueueService.shared
    @State private var searchText = ""
    @State private var showsSearch = false
    /// Optimistic order shown while a move or remove is in flight or until the next poll lands.
    @State private var localOrder: [SpotifyQueueService.Track]?
    @State private var dragID: String?
    @State private var dragFrom = 0
    @State private var dragTo = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hoveredID: String?
    /// The row under a mouse down that has not travelled yet; it draws the press until the pointer lifts or swipes.
    @State private var pressedID: String?
    @State private var orderFailed = false
    @FocusState private var focusedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A move or remove is on its way to Spotify. No new drag starts until it lands, so a
    /// drag's positions always count rows in the list Spotify last sent (service.upNext).
    @State private var committing = false
    private static let rowHeight: CGFloat = NotchQueueMetrics.rowHeight
    private let text = SpotifyQueueStrings.current

    var body: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
            header
            if !connected {
                connectPrompt
            } else {
                if showsSearch { searchArea }
                if service.actionThrottled {
                    Text(text.throttled).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Palette.warning)
                }
                if service.actionFailed {
                    Text(text.actionFailed).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Palette.warning)
                }
                if orderFailed {
                    Text(text.orderRejected).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Palette.warning)
                }
                if let code = service.failureCode {
                    HStack(spacing: NotchDesign.Spacing.small) {
                        Text(String(format: text.noAnswer, code)).font(NotchDesign.Typography.callout.font)
                            .foregroundStyle(NotchDesign.Palette.warning).lineLimit(2)
                        Spacer(minLength: 0)
                        NotchPillButton(title: text.retry) { service.retryNow() }
                    }
                }
                if let playing = service.current { nowPlayingRow(playing) }
                if service.upNext.isEmpty, !service.loading, service.failureCode == nil {
                    Text(text.nothingQueued).font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { index, track in
                                queueRow(track, index: index)
                            }
                        }
                    }
                    .notchScrollEdgeFade()
                }
                Text(text.reorderLimit).font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(2)
            }
        }
        .padding(.top, NotchDesign.Spacing.xSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { service.setVisible(true) }
        .onDisappear { service.setVisible(false) }
        .onChange(of: service.upNext) { _, _ in if dragID == nil { localOrder = nil } }
        .onChange(of: connected) { _, connected in service.setVisible(connected) }
    }

    private var shown: [SpotifyQueueService.Track] { localOrder ?? service.upNext }

    /// Offset that opens a gap where the dragged row will land.
    private func shift(for index: Int) -> CGFloat {
        guard dragID != nil, index != dragFrom else { return 0 }
        if dragFrom < dragTo, index > dragFrom, index <= dragTo { return -Self.rowHeight }
        if dragTo < dragFrom, index >= dragTo, index < dragFrom { return Self.rowHeight }
        return 0
    }

    /// The playing song, pinned above up next. Not in `shown`, so it never moves or gets removed.
    private func nowPlayingRow(_ track: SpotifyQueueService.Track) -> some View {
        row(track) {
            Text(text.nowPlaying).font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
        }
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .combine)
    }

    private func queueRow(_ track: SpotifyQueueService.Track, index: Int) -> some View {
        let dragging = dragID == track.id
        let hovered = hoveredID == track.id
        // Pointer or keyboard focus reveals the row's controls, so focus is never on something unseen.
        let revealed = hovered || focusedID == track.id
        let inset = NotchDesign.Control.iconButton * 2 + NotchDesign.Control.minimumHit * 0.7 + NotchDesign.Spacing.xSmall
            + 2 * (NotchDesign.Spacing.xSmall - NotchDesign.Spacing.xxSmall)
        let name = track.artist.isEmpty ? track.title : "\(track.title), \(track.artist)"
        return ZStack(alignment: .trailing) {
            // Not a Button: the row also swipes to skip, and a Button under a drag sends Spotify
            // two commands. A tap plays; the glyph on the trailing edge is the labelled way to say so.
            NotchPressFace(pressed: pressedID == track.id && !dragging,
                           shape: .rounded(NotchDesign.Radius.control), lifts: false) {
                NotchQueueRowLabel(image: track.artworkURL.flatMap { service.artwork[$0] }, title: track.title, artist: track.artist)
                    .padding(.trailing, revealed || dragging ? inset : NotchDesign.Control.iconButton + NotchDesign.Spacing.xSmall)
            }
                // Simultaneous, so the row's swipe to skip still sees the same pointer. The press
                // is drawn on mouse down and given up once the pointer travels past a tap.
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let travelled = max(abs(value.translation.width), abs(value.translation.height))
                        let pressed = travelled < NotchDesign.Interaction.dragThreshold
                        if pressed, pressedID != track.id { pressedID = track.id } else if !pressed, pressedID == track.id { pressedID = nil }
                    }
                    .onEnded { value in
                        let tapped = pressedID == track.id
                        pressedID = nil
                        if tapped, !service.actionPending { service.playNow(track) }
                    })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(name)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if !service.actionPending { service.playNow(track) } }
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                NotchFuseButton("\(text.removeFromQueue): \(track.title)", symbol: "xmark", doneAnnouncement: text.removeFromQueue,
                                shape: .rounded(NotchDesign.Radius.control)) {}
                    .capturing { let captured = track; return { remove(captured) } }
                    .focused($focusedID, equals: track.id)
                    .opacity(revealed ? 1 : 0)
                    .allowsHitTesting(revealed)
                NotchIconButton(symbol: "play.fill", title: "\(text.playNow): \(track.title)") { service.playNow(track) }
                    .disabled(service.actionPending)
                Image(systemName: "line.3.horizontal").font(NotchDesign.Icon.button.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .frame(width: NotchDesign.Spacing.xLarge, height: NotchDesign.Control.iconButton).contentShape(Rectangle())
                    .opacity(revealed || dragging ? 1 : 0)
                    .help(text.dragToReorder)
                    .accessibilityHidden(true)
                    .gesture(reorderGesture(track, index: index))
            }
            .padding(.trailing, NotchDesign.Spacing.xSmall)
        }
        .frame(height: Self.rowHeight)
        .background(dragging ? NotchDesign.Fill.selected : .clear,
                    in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
        .contentShape(Rectangle())
        .onHover { inside in hoveredID = inside ? track.id : (hoveredID == track.id ? nil : hoveredID) }
        // Exclusive, on a row that is not a Button: a swipe skips and never also plays.
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.width < -40 { service.skipNext() }
            if value.translation.width > 40 { service.skipPrevious() }
        })
        .offset(y: dragging ? dragOffset : shift(for: index))
        .zIndex(dragging ? 1 : 0)
        .animation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion), value: dragTo)
        .accessibilityAction(named: Text(text.moveUp)) { step(index, by: -1) }
        .accessibilityAction(named: Text(text.moveDown)) { step(index, by: 1) }
        .contextMenu {
            Button(text.moveUp) { step(index, by: -1) }.disabled(index == 0)
            Button(text.moveDown) { step(index, by: 1) }.disabled(index >= shown.count - 1)
            Button(text.removeFromQueue) { remove(track) }
        }
    }

    /// Keyboard and VoiceOver reorder: one place up or down, same path as the drag.
    private func step(_ index: Int, by offset: Int) {
        let to = index + offset
        guard dragID == nil, !committing, shown.indices.contains(index), shown.indices.contains(to) else { return }
        applyMove(from: index, to: to)
    }

    /// Optimistic move, then the command; the drop and the actions share it.
    private func applyMove(from: Int, to: Int) {
        guard from != to else { return }
        withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion)) {
            var list = shown
            list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            localOrder = list
        }
        commit { try await QueueCommandsProvider.current.moveInQueue(from: from, to: to) }
    }

    private func reorderGesture(_ track: SpotifyQueueService.Track, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if dragID == nil {
                    guard !committing else { return }
                    dragID = track.id; dragFrom = index; dragTo = index
                }
                dragOffset = value.translation.height
                let target = dragFrom + Int((value.translation.height / Self.rowHeight).rounded())
                dragTo = min(max(target, 0), shown.count - 1)
            }
            .onEnded { _ in
                guard dragID != nil else { return }
                let from = dragFrom, to = dragTo
                withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion)) { dragID = nil; dragOffset = 0 }
                applyMove(from: from, to: to)
            }
    }

    private func remove(_ track: SpotifyQueueService.Track) {
        let uid = track.queueUID
        withAnimation(NotchDesign.Motion.animation(NotchDesign.Motion.snappy, reduceMotion: reduceMotion)) { localOrder = shown.filter { $0.id != track.id } }
        commit { try await QueueCommandsProvider.current.removeFromQueue(uid: uid) }
    }

    /// Optimistic: the list already changed. On success the queue was re-read before `work`
    /// returned, so drop the local order; on failure put the real queue back and say so once.
    private func commit(_ work: @escaping () async throws -> Void) {
        orderFailed = false
        committing = true
        Task { @MainActor in
            do {
                try await work()
                localOrder = nil
                committing = false
            } catch {
                withAnimation(NotchDesign.Motion.fade) { localOrder = nil }
                committing = false
                orderFailed = true
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                orderFailed = false
            }
        }
    }

    private var title: String {
        switch service.contextKind {
        case "playlist": return text.fromPlaylist
        case "album": return text.fromAlbum
        default: return text.upNext
        }
    }

    /// Either login works: the Spotify login first, the developer app second.
    private var connected: Bool { privateAuth.isConnected || auth.isConnected }

    private var header: some View {
        HStack(spacing: NotchDesign.Spacing.xSmall) {
            Text(title).font(NotchDesign.Typography.title.font).padding(.leading, NotchDesign.Spacing.small)
            Spacer()
            if service.loading || service.actionPending || service.searching { ProgressView().controlSize(.mini) }
            if connected {
                iconButton("backward.end.fill", text.skipPrevious) { service.skipPrevious() }
                iconButton("forward.end.fill", text.skipNext) { service.skipNext() }
                iconButton(showsSearch ? "xmark" : "plus", text.addToQueue) {
                    showsSearch.toggle()
                    if !showsSearch { searchText = ""; service.clearSearch() }
                }
            }
        }
        .padding(.trailing, NotchDesign.Spacing.xSmall)
    }

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
            Text(text.connectPrompt).font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.secondary)
            NotchPillButton(title: text.connect, prominent: true) { privateAuth.login() }
            if let error = privateAuth.lastError ?? auth.lastError {
                Text(error).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Palette.warning).lineLimit(3)
            }
        }
    }

    private var searchArea: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.xxSmall) {
            TextField(text.searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { service.search(searchText) }
            ForEach(service.searchResults) { track in
                ZStack(alignment: .trailing) {
                    Button { if !service.actionPending { service.addToQueue(track) } } label: {
                        NotchQueueRowLabel(image: track.artworkURL.flatMap { service.artwork[$0] }, title: track.title, artist: track.artist)
                            .padding(.trailing, NotchDesign.Control.iconButton + NotchDesign.Spacing.xSmall)
                    }
                    .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
                    .accessibilityLabel("\(text.addToQueue): \(track.title)")
                    NotchIconButton(symbol: "plus", title: "\(text.addToQueue): \(track.title)") { service.addToQueue(track) }
                        .disabled(service.actionPending)
                        .padding(.trailing, NotchDesign.Spacing.xSmall)
                }
                .frame(height: Self.rowHeight)
            }
        }
    }

    /// The pinned playing song: the same row shape, with its label where the controls sit.
    private func row<Trailing: View>(_ track: SpotifyQueueService.Track,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: NotchDesign.Spacing.small) {
            NotchQueueRowLabel(image: track.artworkURL.flatMap { service.artwork[$0] }, title: track.title, artist: track.artist)
            trailing().padding(.trailing, NotchDesign.Spacing.small)
        }
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        NotchIconButton(symbol: symbol, title: label, action: action).disabled(service.actionPending)
    }
}
