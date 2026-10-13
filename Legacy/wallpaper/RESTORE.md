# Restore wallpaper
1. git mv Wallpaper Sources/Vorssaint/Services/Wallpaper; WallpaperSection.swift to UI/MenuPanel/; WallpaperStrings.swift to Core/; WallpaperTests.swift to Tests/.
2. Re-add AppFeature.wallpaper in FeatureCatalog.swift (all switch lists, icon "photo.on.rectangle"), FeaturePresets.swift, FeatureRuntime.swift (.wallpaper: syncWithPreferences).
3. Re-add PanelLayout/PanelID .wallpaper (+ MenuPanelView height 480, showWallpaper, WallpaperSection case), PanelLayoutEditor, FeatureHubSettings, SettingsDirectory, FeatureVisibilitySupport (anchor + destination), QuickToolsSettings section.
4. Re-add DefaultsKey panelShowWallpaper, wallpaperApplyAllDisplays, wallpaperFilter, wallpaperOwnBookmarks, wallpaperExcludedOwnPaths (+ defaults, backup exclusions) and the tests' "wallpaper" entries.
5. git log -1 on the chore/cut-wallpaper commit shows every removed line; revert it to restore all at once.
