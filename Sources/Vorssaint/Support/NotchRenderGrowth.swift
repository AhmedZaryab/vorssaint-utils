// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import QuartzCore
import SwiftUI

/// Three frames of the island opening from the closed music strip onto the
/// music page, taken from the production `NotchWindowHost` itself. Its whole
/// motion is Core Animation, so the harness starts the real opening, stops
/// the window's layer clock and moves it to the moment wanted, then draws the
/// layers as they are at that moment. The same moment draws the same frame
/// on every run.
@MainActor
enum NotchRenderGrowth {
    /// The frames sit on a dark grey, not black: the outline growing is the
    /// point, and a black island on black would hide it.
    static let ground = NSColor(srgbRed: 0.23, green: 0.23, blue: 0.24, alpha: 1)

    static func summary(step: Int) -> String {
        switch step {
        case 1: return "growth 1 of 3: the closed music strip as the opening starts"
        case 2: return "growth 2 of 3: halfway, the outline at half its added height"
        default: return "growth 3 of 3: the music page once the motion settles"
        }
    }

    static func draw(step: Int, now: Date, background: NSColor) throws -> NSBitmapImageRep {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            throw RenderError("Reduce Motion is on, so the island opens without frames in between")
        }
        let service = NotchService.shared
        let geometry = NotchRenderFixtures.geometry
        var fixture = NotchService.RenderFixture(geometry: geometry, modules: NotchSupport.modules(),
                                                 power: NotchRenderFixtures.power)
        service.applyRenderFixture(fixture)
        guard service.compactActivity == .music else { throw RenderError("the closed island is not showing the song") }
        let closed = service.surfaceSize
        fixture.expanded = true
        fixture.selected = .music
        let opened: CGSize = {
            service.applyRenderFixture(fixture)
            defer { fixture.expanded = false; service.applyRenderFixture(fixture) }
            return service.surfaceSize
        }()

        let host = NotchWindowHost(content: AnyView(NotchView(service: service)), geometry: geometry, size: closed,
                                   background: { _ in AnyView(Color.black) })
        host.panel.alphaValue = 0
        host.panel.ignoresMouseEvents = true
        host.panel.orderFrontRegardless()
        defer { host.close() }
        settle(0.3)
        guard let root = host.panel.contentView?.layer else { throw RenderError("the island's window has no layer") }
        // The first frame is the strip the opening leaves, drawn at rest.
        if step == 1 { return try frame(of: root, panel: host.panel, size: opened, background: background) }

        // Opening, as NotchService.open asks it of the host.
        fixture.expanded = true
        service.applyRenderFixture(fixture)
        host.present(size: opened, geometry: geometry, animated: true, transitionContent: .reveal)
        // The opening's own start: the outline's motion is committed a
        // moment after `present` returns, and before it the layers show
        // where the island is going, not where it is.
        let found = beginning(of: "notch.resize", in: root)
        let start = found ?? root.convertTime(CACurrentMediaTime(), from: nil)
        root.speed = 0
        root.timeOffset = start
        let motion = NotchMotion.frames(from: closed, to: opened)
        let moment: CFTimeInterval
        switch step {
        case 2:
            // The first frame whose height has covered half the way.
            let half = closed.height + (opened.height - closed.height) / 2
            let index = motion.sizes.firstIndex { $0.height >= half } ?? motion.sizes.count / 2
            moment = motion.keyTimes[index] * motion.duration
        default: moment = motion.duration + 0.5
        }
        root.timeOffset = start + moment
        // Let SwiftUI draw the open page under the frozen motion.
        settle(0.35)
        root.timeOffset = start + moment
        return try frame(of: root, panel: host.panel, size: opened, background: background)
    }

    /// The layers as presented at the frozen moment, cut to the open
    /// island's frame, centred on the camera as the window is.
    private static func frame(of root: CALayer, panel: NSPanel, size: CGSize, background: NSColor) throws -> NSBitmapImageRep {
        let scale = NotchRenderHarness.pixelScale
        let bounds = root.bounds
        let crop = CGRect(x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((size.width * scale).rounded()),
                                         pixelsHigh: Int((size.height * scale).rounded()), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: rep) else { throw RenderError("no bitmap for the frame") }
        rep.size = size
        let context = graphics.cgContext
        context.setFillColor(background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh)))
        context.scaleBy(x: scale, y: scale)
        // Layer coordinates run down from the top of the window, as the
        // island's flipped views lay them out.
        if root.contentsAreFlipped() || (panel.contentView?.isFlipped ?? false) {
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
        } else {
            context.translateBy(x: 0, y: size.height - bounds.height)
        }
        context.translateBy(x: -crop.minX, y: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        (root.presentation() ?? root).render(in: context)
        CATransaction.commit()
        return rep
    }

    /// When the animation under `key` began, on the first layer running it.
    private static func beginning(of key: String, in layer: CALayer) -> CFTimeInterval? {
        if let animation = layer.animation(forKey: key), animation.beginTime > 0 { return animation.beginTime }
        for sublayer in (layer.sublayers ?? []) + [layer.mask].compactMap({ $0 }) {
            if let begin = beginning(of: key, in: sublayer) { return begin }
        }
        return nil
    }

    private static func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
#endif
