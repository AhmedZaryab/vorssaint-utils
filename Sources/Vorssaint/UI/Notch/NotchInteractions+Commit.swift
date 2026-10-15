// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

private typealias Metrics = NotchInteractionMetrics

/// Which way a commit's glyph kicks when it fires, matching what it does.
enum NotchCommitKick: Equatable {
    /// Out to the trailing side while a copy slides in behind it: next track.
    case forward
    /// The mirror of `forward`: previous track.
    case backward
    /// Up and away while a copy rises into the seat: AirPlay, join, start.
    case up
    /// Stays put while the caller's symbol morphs, as play turning into pause.
    case morph

    var direction: CGVector {
        switch self {
        case .forward: CGVector(dx: 1, dy: 0)
        case .backward: CGVector(dx: -1, dy: 0)
        case .up: CGVector(dx: 0, dy: -1)
        case .morph: CGVector(dx: 0, dy: 0)
        }
    }
}

/// The commit class: play, skip, like, send to AirPlay, join, start. A tap
/// fires at once and launches: the glyph kicks the way the action goes and a
/// few particles leave the rim. With `dragToFire` it can also be pulled from
/// its seat against a stretching band; let go past the arm point and it
/// snaps back through with a stronger burst, let go inside and nothing
/// happens. A plain click and Return always fire; the gesture is never
/// required. Space and Return fire with no motion at all. For play and pause,
/// pass `launches: !isPlaying` so only play launches and pause just morphs.
struct NotchCommitButton: View {
    let title: String
    let symbol: String
    var kick: NotchCommitKick
    var hint: String?
    var dragToFire: Bool
    var size: CGFloat
    /// Nil sizes the glyph from the control's side; callers name Icon.button, Icon.transport or Icon.transportPrimary.
    var glyph: NotchDesign.TypeStyle?
    /// Source compatible point size for callers that have not moved to `glyph`.
    var symbolSize: CGFloat?
    var filled: Bool
    /// Off, a pointer fire only morphs the symbol: no kick, no burst.
    var launches: Bool
    /// The glyph and its particles: white, or the music tint.
    var tint: Color
    /// The burst's particles; nil keeps them the glyph's colour. Music passes the cover colour here only.
    var burstTint: Color?
    /// Fires from anywhere in the window, as Space does for play and pause.
    var keyboardShortcut: KeyboardShortcut?
    let action: () -> Void

    @State private var held = false
    /// The pointer is still within reach of the control; leaving it shows the cancel at once.
    @State private var inside = true
    @State private var armed = false
    @State private var pull = CGSize.zero
    @State private var sling = NotchSlingTracker(armAt: Metrics.slingArm, limit: Metrics.slingLimit,
                                                 slop: Metrics.slingSlop)
    @State private var presented = NotchPresentedPull()
    @State private var kicks = 0
    @State private var burst: NotchBurst?
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchInteractionPreview) private var preview

    init(_ title: String, symbol: String, kick: NotchCommitKick = .morph, hint: String? = nil,
         dragToFire: Bool = false, size: CGFloat = Metrics.commitSide, glyph: NotchDesign.TypeStyle? = nil,
         symbolSize: CGFloat? = nil, filled: Bool = false,
         launches: Bool = true, tint: Color = .white, burstTint: Color? = nil, keyboardShortcut: KeyboardShortcut? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.kick = kick
        self.hint = hint
        self.dragToFire = dragToFire
        self.size = size
        self.glyph = glyph
        self.symbolSize = symbolSize
        self.filled = filled
        self.launches = launches
        self.tint = tint
        self.burstTint = burstTint
        self.keyboardShortcut = keyboardShortcut
        self.action = action
    }

    private var side: CGFloat { max(size, Metrics.minimumTarget) }
    private var glyphFont: Font {
        glyph?.font ?? .system(size: symbolSize ?? (side * 0.45).rounded(), weight: NotchDesign.Weight.semibold.font)
    }
    /// How far the pointer may stray from the control before a release cancels.
    private var reach: CGFloat { side / 2 + Metrics.pressCancelMargin }
    /// Reduce Motion keeps the gesture a plain press: no band, no flight.
    private var slings: Bool { dragToFire && !reduceMotion }

    var body: some View {
        let frozen = preview == .armed && dragToFire
        let shownPull = frozen ? CGSize(width: -Metrics.slingArm - 4, height: 10) : pull
        let shownArmed = frozen || armed
        ZStack {
            if slings || frozen {
                NotchSlingWell(pull: shownPull, armed: shownArmed, side: side)
            }
            NotchPressFace(pressed: (held && (slings || inside)) || frozen, shape: .capsule) {
                NotchCommitGlyph(symbol: symbol, kick: kick, font: glyphFont,
                                 side: side, tint: tint, kicks: kicks, reduceMotion: reduceMotion)
                    .frame(width: side, height: side)
                    .background(.white.opacity(filled ? Metrics.restingFill : 0), in: Circle())
            }
            .scaleEffect(shownArmed && !reduceMotion ? Metrics.armedScale : 1)
            .animation(Metrics.pressIn, value: shownArmed)
            .modifier(NotchPresentedOffset(pull: shownPull, probe: presented))
            if let burst {
                NotchBurstView(burst: burst, side: side, tint: burstTint ?? tint).allowsHitTesting(false)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .gesture(press)
        .focusable(interactions: .activate)
        .focused($focused)
        .focusEffectDisabled()
        .notchFocusRing(.capsule, visible: focused)
        .onKeyPress(keys: [.space, .return], phases: .down) { _ in
            fire(.keyboard)
            return .handled
        }
        .background { shortcutButton }
        .task(id: burst) {
            guard let burst else { return }
            let left = burst.start.timeIntervalSinceNow + burst.duration
            try? await Task.sleep(for: .seconds(max(0, left)))
            if !Task.isCancelled { self.burst = nil }
        }
        .help(title)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire(.keyboard) }
    }

    @ViewBuilder private var shortcutButton: some View {
        if let keyboardShortcut {
            Button("") { fire(.keyboard) }
                .keyboardShortcut(keyboardShortcut)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard enabled else { return }
                if !held {
                    held = true
                    inside = true
                    sling.begin(presentedX: presented.pull.width, y: presented.pull.height)
                }
                guard slings else {
                    let within = hypot(value.translation.width, value.translation.height) <= reach
                    if within != inside { inside = within }
                    return
                }
                let next = sling.pull(dx: value.translation.width, dy: value.translation.height)
                if sling.armed != armed {
                    armed = sling.armed
                    if armed { NotchHaptics.tick() }
                }
                withAnimation(Metrics.slingTrack) { pull = CGSize(width: next.x, height: next.y) }
            }
            .onEnded { value in
                guard held else { return }
                held = false
                inside = true
                armed = false
                let outcome: NotchSlingTracker.Release
                if slings {
                    outcome = sling.release()
                } else {
                    outcome = hypot(value.translation.width, value.translation.height) <= reach ? .tap : .cancel
                }
                switch outcome {
                case .tap: fire(.pointer)
                case .fire: fire(.sling)
                case .cancel: break
                }
                if slings { recoil(velocity: value.velocity, fired: outcome == .fire) }
            }
    }

    private enum Source { case pointer, sling, keyboard }

    private func fire(_ source: Source) {
        guard enabled else { return }
        action()
        // A keyboard action repeats too often to animate; Reduce Motion
        // keeps only the symbol's own crossfade.
        guard source != .keyboard, !reduceMotion, launches || source == .sling else { return }
        kicks &+= 1
        let slung = source == .sling
        let away = hypot(pull.width, pull.height)
        let direction = slung && away > 0.5
            ? CGVector(dx: -pull.width / away, dy: -pull.height / away) : kick.direction
        burst = NotchBurst(start: Date().addingTimeInterval(slung ? Metrics.slingBurstDelay : 0),
                           duration: slung ? Metrics.slingBurst : Metrics.tapBurst,
                           count: slung ? Metrics.slingParticles : Metrics.tapParticles,
                           reach: Metrics.burstReach * (slung ? 1.5 : 1),
                           direction: direction, seed: kicks)
    }

    /// Back to the seat from wherever the control is, carrying the pointer's
    /// velocity along the pull so the release has no seam. A fired sling
    /// snaps through the seat; a cancelled one only settles.
    private func recoil(velocity: CGSize, fired: Bool) {
        let away = hypot(pull.width, pull.height)
        guard away > 0.5 else {
            pull = .zero
            return
        }
        let outward = (velocity.width * pull.width + velocity.height * pull.height) / away
        let kick = fired ? Metrics.slingFireKick : Metrics.slingCancelKick
        let toward = min(Metrics.slingMaxKick, max(-Metrics.slingMaxKick, kick - outward / away))
        withAnimation(.interpolatingSpring(Metrics.slingRecoil, initialVelocity: toward)) { pull = .zero }
    }
}

/// What a burst throws, decided when it fires so every frame draws the same.
struct NotchBurst: Equatable {
    let start: Date
    let duration: TimeInterval
    let count: Int
    let reach: CGFloat
    /// Zero throws the particles all around the rim.
    let direction: CGVector
    let seed: Int
}

/// Particles on an additive layer. The timeline exists only while a burst is
/// live, so an idle button costs nothing.
private struct NotchBurstView: View {
    let burst: NotchBurst
    let side: CGFloat
    let tint: Color

    var body: some View {
        let canvas = side + 2 * burst.reach + 2 * Metrics.particleSize
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let progress = timeline.date.timeIntervalSince(burst.start) / max(0.01, burst.duration)
                guard progress >= 0, progress < 1 else { return }
                context.blendMode = .plusLighter
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let rim = side * 0.4
                for index in 0..<burst.count {
                    let particle = NotchInteractionMath.particle(index, of: burst.count, seed: burst.seed,
                                                                directionX: burst.direction.dx,
                                                                directionY: burst.direction.dy,
                                                                spreadDegrees: Metrics.burstSpread, progress: progress)
                    let length = hypot(particle.x, particle.y)
                    let unitX = length > 0 ? particle.x / length : 0
                    let unitY = length > 0 ? particle.y / length : 0
                    let x = center.x + unitX * rim + particle.x * burst.reach
                    let y = center.y + unitY * rim + particle.y * burst.reach
                    let radius = Metrics.particleSize * particle.size / 2
                    context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius)),
                                 with: .color(tint.opacity(0.9 * particle.opacity)))
                }
            }
        }
        .frame(width: canvas, height: canvas)
        .accessibilityHidden(true)
    }
}

/// The seat a pulled commit leaves and the band stretched back to it.
private struct NotchSlingWell: View {
    let pull: CGSize
    let armed: Bool
    let side: CGFloat

    var body: some View {
        let tension = min(1, hypot(pull.width, pull.height) / 6)
        ZStack {
            Circle().fill(.white.opacity(0.06 * tension))
            NotchSlingBand(pull: pull, seat: side / 2, pad: side / 2 - 1)
                .stroke(.white.opacity(armed ? 0.55 : 0.22),
                        style: StrokeStyle(lineWidth: armed ? 2.25 : 1.5, lineCap: .round))
                .opacity(tension)
        }
        .animation(Metrics.pressIn, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Two lines tangent to the seat and to the pulled control.
private struct NotchSlingBand: Shape {
    var pull: CGSize
    let seat: CGFloat
    let pad: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pull.width, pull.height) }
        set { pull = CGSize(width: newValue.first, height: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let distance = hypot(pull.width, pull.height)
        guard distance > 0.5 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let heading = atan2(pull.height, pull.width)
        let spread = acos(min(1, max(-1, (seat - pad) / distance)))
        for angle in [heading + spread, heading - spread] {
            path.move(to: CGPoint(x: center.x + seat * cos(angle), y: center.y + seat * sin(angle)))
            path.addLine(to: CGPoint(x: center.x + pull.width + pad * cos(angle),
                                     y: center.y + pull.height + pad * sin(angle)))
        }
        return path
    }
}

/// The pull on screen this frame, kept outside SwiftUI's state so reading it
/// never redraws anything.
final class NotchPresentedPull {
    var pull = CGSize.zero
}

/// Offsets the control by its animated pull and remembers the value drawn,
/// so a grab mid flight takes over from there instead of jumping.
private struct NotchPresentedOffset: ViewModifier, Animatable {
    var pull: CGSize
    let probe: NotchPresentedPull

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pull.width, pull.height) }
        set { pull = CGSize(width: newValue.first, height: newValue.second) }
    }

    func body(content: Content) -> some View {
        probe.pull = pull
        return content.offset(pull)
    }
}

/// The glyph that kicks: the outgoing copy leaves the way the action goes
/// while an incoming one takes the seat, so it reads as a step, not a jump.
/// `kicks` drives a spring on state: each press moves a conveyor one place
/// on, and a press during a flight retargets it from where it is drawn.
private struct NotchCommitGlyph: View {
    let symbol: String
    let kick: NotchCommitKick
    let font: Font
    let side: CGFloat
    let tint: Color
    let kicks: Int
    let reduceMotion: Bool
    @State private var place = 0.0

    var body: some View {
        if kick == .morph {
            glyph
                .notchSymbolReplace(reduceMotion: reduceMotion)
                .animation(reduceMotion ? Metrics.crossfade : Metrics.symbolMorph, value: symbol)
                .symbolEffect(.bounce, value: kicks)
        } else {
            NotchKickConveyor(place: place, symbol: symbol, font: font, tint: tint,
                              dx: kick.direction.dx * side * Metrics.kickTravel,
                              dy: kick.direction.dy * side * Metrics.kickTravel)
                .onChange(of: kicks) { withAnimation(Metrics.kickSpring) { place = Double(kicks) } }
        }
    }

    private var glyph: some View {
        Image(systemName: symbol).font(font).foregroundStyle(tint)
    }
}

/// Copies of one glyph on a conveyor: the whole part of `place` is the copy
/// at the seat, the fraction is how far it has left and the next has arrived.
/// Both are the same symbol, so crossing a whole number never shows a seam.
private struct NotchKickConveyor: View, Animatable {
    var place: Double
    let symbol: String
    let font: Font
    let tint: Color
    let dx: CGFloat
    let dy: CGFloat

    var animatableData: Double {
        get { place }
        set { place = newValue }
    }

    var body: some View {
        let progress = CGFloat(place - place.rounded(.down))
        ZStack {
            Image(systemName: symbol).font(font).foregroundStyle(tint)
                .offset(x: dx * progress, y: dy * progress).opacity(1 - progress)
            if progress > 0 {
                Image(systemName: symbol).font(font).foregroundStyle(tint)
                    .offset(x: -dx * (1 - progress), y: -dy * (1 - progress)).opacity(progress)
            }
        }
    }
}
