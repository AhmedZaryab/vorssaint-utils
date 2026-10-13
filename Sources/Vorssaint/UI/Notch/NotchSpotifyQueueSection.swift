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
    @State private var orderFailed = false
    /// A move or remove is on its way to Spotify. No new drag starts until it lands, so a
    /// drag's positions always count rows in the list Spotify last sent (service.upNext).
    @State private var committing = false
    private static let rowHeight: CGFloat = 44
    private let text = SpotifyQueueStrings.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !connected {
                connectPrompt
            } else {
                if showsSearch { searchArea }
                if service.actionThrottled {
                    Text(text.throttled).font(.caption).foregroundStyle(.orange)
                }
                if service.actionFailed {
                    Text(text.actionFailed).font(.caption).foregroundStyle(.orange)
                }
                if orderFailed {
                    Text("Spotify did not accept the new order").font(.caption).foregroundStyle(.orange)
                }
                if let code = service.failureCode {
                    HStack(spacing: 8) {
                        Text(String(format: text.noAnswer, code)).font(.caption).foregroundStyle(.orange).lineLimit(2)
                        Spacer(minLength: 0)
                        Button(text.retry) { service.retryNow() }.buttonStyle(.borderless).font(.caption)
                    }
                }
                if let playing = service.current { nowPlayingRow(playing) }
                if service.upNext.isEmpty, !service.loading, service.failureCode == nil {
                    Text(text.nothingQueued).font(.callout).foregroundStyle(.secondary)
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
                Text(text.reorderLimit).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
            }
        }
        .padding(.top, 6)
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
            Text(text.nowPlaying).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .combine)
    }

    private func queueRow(_ track: SpotifyQueueService.Track, index: Int) -> some View {
        let dragging = dragID == track.id
        return row(track) {
            HStack(spacing: 4) {
                Button { remove(track) } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                        .frame(width: 24, height: 24).contentShape(Circle())
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: 12))
                .opacity(hoveredID == track.id ? 1 : 0)
                .help("Remove from queue").accessibilityLabel("Remove from queue: \(track.title)")
                Button { service.playNow(track) } label: {
                    Image(systemName: "play.fill").font(.system(size: 11))
                        .frame(width: 28, height: 28).contentShape(Circle())
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: 14))
                .disabled(service.actionPending)
                .help(text.playNow).accessibilityLabel("\(text.playNow): \(track.title)")
                Image(systemName: "line.3.horizontal").font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 28).contentShape(Rectangle())
                    .opacity(hoveredID == track.id || dragging ? 1 : 0)
                    .help("Drag to reorder")
                    .gesture(reorderGesture(track, index: index))
            }
        }
        .frame(height: Self.rowHeight)
        .background(dragging ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { inside in hoveredID = inside ? track.id : (hoveredID == track.id ? nil : hoveredID) }
        .onTapGesture { service.playNow(track) }
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.width < -40 { service.skipNext() }
            if value.translation.width > 40 { service.skipPrevious() }
        })
        .offset(y: dragging ? dragOffset : shift(for: index))
        .zIndex(dragging ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: dragTo)
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
                withAnimation(.easeOut(duration: 0.15)) {
                    dragID = nil; dragOffset = 0
                    if from != to {
                        var list = shown
                        list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                        localOrder = list
                    }
                }
                if from != to { commit { try await QueueCommandsProvider.current.moveInQueue(from: from, to: to) } }
            }
    }

    private func remove(_ track: SpotifyQueueService.Track) {
        let uid = track.queueUID
        withAnimation(.easeOut(duration: 0.15)) { localOrder = shown.filter { $0.id != track.id } }
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
                withAnimation { localOrder = nil }
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
        HStack(spacing: 6) {
            Text(title).font(.callout.weight(.semibold))
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
    }

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.connectPrompt).font(.callout).foregroundStyle(.secondary)
            NotchPillButton(title: text.connect, prominent: true) { privateAuth.login() }
            if let error = privateAuth.lastError ?? auth.lastError {
                Text(error).font(.caption).foregroundStyle(.orange).lineLimit(3)
            }
        }
    }

    private var searchArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(text.searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { service.search(searchText) }
            ForEach(service.searchResults) { track in
                row(track) {
                    Button { service.addToQueue(track) } label: {
                        Image(systemName: "plus").font(.system(size: 11))
                            .frame(width: 28, height: 28).contentShape(Circle())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 14))
                    .disabled(service.actionPending)
                    .help(text.addToQueue).accessibilityLabel("\(text.addToQueue): \(track.title)")
                }
            }
        }
    }

    private func row<Trailing: View>(_ track: SpotifyQueueService.Track,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            NotchArtwork(image: track.artworkURL.flatMap { service.artwork[$0] }, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.callout.weight(.medium)).lineLimit(1)
                if !track.artist.isEmpty {
                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 6)
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)) }
            .buttonStyle(.borderless)
            .disabled(service.actionPending)
            .help(label).accessibilityLabel(label)
    }
}
