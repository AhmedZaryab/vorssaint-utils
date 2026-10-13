# Restore keyboardDebounce
1. git mv Legacy/keyboardDebounce/KeyboardDebounce Sources/Vorssaint/Services/ ; KeyboardDebounceSettings.swift to Sources/Vorssaint/UI/Settings/ ; KeyboardDebounceTapTests.swift to Tests/.
2. Re-add AppFeature case keyboardDebounce and SettingsPage/panel case keyDebounce (see the parking commit diff for FeatureCatalog, FeaturePresets, FeatureRuntime, FeatureVisibilitySupport, SettingsView, SettingsDirectory, FeatureHubSettings, MenuPanelView, PanelLayout, AppDelegate).
3. Re-add the keyDebounce* and descKeyboardDebounce strings in Localization.swift, Localizations/*, FeatureHubStrings.swift, and the DefaultsKey/Defaults entries (keyboardDebounce*, migrateLegacyKeyboardDebounceWindow, sanitizedKeyboardDebounceWindow).
4. Re-add the KeyboardDebounce tests in Tests/ (PointerInputFeatureTests, AppManagementFeatureTests, SwitcherModelFeatureTests, MetricsTests, generate_sources.py) and the SelfUninstall/CleaningModeManager/AppDelegate suspend() and syncWithPreferences() calls.
5. Easiest path: git revert the commit "chore(lightness): park keyboardDebounce in Legacy".
