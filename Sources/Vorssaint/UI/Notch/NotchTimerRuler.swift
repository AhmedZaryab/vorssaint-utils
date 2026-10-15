// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A native slider with a centered ruler, including mouse dragging on desktop.
struct NotchTimerRuler: NSViewRepresentable {
    @Binding var minutes: Int
    let label: String
    let locale: Locale

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NotchTimerRulerControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: proposal.height ?? NotchLayout.timerRulerHeight)
    }

    func makeNSView(context: Context) -> NotchTimerRulerControl {
        let control = NotchTimerRulerControl()
        control.focusRingType = .none
        control.minValue = 1
        control.maxValue = 180
        control.altIncrementValue = 1
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        return control
    }

    func updateNSView(_ control: NotchTimerRulerControl, context: Context) {
        context.coordinator.parent = self
        control.durationLocale = locale
        control.synchronize(minutes: minutes)
        control.isEnabled = context.environment.isEnabled
        control.increasedContrast = context.environment.colorSchemeContrast == .increased
        control.setAccessibilityLabel(label)
        control.setAccessibilityValueDescription(NotchTimerSupport.compactText(Double(minutes) * 60, locale: locale))
        control.needsDisplay = true
    }

    final class Coordinator: NSObject {
        var parent: NotchTimerRuler
        init(_ parent: NotchTimerRuler) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            guard parent.minutes != sender.integerValue else { return }
            parent.minutes = sender.integerValue
            NotchHaptics.tick()
        }
    }
}

final class NotchTimerRulerControl: NSSlider {
    private typealias Design = NotchDesign
    private static let spacing = NotchTimerRulerScale.spacing
    /// How far a flick carries after release: the velocity projected over a short, fixed coast.
    private static let coast = Design.Interaction.rulerCoast

    var increasedContrast = false
    var durationLocale = Locale.current
    /// The drag as it is: the pointer's x, the raw (unclamped) value under it and the velocity in minutes per second.
    private var drag: (x: CGFloat, raw: Double, time: TimeInterval, velocity: Double)?
    private var didDrag = false
    private var showsKeyboardFocus = false
    private var scrollValue: Double?
    /// What the ruler draws: continuous, so a drag moves the ticks 1:1 with the pointer.
    /// Past either end it sits a little beyond the range, the rubberband.
    private var position = 1.0
    private var spring: (link: CADisplayLink, start: TimeInterval, from: Double, target: Double, velocity: Double)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { isEnabled }

    deinit { spring?.link.invalidate() }

    func synchronize(minutes: Int) {
        let bounded = NotchTimerRulerScale.minute(Double(minutes))
        guard integerValue != bounded else { return }
        integerValue = bounded
        drag = nil
        scrollValue = nil
        stopSettling()
        position = Double(bounded)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopSettling(); position = Double(integerValue) }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        showsKeyboardFocus = false
        needsDisplay = true
        stopSettling()
        drag = (convert(event.locationInWindow, from: nil).x, position, event.timestamp, 0)
        scrollValue = nil
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, let previous = drag else { return }
        let x = convert(event.locationInWindow, from: nil).x
        let raw = previous.raw - Double(x - previous.x) / Self.spacing
        let elapsed = max(0.001, event.timestamp - previous.time)
        let instant = (raw - previous.raw) / elapsed
        drag = (x, raw, event.timestamp, previous.velocity * Design.Interaction.rulerVelocityCarry + instant * (1 - Design.Interaction.rulerVelocityCarry))
        didDrag = true
        position = stretched(raw)
        select(raw)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, let finished = drag else { drag = nil; return }
        drag = nil
        if didDrag {
            // A flick that sat still before release carries nothing.
            let stale = event.timestamp - finished.time > Design.Interaction.rulerStale
            release(from: finished.raw, velocity: stale ? 0 : finished.velocity)
        } else {
            let offset = convert(event.locationInWindow, from: nil).x - bounds.midX
            settle(to: Double(NotchTimerRulerScale.minute(position + Double(offset) / Self.spacing)), velocity: 0)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled, drag == nil else { return }
        stopSettling()
        if event.phase.contains(.began) { scrollValue = nil }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        let points = Double(delta) * (event.hasPreciseScrollingDeltas ? 1 : Self.spacing)
        let value = NotchTimerRulerScale.moving(scrollValue ?? position, by: points)
        scrollValue = value
        position = value
        select(value)
        needsDisplay = true
        if !event.hasPreciseScrollingDeltas || event.phase.contains(.ended) || event.phase.contains(.cancelled)
            || event.momentumPhase.contains(.ended) {
            scrollValue = nil
            settle(to: Double(NotchTimerRulerScale.minute(value)), velocity: 0)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled, event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        scrollValue = nil
        showsKeyboardFocus = true
        needsDisplay = true
        switch event.keyCode {
        case 123, 125: jump(to: position - 1)
        case 124, 126: jump(to: position + 1)
        case 115: jump(to: minValue)
        case 119: jump(to: maxValue)
        default: super.keyDown(with: event)
        }
    }

    override func setAccessibilityValue(_ value: Any?) {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else { return }
        scrollValue = nil
        jump(to: number.doubleValue)
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        scrollValue = nil
        jump(to: position + 1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        scrollValue = nil
        jump(to: position - 1)
        return true
    }

    /// Keyboard and accessibility steps land at once: nothing animates on them.
    private func jump(to value: Double) {
        stopSettling()
        let minute = NotchTimerRulerScale.minute(value)
        position = Double(minute)
        select(Double(minute))
        needsDisplay = true
    }

    private func select(_ value: Double) {
        guard isEnabled else { return }
        let minute = NotchTimerRulerScale.minute(value)
        guard integerValue != minute else { return }
        integerValue = minute
        setAccessibilityValueDescription(NotchTimerSupport.compactText(Double(minute) * 60, locale: durationLocale))
        needsDisplay = true
        sendAction(action, to: target)
    }

    /// The raw value as drawn: inside the range as it is, past an end resisted by the rubberband.
    private func stretched(_ raw: Double) -> Double {
        let low = minValue, high = maxValue
        if raw >= low && raw <= high { return raw }
        let past = raw < low ? low - raw : raw - high
        let points = Double(Design.Interaction.rubberbanded(CGFloat(past * Self.spacing), dimension: max(1, bounds.width)))
        return raw < low ? low - points / Self.spacing : high + points / Self.spacing
    }

    /// On release the flick is projected, and the ruler settles on the nearest whole minute.
    private func release(from raw: Double, velocity: Double) {
        let outside = raw < minValue || raw > maxValue
        let projected = outside ? raw : raw + velocity * Self.coast
        let target = Double(NotchTimerRulerScale.minute(projected))
        let toward = (target - position) * velocity > 0
        settle(to: target, velocity: outside || !toward ? 0 : velocity)
    }

    /// A critically damped spring on Motion.snappy from where the ruler is to the minute,
    /// carrying the pointer's velocity in. Reduce Motion lands at once. Each whole minute it
    /// passes is selected, so the haptic ticks follow the ticks going by.
    private func settle(to target: Double, velocity: Double) {
        stopSettling()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || abs(position - target) < 0.001 {
            position = target
            select(target)
            needsDisplay = true
            return
        }
        // The display link ticks on vsync and stops with the settle, so a 60 Hz panel redraws 60 times.
        let link = displayLink(target: self, selector: #selector(stepSettle))
        link.add(to: .main, forMode: .common)
        spring = (link, ProcessInfo.processInfo.systemUptime, position, target, velocity)
    }

    @objc private func stepSettle() {
        guard let spring else { return }
        let omega = 2 * Double.pi / Design.Motion.snappy.response
        let t = ProcessInfo.processInfo.systemUptime - spring.start
        let offset = spring.from - spring.target
        let carried = spring.velocity + omega * offset
        position = spring.target + (offset + carried * t) * exp(-omega * t)
        select(position)
        if t > Design.Interaction.rulerSettleCap || abs(position - spring.target) < 0.002 {
            position = spring.target
            select(spring.target)
            stopSettling()
        }
        needsDisplay = true
    }

    private func stopSettling() {
        spring?.link.invalidate()
        spring = nil
    }

    /// Tick weights: a whole minute is short, a five is taller and carries its number.
    /// Ticks up to the chosen minute are the accent, the rest a quiet white, and the
    /// pointer is a white line, so the chosen value reads at a glance.
    override func draw(_ dirtyRect: NSRect) {
        typealias Design = NotchDesign
        let edgeFade = max(1, bounds.width * 0.12)
        // Drawn for the full ruler height; a shorter island compresses the
        // ticks and pointer below the labels instead of cutting them off.
        let scale = bounds.height / NotchLayout.timerRulerHeight
        let accent = NSColor.controlAccentColor
        let rest = NSColor(Design.Fill.track)
        let labelFont = NSFont.monospacedDigitSystemFont(ofSize: Design.Typography.caption.nsFont.pointSize,
                                                         weight: Design.Weight.medium.appKit)
        let enabledAlpha: CGFloat = isEnabled ? 1 : Design.Opacity.disabled
        let baseline = 66 * scale
        for minute in 1...180 {
            let x = bounds.midX + CGFloat((Double(minute) - position) * Self.spacing)
            guard x >= bounds.minX - 16, x <= bounds.maxX + 16 else { continue }
            let fade = min(1, max(0, min(x - bounds.minX, bounds.maxX - x) / edgeFade))
            let chosen = minute <= integerValue
            let major = minute.isMultiple(of: 5) || minute == 1
            let height = (major ? 34 : 20) * scale
            let color = (chosen ? accent : (increasedContrast ? NSColor(Design.Ink.secondary) : rest))
                .withAlphaComponent((chosen ? 1 : increasedContrast ? 0.75 : 1) * fade * enabledAlpha)
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 0.75, y: baseline - height, width: 1.5, height: height),
                         xRadius: 0.75, yRadius: 0.75).fill()
            if major {
                let near = minute == integerValue
                let title = NSAttributedString(string: NotchTimerRulerScale.label(for: minute), attributes: [
                    .font: labelFont,
                    .foregroundColor: NSColor.white.withAlphaComponent(
                        (near ? 1 : Design.Opacity.secondary) * fade * enabledAlpha)
                ])
                title.draw(at: NSPoint(x: x - title.size().width / 2, y: 0))
            }
        }
        let pointer = NSBezierPath(roundedRect: NSRect(x: bounds.midX - 1, y: 22 * scale, width: 2, height: 50 * scale),
                                   xRadius: 1, yRadius: 1)
        NSColor.white.withAlphaComponent(enabledAlpha).setFill()
        pointer.fill()
        if window?.firstResponder === self, showsKeyboardFocus {
            NSColor(NotchInteractionMetrics.focusRingInk).setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                     xRadius: Design.Radius.control, yRadius: Design.Radius.control)
            focus.lineWidth = NotchInteractionMetrics.focusRingWidth
            focus.stroke()
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        showsKeyboardFocus = accepted
        needsDisplay = true
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        needsDisplay = true
        return accepted
    }
}

extension NotchDesign.Interaction {
    /// The ruler's settle tuning, named once: coast seconds a flick carries, the pause after which a drag is stale,
    /// the share of the old velocity kept in the blend, and the longest a settle may run.
    static let rulerCoast = 0.1
    static let rulerStale = 0.08
    static let rulerVelocityCarry = 0.6
    static let rulerSettleCap = 0.6
}
