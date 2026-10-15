// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchNotificationsView: View {
    let size: CGSize
    @ObservedObject private var service = NotchNotificationService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchNotificationStrings { FeatureStrings.notchNotifications(l10n.language) }

    var body: some View {
        Group {
            if !permissions.accessibility {
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.small) {
                    PermissionRow(kind: .accessibility)
                    Text(text.privacy).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if service.items.isEmpty {
                NotchEmptyView(symbol: "bell", message: (service.monitoring ? text.empty : text.waiting) + "\n" + text.privacy)
            } else {
                let gutter = NotchDesign.Spacing.gutter
                let rows = NotchLayout.railRows(count: service.items.count,
                                                perRow: NotchLayout.railCapacity(width: size.width, itemWidth: 240, spacing: gutter),
                                                rowHeight: 120, spacing: gutter, height: size.height)
                let cardHeight = (size.height - CGFloat(rows - 1) * gutter) / CGFloat(rows)
                NotchRail(items: service.items, rows: rows, itemWidth: 240, width: size.width) { item in
                    NotchNotificationRow(item: item, service: service, text: text)
                        .frame(height: cardHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.locale, l10n.language.formattingLocale())
    }
}

/// The page shows only the cards, so clearing sits in the island's header
/// like the captures page's. Observes the inbox on its own, so a new message
/// does not redraw the island.
struct NotchClearNotificationsButton: View {
    @ObservedObject private var notifications = NotchNotificationService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // A fuse: a press lights it, the control becomes Undo while it burns, and
        // the inbox clears when it burns down. The confirm alert stays for the
        // keyboard path in NotchView.
        let title = FeatureStrings.notchNotifications(l10n.language).clearAll
        NotchFuseButton(title, symbol: "trash") { NotchNotificationService.shared.clearAll() }
            .disabled(notifications.items.isEmpty || notifications.openingID != nil)
    }

    /// With the system banner dismissed, a banner shown while the island was
    /// closed may never reach Notification Center before macOS 27, so the
    /// island can hold the only copy. Clearing asks first, above the island.
    static func confirmClearAboveIsland() {
        DispatchQueue.main.async {
            let l10n = L10n.shared
            let title = FeatureStrings.notchNotifications(l10n.language).clearAll
            guard NSAlert.confirmAboveIsland(title, message: "", action: title, destructive: true,
                                             cancel: l10n.s.uninstallerCancel) else { return }
            NotchNotificationService.shared.clearAll()
        }
    }
}

/// One card per message: its app and actions on top, the text below taking
/// whatever room the card has.
private struct NotchNotificationRow: View {
    let item: NotchSystemNotification
    @ObservedObject var service: NotchNotificationService
    let text: NotchNotificationStrings
    @State private var feedback: String?
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.xSmall) {
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                NotchNotificationAppIcon(app: item.content.app, size: 20)
                Text(item.content.app.isEmpty ? text.title : item.content.app)
                    .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
                    .lineLimit(1)
                Spacer(minLength: NotchDesign.Spacing.xxSmall)
                Text(item.received, format: .dateTime.hour().minute())
                    .font(NotchDesign.Typography.caption.font).monospacedDigit().foregroundStyle(NotchDesign.Ink.secondary)
                if service.openingID == item.id {
                    ProgressView().controlSize(.mini)
                } else if service.canOpen(item) {
                    NotchCommitButton(text.open, symbol: "arrow.up.forward.app", kick: .up,
                                      size: NotchDesign.Control.iconButton, symbolSize: 13,
                                      tint: NotchDesign.Ink.secondary) {
                        feedback = nil
                        service.open(item.id) { result in
                            if result == .unavailable || result == .uncertain { feedback = text.unavailable }
                        }
                    }
                    .disabled(service.openingID != nil)
                }
                NotchNotificationDismissButton(title: text.dismiss) {
                    withAnimation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.exit) { service.dismiss(item.id) }
                }
                .disabled(service.openingID == item.id)
            }
            .frame(height: NotchDesign.Control.rowHeight)
            // The 28 pt header row keeps its hit targets but its 4 pt of air above the 20 pt
            // icon would make the top inset 16 against 12 on the sides; pull the row up so
            // the icon sits cardPadding from the top and the two text lines centre on it.
            .padding(.top, -(NotchDesign.Control.rowHeight - 20) / 2)
            Text(item.content.title).font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.primary).lineLimit(2)
            if !item.content.subtitle.isEmpty {
                Text(item.content.subtitle).font(NotchDesign.Typography.callout.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
            }
            if !item.content.body.isEmpty {
                Text(item.content.body).font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if let message = feedback ?? (service.unavailableID == item.id ? text.unavailable : nil) {
                Text(message).font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Palette.warning).lineLimit(1)
            }
        }
        .padding(NotchDesign.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NotchDesign.Fill.card, in: shape)
        .overlay { shape.fill(NotchDesign.Fill.hover.opacity(hovered ? 1 : 0)).allowsHitTesting(false) }
        .overlay {
            if contrast == .increased {
                shape.strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovered = $0 }
        .animation(NotchDesign.Motion.fade, value: hovered)
        .clipShape(shape)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
    }
}

/// Dismisses one message: a tap that answers on press and leaves on an exit.
private struct NotchNotificationDismissButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(NotchDesign.Icon.button.font)
                .foregroundStyle(NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
        }
        .buttonStyle(NotchPressStyle())
        .help(title)
        .accessibilityLabel(title)
    }
}

/// A banner held open under the pointer: the whole message with its actions,
/// laid out with the fonts and limits the service measured it with.
struct NotchNotificationPreviewView: View {
    let notice: NotchNotice
    let content: NotchNotificationContent
    @ObservedObject var service: NotchService
    @ObservedObject private var notifications = NotchNotificationService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchNotificationStrings { FeatureStrings.notchNotifications(l10n.language) }
    private var item: NotchSystemNotification? {
        notifications.items.first { $0.id == notice.notificationID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchNotificationPreviewLayout.spacing) {
            HStack(spacing: NotchDesign.Spacing.small) {
                NotchNotificationAppIcon(app: content.app, size: NotchNotificationPreviewLayout.iconSize)
                Text(content.app.isEmpty ? text.title : content.app)
                    .font(NotchDesign.Typography.stripPrimary.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .lineLimit(1)
                Spacer(minLength: NotchDesign.Spacing.small)
                if let item {
                    Text(item.received, format: .dateTime.hour().minute())
                        .font(NotchDesign.Typography.caption.font).monospacedDigit()
                        .foregroundStyle(NotchDesign.Ink.secondary)
                }
                NotchNotificationDismissButton(title: text.dismiss) { service.dismissNotification(notice) }
            }
            .frame(height: NotchNotificationPreviewLayout.headerHeight)
            if !content.title.isEmpty {
                Text(content.title)
                    .font(Font(NotchNotificationPreviewLayout.titleFont as CTFont))
                    .lineLimit(NotchNotificationPreviewLayout.titleLines)
            }
            if !content.subtitle.isEmpty {
                Text(content.subtitle)
                    .font(Font(NotchNotificationPreviewLayout.subtitleFont as CTFont))
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .lineLimit(NotchNotificationPreviewLayout.subtitleLines)
            }
            if !content.body.isEmpty {
                Text(content.body)
                    .font(Font(NotchNotificationPreviewLayout.bodyFont as CTFont))
                    .foregroundStyle(NotchDesign.Ink.primary)
                    .lineLimit(NotchNotificationPreviewLayout.bodyLines)
                    .textSelection(.enabled)
            }
            HStack(spacing: NotchDesign.Spacing.small) {
                if let item, notifications.canOpen(item) {
                    NotchCommitButton(text.open, symbol: "arrow.up.forward.app", kick: .up,
                                      size: NotchDesign.Control.iconButton, symbolSize: 13) { service.activateNotice(notice) }
                        .disabled(notifications.openingID != nil)
                }
                if notifications.openingID == notice.notificationID { ProgressView().controlSize(.small) }
                Spacer(minLength: NotchDesign.Spacing.small)
                if notifications.items.count > 1 {
                    Button { service.open(.notifications) } label: {
                        HStack(spacing: NotchDesign.Spacing.xxSmall) {
                            Image(systemName: "tray.full").font(NotchDesign.Icon.button.font)
                            Text(notifications.items.count, format: .number)
                                .font(NotchDesign.Typography.readout.font).monospacedDigit()
                        }
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .padding(.horizontal, NotchDesign.Spacing.medium)
                        .frame(height: NotchDesign.Control.rowHeight)
                    }
                    .buttonStyle(NotchPressStyle(shape: .capsule))
                    .help(text.title)
                    .accessibilityLabel(text.title)
                    .accessibilityValue(Text(notifications.items.count, format: .number))
                }
            }
            .frame(height: NotchNotificationPreviewLayout.actionHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.accessibilityText)
        .environment(\.locale, l10n.language.formattingLocale())
    }
}

struct NotchNotificationAppIcon: View {
    let app: String
    let size: CGFloat
    @ObservedObject private var service = NotchNotificationService.shared

    var body: some View {
        // Apple's icon corner is about 22 percent of the side, continuous.
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        Group {
            if let icon = service.icon(for: app) {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(NotchDesign.Ink.secondary)
                    .frame(width: size, height: size)
                    .background(NotchDesign.Fill.control, in: shape)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
