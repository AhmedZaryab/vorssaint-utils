// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Where the island sits and how large it draws on any screen, from plain
/// values: no NSScreen, so every arrangement of displays can be described.
/// Each case asserts the centre x, the top y, the factor and the silhouette.
enum NotchGeometryTests {
    /// What a screen reports, with the density the way the app reads it.
    private struct FakeScreen {
        var frame: CGRect
        var visibleFrame: CGRect?
        var safeAreaTop: CGFloat = 0
        var auxGap: CGFloat = 0
        var scale: CGFloat = 2
        var pointsPerInch: CGFloat?
        var isMain = false
        var barHeight: CGFloat = 30
    }

    private static let builtInPPI: CGFloat = 127.5

    private static func geometry(_ screen: FakeScreen) -> NotchGeometry {
        let notched = screen.safeAreaTop > 0 && screen.auxGap > 0
        let factor = NotchDisplayScale.factor(pointsPerInch: screen.pointsPerInch, referencePointsPerInch: builtInPPI,
                                              isNotched: notched, setting: .auto)
        return NotchGeometry.base(
            for: NotchScreenDescription(frame: screen.frame, safeAreaTop: screen.safeAreaTop, cameraWidth: screen.auxGap,
                                        menuBarHeight: screen.barHeight, backingScale: screen.scale, displayScale: factor),
            layout: .spacious, customWidth: NotchSize.defaultWidth, customHeight: NotchSize.defaultHeight)
    }

    private static func check(_ suite: TestSuite, _ name: String, _ screen: FakeScreen,
                              centreX: CGFloat, top: CGFloat, factor: CGFloat, floats: Bool,
                              file: StaticString = #filePath, line: UInt = #line) {
        let g = geometry(screen)
        for (label, size) in [("rest", g.restingSize(showsContent: false)), ("open", g.expandedSize(module: .tools, panel: true))] {
            let frame = g.frame(for: size)
            suite.expectClose(frame.midX, centreX, "\(name) \(label) centre x", tol: 0.5, file: file, line: line)
            suite.expectClose(frame.maxY, top, "\(name) \(label) top y", tol: 0.001, file: file, line: line)
        }
        suite.expectClose(g.displayScale, factor, "\(name) factor", file: file, line: line)
        suite.expect(g.floats == floats, "\(name) silhouette: floats \(g.floats), expected \(floats)", file: file, line: line)
        suite.expect(g.isNotched == !floats, "\(name) isNotched \(g.isNotched)", file: file, line: line)
    }

    static func run(_ suite: TestSuite) {
        // (a) the external 6K monitor, left of the built-in, no camera.
        let external = FakeScreen(frame: CGRect(x: -3008, y: -357, width: 3008, height: 1692), pointsPerInch: 127.5)
        check(suite, "external left", external, centreX: -1504, top: 1335, factor: 1.0, floats: true)
        let pill = geometry(external)
        suite.expect(pill.restingSize(showsContent: false).height * pill.displayScale <= 30,
                     "pill fits inside the 30 pt bar: \(pill.restingSize(showsContent: false).height * pill.displayScale)")

        // (b) the built-in with a camera.
        let builtIn = FakeScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, auxGap: 185,
                                 pointsPerInch: 127.5, isMain: true, barHeight: 32)
        check(suite, "built-in", builtIn, centreX: 756, top: 982, factor: 1.0, floats: false)
        suite.expectClose(geometry(builtIn).cameraWidth, 185, "built-in width from the 185 gap")

        // (c) a 2560x1440 screen at 109 pt per inch, right of the built-in.
        let right = FakeScreen(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), pointsPerInch: 109)
        check(suite, "external right", right, centreX: 2792, top: 1440, factor: 1.0, floats: true)

        // (d) a dense 3840x2160 screen clamps to the largest factor.
        let dense = FakeScreen(frame: CGRect(x: 0, y: 982, width: 3840, height: 2160), pointsPerInch: 160)
        check(suite, "external above", dense, centreX: 1920, top: 3142, factor: 1.25, floats: true)

        // (e) a screen whose physical size reads zero keeps 1.0.
        let unknown = FakeScreen(frame: CGRect(x: -5000, y: 200, width: 2000, height: 1000),
                                 pointsPerInch: NotchDisplayScale.pointsPerInch(screenWidth: 2000, widthMillimetres: 0))
        check(suite, "unknown size", unknown, centreX: -4000, top: 1200, factor: 1.0, floats: true)

        // The bar is divided by the factor once: a 30 pt bar on a 1.25 screen is 24 layout points.
        suite.expectClose(geometry(dense).menuBarHeight * 1.25, 30, "bar divided by the factor once", tol: 6)
    }
}
