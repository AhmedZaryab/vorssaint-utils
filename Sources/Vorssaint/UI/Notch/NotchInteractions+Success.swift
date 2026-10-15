// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

private typealias Metrics = NotchInteractionMetrics

/// The success class: morphs a view's glyph into a checkmark for 1.2 s and
/// back each time `trigger` changes, for results that land in place: copied,
/// saved, added to the queue. Set the font after this modifier so the
/// checkmark matches the glyph it stands in for.
struct NotchSuccessMorph<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    var symbol = "checkmark"
    /// Read out by VoiceOver when the morph plays.
    var announcement: String?
    @State private var showing = false
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchInteractionPreview) private var preview

    func body(content: Content) -> some View {
        let shown = showing || preview == .success
        let moves = !reduceMotion
        content
            .opacity(shown ? 0 : 1)
            .scaleEffect(shown && moves ? Metrics.successFrom : 1)
            .blur(radius: shown && moves ? Metrics.blurBridge : 0)
            .overlay {
                Image(systemName: symbol)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown || !moves ? 1 : Metrics.successFrom)
                    .blur(radius: shown || !moves ? 0 : Metrics.blurBridge)
                    .accessibilityHidden(true)
            }
            // Arrives on the bouncy spring, leaves faster on an ease out with no overshoot.
            .animation(!moves ? Metrics.crossfade : shown ? Metrics.successMorph : Metrics.successReturn, value: shown)
            .onChange(of: trigger) {
                showing = true
                generation &+= 1
                if let announcement { AccessibilityNotification.Announcement(announcement).post() }
            }
            // The hold is a timer, so a second success restarts it cleanly.
            .task(id: generation) {
                guard showing else { return }
                try? await Task.sleep(for: .seconds(Metrics.successHold))
                if !Task.isCancelled { showing = false }
            }
    }
}

extension View {
    func notchSuccessMorph<Trigger: Equatable>(trigger: Trigger, symbol: String = "checkmark",
                                               announcement: String? = nil) -> some View {
        modifier(NotchSuccessMorph(trigger: trigger, symbol: symbol, announcement: announcement))
    }
}
