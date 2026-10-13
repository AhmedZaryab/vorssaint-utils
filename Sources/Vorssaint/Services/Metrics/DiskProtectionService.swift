// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The volumes "Eject all disks" leaves alone. The per-disk eject buttons the
/// Disk monitor drew on top of this list are parked with that monitor in
/// Legacy/monitorDisk/split/DiskProtectionService.swift.
final class DiskProtectionService: ObservableObject {
    static let shared = DiskProtectionService()

    @Published private(set) var excludedVolumes: [String] = []

    private init() {
        reloadExclusions()
    }

    func reloadExclusions() {
        let raw = UserDefaults.standard.stringArray(forKey: DefaultsKey.diskEjectExcludedVolumes) ?? []
        let sanitized = Defaults.sanitizedDiskExclusionList(raw)
        if raw != sanitized {
            UserDefaults.standard.set(sanitized, forKey: DefaultsKey.diskEjectExcludedVolumes)
        }
        excludedVolumes = sanitized
    }

    func addExcludedVolume(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !excludedVolumes.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        let updated = Defaults.sanitizedDiskExclusionList(excludedVolumes + [trimmed])
        UserDefaults.standard.set(updated, forKey: DefaultsKey.diskEjectExcludedVolumes)
        excludedVolumes = updated
    }

    func removeExcludedVolume(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = excludedVolumes.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        UserDefaults.standard.set(updated, forKey: DefaultsKey.diskEjectExcludedVolumes)
        excludedVolumes = updated
    }
}
