// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The OS on this Mac, in one card: a dot per agent, the last HQ line and the
/// P0 count. The whole card opens the OS. It reads only while this page is
/// open, and says so quietly when the OS does not answer.
struct NotchOSView: View {
    let size: CGSize
    @Environment(\.notchSettingsPreview) private var preview
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NotchOSService.shared

    private var text: NotchOSStrings { FeatureStrings.notchOS(l10n.language) }

    var body: some View {
        Group {
            switch service.state {
            case .waiting:
                Color.clear
            case .off:
                NotchEmptyView(symbol: NotchModule.os.symbol, message: text.off)
            case .live(let snapshot):
                VStack(spacing: NotchLayout.rowSpacing) {
                    card(snapshot)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { if !preview { await service.run() } }
    }

    private func card(_ snapshot: NotchOSSnapshot) -> some View {
        Button { NSWorkspace.shared.open(NotchOSService.destination(for: snapshot)) } label: {
            VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                HStack(spacing: NotchDesign.Spacing.small) {
                    Text(snapshot.hq?.title ?? text.title)
                        .font(NotchDesign.Typography.title.font)
                        .foregroundStyle(NotchDesign.Ink.primary)
                        .lineLimit(1)
                    Spacer(minLength: NotchDesign.Spacing.small)
                    HStack(spacing: NotchDesign.Spacing.xxSmall) {
                        ForEach(Array(snapshot.dots.enumerated()), id: \.offset) { _, status in
                            Circle().fill(Self.tint(status)).frame(width: NotchDesign.Control.statusDot,
                                                                   height: NotchDesign.Control.statusDot)
                        }
                    }
                    .accessibilityHidden(true)
                }
                lastLine(snapshot.hq?.last)
                HStack(spacing: NotchDesign.Spacing.small) {
                    Text(text.p0(snapshot.board?.p0 ?? 0))
                        .font(NotchDesign.Typography.readout.font)
                        .monospacedDigit()
                        .foregroundStyle(NotchDesign.Ink.primary)
                    Text(counts(snapshot))
                        .font(NotchDesign.Typography.caption.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(NotchDesign.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.card)))
        .modifier(NotchControlSurface(cornerRadius: NotchDesign.Radius.card))
        .accessibilityLabel((snapshot.hq?.title ?? text.title) + ", " + counts(snapshot) + ", "
                            + text.p0(snapshot.board?.p0 ?? 0))
        .accessibilityHint(text.open)
    }

    @ViewBuilder private func lastLine(_ message: NotchOSSnapshot.Message?) -> some View {
        if let message {
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                Text(message.name)
                    .font(NotchDesign.Typography.label.font)
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .layoutPriority(1)
                Text(message.body)
                    .font(NotchDesign.Typography.callout.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
            }
            .lineLimit(1)
            .truncationMode(.tail)
        } else {
            Text(text.noMessages)
                .font(NotchDesign.Typography.callout.font)
                .foregroundStyle(NotchDesign.Ink.hint)
                .lineLimit(1)
        }
    }

    private func counts(_ snapshot: NotchOSSnapshot) -> String {
        text.duty(snapshot.dutyCount) + " \u{00B7} " + text.door(snapshot.doorCount)
    }

    private static func tint(_ status: NotchOSSnapshot.Status) -> Color {
        switch status {
        case .duty: return NotchDesign.Palette.positive
        case .door: return NotchDesign.Palette.warning
        case .off: return NotchDesign.Fill.track
        }
    }
}
