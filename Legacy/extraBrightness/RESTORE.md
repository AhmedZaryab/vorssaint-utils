# Restore extraBrightness
1. `git mv Legacy/extraBrightness/*.swift Sources/Vorssaint/Services/Display/`
2. Re-add `case extraBrightness` to AppFeature and every switch (FeatureCatalog, FeaturePresets, FeatureRuntime binding, FeatureVisibilitySupport, SettingsDirectory, FeatureHubSettings); see `git show <cut commit>` for each line.
3. Re-add DefaultsKey extraBrightnessEnabled/Level + registered defaults, and the extraBrightness*/descExtraBrightness strings in Localization, FeatureHubStrings and every Localizations/Strings+*.swift.
4. Re-add the EnergySettings card/anchor, the BrightnessSection ExtraBrightnessPanelToggle, AppDelegate/UpdateService stop()/sync calls.
5. Re-add the Tests/ blocks (AppManagementFeatureTests ExtraBrightnessSupport block, FeatureCatalogTests ids), then `swift build --build-tests`.
