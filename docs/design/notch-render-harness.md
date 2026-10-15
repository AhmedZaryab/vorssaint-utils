# Notch render harness

Draws every state of the notch island to a PNG from made-up data, so a design
change can be judged as before and after pictures. It runs in the Developer
build only, needs no clicks and no Screen Recording permission, and reads
nothing from the Mac's user.

## Run it

```sh
scripts/render-notch.sh <output dir>                      # every state, about 30 s
scripts/render-notch.sh <output dir> --only music,30-peek # a subset
scripts/render-notch.sh <output dir> --background 3a3a3c  # a grey ground instead of black
```

The script builds the Developer variant (`./build.sh --dev`, about a minute)
when any file under `Sources/`, `Resources/` or `build.sh` is newer than its
binary, then runs
`build/stage.noindex/Vorssaint (Developer).app/Contents/MacOS/VorssaintDeveloper --render-notch <dir>`.
The process draws every scene, prints one line per file and exits by itself:
0 when every scene drew, 1 when any failed (each failure is named), 2 for bad
arguments. When `python3` has Pillow, the script also writes
`<dir>/contact-sheet.png` with every picture tiled and labelled
(`scripts/notch-contact-sheet.py <dir>` makes one on its own).

`--only` takes a comma-separated list. Each item picks scenes by their full
name, by any start of the name (`30-peek`, `lockscreen`), or by any start of
the name after its number (`music` picks `04-music`, `peek` every peek). A list
that picks nothing fails and prints every name.

## Output

One PNG per state, `<output dir>/<name>.png`, at **2 pixels per point**
always, whatever the display (a 560 pt wide page is 1120 px). Each picture is
the island's real panel size: the window the island would occupy, on a black
ground (the island is black too, so a closed island at rest shows only what
it holds). The growth frames use a dark grey ground so the outline shows.

| Name | State |
| --- | --- |
| `01-closed-idle` | Closed island at rest. With the default resting content (music) and nothing playing it is an empty black outline, so the picture is black. |
| `02-closed-music` | Closed island with a song playing: cover and live bars in the wings. |
| `03-song-peek` | The next-song peek band under the closed strip. |
| `04-music` | Music page, song playing. |
| `05-lyrics` | Music page with synced lyrics open. |
| `06-queue` | Music page with the Up Next queue open. |
| `07-controls` | Controls page: volume and brightness, shortcut tiles. |
| `08-mixer` | Volume mixer, three apps. |
| `09-calendar` | Calendar page, today's events. |
| `10-calendar-month` | Calendar page on its month grid. |
| `11-timer` | Timer page, a 25 minute timer at 18:00. |
| `12-watch` | Watch page following a terminal window. |
| `13-agents` | AI agents page, Claude and Codex usage. |
| `14-files` | Files shelf with three items. |
| `15-clipboard` | Clipboard history, five entries. |
| `16-downloads` | Downloads, one active, two finished. |
| `17-scratchpad` | Scratchpad with two pads. |
| `18-camera` | Camera page before the camera starts. No camera is used. |
| `19-notifications` | Notifications page, three messages. |
| `20-notice-low-battery` | The closed island's low battery alert. |
| `21-quick-access` | The open island with its floating quick access buttons. |
| `22-update-control` | The open header offering an update. |
| `30-peek-agent-finished` | Claude finished, with its time and spend. |
| `30-peek-notification` | A message mirrored from Notification Center. |
| `30-peek-download-finished` | A download finished. |
| `30-peek-device-connected` | AirPods connected. |
| `30-peek-timer-ended` | The timer ran out. |
| `30-peek-volume` | Volume HUD at 62%. |
| `30-peek-brightness` | Brightness HUD at 70%. |
| `30-peek-keep-awake` | Keep awake strip, 1h35 left. |
| `30-peek-calendar-soon` | Calendar strip, next meeting in 12:00. |
| `30-peek-timer` | Timer strip, 18m left. |
| `30-peek-agent-working` | Agent strip while Claude works. |
| `30-peek-download-progress` | Download strip at 42%. |
| `40-grow-1` to `40-grow-3` | The island opening from the closed music strip onto the music page: at rest, halfway, settled. |
| `lockscreen-1-idle` to `lockscreen-8-agents` | The lock screen surfaces at the display's full size (1512 by 982 pt): padlock island alone, music playing, timer running, stopwatch running, timer finished, battery and keep awake lines, calendar countdown, agents working. |
| `interactions-gallery` | The interaction library's gallery: every button and slider in every state. |

## How it stays the same from run to run

- **Display.** A 14-inch MacBook Pro at its default resolution: 1512 by 982 pt,
  a 185 pt camera, a 32 pt menu bar. The island's size preset comes from the
  defaults below (spacious unless set).
- **Preferences.** Every registered default, plus a few switches the pages
  need (the island and each section on, English, the calendar countdown and
  keep awake strip on), is put in the volatile argument domain. It outranks
  anything saved, is shared by every suite and `@AppStorage`, and is never
  written. Only a key with no registered default could still fall through to
  the Developer build's own saved preferences.
- **Clock.** The process's time zone is set to whatever whole-minute offset
  makes the clock read 09:41 when each scene starts, and a scene never starts
  in the last seconds of a minute. Times shown are therefore fixed; the date
  follows the real one. Values that count (the timer, a countdown, the agent's
  elapsed time) are built from the moment of drawing, and the song's position
  is held still while it reads as playing. The timer reads a frozen clock.
- **Data.** One song with drawn cover art, a day of events, a timer, two
  agents, files, clipboard entries, notes and messages, all in
  `Support/NotchRenderFixtures.swift`. There is no randomness in the island's
  views, so there is no seed to fix.
- **No real services.** While the harness runs, `NotchRenderHarness.isActive`
  makes every service that would read files, the network, Apple events, the
  camera, Core Audio, EventKit or the hardware return early, including the
  saves that would write fixtures into the user's stores (clipboard,
  scratchpad, shelf). The fixtures are set through `applyRenderFixture`
  extensions at the end of each service's file. All of it is compiled only
  with `VORSSAINT_DEVELOPMENT`.
- **Animations** are off: every transaction disables them and the window has
  no animation behaviour. Two full runs give byte-identical PNGs for every
  scene except `40-grow-2` (see below).

## How it draws

Each scene is laid out in an invisible window (alpha 0, ignoring the mouse)
in a `NSHostingView`, given three short run-loop turns so appearing pages
settle, then drawn with `cacheDisplay(in:to:)` into a 2x bitmap. That draws
the window's own layers, so it needs no Screen Recording, unlike
`CGWindowListCreateImage`. `ImageRenderer` was tried and rejected: it draws
text fields, menus and scroll views as yellow placeholder boxes and runs
`onAppear` just the same.

The island scenes are the real `NotchView` over the black island outline, cut
to that outline, as `NotchWindowHost` composes them. A notice that reaches
further to one side shifts the outline while the view stays centred on the
camera, as the window does.

The growth frames come from the production `NotchWindowHost` itself. Its
opening is all Core Animation, so the harness starts a real opening, stops the
window's layer clock (`speed = 0`), moves `timeOffset` to the moment wanted,
and draws the presented layers.

## Known gaps

- **Blur is not drawn.** `cacheDisplay` draws layers without Core Animation
  filters, so `.blur` (the lyrics backdrop's colour blobs) and the content's
  arrival blur render sharp. Materials draw as flat tints. Shadows, masks,
  clips and `drawingGroup` content draw correctly.
- **`40-grow-2` is not byte-identical between runs.** The halfway frame is
  read from the live animation and its outline can differ by a pixel or two.
  At that moment the page has not begun to fade in (it waits for the outline),
  so the frame shows the bare outline.
- **`interactions-gallery`** shows the gallery's frozen states as laid out;
  its live controls sit at rest, since nothing presses them.
- **The lock screen's own clock and password field** belong to macOS and are
  not drawn; the wallpaper is a fixed grey gradient.
- **Liquid glass and the translucent background** are drawn off, the
  registered default. On a black ground the translucent background would look
  the same as black.
- **Not covered:** the section picker (Explore), the capture controls and
  capture preview, the tools page, the app panel, drag and drop hints, and
  hover states.
- **Running app icons** come from the system for the mixer, files and
  notifications, so they follow the macOS version.
