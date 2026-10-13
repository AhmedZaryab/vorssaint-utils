# Restore bluetoothSleep
1. git mv the three files in this folder back: Service and Support to Sources/Vorssaint/Services/Bluetooth/, Strings to Sources/Vorssaint/Core/; re-add the two Bluetooth lines to build.sh.
2. Re-add `bluetoothSleep` to AppFeature (FeatureCatalog: case, group, icon, enabledKeys, availability and order lists), FeatureSettingsSection (FeatureVisibilitySupport: case, group, destination, energy list), FeaturePresets, FeatureRuntime (`.bluetoothSleep: { BluetoothSleepService.shared.syncWithPreferences() }`).
3. Re-add DefaultsKey bluetoothSleepEnabled/RestoreOnWake/RestorePending plus their registered defaults, and the RestorePending entry in SettingsBackupSupport's not-exported list.
4. Re-add the bluetoothCard and focus cases in EnergySettings, titles in FeatureHubSettings, and the search entry in SettingsDirectory.
5. Restore the removed Tests (git show chore/cut-bluetoothSleep^:Tests/FeatureCatalogTests.swift) and run swift build --build-tests.
