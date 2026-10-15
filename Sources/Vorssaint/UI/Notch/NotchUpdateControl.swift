// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The same offer and progress as the menu panel, kept inside the island's
/// existing header so it cannot displace or resize the active tool.
struct NotchUpdateControl: View {
    @ObservedObject private var updates = UpdateService.shared
    let action: () -> Void
    var compact = false
    @ObservedObject private var l10n = L10n.shared

    @ViewBuilder var body: some View {
        switch updates.state {
        case let .available(version):
            let tint: Color = UpdateServiceSupport.SemanticVersion(raw: version)?.isPrerelease == true
                ? NotchDesign.Palette.warning : NotchDesign.Palette.accent
            let title = "\(l10n.s.updateBannerTitle), \(l10n.s.versionPrefix) \(version)"
            // A commit: it answers on press and its glyph kicks up and away as the update opens.
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                NotchCommitButton(title, symbol: "arrow.down.circle.fill", kick: .up,
                                  hint: l10n.s.updateBannerAction, size: NotchDesign.Control.iconButton,
                                  symbolSize: 15, tint: tint, action: action)
                if !compact {
                    Text(l10n.s.updateBannerAction).font(NotchDesign.Typography.label.font)
                        .foregroundStyle(tint).lineLimit(1)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize()
            .help(title)
        case let .downloading(progress):
            progressIndicator(title: l10n.s.updateDownloading, fraction: progress)
        case .installing:
            progressIndicator(title: l10n.s.updateInstalling)
        default:
            EmptyView()
        }
    }

    private func progressIndicator(title: String, fraction: Double? = nil) -> some View {
        HStack(spacing: NotchDesign.Spacing.xSmall) {
            if let fraction {
                NotchUpdateRing(fraction: fraction)
            } else {
                ProgressView().controlSize(.small)
            }
            if !compact {
                if let fraction {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(NotchDesign.Typography.readout.font).monospacedDigit()
                } else {
                    Text(title).font(NotchDesign.Typography.label.font).lineLimit(1).truncationMode(.tail)
                }
            }
        }
        .foregroundStyle(NotchDesign.Ink.secondary)
        .frame(minHeight: NotchDesign.Control.minimumHit)
        .frame(maxWidth: compact ? nil : 110)
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "")
    }

    /// Download progress as a ring that fills clockwise; it eases between readings
    /// and jumps under Reduce Motion.
    private struct NotchUpdateRing: View {
        let fraction: Double
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            ZStack {
                Circle().stroke(NotchDesign.Fill.track, lineWidth: NotchDesign.Control.meter / 2 + 1)
                Circle().trim(from: 0, to: min(1, max(0, fraction)))
                    .stroke(NotchDesign.Palette.accent, style: StrokeStyle(lineWidth: NotchDesign.Control.meter / 2 + 1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)
            .animation(NotchDesign.Motion.animation(NotchDesign.Motion.smooth, reduceMotion: reduceMotion), value: fraction)
        }
    }
}
