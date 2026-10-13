// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// English only for now; other languages fall back to these lines.
struct SpotifyQueueStrings {
    let featureTitle: String
    let featureDescription: String
    let connect: String
    let connecting: String
    let disconnect: String
    let connectedAs: String
    let connectPrompt: String
    let clientID: String
    let clientIDHint: String
    let redirectLabel: String
    let copy: String
    let needsClientID: String
    let portBusy: String
    let signInFailed: String
    let browserDone: String
    let upNext: String
    let nowPlaying: String
    let nothingQueued: String
    let fromPlaylist: String
    let fromAlbum: String
    let noAnswer: String
    let retry: String
    let reorderLimit: String
    let searchPlaceholder: String
    let addToQueue: String
    let playNow: String
    let skipNext: String
    let skipPrevious: String
    let actionFailed: String
    let throttled: String
    let advanced: String
    let advancedHint: String

    static let current = SpotifyQueueStrings(
        featureTitle: "Spotify up next",
        featureDescription: "Show Spotify's real queue on the music page, play a queued song now, or add one.",
        connect: "Connect Spotify",
        connecting: "Waiting for Spotify in your browser…",
        disconnect: "Disconnect",
        connectedAs: "Connected as %@",
        connectPrompt: "Connect Spotify to see what plays next",
        clientID: "Client ID",
        clientIDHint: "Create one at developer.spotify.com, redirect URI shown here.",
        redirectLabel: "Redirect URI",
        copy: "Copy",
        needsClientID: "Add a Spotify Client ID in Settings, Dynamic Island, Music.",
        portBusy: "Could not listen on 127.0.0.1:43821. Close the app using that port and try again.",
        signInFailed: "Spotify sign in did not finish. Try again.",
        browserDone: "Spotify is connected to Vorssaint. You can close this tab.",
        upNext: "Up next",
        nowPlaying: "Now playing",
        nothingQueued: "Nothing queued after this song",
        fromPlaylist: "From the playlist",
        fromAlbum: "From the album",
        noAnswer: "Spotify did not answer (code %d), retrying",
        retry: "Retry",
        reorderLimit: "Drag to reorder. Tap a song to play it now.",
        searchPlaceholder: "Add a song to the queue",
        addToQueue: "Add to queue",
        playNow: "Play now",
        skipNext: "Next song",
        skipPrevious: "Previous song",
        actionFailed: "Spotify did not accept that. Playback may be on a device that is offline.",
        throttled: "Spotify is throttling this right now",
        advanced: "Advanced (developer login)",
        advancedHint: "Only needed if the normal Spotify login does not work for you.")
}
