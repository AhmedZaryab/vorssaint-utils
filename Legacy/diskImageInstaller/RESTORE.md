# Restore diskImageInstaller
Parked 2026-10-13 (lightness cut). git mv DiskImageInstaller/ to Sources/Vorssaint/Services/ and DiskImageInstallerStrings.swift to Sources/Vorssaint/Core/.
Re-add AppFeature.diskImageInstaller (FeatureCatalog case, group clipboardFiles, icon externaldrive.badge.plus, permissions appManagement, FeaturePresets idle), FeatureHubSettings title and hubDescription, FeatureVisibilitySupport destination .features, FeatureRuntime syncWithPreferences entry.
Re-add DefaultsKey diskImageInstaller TrashesDownload(true), RevealsApp(false), UseUserApplications(false) plus registered defaults, and the two DiskImage lines in build.sh.
Removed test assertions are in this change's diff (FeatureCatalog, Settings, Update, AppManagement, OverlayPanel tests).
