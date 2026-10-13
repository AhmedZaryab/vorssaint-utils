// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// What a removal left behind, and why. Sandboxed app data lives in
/// ~/Library/Containers, which macOS keeps behind Full Disk Access; the
/// administrator prompt Finder shows covers file ownership, not that
/// permission, so those items are refused however the removal is attempted.
/// Naming them at the moment they survive is the only point where the
/// permission has visibly cost the person something.
struct UninstallFailureNote: View {
    let items: [AppUninstaller.Leftover]
    var compact = false

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared

    private static let namesShown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            Text(l10n.s.uninstallerSomeFailed)
                .font(compact ? .system(size: 10) : .caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items.prefix(Self.namesShown)) { item in
                Text(item.name)
                    .font(compact ? .system(size: 9.5) : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if items.count > Self.namesShown {
                Text(String(format: l10n.s.uninstallerFailedMoreFormat,
                            items.count - Self.namesShown))
                    .font(compact ? .system(size: 9.5) : .caption2)
                    .foregroundStyle(.tertiary)
            }
            if !permissions.fullDiskAccess,
               UninstallerSupport.failureNeedsFullDiskAccess(paths: items.map(\.url.path)) {
                FullDiskAccessNote(compact: compact, reason: l10n.s.uninstallerFailedNeedsFDA)
            }
        }
    }
}
