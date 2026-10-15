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
    var increasedContrast = false
    var durationLocale = Locale.current
    private var drag: (x: CGFloat, value: Double)?
    private var didDrag = false
    private var showsKeyboardFocus = false
    private var scrollValue: Double?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { isEnabled }

    func synchronize(minutes: Int) {
        let bounded = NotchTimerRulerScale.minute(Double(minutes))
        guard integerValue != bounded else { return }
        integerValue = bounded
        drag = nil
        scrollValue = nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        showsKeyboardFocus = false
        needsDisplay = true
        drag = (convert(event.locationInWindow, from: nil).x, doubleValue)
        scrollValue = nil
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, let previous = drag else { return }
        let x = convert(event.locationInWindow, from: nil).x
        let value = NotchTimerRulerScale.moving(previous.value, by: Double(x - previous.x))
        drag = (x, value)
        didDrag = true
        select(value)
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, drag != nil else { drag = nil; return }
        if !didDrag {
            let offset = convert(event.locationInWindow, from: nil).x - bounds.midX
            select(NotchTimerRulerScale.moving(doubleValue, by: -Double(offset)))
        }
        drag = nil
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled, drag == nil else { return }
        if event.phase.contains(.began) { scrollValue = nil }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        let points = Double(delta) * (event.hasPreciseScrollingDeltas ? 1 : NotchTimerRulerScale.spacing)
        let value = NotchTimerRulerScale.moving(scrollValue ?? doubleValue, by: points)
        scrollValue = value
        select(value)
        if !event.hasPreciseScrollingDeltas || event.phase.contains(.ended) || event.phase.contains(.cancelled)
            || event.momentumPhase.contains(.ended) { scrollValue = nil }
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled, event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        scrollValue = nil
        showsKeyboardFocus = true
        needsDisplay = true
        switch event.keyCode {
        case 123, 125: select(doubleValue - 1)
        case 124, 126: select(doubleValue + 1)
        case 115: select(minValue)
        case 119: select(maxValue)
        default: super.keyDown(with: event)
        }
    }

    override func setAccessibilityValue(_ value: Any?) {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else { return }
        scrollValue = nil
        select(number.doubleValue)
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        scrollValue = nil
        select(doubleValue + 1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        scrollValue = nil
        select(doubleValue - 1)
        return true
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
            let x = bounds.midX + CGFloat(NotchTimerRulerScale.offset(of: minute, selected: integerValue))
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
            NSColor.white.withAlphaComponent(NotchInteractionMetrics.focusRingOpacity).setStroke()
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
