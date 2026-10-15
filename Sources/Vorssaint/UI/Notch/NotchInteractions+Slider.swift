// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

private typealias Metrics = NotchInteractionMetrics

/// The level class, a horizontal slider for volume, brightness, keyboard
/// light and the playback position. Grab the knob and it follows 1:1 from
/// where it was grabbed; click the track and it jumps there first. Past
/// either end the track stretches against a rubber band and settles back on
/// release. Near a detent the value lands on it, with a small knob pulse and
/// a trackpad tick on the same frame. The value label fades in while
/// dragging, arrows step from the keyboard, and VoiceOver adjusts it like a
/// native slider. Only the gesture changes its state: no timers.
struct NotchSlider: View {
    @Binding var value: Double
    let label: String
    var range: ClosedRange<Double>
    var detents: [Double]
    /// One arrow press, as a share of the range.
    var step: Double
    var tint: Color
    /// Shown while dragging and read by VoiceOver; a percentage by default.
    var valueText: String?
    var onEditingChanged: ((Bool) -> Void)?

    @State private var dragging = false
    /// Where on the knob it was grabbed, so it never jumps under the pointer.
    @State private var grab: CGFloat = 0
    @State private var overshoot: CGFloat = 0
    @State private var detentTracker = NotchDetentTracker(detents: [])
    @State private var ticks = 0
    @State private var editing = NotchSliderEditing()
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchInteractionPreview) private var preview

    init(value: Binding<Double>, label: String, range: ClosedRange<Double> = 0...1, detents: [Double] = [],
         step: Double = NotchInteractionMetrics.sliderStep, tint: Color = .white, valueText: String? = nil,
         onEditingChanged: ((Bool) -> Void)? = nil) {
        _value = value
        self.label = label
        self.range = range.lowerBound < range.upperBound ? range : range.lowerBound...(range.lowerBound + 1)
        self.detents = detents
        self.step = step
        self.tint = tint
        self.valueText = valueText
        self.onEditingChanged = onEditingChanged
    }

    private var fraction: Double {
        let clamped = NotchInteractionMath.clamp(value, to: range)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var spokenValue: String { valueText ?? "\(Int((fraction * 100).rounded()))%" }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knob = Metrics.sliderKnob
            let travel = max(0, width - knob)
            let center = knob / 2 + travel * fraction + overshoot
            let showsValue = dragging || preview == .pressed
            ZStack(alignment: .leading) {
                NotchSliderTrack(fraction: fraction, tint: tint, enabled: enabled, knob: knob)
                    .frame(height: Metrics.sliderTrack)
                    // Stretches from the far end, so the end being pulled is the one that gives.
                    .scaleEffect(x: 1 + abs(overshoot) / max(1, width), y: 1,
                                 anchor: overshoot < 0 ? .trailing : .leading)
                Circle()
                    .fill(.white.opacity(enabled ? 1 : 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                    .frame(width: knob, height: knob)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: ticks) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(Metrics.detentPulse, duration: 0.07, spring: Spring(duration: 0.07, bounce: 0))
                        SpringKeyframe(1, duration: 0.2, spring: Spring(duration: 0.2, bounce: 0))
                    }
                    .offset(x: center - knob / 2)
                Text(spokenValue)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize()
                    .opacity(showsValue ? 1 : 0)
                    .animation(Metrics.valueFade, value: showsValue)
                    .position(x: center, y: proxy.size.height / 2 - knob - 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(drag(knob: knob, width: width, center: center - overshoot), including: enabled ? .all : .none)
        }
        .frame(height: Metrics.minimumTarget)
        .focusable(interactions: .activate)
        .focused($focused)
        .focusEffectDisabled()
        .notchFocusRing(.capsule, visible: focused)
        .onMoveCommand { direction in
            switch direction {
            case .left, .down: nudge(-1)
            case .right, .up: nudge(1)
            @unknown default: break
            }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(1)
            case .decrement: nudge(-1)
            @unknown default: break
            }
        }
    }

    private func drag(knob: CGFloat, width: CGFloat, center: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !dragging {
                    dragging = true
                    let offset = gesture.startLocation.x - center
                    grab = abs(offset) <= knob / 2 + 4 ? offset : 0
                    detentTracker = NotchDetentTracker(detents: detents)
                    detentTracker.begin(at: value)
                    editing.trackingChanged(true, onEditingChanged: onEditingChanged)
                }
                let x = gesture.location.x - grab
                let start = knob / 2
                let end = max(start, width - knob / 2)
                let next = NotchInteractionMath.snapped(
                    NotchInteractionMath.clamp(
                        NotchInteractionMath.trackValue(at: x, start: start, end: end, range: range), to: range),
                    to: detents, within: Metrics.detentSnap * (range.upperBound - range.lowerBound))
                if next != value { value = next }
                if detentTracker.move(to: next) != nil {
                    NotchHaptics.tick()
                    if !reduceMotion { ticks &+= 1 }
                }
                guard !reduceMotion else { return }
                let past = NotchInteractionMath.trackOvershoot(at: x, start: start, end: end)
                let stretched = CGFloat(NotchInteractionMath.rubberband(
                    past, dimension: Metrics.sliderStretch, constant: Metrics.rubberbandConstant))
                if stretched != overshoot { overshoot = stretched }
            }
            .onEnded { _ in
                dragging = false
                editing.trackingChanged(false, onEditingChanged: onEditingChanged)
                if overshoot != 0 { withAnimation(Metrics.sliderSettle) { overshoot = 0 } }
            }
    }

    /// An arrow or VoiceOver step: a complete edit, with no motion.
    private func nudge(_ direction: Int) {
        guard enabled else { return }
        let next = NotchInteractionMath.stepped(value, step: step, direction: direction, range: range)
        guard next != value else { return }
        editing.valueChanged({ value = next }, onEditingChanged: onEditingChanged)
    }
}

/// The track and its fill, drawn in the same language as `NotchMeter`.
private struct NotchSliderTrack: View {
    let fraction: Double
    let tint: Color
    let enabled: Bool
    let knob: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let fill = knob / 2 + max(0, proxy.size.width - knob) * fraction
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(.white.opacity(Metrics.trackFill))
                Capsule(style: .continuous)
                    .fill(tint.opacity(enabled ? 0.92 : 0.3))
                    .frame(width: max(proxy.size.height, fill))
            }
        }
    }
}
