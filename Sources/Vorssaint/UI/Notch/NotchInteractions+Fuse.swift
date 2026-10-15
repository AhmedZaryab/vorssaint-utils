// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

private typealias Metrics = NotchInteractionMetrics

/// When a fuse commits. Only when it burns down: the row stays put while it
/// burns, so Undo is still there to press.
enum NotchFuseCommit: Equatable {
    case fuseEnd
}

/// Owns the fuse's timer apart from the view, so a fuse whose page closes
/// while it burns still commits on time instead of stranding the action.
@MainActor @Observable
final class NotchFuseController {
    private(set) var burning = false
    /// The pointer is holding the burn, so the rim has nothing new to draw.
    private(set) var paused = false
    /// Counts commits, so the control can show it is done.
    private(set) var commits = 0
    @ObservationIgnored private var clock = NotchFuseClock(duration: 0)
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var commit: (() -> Void)?
    @ObservationIgnored private var onBlowOut: (() -> Void)?

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func remaining() -> TimeInterval { clock.remaining(at: Self.now) }
    func fraction() -> Double { clock.fraction(at: Self.now) }

    func light(duration: TimeInterval, onBlowOut: (() -> Void)? = nil, onCommit: @escaping () -> Void) {
        guard !burning else { return }
        self.onBlowOut = onBlowOut
        NotchFuseRegistry.add(self) { [weak self] in self?.escape() ?? false }
        clock = NotchFuseClock(duration: duration)
        clock.light(at: Self.now)
        commit = onCommit
        burning = true
        schedule()
    }

    /// The pointer resting on a burning fuse holds it; leaving lets it burn on.
    func hold(_ held: Bool) {
        guard burning else { return }
        if held {
            clock.pause(at: Self.now)
            if clock.isPaused { timer?.cancel(); timer = nil; paused = true }
        } else if clock.isPaused {
            clock.resume(at: Self.now)
            paused = false
            schedule()
        }
    }

    /// The task holds the controller, not the view, until the fuse resolves.
    private func schedule() {
        timer?.cancel()
        timer = Task {
            while !Task.isCancelled {
                let left = clock.remaining(at: Self.now)
                if left > 0 { try? await Task.sleep(for: .seconds(left)) }
                if Task.isCancelled || settle() { return }
            }
        }
    }

    /// Escape from the island's key monitor: blows the fuse out and runs the
    /// button's undo handling. True when it did, so the key is consumed.
    private func escape() -> Bool {
        guard blowOut() else { return false }
        onBlowOut?()
        return true
    }

    /// True when this blew the fuse out. One that has just burnt down commits
    /// instead, so the clock alone decides.
    func blowOut() -> Bool {
        guard clock.blowOut(at: Self.now) else {
            settle()
            return false
        }
        timer?.cancel()
        timer = nil
        commit = nil
        burning = false
        paused = false
        NotchFuseRegistry.remove(self)
        return true
    }

    @discardableResult private func settle() -> Bool {
        switch clock.settle(at: Self.now) {
        case .burning: return false
        case .idle:
            burning = false
            paused = false
            NotchFuseRegistry.remove(self)
            return true
        case .committed:
            let action = commit
            commit = nil
            timer = nil
            burning = false
            paused = false
            NotchFuseRegistry.remove(self)
            commits += 1
            action?()
            return true
        }
    }
}

/// The destructive class: clear the clipboard history, delete a download,
/// remove a queue item, stop a timer. A press lights a fuse along the rim and
/// the control becomes Undo while it burns; press again or Escape to blow it
/// out and nothing happens, let it burn down and `onCommit` runs and the glyph
/// morphs to done. The pointer resting on it holds the burn, once it has left
/// the control after the press. The commit rides a timer, never the drawing,
/// so it always lands. Under Reduce Motion the rim stays still and the label
/// counts down in whole seconds. VoiceOver hears it light, undo and finish.
struct NotchFuseButton: View {
    let title: String
    let symbol: String
    var undoTitle: String?
    var hint: String?
    /// Read out when the fuse commits, such as "Deleted"; "Done" by default.
    var doneAnnouncement: String?
    var fuseDuration: TimeInterval
    var commitOn: NotchFuseCommit
    /// A pill with the words; off, a square glyph for a row of icons.
    var showsTitle: Bool
    var shape: NotchPressShape
    var onUndo: (() -> Void)?
    /// Builds the commit when the fuse lights, so what it acts on is what was
    /// on screen at the press, not whatever is selected when it burns out.
    private var makeCommit: () -> () -> Void

    @State private var fuse = NotchFuseController()
    @ObservedObject private var l10n = L10n.shared
    @State private var keyboardLit = false
    /// The pointer that pressed has left since, so resting on it may hold the burn.
    @State private var mayHold = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchInteractionPreview) private var preview

    init(_ title: String, symbol: String, undoTitle: String? = nil, hint: String? = nil,
         doneAnnouncement: String? = nil, fuseDuration: TimeInterval = NotchInteractionMetrics.fuseDuration,
         commitOn: NotchFuseCommit = .fuseEnd, showsTitle: Bool = false, shape: NotchPressShape = .capsule,
         onUndo: (() -> Void)? = nil, onCommit: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.undoTitle = undoTitle
        self.hint = hint
        self.doneAnnouncement = doneAnnouncement
        self.fuseDuration = fuseDuration
        self.commitOn = commitOn
        self.showsTitle = showsTitle
        self.shape = shape
        self.onUndo = onUndo
        self.makeCommit = { onCommit }
    }

    /// Takes the payload at the press. `make` runs when the fuse lights and
    /// returns the commit, which acts on what it captured then:
    /// `NotchFuseButton(t, symbol: s) {}.capturing { let ids = selection; return { remove(ids) } }`.
    /// The `onCommit` the button was made with is replaced.
    func capturing(_ make: @escaping () -> () -> Void) -> NotchFuseButton {
        var copy = self
        copy.makeCommit = make
        return copy
    }

    private var undo: String { undoTitle ?? l10n.s.menuUndo }

    private var frozenFraction: Double? {
        if case .burning(let fraction) = preview { return fraction }
        return nil
    }

    var body: some View {
        let burning = fuse.burning || frozenFraction != nil
        Button(action: press) {
            ZStack {
                NotchFuseFace(symbol: symbol, text: showsTitle ? title : nil, commits: fuse.commits)
                    .opacity(burning ? 0 : 1)
                    .blur(radius: burning && !reduceMotion ? Metrics.blurBridge : 0)
                NotchFuseUndoFace(text: showsTitle ? undo : nil, countdown: burning && reduceMotion,
                                  remaining: { frozenFraction.map { $0 * fuseDuration } ?? fuse.remaining() })
                    .opacity(burning ? 1 : 0)
                    .blur(radius: burning || reduceMotion ? 0 : Metrics.blurBridge)
            }
            // A face swapped from the keyboard swaps at once.
            .animation(keyboardLit ? nil : Metrics.fuseFace, value: burning)
            .padding(.horizontal, showsTitle ? 12 : 0)
            .frame(minWidth: Metrics.minimumTarget, minHeight: Metrics.minimumTarget)
            .background(.white.opacity(burning ? Metrics.restingFill : 0), in: shape)
            .overlay {
                if let frozenFraction {
                    NotchFuseRim(left: frozenFraction, outline: shape).fill(Metrics.fuseTint)
                } else if burning, reduceMotion {
                    NotchFuseRim(left: 1, outline: shape).fill(Metrics.fuseTint)
                } else if burning {
                    // Drawn from the fuse's own clock, frame by frame while it
                    // burns and not at all otherwise, so no animation of the
                    // press around it can bend the burn.
                    TimelineView(.animation(paused: fuse.paused)) { _ in
                        NotchFuseRim(left: fuse.fraction(), outline: shape).fill(Metrics.fuseTint)
                            .transaction { $0.animation = nil }
                    }
                }
            }
        }
        .buttonStyle(NotchPressStyle(shape: shape))
        .onHover { inside in
            if inside, mayHold { fuse.hold(true) }
            if !inside {
                mayHold = fuse.burning
                fuse.hold(false)
            }
        }
        .onExitCommand {
            if fuse.burning { blowOut() }
        }
        .onDisappear { if fuse.burning { fuse.hold(false) } }
        .help(burning ? undo : title)
        .accessibilityLabel(burning ? undo : title)
        .accessibilityValue(burning ? title : "")
        .accessibilityHint(burning ? "" : hint ?? "")
    }

    private func press() {
        if fuse.burning {
            blowOut()
            return
        }
        keyboardLit = NSApp.currentEvent?.type == .keyDown
        mayHold = false
        let done = doneAnnouncement ?? l10n.s.mediaCompleted
        let commit = makeCommit()
        let undone = onUndo
        let cancelled = NotchFuseStrings.cancelled(l10n.language)
        fuse.light(duration: fuseDuration, onBlowOut: {
            undone?()
            AccessibilityNotification.Announcement(cancelled).post()
        }) {
            commit()
            AccessibilityNotification.Announcement(done).post()
        }
        AccessibilityNotification.Announcement("\(title), \(undo)").post()
    }

    private func blowOut() {
        keyboardLit = NSApp.currentEvent?.type == .keyDown
        guard fuse.blowOut() else { return }
        onUndo?()
        AccessibilityNotification.Announcement(NotchFuseStrings.cancelled(l10n.language)).post()
    }
}

private struct NotchFuseFace: View {
    let symbol: String
    let text: String?
    let commits: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .notchSuccessMorph(trigger: commits)
                .font(.system(size: 12, weight: .medium))
            if let text { Text(text).font(.system(size: 12, weight: .medium)).lineLimit(1) }
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

/// Undo, with the seconds left beside it under Reduce Motion. The countdown
/// ticks only while that fuse burns.
private struct NotchFuseUndoFace: View {
    let text: String?
    let countdown: Bool
    let remaining: () -> TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .semibold))
            if let text { Text(text).font(.system(size: 12, weight: .semibold)).lineLimit(1) }
            if countdown {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text("\(Int(remaining().rounded(.up)))")
                        .font(NotchDesign.Typography.caption.font)
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(Metrics.accent)
    }
}

/// What is left of the fuse along the control's own outline, with a spark
/// at the burning tip.
private struct NotchFuseRim: Shape {
    var left: Double
    let outline: NotchPressShape

    var animatableData: Double {
        get { left }
        set { left = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: Metrics.fuseLine / 2, dy: Metrics.fuseLine / 2)
        let line = outline.path(in: inset).trimmedPath(from: 0, to: max(0, min(1, left)))
        var path = line.strokedPath(StrokeStyle(lineWidth: Metrics.fuseLine, lineCap: .round))
        if left > 0.001, left < 0.999, let tip = line.currentPoint {
            path.addEllipse(in: CGRect(x: tip.x - Metrics.fuseSpark, y: tip.y - Metrics.fuseSpark,
                                       width: 2 * Metrics.fuseSpark, height: 2 * Metrics.fuseSpark))
        }
        return path
    }
}

/// What VoiceOver hears when a fuse is blown out. Kept here because the
/// fuse is the only place that says it.
private enum NotchFuseStrings {
    static func cancelled(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Cancelled"
        case .ptBR: return "Cancelado"
        case .tr: return "Iptal edildi"
        case .ru: return "Отменено"
        case .es: return "Cancelado"
        case .sk: return "Zrušené"
        case .de: return "Abgebrochen"
        case .fr: return "Annulé"
        case .it: return "Annullato"
        case .ja: return "キャンセルしました"
        case .ko: return "취소됨"
        case .uk: return "Скасовано"
        case .zhHans: return "已取消"
        case .zhTW, .zhHK: return "已取消"
        }
    }
}
