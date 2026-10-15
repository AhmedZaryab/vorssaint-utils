// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Feedback keeps the central camera area clear on physical and simulated notches.
struct NotchNoticeView: View {
    let notice: NotchNotice
    let geometry: NotchGeometry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var wings: NotchNoticeWings { notice.wings(in: geometry) }
    private var tint: Color {
        switch notice.event {
        // A warning reads as one in any agent's color; other AI notices wear it.
        case .agents: return notice.symbol.hasPrefix("exclamationmark") ? .orange : notice.agent?.tint ?? .white
        // The timer's notice keeps the orange its strip and page wear.
        case .timer: return .orange
        default: return .white
        }
    }
    /// The words of a timer's notice share its orange too.
    private var textTint: Color { notice.event == .timer ? .orange : .white }

    @ViewBuilder var body: some View {
        if notice.tall {
            tallBody
        } else {
            compactBody
        }
    }

    /// The tall peek: the strip as it rests, then a band with the agent's mark,
    /// what happened and what it took. Nothing beside the camera widens.
    private var tallBody: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.stripHeight)
            NotchTallPeekRow(primary: notice.title, secondary: notice.detail, hasLive: warns) {
                if let agent = notice.agent {
                    // The mark at the plate's size, with no container behind it.
                    NotchAgentMark(provider: agent, size: Self.markSize(agent, fitting: NotchDesign.Peek.artwork))
                } else {
                    Image(systemName: notice.symbol)
                        .font(.system(size: NotchDesign.Peek.artwork * 0.6, weight: .medium))
                        .foregroundStyle(NotchDesign.Ink.primary)
                }
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
        .foregroundStyle(.white)
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
        if let content = notice.notification {
            HStack(spacing: NotchNotificationBannerLayout.spacing) {
                NotchNotificationAppIcon(app: content.app, size: min(NotchNotificationBannerLayout.iconSize, geometry.stripHeight - 4))
                Text(content.compactTitle)
                    .font(Font(NotchNotificationBannerLayout.titleFont as CTFont))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if notice.showsGlyphAndWord {
            glyph
                .frame(width: NotchDesign.Peek.wingArtwork, height: NotchDesign.Peek.wingArtwork)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                Group {
                    // A notice about the agent itself wears its mark, and a
                    // warning keeps a symbol that says what happened.
                    if notice.event == .agents, let agent = notice.agent, notice.symbol == agent.symbol {
                        NotchAgentMark(provider: agent, size: 13)
                    } else if notice.event == .track {
                        NotchTrackArtwork(size: min(18, geometry.stripHeight - 6))
                    } else {
                        Image(systemName: notice.symbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 18)
                Text(notice.level == nil ? notice.title : notice.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textTint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(notice.event == .track ? .tail : .middle)
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
        } else {
            Image(systemName: notice.symbol)
                .font(NotchDesign.Icon.strip.font)
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder private var trailing: some View {
        if notice.showsGlyphAndWord {
            Text(notice.title)
                .font(NotchDesign.Typography.stripPrimary.font)
                .foregroundStyle(textTint)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if let content = notice.notification {
            // At the far end, as far from it as the sender is from the other
            // one, with the air that fits it beside the camera.
            Text(content.compactDetail)
                .font(Font(NotchNotificationBannerLayout.messageFont as CTFont))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(NotchNotificationBannerLayout.messageLines(stripHeight: geometry.stripHeight))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if let level = notice.level {
            NotchMeter(value: level, height: 5, tint: tint)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: level)
                .transaction { $0.disablesAnimations = false }
        } else {
            Text(notice.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textTint.opacity(0.8))
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
        // Equal insets from the band's two edges, so the row sits centred on
        // the island and the camera (the anatomy's 16 pt, Geometry.margin).
        .padding(.horizontal, NotchDesign.Geometry.margin)
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
        HStack(spacing: 8) {
            Image(systemName: notice.symbol)
                .frame(width: 18)
            NotchMeter(value: notice.level ?? 0, height: 5, tint: .white)
                .frame(maxWidth: 96)
            Text(notice.detail)
                .monospacedDigit()
                .fixedSize()
        }
        .font(.system(size: 11, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityText)
    }
}
