# Switcher shows icons, not window previews: root cause

Investigated 2026-10-12 22:30 to 22:37 local, branch `ours`, installed app `/Applications/Vorssaint.app` (pid 30753, launched 22:33:53), macOS Darwin 25.6.

## Short answer

Vorssaint does not have Screen Recording permission. The old Screen Recording entry belonged to a differently signed copy, so macOS refused it; then a `tccutil` reset at 22:33:51 deleted it. Accessibility was granted again after that, Screen Recording never was. Without Screen Recording the preview code bails out on its first line and the cards draw the app icon. No code change is needed.

## How the switcher decides: preview or icon

A card shows a live preview only if every gate below passes. Fail any one and the card falls back to the app icon, with no error and no log line.

1. **Simple mode off.** `switcherSimpleMode` true turns capture off entirely (`SwitcherSupport.capturesPreviews`, SwitcherSupport.swift:550; used at AppSwitcher.swift:243, 1035, 1071). Live value: `0`, passes.
2. **Icon row mode.** `switcherIconRowMode` (or simple mode) switches to the icon row layout (SwitcherView.swift:58). The icon row can still show previews for the selected app's windows, but the main grid is icons. Live value: `0`, passes.
3. **Screen Recording granted.** `WindowPreviewProvider.refreshPreviews` starts with `guard Permissions.shared.screenRecording` (WindowPreviewProvider.swift:68). Warming has the same guard (line 444). `Permissions.shared.screenRecording` is `CGPreflightScreenCaptureAccess()` polled in Permissions.swift:206. If false, the provider cancels and returns. Nothing is captured, nothing is cached. **This is the gate that fails.**
4. **Front app not in the exclusion list.** `switcherPreviewExcludedApps` pauses capture while a listed app is frontmost (WindowPreviewProvider.swift:509). Live value: empty list, passes.
5. **Per window capture.** First the private window server call `CGSHWCaptureWindowList` (line 226 onward). If it returns nothing, or only a clipped slice of the window, the window goes to the ScreenCaptureKit fallback (`SCShareableContent` then `SCScreenshotManager.captureImage`, lines 157 to 185). Any failure there is a silent `continue`, so that one card keeps its icon.
6. **Stage Manager strip windows.** A capture that looks like the tilted strip artwork is replaced by a rectified stand in only when nothing better is cached (lines 114 to 130).
7. **Cache.** On open, the switcher first shows whatever is already in the in memory cache (AppSwitcher.swift:1035 to 1042), then fresh captures stream in through `enqueuePreviewUpdate`. The cache is filled by those refreshes and by warming each time an app becomes active. On a first open with permission, cards can show icons for a fraction of a second, then previews arrive.
8. **Drawing.** SwitcherView.swift:973 (grid) and :801: `if let preview` draws the image, otherwise the app icon.

`switcherPreviewSize` (live value `normal`) only changes the pixel size (`640 * PreviewSizing.switcherScale`), never whether a preview is drawn. There is no feature flag beyond `featureAvailable.switcher` (live value `1`).

## Evidence

Live defaults (`defaults read com.vorssaint.utils | grep -i switcher`):

```
switcherEnabled = 1;  switcherSimpleMode = 0;  switcherIconRowMode = 0;
switcherPreviewSize = normal;  switcherPreviewExcludedApps = ( );
featureAvailable.switcher = 1;  switcherTakeOverSystemShortcuts = 1;
```

So gates 1, 2 and 4 pass. Only permission is left.

TCC log (`/usr/bin/log show --last 60m --predicate 'subsystem == "com.apple.TCC" OR process == "tccd"'`):

1. From 22:05 to 22:33, about 25 times: `Failed to match existing code requirement for subject com.vorssaint.utils and service kTCCServiceScreenCapture`. A Screen Recording entry existed, but it was recorded against a different code signature (an earlier build or the official Vorssaint). The current app is signed by `Vorssaint Utils Signing`, no team id, designated requirement `identifier "com.vorssaint.utils" and certificate root = H"ed6e65ef..."`, so the old entry does not apply to it.
2. 22:33:51.163 and 22:33:51.185: `TCCDEvent: type=Delete` for `kTCCServiceAccessibility` and `kTCCServiceScreenCapture`, identifier `com.vorssaint.utils`. Sender pid 30702 made 16 `TCCAccessResetInternal` calls: a `tccutil reset` run just before the relaunch.
3. 22:33:53: the new app (pid 30753) launches. Its own Screen Recording preflight (msgID 30753.4) and the WindowServer check on its behalf (msgID 400.2207) both return `authValue=1` (no entry, not allowed). For comparison Chrome's check returns `authValue=2` (allowed).
4. 22:33:53.567 and 22:34:04.190: `type=Modify` for `kTCCServiceAccessibility`. That is the Accessibility prompt and the owner switching it on. That is why Cmd+Tab now works.
5. No `Create` or `Modify` event for `kTCCServiceScreenCapture` from 22:33:51 to 22:36:49. Screen Recording was never granted to this build.

Vorssaint's own log for the last 15 minutes has no capture, ScreenCaptureKit or TCC errors. That matches the code: the provider returns quietly when permission is missing, so the silence is expected.

A fresh `swift` script calling `CGPreflightScreenCaptureAccess()` printed `true`, but that reflects the terminal's own grant (the responsible process), not Vorssaint's. It does not contradict the above.

## Hypotheses considered

1. **Screen Recording missing for this signature.** Confirmed by the TCC log: code requirement mismatch, then the entry was deleted, then `authValue=1` for pid 30753.
2. **A setting turns previews off** (simple mode, icon row, exclusions, preview size). Ruled out: every value in defaults is the preview friendly one.
3. **The capture API is broken on this macOS** (CGWindowListCreateImage nil, needs ScreenCaptureKit). Ruled out as the cause: the app never calls `CGWindowListCreateImage`. It uses `CGSHWCaptureWindowList` with a ScreenCaptureKit fallback, and neither runs, because gate 3 returns first.
4. **Empty cache on first open.** Ruled out as the cause: with permission, a refresh fills the cards within the same session. Without permission the cache can never fill.

## Fix: what to click (no code change)

1. Open System Settings, Privacy and Security, Screen and System Audio Recording.
2. If Vorssaint is listed, select it and remove it with the minus button. An entry left over from another signature can look switched on and still not count.
3. Click plus, choose `/Applications/Vorssaint.app`, make sure the switch is on.
4. When macOS asks to Quit and Reopen, accept. If it does not ask, quit Vorssaint from its menu and open it again. The window server checks permission per process, so a relaunch is the reliable way to make it take effect.
5. Press Cmd+Tab, release, press it again. The first open can briefly show icons while captures land; the second open shows previews from the cache straight away.

Alternative from inside the app: Settings, Switcher shows a Screen Recording permission row when it is missing (SwitcherSettings.swift:70 to 73). Requesting from there floats the permission guide card, whose start over button (PermissionGuideOverlay.swift:53) runs `tccutil reset ScreenCapture com.vorssaint.utils` and asks again.

Do not run `tccutil reset All com.vorssaint.utils` again after granting. That is what removed it this time.

## Will it stay granted after the next rebuild?

Yes, as long as every build is signed with the same `Vorssaint Utils Signing` certificate. The designated requirement pins the certificate root, not the binary hash, so a rebuild signed the same way still matches. An ad hoc signed build, or a build signed with a different certificate, will hit the same "failed to match existing code requirement" and lose both permissions again.

## Optional improvement (not required)

The switcher gives no hint that previews are off for lack of permission. A small "Turn on Screen Recording for previews" line in the panel when `capturesPreviews && !Permissions.shared.screenRecording` would have made this obvious in one glance. Regression test: a `SwitcherSupport` unit test asserting the hint shows exactly when previews are wanted and permission is missing.

## Investigation note

In zsh, `log` is a builtin. `log show ...` silently prints nothing. Use `/usr/bin/log show ...`.
