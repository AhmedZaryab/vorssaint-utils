// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The notch's single source of visual truth: every gap, corner, font, alpha,
/// stroke, shadow, spring and control size a notch view draws comes from here.
/// The why, and which token goes where: docs/design/NOTCH-DESIGN.md.
/// NotchLayout keeps the window budgets it sizes the island with and NotchMotion
/// keeps the frame planner; both take their numbers from Geometry below.
/// Self-contained on purpose: the test target compiles this file on its own.
enum NotchDesign {
    /// The 4 pt grid with Apple's 6 pt step. A gap that is not here is a bug.
    enum Spacing {
        /** Between stacked lines of one text block, title over subtitle. The only value under 4. */ static let line: CGFloat = 2
        /** A glyph to its own label inside a chip, a meter to its reading. */ static let xxSmall: CGFloat = 4
        /** Icon button to icon button in the header and in toolbars; a card's inset to its inner plates. */ static let xSmall: CGFloat = 6
        /** Icon to text in a row; the gutter between cards and tiles. */ static let small: CGFloat = 8
        /** Inside a card; header to page; between a page's groups. */ static let medium: CGFloat = 12
        /** The island body margin, sides and bottom alike; transport button gaps. */ static let large: CGFloat = 16
        /** Artwork to the text beside it on the music page. */ static let xLarge: CGFloat = 20
        /** Empty-state glyph to its message; the widest gap the notch uses. */ static let xxLarge: CGFloat = 24
        /** Between cards and tiles in a row or a column. */ static let gutter = small
        /** Padding inside a card. */ static let cardPadding = medium
        /** Between the header row and the page, and between a page's groups. */ static let section = medium
    }
    /// The silhouette: how the island sits on the hardware notch and how it grows.
    enum Geometry {
        /** Closed corner, a continuous curve, as a share of the notch height: 10.3 pt on the 32 pt notch, measured from the panel (docs/design/notch-geometry.md). Feeds NotchLayout.surfaceRadius. */ static let closedCornerRatio: CGFloat = 0.322
        /** The open panel's bottom corners, and the cap for an island of any height. */ static let panelCornerRadius: CGFloat = 28
        /** The flare where the island meets the screen's top edge, at full height. Feeds NotchLayout.shoulder. */ static let shoulderRadius: CGFloat = 14
        /** Shoulder as a share of height until it reaches shoulderRadius: 6.8 pt on a 32 pt notch, measured. */ static let shoulderRatio: CGFloat = 0.2129
        /** The shoulder's Bezier handles as a share of its extent, as the cutout draws them. */ static let shoulderHandle: CGFloat = 0.776
        /** Body to content, sides and bottom alike, so inner corners stay concentric. */ static let margin: CGFloat = Spacing.large
        /// The island's corner at `height`: the cutout's own curve closed, panelCornerRadius open.
        static func islandCornerRadius(height: CGFloat) -> CGFloat {
            min(panelCornerRadius, max(0, height) * closedCornerRatio)
        }
        /** Growth on both axes together, one spring, anchored at the top centre. */ static let growSpring = Spring(response: 0.40, dampingFraction: 0.85)
        /** Shrink on both axes together, no overshoot. 0.20 s so the close (99% at about 0.21 s after its delay) leaves as fast as the open arrives. */ static let shrinkSpring = Spring(response: 0.20, dampingFraction: 1)
        /** The farthest a growing side may pass its target, in points. */ static let overshootLimit: CGFloat = 8
        /** Content arrives the way Dynamic Island does: it starts 0.12 s in, under blur, while the shape is still growing, and the 0.18 s fade from the 4 pt blur is sharp by 0.30 s. Never scaled, clipped to the growing shape. */ static let contentRevealDelay: TimeInterval = 0.12
        /** Content then fades in over this, fully in at the delay plus this (0.30 s). It never scales, so it is never squished. */ static let contentRevealDuration: TimeInterval = 0.18
        /** The blur content arrives from, in points; none under Reduce Motion. */ static let contentRevealBlur: CGFloat = 4
        /** Content leaves this fast, ease out; the shrink starts halfway through it. */ static let contentExitDuration: TimeInterval = 0.12
        /** Under Reduce Motion the silhouette resizes on an ease out this long, no spring. */ static let reducedMotionResize: TimeInterval = 0.2
    }
    /// Corners nest: an inner radius is its container's radius minus the inset between them.
    enum Radius {
        /** The open island. */ static let panel = Geometry.panelCornerRadius
        /** Cards, tiles and the music artwork that sit on the page: panel minus the body margin. */ static let card = panel - Geometry.margin
        /** Plates inside a card: icon buttons, chips, fields, menu buttons, small thumbnails. */ static let control = card - Spacing.xSmall
        /** Keycaps, badges and tags only. Pills and round buttons are Capsule and Circle. */ static let small: CGFloat = 4
        /// The radius of a shape inset `inset` inside a corner of radius `outer`.
        static func concentric(_ outer: CGFloat, inset: CGFloat) -> CGFloat { max(0, outer - inset) }
        /// Artwork that hugs no corner: a fifth of its side, never rounder than a card.
        static func artwork(side: CGFloat) -> CGFloat { min(card, (side * 0.2).rounded()) }
    }
    /// The only weights the notch uses; light and thin are too faint on glass at these sizes.
    struct Weight {
        let font: Font.Weight
        let appKit: NSFont.Weight
        /** Running text and second lines. */ static let regular = Weight(font: .regular, appKit: .regular)
        /** Labels, captions, glyphs in buttons. */ static let medium = Weight(font: .medium, appKit: .medium)
        /** Titles, the strip's first line, readouts. */ static let semibold = Weight(font: .semibold, appKit: .semibold)
        /** Reserved for a single emphasised word inside running text. */ static let bold = Weight(font: .bold, appKit: .bold)
    }
    /// A system text style with an explicit weight. Rounded is for numbers only.
    struct TypeStyle {
        let style: Font.TextStyle
        let weight: Weight
        let rounded: Bool
        /// A fixed point size, for a face that must fill a fixed box (Icon.wing); nil follows the text style.
        let fixedSize: CGFloat?
        /// The AppKit face, built once: layout reads it many times a pass (NotchLayout.wings, preferredWings).
        let nsFont: NSFont
        init(style: Font.TextStyle, weight: Weight, rounded: Bool = false, fixedSize: CGFloat? = nil) {
            self.style = style
            self.weight = weight
            self.rounded = rounded
            self.fixedSize = fixedSize
            let size = fixedSize ?? NSFont.preferredFont(forTextStyle: Self.appKitStyles[style] ?? .body).pointSize
            let font = NSFont.systemFont(ofSize: size, weight: weight.appKit)
            if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) {
                self.nsFont = NSFont(descriptor: descriptor, size: size) ?? font
            } else {
                self.nsFont = font
            }
        }
        /// The smallest point size anything in the notch draws at.
        static let minimumPointSize: CGFloat = 10
        /// The style's size in points.
        var pointSize: CGFloat { nsFont.pointSize }
        /// For `minimumScaleFactor`: the most this style may shrink before it sits under minimumPointSize. Truncate instead of going lower.
        var minimumScale: CGFloat { min(1, Self.minimumPointSize / pointSize) }
        /// The SwiftUI font.
        var font: Font {
            if let fixedSize { return .system(size: fixedSize, weight: weight.font, design: rounded ? .rounded : .default) }
            return .system(style, design: rounded ? .rounded : .default, weight: weight.font)
        }
        private static let appKitStyles: [Font.TextStyle: NSFont.TextStyle] = [
            .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3, .headline: .headline,
            .subheadline: .subheadline, .body: .body, .callout: .callout, .footnote: .footnote,
            .caption: .caption1, .caption2: .caption2]
    }
    /// The ramp, in macOS sizes. Ten is the floor: nothing in the notch is smaller.
    enum Typography {
        /** Timer and stopwatch readouts on their pages: 26 pt rounded. */ static let display = TypeStyle(style: .largeTitle, weight: .semibold, rounded: true)
        /** The music page's track title and the sung lyric line: 17 pt. */ static let hero = TypeStyle(style: .title2, weight: .semibold)
        /** The header's page title and a detail's title by its back button: 15 pt. */ static let pageTitle = TypeStyle(style: .title3, weight: .semibold)
        /** Card titles, row titles, the track title on cards: 13 pt. */ static let title = TypeStyle(style: .body, weight: .semibold)
        /** Running text: notification bodies, scratchpad, clipboard previews, empty-state sentences: 13 pt. */ static let body = TypeStyle(style: .body, weight: .regular)
        /** A row's second line, pill labels, menu button labels: 12 pt. */ static let callout = TypeStyle(style: .callout, weight: .regular)
        /** Tile labels under their glyph, chips, segment labels: 11 pt. */ static let label = TypeStyle(style: .subheadline, weight: .medium)
        /** Times by the scrubber, shortcut hints, metadata: 10 pt. */ static let caption = TypeStyle(style: .caption, weight: .medium)
        /** Live numbers inside rows and tiles (percent, countdown, cost): 12 pt rounded, add monospacedDigit. */ static let readout = TypeStyle(style: .callout, weight: .semibold, rounded: true)
        /** The closed island's and every peek's first line: 12 pt. */ static let stripPrimary = TypeStyle(style: .callout, weight: .semibold)
        /** The closed island's and every peek's second line: 10 pt. */ static let stripSecondary = TypeStyle(style: .caption, weight: .medium)
    }
    /// SF Symbols sized by font, so their weight matches the text beside them.
    enum Icon {
        /** A glyph in a 28 pt icon button: 13 pt. */ static let button = TypeStyle(style: .body, weight: .medium)
        /** A glyph beside the closed island's and a peek's text: 12 pt. */ static let strip = TypeStyle(style: .callout, weight: .semibold)
        /** A mark in a compact peek's wing or a closed strip, inking Peek.wingArtwork (20 pt): a fixed 17 pt face, so a symbol fills the 20 pt box at any text size; one size for notices, strips and agent marks so a mark never resizes as a strip becomes a notice. Icon.strip stays for glyphs inline with text. */ static let wing = TypeStyle(style: .title2, weight: .medium, fixedSize: 17)
        /** A shortcut tile's glyph in its 40 pt circle: 17 pt. */ static let tile = TypeStyle(style: .title2, weight: .medium)
        /** Previous and next, shuffle: 17 pt. */ static let transport = TypeStyle(style: .title2, weight: .semibold)
        /** Play and pause: 26 pt. */ static let transportPrimary = TypeStyle(style: .largeTitle, weight: .semibold)
        /** An empty page's glyph in its 56 pt plate: 26 pt. */ static let hero = TypeStyle(style: .largeTitle, weight: .medium)
    }
    /// Text and glyph alphas on the island's black and its glass.
    enum Opacity {
        /** Titles, values, anything the eye lands on first. */ static let primary: Double = 1
        /** Second lines, labels, times: 7.4 to 1 on black. */ static let secondary: Double = 0.6
        /** Placeholders and hints that need not be read: 2.5 to 1, never information. */ static let tertiary: Double = 0.3
        /** A whole control that cannot act right now. */ static let disabled: Double = 0.4
    }
    /// Text and glyph colours.
    enum Ink {
        /** See Opacity.primary. */ static let primary = Color.white
        /** See Opacity.secondary. */ static let secondary = Color.white.opacity(Opacity.secondary)
        /** See Opacity.tertiary. */ static let tertiary = Color.white.opacity(Opacity.tertiary)
        /** Text and glyphs on Fill.inverse. */ static let onInverse = Color.black
        /// Placeholders and instructions that must stay legible: tertiary, rising to 0.6 under Increase Contrast. A ShapeStyle, so use it in foregroundStyle.
        static let hint = HintInk()
        /// Hint ink as a Color for views that already read colorSchemeContrast.
        static func hint(_ contrast: ColorSchemeContrast) -> Color { contrast == .increased ? secondary : tertiary }
        /// Glyphs and semibold labels on the accent fill: white always, as in Control Center. Use this, not onFill, on Palette.accent.
        static let onAccent = Color.white
        /// White unless white would fall under the bar on `fill`, then Ink.onInverse. The bar is 3 to 1 for glyphs and bold or semibold text (the default), 4.5 to 1 only for `regularText`. Use on any other coloured fill: pills, tile glyphs, toggle faces, tints; one ink across the home tiles.
        static func onFill(_ fill: Color, regularText: Bool = false) -> Color {
            guard let rgb = NSColor(fill).usingColorSpace(.sRGB) else { return primary }
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            let luminance = 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
            return 1.05 / (luminance + 0.05) < (regularText ? 4.5 : 3) ? onInverse : primary
        }
    }
    /// See Ink.hint.
    struct HintInk: ShapeStyle {
        func resolve(in environment: EnvironmentValues) -> Color {
            environment.colorSchemeContrast == .increased ? Ink.secondary : Ink.tertiary
        }
    }
    /// One accent and three signals. Nothing else is coloured but content.
    enum Palette {
        /** The person's system accent: a toggle that is on, a page's one primary action, a fuse's undo. */ static let accent = Color.accentColor
        /** Recording, a destructive commit, a critical battery. Always beside a symbol or a word. */ static let critical = Color.red
        /** A limit close, an early battery warning, a fuse burning. */ static let warning = Color.orange
        /** Connected, saved, finished. */ static let positive = Color.green
    }
    /// Surfaces on the island: white at low alpha, never grey hex.
    enum Fill {
        /** A card or tile at rest. */ static let card = Color.white.opacity(0.06)
        /** A control plate: an icon button's chosen state, a segmented track, a tile's glyph circle. */ static let control = Color.white.opacity(0.10)
        /** The wash under the pointer. */ static let hover = Color.white.opacity(0.08)
        /** The wash under a pressed plate when the scale is off (Reduce Motion). */ static let press = Color.white.opacity(0.13)
        /** The chosen option in a set; the keyboard's highlighted tile. */ static let selected = Color.white.opacity(0.16)
        /** Slider and meter tracks; AppKit cells take NSColor(Fill.track). */ static let track = Color.white.opacity(0.16)
        /** The one chosen chip in a picker, with Ink.onInverse on it. */ static let inverse = Color.white
    }
    /// Edges. Every border in the notch is a hairline, or it is not drawn.
    enum Stroke {
        /** The only stroke width for cards, artwork and the key line. */ static let hairline: CGFloat = 0.5
        /** A card's edge on Liquid Glass only; on the black island cards have no edge. */ static let glassEdge = Color.white.opacity(0.08)
        /** The key line round an open island, Stroke.hairline wide; the optional outline is 1 pt at most. */ static let keyLine = Color.white.opacity(0.14)
        /** Artwork's edge, so a dark cover stays apart from the island. */ static let artworkEdge = Color.white.opacity(0.12)
        /** Increase Contrast: every plate and card gets this 1 pt edge. */ static let increasedContrast = Color.white.opacity(0.5)
        /** Width of the Increase Contrast edge. */ static let increasedContrastWidth: CGFloat = 1
        /** The library's keyboard focus ring: the system focus colour; gallery tiles, clipboard cards and controls all read it. */ static let keyboardFocus = Color(nsColor: .keyboardFocusIndicatorColor)
        /** Width of the library's focus ring, the same 2 pt NotchSectionsView uses. */ static let keyboardFocusWidth: CGFloat = 2
        /** Gap between a control's edge and its focus ring. */ static let focusRingGap: CGFloat = 2.5
        /** Drop targets only. */ static let dropTarget = StrokeStyle(lineWidth: 1, dash: [5, 4])
    }
    /// A shadow recipe.
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }
    /// Depth. The island is black, so shadows are rare and always soft.
    enum Shadow {
        /** Quick-access buttons floating over the desktop below the island. */ static let floating = ShadowStyle(color: .black.opacity(0.35), radius: 8, y: 2)
        /// The music page's artwork halo in the cover's tint. Music only, one layer.
        static func halo(_ tint: Color) -> ShadowStyle { ShadowStyle(color: tint.opacity(0.4), radius: 20, y: 6) }
    }
    /// The Liquid Glass recipe for the island shell and its floating controls.
    enum Glass {
        /** Black kept under any text on glass: secondary text holds 4.5 to 1 over a white desktop. */ static let textDim: Double = 0.72
        /** Black at the bottom 16 pt lip, where no text sits. */ static let lipDim: Double = 0.55
        /** Black everywhere on glass under Increase Contrast. */ static let increasedContrastDim: Double = 0.9
        /** Before macOS 26, and whenever glass is off: the material a floating control sits on. */ static let fallbackMaterial: Material = .ultraThinMaterial
    }
    /// A spring as Apple names it. NotchMotion and Core Animation read `bounce`.
    struct Spring {
        /// Seconds to arrive; SwiftUI's response, NotchMotion's duration.
        let response: Double
        /// 1 settles without overshoot; below 1 overshoots.
        let dampingFraction: Double
        /// One minus the damping fraction.
        var bounce: Double { 1 - dampingFraction }
        /// The SwiftUI animation.
        var animation: Animation { .spring(response: response, dampingFraction: dampingFraction) }
    }
    /// Content motion. The silhouette's own springs live in Geometry.
    enum Motion {
        /** Press release, toggles, hover wash timing, selection moving: quick, no overshoot. */ static let snappy = Spring(response: 0.25, dampingFraction: 1)
        /** Content that moves or resizes: rows, page content, a thumb settling. */ static let smooth = Spring(response: 0.4, dampingFraction: 1)
        /** Only after momentum or a commit: a launch, a success landing, a released swipe. */ static let bouncy = Spring(response: 0.4, dampingFraction: 0.8)
        /** Opacity cross-fades: the one motion Reduce Motion keeps. */ static let fade = easeOut(0.18)
        /** Anything leaving: faster than it came, and never ease in. */ static let exit = easeOut(0.12)
        /** A hover wash and a dimmed value fading: 0.15 s ease out. */ static let hover = easeOut(0.15)
        /** A symbol swapping for another in place (play to pause): 0.25 s, no bounce. */ static let symbolMorph = Spring(response: 0.25, dampingFraction: 1)
        /** A closed-island width that follows a live value (volume keys): a quick settle, under 300 ms. */ static let steady = Spring(response: 0.25, dampingFraction: 1)
        /** Detail text or a level changing under a peek: 0.14 s ease out. */ static let valueChange = easeOut(0.14)
        /** A tint or palette following new artwork, a slow ambient change (never user-initiated): 0.6 s. */ static let ambient = easeOut(0.6)
        /** Two views replacing each other in place: 0.18 s, the same as fade. */ static let replaceDuration: TimeInterval = 0.18
        /** No transient animation runs longer than this, as Live Activities. */ static let ceiling: TimeInterval = 2
        /// Apple's strong ease out for something entering on a fixed time.
        static func easeOut(_ duration: TimeInterval) -> Animation { .timingCurve(0.23, 1, 0.32, 1, duration: duration) }
        /// `spring`, or nothing under Reduce Motion so the change lands at once; fade opacity with `fade`.
        static func animation(_ spring: Spring, reduceMotion: Bool) -> Animation? { reduceMotion ? nil : spring.animation }
    }
    /// Button feel: feedback matches consequence. Read by NotchPressStyle, NotchToggleStyle,
    /// NotchCommitButton, NotchFuseButton, NotchSlider and NotchSuccessMorph.
    enum Interaction {
        /** NotchPressStyle: the scale on mouse down, landed within pressDuration. */ static let pressScale: CGFloat = 0.97
        /** How fast the press lands, ease out; release springs back on Motion.snappy. */ static let pressDuration: TimeInterval = 0.1
        /** NotchPressStyle under the pointer: 1, because macOS highlights with Fill.hover and never lifts (lift is iPadOS). */ static let hoverScale: CGFloat = 1
        /** NotchCommitButton held past its threshold, about to fire. */ static let armedScale: CGFloat = 1.04
        /** Travel before a press becomes a drag, in points. */ static let dragThreshold: CGFloat = 4
        /** NotchSuccessMorph: how long the done state holds before the control returns. */ static let successMorphDuration: TimeInterval = 1.2
        /** NotchFuseButton: the burn before a destructive action commits; Escape or a click undoes it. Two seconds linear, inside Motion.ceiling. */ static let fuseDuration: TimeInterval = 2.0
        /** The one-shot nudge a control gives when its result lands (a kick): 0.3 s. */ static let kickDuration: TimeInterval = 0.3
        /** A slung control's burst: 0.35 s. */ static let slingBurst: TimeInterval = 0.35
        /** A sling following the pointer. */ static let slingTrack = Animation.interactiveSpring(response: 0.1, dampingFraction: 0.9)
        /** A sling's recoil spring: 0.38 s, a little bounce. */ static let slingRecoil = Spring(response: 0.38, dampingFraction: 0.76)
        /** The fuse button's face changing between idle and burning: 0.2 s ease out. */ static let fuseFace = Motion.easeOut(0.2)
        /** A value's number or label cross-fading: 0.15 s ease out. */ static let valueFade = Motion.easeOut(0.15)
        /** NotchFuseButton: the burning rim's width. */ static let fuseLineWidth: CGFloat = 1.5
        /** NotchCommitButton: particles in the burst when it fires. */ static let burstParticleCount = 8
        /** NotchCommitButton: particle diameter, in points. */ static let burstParticleSize: CGFloat = 3
        /** NotchCommitButton: how far particles fly past the control's edge; they stay inside the island. */ static let burstReach: CGFloat = 18
        /** NotchCommitButton: particle lifetime. */ static let burstDuration: TimeInterval = 0.3
        /** NotchCommitButton: the burst's cone round its direction, in degrees. */ static let burstSpread: Double = 60
        /** NotchSlider: Apple's rubberband constant past either end. */ static let rubberband: CGFloat = 0.55
        /** NotchSlider: the farthest the track stretches past an end, in points. */ static let rubberbandLimit: CGFloat = 6
        /** NotchSlider: snaps to a detent within this share of its range, with a trackpad tick. */ static let detentSnap: Double = 0.02
        /** NotchSlider: the tick at a detent, on the same frame as the snap. */ static let detentHaptic = NSHapticFeedbackManager.FeedbackPattern.alignment
        /// NotchSlider: `offset` past an end, resisted the further it goes, capped at rubberbandLimit.
        static func rubberbanded(_ offset: CGFloat, dimension: CGFloat) -> CGFloat {
            let stretched = offset * dimension * rubberband / (dimension + rubberband * abs(offset))
            return min(rubberbandLimit, max(-rubberbandLimit, stretched))
        }
    }
    /// Sizes. A hit target is never smaller than minimumHit, whatever the drawing.
    enum Control {
        /** The smallest hit target on the island. */ static let minimumHit: CGFloat = 28
        /** Icon buttons in the header and in rows. */ static let iconButton: CGFloat = 28
        /** A level row, a list row, a menu button, a pill. */ static let rowHeight: CGFloat = 28
        /** A commit button when its caller names no size. */ static let commit: CGFloat = 32
        /** Transport on cards and short players. */ static let transportCompact: CGFloat = 36
        /** Transport on a roomy music page. */ static let transport: CGFloat = 44
        /** A shortcut tile's glyph circle. */ static let tileGlyph: CGFloat = 40
        /** An empty page's glyph plate. */ static let heroGlyph: CGFloat = 56
        /** A slider's drawn track; its hit area stays rowHeight tall. */ static let sliderTrack: CGFloat = 6
        /** A read-only meter's bar. */ static let meter: CGFloat = 4
        /** A status dot: one agent on the OS page. Always beside a count in words. */ static let statusDot: CGFloat = 8
    }
    /// Every moment the closed island widens or grows on its own shares this anatomy.
    enum Peek {
        /** Compact peek: the widest a wing beside the camera may grow. */ static let wingMaximum: CGFloat = 96
        /** Compact peek: the narrowest wing, its curved end and some air. */ static let wingMinimum: CGFloat = 36
        /** Compact peek: a glyph or cover in a wing. */ static let wingArtwork: CGFloat = 20
        /** Compact peek: the one edge inset for a wingArtwork box on the curved outer end of a wing: the closed corner's radius at the 32 pt notch (10.3) plus a little air, rounded to the grid. Every strip and notice uses it, so no mark crowds the curve. */ static let wingInset: CGFloat = Spacing.small
        /** Reference camera width of the owner's notch (185 pt), only to evaluate bandMaximumWidth; layout code uses bandMaximumWidth(cameraWidth:). */ static let referenceCameraWidth: CGFloat = 185
        /** Content waits this long inside a peek before it fades in. Zero: a volume, brightness, keyboard light or Copied notice answers on the first frame with the grow, no blur, as the system HUD does; keyboard-initiated moments never wait. */ static let contentRevealDelay: TimeInterval = 0
        /** Tall peek: the band grown below the strip. */ static let bandHeight: CGFloat = 60
        /** Tall peek: the band is the resting island's width but never narrower than this. */ static let bandMinimumWidth: CGFloat = 300
        /** Tall peek: never wider than the widest compact strip, camera plus a full wingMaximum each side; text truncates, the island does not widen for it. */ static func bandMaximumWidth(cameraWidth: CGFloat) -> CGFloat { cameraWidth + 2 * wingMaximum }
        /** The same on the reference camera: 377 pt. */ static let bandMaximumWidth: CGFloat = referenceCameraWidth + 2 * wingMaximum
        /** Tall peek: the cover or glyph plate in the band. */ static let artwork: CGFloat = 32
        /** Tall peek: band inset under the strip; sides and bottom use Geometry.margin. */ static let bandTop: CGFloat = Spacing.medium
        /** The optional trailing live element: equaliser, ring, amount. */ static let trailingSide: CGFloat = 20
        /** A peek's grow: both axes, a little life, settles quickly. */ static let grow = Spring(response: 0.36, dampingFraction: 0.88)
        /** Volume, brightness and keyboard light, after their last change. */ static let hudDwell: TimeInterval = 1.5
        /** A short fact: copied, device connected, keep awake on. */ static let infoDwell: TimeInterval = 2.5
        /** A tall peek: song, agent, notification, download, calendar. */ static let tallDwell: TimeInterval = 4
        /** Something that asked for attention: timer ended, watch fired. */ static let attentionDwell: TimeInterval = 8
        /** A peek shows at least this long before a higher one replaces it. */ static let minimumRead: TimeInterval = 1
        /** Peeks waiting at most; older ones of a kind merge into the newest. */ static let queueLimit = 3
    }
}

extension View {
    /// Liquid Glass on macOS 26, the fallback material before it, black under Reduce Transparency.
    /// Floating controls and the shell only: never cards or rows inside the island.
    func notchGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(NotchGlassModifier(shape: shape, interactive: interactive))
    }
}

private struct NotchGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color.black, in: shape)
        } else {
#if compiler(>=6.2)
            if #available(macOS 26, *) {
                content.glassEffect(.regular.interactive(interactive), in: shape)
            } else {
                content.background(NotchDesign.Glass.fallbackMaterial, in: shape)
            }
#else
            content.background(NotchDesign.Glass.fallbackMaterial, in: shape)
#endif
        }
    }
}
