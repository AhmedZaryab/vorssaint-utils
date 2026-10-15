# Vorssaint notch: enabled scope (what he uses)

Owner rule: only touch what is enabled now. Everything disabled stays untouched.

## Source

- Domain: `com.vorssaint.utils` (non-empty, so no other domain was read). Read with `defaults read` only, nothing written. App was quit.
- Date: 2026-10-14. Repo branch `ours`, HEAD c5a0c849.
- Rule used: a feature is ON only if `featureAvailable.<id>` is 1 AND its enable key is true. A key missing from the live domain takes its registered default from `Core/Defaults.swift` (lines ~870 to 1145). `notchDefaultProfileInitialized = 1`, so the one-time "existing user" default flip (which would set camera, accessories, lyrics etc. false) does NOT run; registered defaults apply.
- Keys absent from the live domain, so on registered default: `notchHiddenModules` "" (no page hidden), `notchModuleOrder` "" (natural order), `notchHiddenControls` "keyboardLight,microphone,recording,panel,scratchpad", `notchControlOrder` "", `notchIdleContent` music, `notchCameraEnabled` true, `notchShelf` true, `notchScratchpad` true, `notchClipboardWindow` true, `notchVolume/Brightness/Clipboard/Capture/TrackChange/KeyboardLight/Microphone/Battery` true, `notchOpensActivity` true, `notchShowPlayingMusic` true, `notchAgentsLiveActivity` true, `notchKeepAwakeActivity` false, `notchCalendarCountdown` false, `notchCalendarTimeLeft` false, `notchLockSounds` false, `notchHomeModule` controls, `notchReturnHome` false, `notchHideUntilHover` false, `notchSilhouette` capsule, `notchDisplay` automatic.

## Enabled features

| Feature | Keys and values that make it on |
| --- | --- |
| Island master | `featureAvailable.notch`=1, `notchEnabled`=1 |
| Open on hover, hide in fullscreen | `notchOpenOnHover`=1, `notchHideInFullscreen`=1 (live). `notchSize`=spacious, custom 514x262 saved, `notchTranslucentBackground`=1, `notchLiquidGlassEnabled`=0, `notchLowBatteryTint`=1 (threshold 20; only matters if a battery reading shows) |
| Gestures | `featureAvailable.notchGestures`=1, `notchGesturesEnabled`=1 |
| Music page and closed music strip | always available; `notchPreferredPlayer`=com.spotify.client; idle content music (default) |
| Lyrics | `featureAvailable.notchLyrics`=1, `notchLyricsEnabled`=1, `notchLyricsOnline`=1 |
| Up Next queue / Spotify queue / peek band | `notchQueue`=1 + `notchQueueEnabled`=1; `spotifyQueue`=1 |
| Live equalizer | `featureAvailable.notchLiveEqualizer`=1, `notchLiveEqualizer`=1 |
| Controls page | always. Visible tiles: volume, brightness, music, mixer, keepAwake, timer, calendar (keyboardLight, microphone, recording, panel, scratchpad hidden by `notchHiddenControls` default) |
| Mixer page | `featureAvailable.mixer`=1 |
| Brightness (slider, HUD) | `featureAvailable.brightness`=1, `brightnessControlEnabled`=1, `notchBrightness` true |
| Keep Awake (tile, lock line) | `featureAvailable.keepAwake`=1. Closed-island Keep Awake strip is OFF (`notchKeepAwakeActivity` false) |
| Clipboard page and notice | `featureAvailable.clipboardHistory`=1, `clipboardHistoryEnabled`=1, `notchClipboard` true, `notchClipboardWindow` true |
| Files (shelf) page | `featureAvailable.shelf`=1, `shelfEnabled`=1, `notchShelf` true (shelf holds 0 items) |
| Calendar page, strip | `featureAvailable.notchCalendar`=1, `notchCalendarEnabled`=1. Countdown on the closed island only for events he chooses (`notchCalendarCountdown`=false, no chosen events saved now) |
| Notifications page and notice | `featureAvailable.notchNotifications`=1, `notchNotificationsEnabled`=1 |
| Timer / stopwatch / pomodoro | `featureAvailable.notchTimer`=1, `notchTimerEnabled`=1, mode timer, pomodoro focus 26 |
| Camera (mirror) page | `featureAvailable.cameraPreview`=1, `notchCameraEnabled` true (default) |
| Downloads page, notice, progress | `featureAvailable.notchDownloads`=1, `notchDownloadsEnabled`=1, folder bookmark saved |
| Scratchpad page | `featureAvailable.scratchpad`=1, `notchScratchpad` true. Reached from the quick access button `control.scratchpad`, not the controls grid |
| AI agents page, strip, notices | `featureAvailable.notchAgents`=1, `notchAgentsEnabled`=1, period month, live activity true, finish alert true, limit alert true |
| Watch page and notice | `featureAvailable.notchWatch`=1, `notchWatchEnabled`=1, condition contains |
| Quick access rail | layout saved: explore, timer, settings (left/right), music, camera (bottom), control.scratchpad (right) |
| Lock screen | `notchLockScreen`=1, `notchLockStatus`=1 (see Lock screen section) |
| Menu bar tidy, switcher, dock, window maximizer | on but NOT notch; out of scope for this job |

## Disabled features (do not touch)

`featureAvailable`=0: connectedDevices, notchMascot, monitorPower (so battery idle content, battery notice and accessory battery notices are all off), monitorCPU/Disk/GPU/Memory/Network, micMute (microphone notice and tile), screenRecorder (so Captures page and capture notice and capture controls), quickLauncher (so Tools page and quick panel), quickToggles, screenshot, screenOCR, colorPicker, commandBar, musicBlock, mediaTools, textSnippets, pastePlain, cleaner, cleaningMode, fanControl, wallpaper, windowLayout, radialMenu, and the rest of the zero list in the domain.

Off by setting although the feature is available: Keep Awake closed-island strip (`notchKeepAwakeActivity`), calendar countdown for every event, lock screen padlock sounds (`notchLockSounds`), `notchOutlineEnabled`, `notchHideMenuBarGap`=0, `notchKeyboardLight` control (hidden, tile not shown), `notchAppPanel` (default false), hide-until-hover.

## Pages in the island, in his order

`notchModuleOrder` is empty, so order is `NotchModule.allCases` filtered by availability and enable keys (`NotchSupport.modules`):

1. controls (c)
2. mixer (v)
3. music (m)
4. clipboard (b)
5. files (f)
6. calendar (a)
7. notifications (n)
8. timer (r)
9. camera (w)
10. downloads (d)
11. scratchpad (p)
12. agents (g)
13. watch (o)

Not in the island: captures (screenRecorder off), tools (quickLauncher off). Home page is controls (`notchHomeModule` default). Open question: his real order might be changed in the layout editor but nothing is saved, so this natural order is what he sees.

## Closed island activities and notices that can fire

Resting content (`notchIdleContent` = music): the music strip shows while a song plays (`notchShowPlayingMusic` true, Spotify preferred), with live equalizer bars. Battery and agents resting content are not chosen (battery also impossible, monitorPower off).

Closed activities (strips): music strip (`NotchMusicStrip`), timer strip while a session runs, agent strip while an agent works (`notchAgentsLiveActivity`), calendar strip only for a chosen event, next-song peek band (queue on). Keep Awake strip is OFF.

Notices (`NotchEvent` routes, priority/duration in `NotchSupport.swift`):

| Notice | Fires? | Why |
| --- | --- | --- |
| volume (3, 1.6s) | yes | mixer on |
| brightness (3, 1.6s) | yes | brightness control on |
| keyboardLight (3, 1.6s) | yes if Mac has one | `notchKeyboardLight` default true, brightness on; control tile hidden but the notice route is on |
| timer (2, 6s) | yes | |
| watch (2, 6s) | yes | |
| systemNotification (1, 3s) | yes | |
| agents (1, 5s) | yes | finish and limit alerts |
| clipboard (0, 2.5s) | yes | |
| download (0, 6s) | yes | |
| track (0, 3s) | yes | `notchTrackChange` default true |
| battery | NO | monitorPower off |
| accessory | NO | needs monitorPower |
| capture | NO | screenRecorder off |
| microphone | NO | micMute off |

## Lock screen

Service: `Services/Notch/NotchLockScreenService.swift`. Support: `NotchLockScreenSupport.swift`. View: `UI/Notch/NotchLockScreenView.swift`. It draws up to three window layers over the lock screen.

Pieces Vorssaint draws:

1. Padlock island (`NotchLockScreenIsland`): the island at rest with a lock icon (closes on lock, opens on unlock) beside the camera, equalizer bars on the other side while a song plays. Only on a notched display. ON (`notchEnabled`; shows with the scene).
2. Now Playing pane (`NotchLockScreenPlayer`): cover, title, artist, seek timeline, previous/play/next on Liquid Glass between the clock row and login controls. Gate `music` = Music page present: ON. Shows while playing, or paused after it played while locked.
3. Activities line (`NotchLockScreenActivities`) under the system clock, one line, gives up the last entries first when too long. Entries in order and their gates:
   - timer or stopwatch or pomodoro (`gates.timer`, needs a running session): ON
   - calendar countdown (`gates.countdown` / `timeLeft` / chosen event): OFF unless he picks an event (both keys false)
   - agents working (`gates.agents` = `notchAgentsLiveActivity` and agents on, only while an agent is live): ON
   - downloads in progress, percent only (`gates.downloads`): ON
   - battery percent and charging icon (`gates.battery` = `notchLockStatus`): ON. Note this reads the battery directly, it does NOT need monitorPower.
   - Keep Awake cup with time left or infinity (`gates.keepAwake` = `notchLockStatus` and keepAwake available): ON
4. Padlock sounds (`notchLockSounds`): OFF (not a visual).

Best reading of "all four lock screen widgets": the four things that appear together and he enabled are (a) the padlock island, (b) the Now Playing pane, (c) the activities line with timer or stopwatch, and (d) the status entries on that line (battery and Keep Awake, enabled by `notchLockStatus`). Alternative reading: four entries of the activities line, most likely timer/stopwatch, agents, battery, Keep Awake (downloads fires only during a download; calendar is off). Needs his confirmation, see Open questions.

Who draws the large clock: macOS. Vorssaint does not draw it. `NotchLockScreenLayout` only measures where the system date and clock end ("macOS draws the lock screen's date, clock and login controls in one window") and places the activities line 18pt under that, and the player above the login controls. `NotchDecorativeClock.swift` is a CADisplayLink throttle for music bars and agent pulses, unrelated to the lock screen clock. No `Text` or clock view for the time exists in the lock screen files.

## File scope table

UI/Notch (path prefix `Sources/Vorssaint/UI/Notch/`):

| File | Feature | Scope |
| --- | --- | --- |
| NotchView.swift | island shell, page host, header, routes `.tools` and `.captures` pages too | SHARED |
| NotchComponents.swift | shared components, buttons, layout | SHARED |
| NotchCapsuleViews.swift | capsule silhouette closed views (non-notched displays) | SHARED |
| NotchNoticeView.swift | notice HUD | SHARED |
| NotchSectionsView.swift | sections gallery (explore) | SHARED |
| NotchQuickAccessView.swift | quick access rail buttons | SHARED |
| NotchMirrorView.swift | closed island mirror on other displays | SHARED |
| NotchIslandAlert.swift | alert above island | SHARED |
| NotchScrollEdgeFade.swift | scroll fade helper | SHARED |
| NotchLevelSlider.swift | sliders for volume and brightness | SHARED |
| NotchDecorativeClock.swift | animation throttle | SHARED |
| NotchUpdateControl.swift | update button in header | SHARED |
| NotchControlsView.swift | Controls page (tiles: volume, brightness, music, mixer, keepAwake, timer, calendar; mic, recording, keyboard light, panel, scratchpad tiles are hidden) | IN (tiles for disabled features stay untouched) |
| NotchMusicView.swift | Music page | IN |
| NotchMusicStrip.swift | closed music strip | IN |
| NotchSongPeekBand.swift | next song peek | IN |
| NotchQueueView.swift | Up Next queue | IN |
| NotchSpotifyQueueSection.swift | Spotify queue (Spotify is preferred player) | IN |
| NotchLyricsView.swift | lyrics | IN |
| NotchLyricsBackdrop.swift | lyrics backdrop | IN |
| NotchEqualizerBars.swift | equalizer bars | IN |
| NotchMixerView.swift | Mixer page | IN |
| NotchClipboardView.swift | Clipboard page | IN |
| NotchFilesView.swift | Files (shelf) page | IN |
| NotchCalendarView.swift | Calendar page | IN |
| NotchCalendarMonthView.swift | month grid | IN |
| NotchCalendarStrip.swift | closed calendar strip | IN |
| NotchNotificationsView.swift | Notifications page | IN |
| NotchTimerView.swift | Timer page | IN |
| NotchTimerRuler.swift | timer dial | IN |
| NotchTimerStrip.swift | closed timer strip | IN |
| NotchCameraView.swift | Camera page | IN |
| NotchDownloadsView.swift | Downloads page | IN |
| NotchScratchpadView.swift | Scratchpad page | IN |
| NotchAgentsView.swift | AI agents page | IN |
| NotchAgentComponents.swift | agent cards | IN |
| NotchAgentStrip.swift | closed agent strip | IN |
| NotchAgentAnimationView.swift | agent animation | IN |
| NotchWatchView.swift | Watch page | IN |
| NotchLockScreenView.swift | lock screen island, player, activities | IN |
| NotchKeepAwakeStrip.swift | closed Keep Awake strip, gated by `notchKeepAwakeActivity` (false) | OUT (dormant; re-check if he turns it on) |
| NotchCaptureControlsView.swift | capture overlay controls, screenRecorder off | OUT |

UI/Settings (prefix `Sources/Vorssaint/UI/Settings/`):

| File | Feature | Scope |
| --- | --- | --- |
| NotchSettings.swift | all island settings (984 lines, mixed) | SHARED (only enabled sections) |
| NotchContentEditor.swift | pages and order editor | SHARED |
| NotchLayoutEditor.swift | layout and quick access editor | SHARED |
| NotchEditorItem.swift | editor item model | SHARED |
| NotchSettingsTabRow.swift | settings tab row | SHARED |
| NotchAgentsSettings.swift | AI agents settings | IN |
| NotchCalendarSelection.swift | calendar picker | IN |

Services/Notch (prefix `Sources/Vorssaint/Services/Notch/`, for reference; builders touching logic only):

| Group | Scope |
| --- | --- |
| NotchSupport, NotchService, NotchWindowHost, NotchOverlaySpace, NotchMenuBarSpace, NotchSectionPaging, NotchSliderEditing, NotchVolumeKeyGate, NotchGestureSupport | SHARED |
| NotchMusic*, NotchPlayback*, NotchPlayerClock, NotchPreferredPlayer, NotchShuffleService, NotchLyrics*, NotchQueueSupport, NotchAudioLevel* | IN |
| NotchCalendar*, NotchTimer*, NotchDownload*, NotchFileTools*, NotchNotification*, NotchWatch*, NotchAgentSupport | IN |
| NotchLockScreenService, NotchLockScreenSupport | IN |
| NotchKeepAwakeSupport | IN for the tile and lock line; the closed strip logic is dormant |
| NotchAccessoryService, NotchAccessorySupport | OUT (monitorPower off) |

## Open questions

1. Which four lock screen widgets? Best guess is padlock island, Now Playing pane, activities line, status entries (battery, Keep Awake). Alternative: four entries of the activities line. Ask him, or build all pieces so any reading is covered.
2. Is a camera housing present on the Mac he looks at? Padlock island only draws on a notched display; capsule files (NotchCapsuleViews) matter for an external monitor.
3. Keyboard light notice route is on by default but the tile is hidden; whether his Mac has a keyboard light decides if that notice fires.
4. Camera page is on only by registered default (`notchCameraEnabled` not saved). The quick access rail has a camera button, so he uses it.
5. Scratchpad page is reached only from the quick access rail, since its controls-grid tile is hidden. Treat as in scope.
6. NotchControlsView and NotchView also contain code for Captures, Tools, microphone and recording. Builders must leave those branches alone.
7. Calendar countdown on the lock line and closed island fires only if he picks an event from the menu; none chosen now.
