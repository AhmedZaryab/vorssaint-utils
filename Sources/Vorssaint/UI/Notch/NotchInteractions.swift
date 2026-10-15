// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The island's interaction library. Feedback matches consequence: a tap
/// settles, a toggle pulses as its symbol morphs, a commit launches, and a
/// destructive action lights a fuse you can blow out.
///
/// Every number the library moves by lives here so the design tokens can
/// replace them without touching a control. A press lands on mouse down with
/// a strong ease out and comes back on a critically damped spring; only
/// motion that carries momentum (a sling let go, a slider dragged past its
/// end) is allowed a small bounce. Hover is a wash, never a lift: macOS
/// highlights under the pointer. Reduce Motion turns every movement into
/// `crossfade`.
enum NotchInteractionMetrics {
    private typealias Design = NotchDesign

    static let cornerRadius: CGFloat = Design.Radius.control
    /// The smallest hit target any control offers, whatever it draws.
    static let minimumTarget: CGFloat = Design.Control.minimumHit
    static let focusRingWidth: CGFloat = 1.5
    static let focusRingGap: CGFloat = 2.5
    static let focusRingOpacity = 0.75

    // Fills, white on the dark island; the amounts of Design.Fill.
    static let hoverWash = 0.08
    static let pressWash = 0.13
    static let restingFill = 0.10
    /// Also the wash a press deepens to under Reduce Motion, in place of the scale.
    static let selectedFill = 0.16
    static let trackFill = 0.16
    static let idleGlyph = 0.55
    static let disabledOpacity = Design.Opacity.disabled
    /// A toggle that is on, and a fuse's Undo.
    static let accent = Design.Palette.accent

    // Press: lands on mouse down, returns without overshoot; both retarget
    // from what is on screen, so a press during a release never restarts.
    static let pressScale: CGFloat = Design.Interaction.pressScale
    static let pressDuration: TimeInterval = Design.Interaction.pressDuration
    static let pressIn = Design.Motion.easeOut(pressDuration)
    /// Quick, no overshoot: a release, a toggle's plate, a slider settling.
    static let snappy = Design.Motion.snappy.animation
    /// Only after momentum or a commit: a launch, a success landing.
    static let bouncy = Spring(response: Design.Motion.bouncy.response,
                               dampingRatio: Design.Motion.bouncy.dampingFraction)
    static let release = snappy
    static let hover = Animation.easeOut(duration: 0.15)
    static let crossfade = Design.Motion.fade
    /// Apple's rubber band constant, shared by every edge that resists.
    static let rubberbandConstant = Double(Design.Interaction.rubberband)

    // Toggle.
    static let togglePulse: CGFloat = 1.06
    static let toggleFill = snappy
    static let symbolMorph = Animation.spring(duration: 0.25, bounce: 0)

    // Commit.
    static let kickDuration = 0.3
    /// How far the glyph kicks, as a share of the control's side.
    static let kickTravel: CGFloat = 0.34
    static let tapBurst: TimeInterval = Design.Interaction.burstDuration
    static let tapParticles = Design.Interaction.burstParticleCount
    /// A sling is rarer and earned, so its burst is stronger and a little longer.
    static let slingBurst: TimeInterval = 0.35
    static let slingParticles = 10
    /// How far particles fly past the rim, in points; a sling throws them half again as far.
    static let burstReach: CGFloat = Design.Interaction.burstReach
    static let burstSpread = Design.Interaction.burstSpread
    static let particleSize: CGFloat = Design.Interaction.burstParticleSize
    static let slingArm: CGFloat = 26
    static let slingLimit: CGFloat = 64
    static let slingSlop: CGFloat = Design.Interaction.dragThreshold
    static let armedScale: CGFloat = Design.Interaction.armedScale
    /// Follows the pointer almost exactly, and retargets from wherever the
    /// control is drawn so a grab mid flight never jumps.
    static let slingTrack = Animation.interactiveSpring(response: 0.1, dampingFraction: 0.9)
    static let slingRecoil = Spring(duration: 0.38, bounce: 0.24)
    /// Release velocities toward the seat, in pull lengths per second.
    static let slingFireKick = 6.0
    static let slingCancelKick = 1.5
    static let slingMaxKick = 14.0
    /// The burst leaves as the control snaps back through its seat.
    static let slingBurstDelay: TimeInterval = 0.06
    /// A press dragged further than this past the rim no longer fires.
    static let pressCancelMargin: CGFloat = 10

    // Fuse: a slow linear burn while you decide, a fast blow out.
    static let fuseDuration: TimeInterval = Design.Interaction.fuseDuration
    static let fuseLine: CGFloat = Design.Interaction.fuseLineWidth
    static let fuseSpark: CGFloat = 2
    static let fuseTint = Design.Palette.warning
    static let fuseFace = Animation.easeOut(duration: 0.2)
    static let blurBridge: CGFloat = 2

    // Slider.
    static let sliderTrack: CGFloat = Design.Control.sliderTrack
    static let sliderKnob: CGFloat = 14
    static let sliderStep = 0.05
    /// The furthest a track stretches when dragged past an end.
    static let sliderStretch: CGFloat = Design.Interaction.rubberbandLimit
    /// A value this close to a detent, as a share of the range, lands on it.
    static let detentSnap = Design.Interaction.detentSnap
    static let detentHaptic = Design.Interaction.detentHaptic
    static let detentPulse: CGFloat = 1.22
    static let sliderSettle = snappy
    static let valueFade = Animation.easeOut(duration: 0.15)

    // Success.
    static let successHold: TimeInterval = Design.Interaction.successMorphDuration
    static let successMorph = Animation.spring(bouncy)
    static let successFrom: CGFloat = 0.8
}

private typealias Metrics = NotchInteractionMetrics

/// The outline a control presses, washes, burns and focuses along.
enum NotchPressShape: Shape {
    case capsule
    /// A rounded rectangle with continuous corners.
    case rounded(CGFloat)

    func path(in rect: CGRect) -> Path {
        switch self {
        case .capsule: Capsule(style: .continuous).path(in: rect)
        case .rounded(let radius): RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        }
    }
}

/// A state the development gallery freezes a control in. Nil, the default,
/// leaves every control live.
enum NotchInteractionPreview: Equatable {
    case hover
    case pressed
    case armed
    case burning(Double)
    case success
}

private struct NotchInteractionPreviewKey: EnvironmentKey {
    static let defaultValue: NotchInteractionPreview? = nil
}

extension EnvironmentValues {
    var notchInteractionPreview: NotchInteractionPreview? {
        get { self[NotchInteractionPreviewKey.self] }
        set { self[NotchInteractionPreviewKey.self] = newValue }
    }
}

enum NotchHaptics {
    /// The trackpad's alignment tick, for a detent or an armed sling, when
    /// the island's haptic feedback is on.
    static func tick() {
        guard NotchSupport.usesHapticFeedback() else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(Metrics.detentHaptic, performanceTime: .now)
    }
}

extension View {
    /// The pointing hand over anything pressable.
    @ViewBuilder func notchPointingCursor(_ active: Bool = true) -> some View {
#if compiler(>=6.0)
        if #available(macOS 15, *) {
            pointerStyle(active ? .link : nil)
        } else {
            modifier(NotchCursorFallback(active: active))
        }
#else
        modifier(NotchCursorFallback(active: active))
#endif
    }

    /// A ring outside the control's own outline while the keyboard is on it.
    func notchFocusRing(_ shape: NotchPressShape, visible: Bool) -> some View {
        overlay {
            if visible {
                shape.stroke(.white.opacity(Metrics.focusRingOpacity), lineWidth: Metrics.focusRingWidth)
                    .padding(-Metrics.focusRingGap)
                    .allowsHitTesting(false)
            }
        }
    }

    /// One symbol replacing another: Magic Replace where the system has it,
    /// a plain replace before, and a crossfade under Reduce Motion.
    @ViewBuilder func notchSymbolReplace(reduceMotion: Bool) -> some View {
        if reduceMotion {
            contentTransition(.opacity)
        } else {
#if compiler(>=6.0)
            if #available(macOS 15, *) {
                contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
            } else {
                contentTransition(.symbolEffect(.replace))
            }
#else
            contentTransition(.symbolEffect(.replace))
#endif
        }
    }
}

/// Before macOS 15 the cursor stack is balanced by hand, so a control that
/// vanishes under the pointer never leaves the hand behind.
private struct NotchCursorFallback: ViewModifier {
    let active: Bool
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { show($0 && active) }
            .onChange(of: active) { _, active in if !active { show(false) } }
            .onDisappear { show(false) }
    }

    private func show(_ hand: Bool) {
        guard hand != pushed else { return }
        pushed = hand
        if hand { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }
}

/// The face every pressable control shares: a low wash under the pointer, a
/// settle the moment the mouse goes down and a clean return on release. A
/// commit button drives `pressed` from its own gesture.
struct NotchPressFace<Content: View>: View {
    let pressed: Bool
    var shape: NotchPressShape = .rounded(NotchInteractionMetrics.cornerRadius)
    var lifts = true
    var washes = true
    let content: Content
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchInteractionPreview) private var preview

    init(pressed: Bool, shape: NotchPressShape = .rounded(NotchInteractionMetrics.cornerRadius), lifts: Bool = true,
         washes: Bool = true, @ViewBuilder content: () -> Content) {
        self.pressed = pressed
        self.shape = shape
        self.lifts = lifts
        self.washes = washes
        self.content = content()
    }

    var body: some View {
        let hover = enabled && (hovered || preview == .hover)
        let down = enabled && (pressed || preview == .pressed)
        let moves = lifts && !reduceMotion
        content
            .frame(minWidth: Metrics.minimumTarget, minHeight: Metrics.minimumTarget)
            .background(.white.opacity(washes ? wash(down: down, hover: hover) : 0), in: shape)
            .contentShape(shape)
            .scaleEffect(moves && down ? Metrics.pressScale : 1)
            .opacity(enabled ? 1 : Metrics.disabledOpacity)
            .animation(reduceMotion ? Metrics.crossfade : down ? Metrics.pressIn : Metrics.release, value: down)
            .animation(Metrics.hover, value: hover)
            .onHover { hovered = $0 }
            .notchPointingCursor(enabled)
    }

    /// Without the scale, a press shows as a deeper wash.
    private func wash(down: Bool, hover: Bool) -> Double {
        down ? (reduceMotion ? Metrics.selectedFill : Metrics.pressWash) : hover ? Metrics.hoverWash : 0
    }
}

/// The tap class, for buttons whose result shows somewhere else: open a page,
/// a player or Finder, pick a menu, choose a folder, row actions that are not
/// destructive. Hover washes, a press settles to 0.97 on mouse down and
/// returns on release. For on and off use `NotchToggleStyle`, for an action
/// that leaves the island `NotchCommitButton`, for one that destroys
/// `NotchFuseButton`.
struct NotchPressStyle: ButtonStyle {
    var shape: NotchPressShape = .rounded(NotchInteractionMetrics.cornerRadius)
    /// Off where a press scale would crowd its neighbours, as in a list row;
    /// the wash still answers.
    var lifts = true
    /// Off where the label draws its own fill.
    var washes = true

    func makeBody(configuration: Configuration) -> some View {
        NotchPressFace(pressed: configuration.isPressed, shape: shape, lifts: lifts, washes: washes) {
            configuration.label
        }
    }
}

/// The toggle class, for on and off: shuffle, repeat, mute, keep awake, pin,
/// a filter. The symbol morphs (or bounces, when on and off share one), the
/// plate fades to the accent and the control gives one small pulse. VoiceOver
/// reads it as a native switch with its value; the Toggle's label is its name.
/// Pass the music tint as `tint` on the music page.
struct NotchToggleStyle: ToggleStyle {
    var onSymbol: String
    var offSymbol: String
    var shape: NotchPressShape = .capsule
    var size: CGFloat = 28
    var symbolSize: CGFloat = 12
    var tint: Color = NotchInteractionMetrics.accent

    init(symbol: String, shape: NotchPressShape = .capsule, size: CGFloat = 28, symbolSize: CGFloat = 12,
         tint: Color = NotchInteractionMetrics.accent) {
        self.init(on: symbol, off: symbol, shape: shape, size: size, symbolSize: symbolSize, tint: tint)
    }

    init(on: String, off: String, shape: NotchPressShape = .capsule, size: CGFloat = 28, symbolSize: CGFloat = 12,
         tint: Color = NotchInteractionMetrics.accent) {
        onSymbol = on
        offSymbol = off
        self.shape = shape
        self.size = size
        self.symbolSize = symbolSize
        self.tint = tint
    }

    func makeBody(configuration: Configuration) -> some View {
        NotchToggleFace(isOn: configuration.$isOn, onSymbol: onSymbol, offSymbol: offSymbol, shape: shape,
                        side: max(size, NotchInteractionMetrics.minimumTarget), symbolSize: symbolSize, tint: tint)
            .accessibilityRepresentation {
                // A style of its own, or this style would draw itself again.
                Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
            }
    }
}

private struct NotchToggleFace: View {
    @Binding var isOn: Bool
    let onSymbol: String
    let offSymbol: String
    let shape: NotchPressShape
    let side: CGFloat
    let symbolSize: CGFloat
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { isOn.toggle() } label: {
            glyph
                .frame(width: side, height: side)
                .background(tint.opacity(isOn ? 1 : 0), in: shape)
                .animation(reduceMotion ? Metrics.crossfade : Metrics.toggleFill, value: isOn)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: reduceMotion ? false : isOn) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(Metrics.togglePulse, duration: 0.09, spring: Spring(duration: 0.09, bounce: 0))
                    SpringKeyframe(1, duration: 0.18, spring: Spring(duration: 0.18, bounce: 0))
                }
        }
        .buttonStyle(NotchPressStyle(shape: shape))
    }

    @ViewBuilder private var glyph: some View {
        let symbol = isOn ? onSymbol : offSymbol
        let image = Image(systemName: symbol)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.white.opacity(isOn ? 1 : Metrics.idleGlyph))
        if onSymbol == offSymbol {
            image.symbolEffect(.bounce, value: reduceMotion ? false : isOn)
        } else {
            image.notchSymbolReplace(reduceMotion: reduceMotion)
                .animation(reduceMotion ? Metrics.crossfade : Metrics.symbolMorph, value: symbol)
        }
    }
}
