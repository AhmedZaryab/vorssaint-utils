# Vorssaint idle cost: measurement before any change

Measured 2026-10-13 on the installed build (/Applications/Vorssaint.app, one process, pid 41301), branch ours.
Honest caveat: it was not perfectly idle. A music player was playing (NotchPlayerClock was following it) and an agent strip animation was moving in the compact notch (NotchDecorativeClock display link firing). That is the state a real user is usually in, so the numbers are a realistic floor, not a cold floor.

## Numbers

| Metric | Value |
| --- | --- |
| App RSS (ps, 3 samples 10 s apart) | 418 MB, 461 MB, 461 MB (grew 42 MB in 10 s) |
| App memory footprint (top MEM) | 135 MB |
| Helper | No NowPlayingAdapter process exists. The helper is `/usr/bin/perl now-playing.pl ... watch_all` (pid 70695), RSS 28.4 MB, 0.0 to 0.1 %CPU |
| Idle CPU, ps | 3.3, 4.7, 3.6 % |
| Idle CPU, top 3 samples (5 s) | 0.0, 2.6, 2.7 %; second run 0.0, 2.2 % |
| Idle wakeups (top IDLEW, cumulative) | 467, 491, 507 across about 4 s steps, so about 4 to 6 wakeups/s |
| powermetrics | skipped, needs sudo |
| Log lines, last 5 min | 1039, so about 208 lines/min |
| Threads (sample, 5 s) | 11 threads; main is 99.8% blocked in the run loop; 4 long-lived tap/watcher threads (Window Focus, Switcher, Brightness Keys, audio IOThread) all parked |

Raw sample: scratchpad/vorssaint-sample.txt (5 s, 4018 samples at 1 ms).

### Where the active samples went (main thread, 5 s, out of 4018)
- 77 (1.9%) NotchPlayerClock.follow closure, of which 74 is `NotchMusicAutomation.clock(of:)` and 72 is `NotchMusicAutomation.access(to:)`. That is an AppleScript or Automation permission probe run once a second.
- 14 NotchService.compactActivity getter, 11 NotchSupport.modules, 9 AppFeature.isAvailable: the compact activity is recomputed repeatedly and each call re-reads UserDefaults feature flags.
- 11 NotchDecorativeClock.Target.fire from NotchAgentAnimationView: 30 fps display link doing a CA transaction commit per frame (5 of those 11 in a mach_msg to the window server).
- 8 NotchWindowHost.refreshMissionControlState (the 0.25 s mission control poll).
- 6 NotchMusicService.launch closure.
- Everything else is the run loop idling.

### Top repeated log lines (5 min)
Only 8 or fewer repeats of any single line, so nothing is spamming one message. The noise is spread out:
- 8x AppKit AutomaticTermination state
- 7x "This method should not be called on the main thread" (Security, a runtime issue: a SecKey or keychain call on main)
- 7x libsystem_trace state dumps
- 6x SecKeyCopyPublicBytes
- 6x ScreenCaptureKit SLSHWCaptureWindowListToIOSurfaceProxying, 5x ReplayKit RPDaemonProxy (something captures windows while idle, likely Dock preview or Notch Watch)
- 5x NSPasteboard data requested for public.utf8-plain-text (clipboard poll reading text)
- 5x RunningBoardServices didChangeInheritances

## Ranked idle burners

Gate column: F = gated on a featureAvailable flag, N = not gated, P = gated on playback or state only.

| # | file:line | Interval | What it does | Idle? | Gate | Fix |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Services/Notch/NotchPlayerClock.swift:40 | 1 s | Re-reads the player position through `NotchMusicAutomation.clock(of:)`, which probes Automation access each time (72 of 77 samples) | Yes, while any track plays, notch closed or not | P | Only run while the notch is expanded or lyrics are visible; cache `access(to:)` per target (the `availability` cache is skipped when nil); otherwise extrapolate from the first anchor and re-anchor on playback notifications. NowPlayingAdapter already re-anchors every 2 s, so this is a second poll of the same fact |
| 2 | UI/Notch/NotchDecorativeClock.swift:36 (used by NotchAgentAnimationView.swift:148) | 30 fps | Display link for the agent pulse and music bars, one CA commit per frame | Yes, while an agent shows as moving in the compact notch | F (notchAgents) + moving | Drop to 10 fps, or replace with one CAAnimation on a layer; stop when the notch is concealed, the screen is asleep, or the window is occluded |
| 3 | Services/Notch/NotchService.swift:483 `compactActivity` and NotchSupport.modules | per read | Computed property rebuilt from UserDefaults flags on every access, hit from timers and refresh paths (14 plus 11 plus 9 samples) | Yes | N | Memoise per revision, invalidate on defaults change notification |
| 4 | Services/Notch/NotchWindowHost.swift:531 | 0.25 s (0.08 s near overview) | Mission Control state poll, only while the panel is visible | Yes whenever the compact notch is on screen (the idle state) | Panel visible | Make it event-driven (activeSpaceDidChange plus a CGWindowList check on app activation), or 1 s when no overview was seen recently |
| 5 | Services/Notch/NotchService.swift:3154 | 1 s | readMenuSpace via Accessibility to size the compact cutout | Yes while an idle content or compact activity is shown | F (notch) | Re-read on frontmost app change and menu bar change, not on a timer; 5 s fallback |
| 6 | Services/Clipboard/ClipboardHistoryService.swift:647 | 0.8 s | Polls NSPasteboard changeCount, and reads utf8 text (5 pasteboard reads in the log) | Yes always | F (clipboardHistory = 1) | Poll changeCount only (cheap); read data only when it changes; 1.5 s |
| 7 | Services/URLCleanerService.swift:89 | 0.8 s | Second pasteboard poll | Only if URL cleaner is on | F | Share one pasteboard poller with clipboard history |
| 8 | Services/Clipboard/ClipboardAutoClearService.swift:94 | 1 s | Countdown | Only when a clear is armed | P | Use a single one shot timer for the deadline |
| 9 | Services/AgentUsage/AgentUsageService.swift:224 (tick 30 s) plus AgentLogObject.swift:72, AgentUsageArchive.swift:362, AgentCodexServer.swift:297 | 30 s plus file watch loops | Reads Claude and Codex usage logs, publishes | Yes | F (notchAgents = 1) | Stop the 30 s tick when no agent session is active and the notch is collapsed; use a file watcher |
| 10 | Services/SystemMonitor/SystemMonitor.swift:663 | intervalSeconds x ticks | Samples CPU, memory, network, disk | Only when a monitor* flag is on (all 0 here) | F | Already gated; verify it stops when all monitors are off |
| 11 | Services/KeepAwakeManager.swift:1116 | 30 s | Keep awake state check | Yes (keepAwake = 1) | F | 60 s, tolerance 10 s; skip when not active |
| 12 | App/StatusItemController.swift:300 | 30 s | Status icon refresh | Yes | N | Event-driven on state change; icon already deduped |
| 13 | Core/SecureInputMonitor.swift:88 | 2 s | Polls IsSecureEventInputEnabled | Only if a consumer needs it | P | Fine; keep tolerance |
| 14 | Services/Update/UpdateService.swift:92 | 1 h | Update check | Yes | N | Fine |
| 15 | Services/Spotify/SongPeekController.swift:97 | 0.25 s | Peek tick | Only on Spotify playback | P | Stop when peek is dismissed, 0.5 s |
| 16 | Services/DockPreview/DockPreviewService.swift:1285 (10 s), 1663 (refreshInterval) | 10 s, short | Dock window cache refresh; ScreenCaptureKit captures in the log suggest capture while idle | Yes (dockPreview = 1) | F | Capture only on dock hover; 10 s timer to 60 s |
| 17 | Services/Notch/NotchWatchService.swift:258 | configurable | Notch Watch screen fingerprint and OCR (Task.detached) | If a watch is armed | F (notchWatch = 1) | Confirm no watch armed means no loop |
| 18 | Many NSWorkspace.didActivateApplicationNotification observers (AutoQuit, ClipboardHistory, ClipboardIgnoredApps, CommandBar, FinderCutPaste, MouseNavigation, NotchService, QuitProtection, RadialMenu, RadialNowPlaying, Snippets x2, WindowActivator x3, WindowLayout, WindowPreviewProvider, WindowUseTracker, CameraPreview, QuickLauncher, RecentCapture) | per app switch | About 25 observers, each wakes on every app switch | Only on switch, not a timer | Mixed | Register in the feature's start, remove in stop; fan out through one shared dispatcher |

Not idle (run only on demand, listed to close the grep): ShelfService 2618/2650/749 (shelf visible), SmoothScrollService 435 (while scrolling), WindowMaximizer 221 and WindowLayoutService 1013 (during drag), ScreenRecorderService 562 and RecorderPointerSampler (while recording), FocusFollowsMouse 102 (flag off here), ExtraBrightnessService 148 (flag off here), FanControlService 631 (flag off here), KillProcessView 299 (window open), SpotifyQueueService 81 (music page open on Spotify), AirPlayRouteManager 337 (picker open), FinderCutPaste 593 (during a paste), WindowActivator 932 (during activation), NotchTimerService 98 and 118 (timer armed).

## Startup, regardless of which features are enabled

From AppDelegate.applicationDidFinishLaunching (App/AppDelegate.swift:57 on):
- AppAppearanceController.apply, GlobalShortcut.startObservingKeyboardLayout (distributed notification), installMainMenu, HorizontalWheelScrolling.install (line 103), HotkeyManager.syncWithPreferences.
- SongPeekController.shared.start() (line 63) and QueueCommandsProvider and SpotifyQueueDebugHook, even with notchQueue off.
- BrightnessService.restoreDisplaysLeftOff (line 97), KeepAwakeManager.recoverIfNeeded and activateOnLaunchIfNeeded.
- ShelfService status item frame hook, ClipboardHistoryService hotkey wiring.
- MaxCapacityProbe.refreshIfStale (line 163), UpdateService.startAutomaticChecks (line 165, hourly timer), Permissions sinks (lines 171 to 189) that trigger FeatureRuntime.sync, L10n sink, appBecameActive observer.
- FeatureRuntime.syncAtLaunch (line 161): runs the binding for every feature where isAvailable is true. This part is correctly gated by featureAvailable.* flags, and `loadedThisSession` is computed at init. On this machine 24 of about 50 flags are on (notch plus 10 notch sub flags, brightness, clipboardHistory, dockClick, dockPreview, keepAwake, menuBarTidy, mixer, cameraPreview), so those services start.
- Helper: now-playing.pl runs under perl watch_all (28 MB) and NowPlayingAdapter.swift:333 re-anchors every 2 s while a track moves.
- Long-lived threads created at launch: Vorssaint Window Focus, Vorssaint Switcher, Vorssaint Brightness Keys (an event tap installed even though brightnessKeysEnabled = 0), com.apple.NSEventThread, an audio IOThread (mixer), NSURLConnectionLoader.
- Memory: 135 MB footprint but 418 to 461 MB RSS, and RSS grew 42 MB in 10 s; check for a cache or image buffer growing (suspects: window preview warm task WindowPreviewProvider.swift:461 and the ScreenCaptureKit captures in the log).

## Suggested order
1. NotchPlayerClock (#1): biggest measured main thread cost, easy gate.
2. NotchDecorativeClock rate and stop conditions (#2).
3. Memoise compactActivity (#3).
4. Pasteboard pollers merged and cheapened (#6, #7).
5. Mission control and menu space polls event-driven (#4, #5).
6. Install the brightness key tap only when brightnessKeysEnabled (startup list), and move SongPeekController.start behind notchQueue.
7. Investigate the 42 MB RSS growth and the idle ScreenCaptureKit captures.
