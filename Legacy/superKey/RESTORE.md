# Restore superKey
Parked 2026-10-13. Nothing here is compiled.
1. `git mv` SuperKey/ to Sources/Vorssaint/Services/SuperKey, SuperKeySettings.swift to UI/Settings, SuperKeyStrings.swift to Core, SuperKeyTapContract.swift to Tests; restore the three build.sh source lines.
2. Revert the "chore(lightness): park superKey in Legacy" commit's edits to shared files (git revert gives them all back): AppFeature case, DefaultsKey/registered defaults, panel row, settings page, shortcut "or Super key" hints, radial hold, recording tap, mouse-exception scope, tests, generate_sources.py.
3. Run `swift build --build-tests`.
