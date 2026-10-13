# Restore audioPriority
1. git mv the three files in this folder back: AudioPriorityService.swift and AudioPrioritySection.swift to their Sources/Vorssaint paths (Services/Audio, UI/MenuPanel), AudioPriorityTests.swift to Tests/.
2. Re-add the AppFeature.audioPriority case and its switch arms (FeatureCatalog, FeaturePresets, FeatureRuntime, FeatureVisibilitySupport, SettingsView, GeneralToolSettings, PanelLayout, FeatureHubSettings, MenuPanelView).
3. Re-add the audioPriority* DefaultsKey constants, defaults and sanitizers (Defaults.swift) and the audioPriority* / titleAudioPriority / descAudioPriority strings in Localization, FeatureHubStrings and every Strings+*.swift.
4. Re-wire MixerSection and NotchMixerView to AudioPriorityService.shared.inputPriorityEnabled (now literal false), plus AudioInputDeviceManager and MixerRoutingSupport.
5. Use `git show <this commit>^:path` or `git revert` of the parking commit for the exact old lines.
