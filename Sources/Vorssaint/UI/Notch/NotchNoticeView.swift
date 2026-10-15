// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Feedback keeps the central camera area clear on physical and simulated notches.
struct NotchNoticeView: View {
    let notice: NotchNotice
    let geometry: NotchGeometry
    /// A tall peek on the hanging island draws only its band; the live strip is drawn above it.
    var reservesStrip = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wings: NotchNoticeWings { notice.wings(in: geometry) }
    private var tint: Color {
        switch notice.event {
        // A warning reads as one in any agent's color; other AI notices wear it.
        case .agents: return notice.symbol.hasPrefix("exclamationmark") ? NotchDesign.Palette.warning : notice.agent?.tint ?? NotchDesign.Ink.primary
        // Words stay white; the timer's glyph wears the one accent, never the warning orange.
        case .timer: return NotchDesign.Palette.accent
        default: return NotchDesign.Ink.primary
        }
    }

    @ViewBuilder var body: some View {
        if notice.tall {
            tallBody
        } else {
            compactBody
        }
    }

    /// The tall peek: the strip as it rests (drawn above by NotchView, or reserved here
    /// on a capsule), then a band with the mark, what happened and what it took.
    /// Nothing beside the camera widens.
    private var tallBody: some View {
        VStack(spacing: 0) {
            if reservesStrip { Color.clear.frame(height: geometry.stripHeight) }
            NotchTallPeekRow(primary: tallPrimary, secondary: tallSecondary, hasLive: warns) {
                tallMark
            } live: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(NotchDesign.Icon.strip.font)
                    .foregroundStyle(NotchDesign.Palette.warning)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }

    private var tallPrimary: String { notice.notification?.compactTitle ?? notice.title }
    private var tallSecondary: String { notice.notification?.compactDetail ?? notice.detail }

    @ViewBuilder private var tallMark: some View {
        if let content = notice.notification {
            NotchNotificationAppIcon(app: content.app, size: NotchDesign.Peek.artwork)
        } else if let agent = notice.agent {
            // The mark at the plate's size, with no container behind it.
            NotchAgentMark(provider: agent, size: Self.markSize(agent, fitting: NotchDesign.Peek.artwork))
        } else if notice.event == .track {
            NotchTrackArtwork(size: NotchDesign.Peek.artwork)
                .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
        } else if let file = notice.fileURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            // One plate for every glyph-only mark, as the song band's no-cover fallback.
            ZStack {
                RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
                    .fill(NotchDesign.Fill.card)
                Image(systemName: notice.symbol)
                    .font(NotchDesign.Icon.wing.font)
                    .foregroundStyle(NotchDesign.Ink.primary)
            }
        }
    }

    /// NotchAgentMark scales its glyph per agent (its `markScale` is private to
    /// that file), so the size that draws a mark `side` points across.
    private static func markSize(_ agent: AgentProvider, fitting side: CGFloat) -> CGFloat {
        side / (agent == .claude ? 1.45 : 1.2)
    }

    /// A limit that is close wears the warning glyph at the trailing end.
    private var warns: Bool { notice.symbol.hasPrefix("exclamationmark") }

    private var compactBody: some View {
        HStack(spacing: 0) {
            leading
                .padding(.leading, notice.inset(wing: wings.leading))
                .padding(.trailing, notice.cameraGap)
                .frame(width: wings.leading, height: geometry.stripHeight)
                .clipped()
            Color.clear.frame(width: geometry.noticeCameraGap)
            trailing
                .padding(.trailing, notice.inset(wing: wings.trailing))
                .padding(.leading, notice.cameraGap)
                .frame(width: wings.trailing, height: geometry.stripHeight)
                .clipped()
        }
        .foregroundStyle(NotchDesign.Ink.primary)
        .frame(height: geometry.stripHeight)
        // Each side is as wide as what it shows, so the island reaches
        // further toward the wider one and the camera's gap stays over it.
        .offset(x: (wings.trailing - wings.leading) / 2)
        // A new reading that needs another width, as a level passing 99%,
        // moves its mark and meter with the island's steady ease, not ahead of it.
        // Keyed on the notice's own widths, so a display change does not ease it.
        .animation(reduceMotion ? nil : .spring(duration: NotchMotion.steadyWidth.duration, bounce: 0),
                   value: notice.preferredWings)
        .transaction { $0.disablesAnimations = false }
        // Another kind of notice is drawn anew at its place, as the island
        // springs to it, rather than easing out of the last one's layout.
        .id(notice.event)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }

    @ViewBuilder private var leading: some View {
        if notice.showsGlyphAndWord || notice.isHUD {
            glyph
                .frame(width: NotchDesign.Peek.wingArtwork, height: NotchDesign.Peek.wingArtwork)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Battery, accessory and microphone notices keep their own layout.
            HStack(spacing: 8) {
                Group {
                    if notice.event == .agents, let agent = notice.agent, notice.symbol == agent.symbol {
                        NotchAgentMark(provider: agent, size: 13)
                    } else {
                        Image(systemName: notice.symbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 18)
                Text(notice.level == nil ? notice.title : notice.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: notice.readsFromEnds ? .leading : .trailing)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: notice.detail)
            .transaction { $0.disablesAnimations = false }
        }
    }

    /// The compact peek's glyph or cover, 20 pt.
    @ViewBuilder private var glyph: some View {
        let side = NotchDesign.Peek.wingArtwork
        if notice.event == .agents, let agent = notice.agent, notice.symbol == agent.symbol {
            NotchAgentMark(provider: agent, size: Self.markSize(agent, fitting: side))
        } else if notice.event == .track {
            NotchTrackArtwork(size: side)
                .clipShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.card * side / NotchDesign.Peek.artwork, style: .continuous))
        } else {
            Image(systemName: notice.symbol)
                .font(NotchDesign.Icon.wing.font)
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder private var trailing: some View {
        if notice.showsGlyphAndWord {
            Text(notice.title)
                .font(NotchDesign.Typography.stripPrimary.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if notice.isHUD, let level = notice.level {
            // The meter fills the wing, the percent keeps its widest reading's width.
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                NotchMeter(value: level, height: NotchDesign.Control.meter, tint: NotchDesign.Ink.primary)
                    .frame(maxWidth: .infinity)
                Text(notice.detail)
                    .font(NotchDesign.Typography.readout.font)
                    .monospacedDigit()
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .frame(width: NotchNotice.hudReadingWidth, alignment: .trailing)
            }
            .animation(reduceMotion ? nil : NotchDesign.Motion.fade, value: level)
            .transaction { $0.disablesAnimations = false }
        } else if let level = notice.level {
            NotchMeter(value: level, height: 5, tint: tint)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: level)
                .transaction { $0.disablesAnimations = false }
        } else {
            Text(notice.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchDesign.Ink.primary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(notice.event == .accessory ? .middle : .tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// The tall peek's one row: a 32 pt mark or cover, a first line and a second,
/// and an optional 20 pt live element at the trailing end. The song band and
/// the agent wrap-up share it, so every tall peek reads the same.
struct NotchTallPeekRow<Mark: View, Live: View>: View {
    let primary: String
    let secondary: String
    var hasLive = true
    @ViewBuilder var mark: Mark
    @ViewBuilder var live: Live
    var body: some View {
        HStack(spacing: NotchDesign.Spacing.medium) {
            mark.frame(width: NotchDesign.Peek.artwork, height: NotchDesign.Peek.artwork)
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                Text(primary)
                    .font(NotchDesign.Typography.stripPrimary.font)
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !secondary.isEmpty {
                    Text(secondary)
                        .font(NotchDesign.Typography.stripSecondary.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if hasLive {
                live.frame(width: NotchDesign.Peek.trailingSide, height: NotchDesign.Peek.trailingSide)
            }
        }
        // The island's body starts a shoulder in from the surface edge, so the row
        // insets by shoulder plus margin: the 32 pt mark's corner is concentric
        // with the island's bottom corner (notch-geometry.md contentInsets).
        .padding(.horizontal, NotchLayout.horizontalInset)
        .padding(.top, NotchDesign.Peek.bandTop)
        .frame(height: NotchDesign.Peek.bandHeight, alignment: .top)
    }
}

/// The new song's cover, read as it arrives: it often lands after the title.
private struct NotchTrackArtwork: View {
    @ObservedObject private var music = NotchMusicService.shared
    let size: CGFloat

    var body: some View { NotchArtwork(image: music.artwork, size: size) }
}

/// Level feedback occupies the header while the current page stays usable.
struct NotchExpandedLevelView: View {
    let notice: NotchNotice

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.small) {
            Image(systemName: notice.symbol)
                .font(NotchDesign.Icon.strip.font)
                .frame(width: NotchDesign.Peek.wingArtwork)
            NotchMeter(value: notice.level ?? 0, height: NotchDesign.Control.meter, tint: NotchDesign.Ink.primary)
                .frame(maxWidth: 96)
            Text(notice.detail)
                .font(NotchDesign.Typography.readout.font)
                .monospacedDigit()
                .fixedSize()
        }
        .foregroundStyle(NotchDesign.Ink.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }
}
