# Notch design

The spec for every pixel and every motion in Vorssaint's notch. A builder should be able to restyle any notch view from this page and `Sources/Vorssaint/UI/Notch/NotchDesign.swift` without asking a question. When this page and the token file disagree, the token file wins and this page gets fixed.

Sources behind the rules: Apple's Human Interface Guidelines (`.claude/skills/apple-design/references/hig/`, cited as `file.md`), Apple's SwiftUI guidance (`apple-swiftui-specialist`), `swiftui-expert`, and Emil Kowalski's `emil-apple-design` and `emil-design-eng`. Cited as `[HIG layout.md]`, `[Emil]`.

Contents: 1 Principles. 2 Geometry. 3 Anatomy. 4 Layout grid. 5 Type. 6 Colour. 7 Materials and borders. 8 Motion. 9 Feel. 10 Controls. 11 Peeks. 12 The song peek band. 13 Accessibility. 14 Never. 15 Per-page checklist. 16 Migration table.

---

## 0. Where we start

The inventory of `Sources/Vorssaint/UI/Notch` (42 files, 12,769 lines) on 2026-10-14, before any migration:

| Literal | Uses | Distinct values |
| --- | --- | --- |
| `.font(.system(size:` and `systemFont(ofSize:` | 217 | 22 sizes, from 7 to 30 pt; five of them (7, 8, 8.5, 9, 9.5) under Apple's 10 pt macOS floor, used 40 times |
| `cornerRadius:` | 99 | 18 |
| `.opacity(` and `withAlphaComponent(` | 147 | 37 |
| `spacing:` | 245 | 17 |
| `.padding(` with a number | 71 | 14 |
| `lineWidth:` | 23 | 6 (0.5 to 2 pt) |
| `.shadow(` | 6 | 6 recipes |
| animation curves | 60 | 14 (`easeOut` 0.14, 0.15, 0.16, 0.18; `smooth` 0.2 to 0.5; two hand-tuned springs) |
| hard-coded colours | 13 `Color(red:)` plus 8 named hues (orange 48 times) | |

The style gate `grep -rnE 'cornerRadius: [0-9]|\.padding\([0-9]|\.font\(\.system\(size:' Sources/Vorssaint/UI/Notch --include='*.swift' | grep -v NotchDesign.swift` matched **353 lines**. It trends to zero as pages migrate.

The biggest problems, in the order a person sees them:

1. **The peeks sprawl.** A notice's wing may grow to 240 pt a side (`NotchNotice.preferredWings`), so the agent wrap-up becomes a 680 pt bar of same-weight text across the menu bar, with the cost as loud as the title. Apple's compact presentation stays "as narrow as possible and snug against the camera" `[HIG live-activities.md]`.
2. **The song peek band is chrome, not content.** `NotchSongPeekBand` carries an uppercase tracked "UP NEXT" eyebrow at 9 pt, a 10.5 pt artist line, and a progress ring in a pine green (`Color(red: 0.42, green: 0.71, blue: 0.56)`) that belongs to no palette. Two of its three type sizes are below 10 pt.
3. **Corners do not nest.** Cards use an 18 pt corner inside a 28 pt silhouette with a 14 pt side margin and a 16 pt bottom margin, so no inner corner is concentric with the island. Radii 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18 and 24 all appear for the same kind of plate.
4. **The island opens squished.** Content starts fading in at 0.16 s, before either side has arrived (height 0.23 s, width 0.25 s), scaled to 0.86 from the top and blurred 12 pt. Width and height ride different springs (0.44 s at 0.25 bounce, 0.38 s at 0.22), so the shape changes aspect as it grows. Departing content fades on ease in.
5. **A rainbow of accents.** Orange (timer), yellow (keep awake), red, green, mint, blue, a pink calendar "today", agent brand colours on text, the cover's tint on text glyphs. Apple: one colour means one thing `[HIG color.md]`.
6. **Visible borders.** Keyboard highlight in the gallery is a 1 pt white stroke at 0.55; the optional outline is 2 pt at 0.65; clipboard and watch focus rings are 1 pt at 0.34.

---

## 1. Principles

1. **Deference.** The island is hardware that learned to talk. At rest it is the notch. It speaks only when something happened, in as few words as the moment needs, then goes quiet.
2. **Clarity.** One job per state. Hierarchy comes from weight and alpha, not from extra boxes. Every element answers "what is this telling me" `[HIG design-principles.md › Simplicity]`.
3. **Depth.** Black is the ground. Glass, when on, is the functional layer the island floats as; content inside it never wears glass `[HIG liquid-glass.md › The two layers]`.
4. **Content first.** Artwork, a name, a number. Labels, eyebrows and borders are the first things to cut.
5. **One accent.** The person's system accent marks "on" and the one primary action. Three signal colours mean critical, warning and positive, always beside a symbol or a word. Everything else is white at an alpha.
6. **Nothing decorative that is not informative.** A glow, a gradient, a bar that does not report a level is noise. The equaliser stays because it says "audio is playing".
7. **Feedback matches consequence.** A tap presses. A toggle morphs. A commit launches. A destructive act burns a fuse you can blow out. A slider resists at its ends `[Emil] [HIG feedback.md]`.
8. **Light.** Vorssaint is very lightweight. Nothing animates, polls or observes while the notch is shut unless it is on screen and reporting something live.

---

## 2. Geometry

The silhouette numbers live in `NotchDesign.Geometry`. NotchLayout and NotchMotion read them; they do not carry their own literals once migrated.

### 2.1 The closed island hugs the hardware notch

| Property | Rule | Token |
| --- | --- | --- |
| Width | The camera housing macOS reports (`NSScreen` auxiliary top areas) plus the per-Mac `NotchCameraFit` correction. Not one point wider at rest. | NotchGeometry.cameraWidth |
| Height | The safe area top (the menu bar on a notched panel). | NotchGeometry.stripHeight |
| Bottom corners | `islandCornerRadius(height:)`: 0.34 of the height, 10.9 pt on a 32 pt notch, drawn as **continuous** corners like the cutout. | Geometry.closedCornerRatio |
| Shoulders | Where the island meets the screen's top edge: 0.19 of the height up to 14 pt, so 6 pt on a 32 pt notch. | Geometry.shoulderRatio, shoulderRadius |
| Edge | No stroke at rest. Open, a 0.5 pt key line at 0.14 white; the optional outline is 1 pt at most. | Stroke.keyLine, Stroke.hairline |
| Seam | None. Between hardware and software there must be no grey fringe and no step. | |

**What is wrong today**

- `NotchShape.path(in:)` draws every corner as a circular quarter arc (control point 0.5523). The cutout and every SwiftUI plate inside the island (`style: .continuous`) are continuous curves, so the silhouette's curve family differs from both what it covers and what it contains. Draw the bottom corners and shoulders as continuous corners (the curve `RoundedRectangle(cornerRadius:style: .continuous)` uses), and change `NotchMusicCover` from `.circular` to `.continuous` in the same step so the strip's cover stays parallel.
- The camera width is rounded to points by macOS and corrected by hand (`NotchCameraFit`, plus or minus 10 pt wide and 6 pt tall). A person should never need to tune it. Ship measured defaults per panel (14 and 16 inch MacBook Pro, 13 and 15 inch MacBook Air) and keep the setting as an override.
- The outline option draws 2 pt at 0.65 white, of which the inner 1 pt shows: a visible white border. Make it 1 pt at 0.35, and the default key line `Stroke.hairline` at `Stroke.keyLine`.

**Verification, required for any change here:** on hardware, white desktop picture, closed island, take a 2x screenshot of the notch region and zoom to 800%. No grey pixels between cutout and island, no step at any of the four curves, both sides symmetric to the pixel. Repeat on a black desktop picture with the key line on, and at every display scaling the Mac offers.

### 2.2 How the island grows

Closed, then a peek, then the expanded panel: one motion language for all three.

1. **Anchor:** top centre, always. The island grows down and out from the camera; it never slides.
2. **Both axes on one spring:** `Geometry.growSpring` (response 0.40 s, damping 0.85, bounce 0.15) for width and height together, so the aspect changes in a straight line, like Dynamic Island. Overshoot is capped at `Geometry.overshootLimit` (8 pt). It reaches 99% of its travel at 0.29 s and settles under 0.55 s for a 400 pt move. A peek uses the gentler `Peek.grow` (0.36 s, damping 0.88).
3. **Content arrives with the shape, never squished:** content is laid out at its final size from the first frame and clipped by the growing silhouette. It **never scales**: not 0.86, not 0.95, so it is never squished. At `Geometry.contentRevealDelay` (0.12 s, when the shape has covered about 60% of its travel) it starts to fade in over `contentRevealDuration` (0.18 s) from a `contentRevealBlur` of 4 pt to sharp, so it is fully in at 0.30 s, the moment the shape arrives (99% of its travel at 0.29 s).

   Why not wait for the shape to settle: the owner asked that content "appears only after the shape has settled, never squished". Waiting for the full settle means about 0.46 s before the page reads (0.55 s to the last half point), on a surface that opens tens of times a day; that reads as lag (`[Emil]` UI under 300 ms, `[emil-apple-design]` section 1, response). Dynamic Island cross-fades its content in while the shape grows. So "never squished" holds absolutely, and "after it has settled" is met as "sharp exactly when it has arrived": during the move the content is faint and blurred, never crisp and clipped. If the owner wants the strict reading, set `contentRevealDelay` to 0.28 and change nothing else.
4. **Shrinking:** content leaves first, `contentExitDuration` (0.12 s) on ease out, and the shape starts its `shrinkSpring` (0.30 s, damping 1, no bounce) halfway through. Never ease in `[Emil]`.
5. **Interrupting:** a new target always starts from the presentation value with the current velocity, never from the logical size (NotchMotion already plans from what is on screen; keep that).
6. **Reduce Motion:** the silhouette resizes on a plain ease out of `reducedMotionResize` (0.2 s), no spring, no overshoot; content cross-fades with no blur.

**What is wrong today** (`NotchMotion` in NotchSupport.swift, `transitionContent` and `beginArrival` in NotchWindowHost.swift): width and height use separate springs (`growingWidth` 0.44 s at 0.25, `growingHeight` 0.38 s at 0.22), so height arrives first and the island briefly reads tall and narrow. Width overshoots 2.8% of its travel, up to 12 pt. Content reveal keyframes `[0, 0.35, 1]` over 0.45 s start the fade at 0.16 s, under a 12 pt blur and a 0.86 scale, which Emil's floor of 0.9 already rules out and the owner's "never squished" rules out entirely. Departing content uses `CAMediaTimingFunction(name: .easeIn)`.

### 2.3 The expanded panel's size: one rule

**Fixed canvas per preset.** Every page draws into the same canvas: the preset's width (compact 480 pt, spacious 560 pt) and the preset's content height (`NotchLayout.compactContentHeight` 180 pt, `spaciousContentHeight` 264 pt), or the person's custom size. Switching pages never resizes the island. A page with more content scrolls inside the canvas with the scroll edge fade; a page with less fills it by design (centred readouts, taller cards), never with an empty black band.

Why: page switches are frequent, and a silhouette that springs on every switch spends motion where nothing physical happened `[Emil: frequency decides]`. One size also means one layout to design per page.

Surfaces that are not pages keep their own size: the sections gallery (`sectionPickerSize`), the embedded app panel and hosted utilities (`NotchLayout.pageContentHeight`, the tall canvas), and a capture preview (measured). Lyrics and the queue open **inside** the music canvas: the player collapses to its one-row form above them (the path `NotchLayout.musicSplit` already takes for custom heights), instead of the island growing by `musicExtrasHeight` 216 pt. Today controls, music, tools, timer and agents shrink to their content and the rest take the full budget, so the island changes height as you page; that goes.

### 2.4 The radii ladder

Inner radius equals outer radius minus the inset between them `[HIG live-activities.md › Use consistent margins and concentric placement]`. Margins are even (16 pt sides and bottom), so the ladder is exact.

```
island (open)        28  Geometry.panelCornerRadius
  margin 16
card, tile, artwork  12  Radius.card       = 28 - 16
  inset 6
plate in a card       6  Radius.control    = 12 - 6   (icon button, chip, field, thumbnail)
keycap, badge         4  Radius.small
pill, round button       Capsule(), Circle()
artwork hugging no corner: Radius.artwork(side:) = side x 0.2, at most 12
closed island     10.9  Geometry.islandCornerRadius(height: 32)
  cover in a strip: concentric with the strip at its inset (NotchMusicStripLayout already does this)
peek band            28  at its height (32 + 60 = 92 pt), so its 32 pt cover at 16 pt inset is 12
```

To move the margins to 16 on every side, `NotchLayout.horizontalInset` becomes shoulder plus margin, 14 + 16 = 30 (it is 28 today, which leaves 14 at the sides), and `bottomInset` stays 16. Do it in one change with the NotchLayout tests, not page by page.

---

## 3. Anatomy of the notch states

| State | What it is | Height | Content |
| --- | --- | --- | --- |
| Closed, at rest | The hardware notch. Optional resting wings (battery, cover and bars, agent allowance). | strip | Wing glyph `Icon.strip`, reading `Typography.readout` at 10 to 12 pt, `Ink.secondary` |
| Compact activity | A running thing beside the camera: music, timer, downloads, agents, calendar, keep awake, watch. | strip | Leading glyph or cover, trailing live reading or bars. Wings follow Peek.wingMaximum. |
| Peek, compact | Something happened, said in the wings. | strip | Section 11 |
| Peek, tall | Something happened that needs two lines: the band below the strip. | strip + 60 | Section 11 |
| Song peek band | The tall peek for a track change. | strip + 60 | Section 12 |
| Hover grow | The pointer over the closed island: it grows a little around its strip, content stays put. | strip + few pt | No new content |
| Expanded panel | Header row and a page in the fixed canvas. | preset | Sections 4 and 15 |
| Sections gallery | The page switcher: a grid of tiles with a row indicator. | its own | Tiles per section 10 |
| Notification preview | A notification opened in place. | canvas | Section 15, notifications |
| Capture controls | The capture toolbar the island becomes. | its own | Section 15, capture |
| Capsule | On a display without a notch, the island floats as a capsule in the menu bar. Same anatomy, round ends, `NotchLayout.capsuleRadius`. | 20 | One row end to end |
| Lock screen | Padlock beside the camera, music bars on the other side. | strip | Section 15, lock screen |

---

## 4. Layout grid of the expanded panel

```
 shoulder 14            camera housing              shoulder 14
 \__________________________|=========|___________________________/
 |<-16->|                                                  |<-16->|
 |      [<] Page title 15 semibold        [..][pin][gear][^]      |  header row 36 (NotchLayout.headerHeight)
 |                                                                |  12 (Spacing.section)
 |      +------------- card r12 ----------+ 8 +---- card r12 ---+ |
 |      | 12                              |   |                 | |  page: the fixed canvas
 |      |  title 13 semibold              |   |                 | |  gutter 8 (Spacing.gutter)
 |      |  second line 12, 0.6            |   |                 | |  card padding 12
 |      +---------------------------------+   +-----------------+ |
 |                                                                |  16 (Geometry.margin)
  \______________________________________________________________/   bottom corners 28
```

- **Margins:** 16 pt from the island body on both sides and at the bottom (`Geometry.margin`).
- **Header:** one row, `NotchLayout.headerHeight` 36 pt, its top at `headerTopInset` (below the camera, or beside it when the header splits round the camera). Leading: back or sections button (28 pt), then the title in `Typography.pageTitle`. Trailing: header actions at 6 pt gaps (`Spacing.xSmall`), hidden until the pointer reaches the row, with the update dot and the pin glyph kept visible at rest.
- **Header to page:** 12 pt (`Spacing.section`, NotchLayout.spacing).
- **Gutter:** 8 pt between cards and tiles, rows and columns alike.
- **Columns:** the canvas is one column by default. Two cards side by side split it with one gutter. A rail of tiles uses `NotchRail` and fixed tile widths.
- **Page switcher:** the sections gallery opens in place of the page from the header's grid button or Command K; it is navigation, not a page, and keeps its own size. Floating quick-access buttons below the island are the second switcher; they wear `notchGlass(in:)` and `Shadow.floating`.
- **Scrolling:** pages scroll vertically inside the canvas with `notchScrollEdgeFade`, never with visible scroll bars; rails scroll sideways.

---

## 5. Type

System font only. SF Pro for words, SF Pro Rounded for numbers that change (readouts, countdowns, percentages). macOS has no Dynamic Type `[HIG typography.md › Desktop]`, so the text styles resolve to fixed sizes, but the views still name the style so the system's definitions apply.

| Token | Style, weight | Size | Where |
| --- | --- | --- | --- |
| Typography.display | largeTitle, semibold, rounded | 26 | Timer and stopwatch readouts on their pages |
| Typography.hero | title2, semibold | 17 | Music page track title, the sung lyric line |
| Typography.pageTitle | title3, semibold | 15 | Header title, a detail's title by its back button; NotchLayout measures it with `.nsFont` |
| Typography.title | body, semibold | 13 | Card titles, row titles, the track on cards |
| Typography.body | body, regular | 13 | Notification bodies, scratchpad, clipboard previews, empty-state sentences |
| Typography.callout | callout, regular | 12 | A row's second line, pill and menu button labels |
| Typography.label | subheadline, medium | 11 | Tile labels, chips, segment labels |
| Typography.caption | caption, medium | 10 | Times by the scrubber, shortcut hints, metadata. The floor |
| Typography.readout | callout, semibold, rounded | 12 | Live numbers in rows and tiles; add `.monospacedDigit()` |
| Typography.stripPrimary | callout, semibold | 12 | Closed island and every peek, first line |
| Typography.stripSecondary | caption, medium | 10 | Closed island and every peek, second line |

Rules: nothing below 10 pt. Weights are regular, medium, semibold and, for one emphasised word, bold; never light or thin (the empty-state glyph at light weight and the 30 pt music note go to medium). Hierarchy is weight plus alpha; a second line is never smaller than 10 pt and never the same weight as the first. No uppercase eyebrows with tracking. Numbers that tick use `.monospacedDigit()` and `NotchRollingDigits`. Use `.font(NotchDesign.Typography.title.font)`; AppKit text the island measures uses `.nsFont` from the same token so measured and drawn widths match.

---

## 6. Colour

The island is always dark (`.environment(\.colorScheme, .dark)`). Text is white at three alphas; surfaces are white at low alpha on black; one accent; three signals.

| Role | Token | Value | Use |
| --- | --- | --- | --- |
| Text, first | Ink.primary | white 1.0 | Titles, values, glyphs of controls |
| Text, second | Ink.secondary | white 0.6 (7.4 to 1 on black) | Second lines, labels, times |
| Text, hint | Ink.tertiary | white 0.3 (2.5 to 1) | Placeholders, disabled hints. Never information |
| Accent | Palette.accent | system accent | A toggle that is on, a page's one primary action, a fuse's undo state |
| Critical | Palette.critical | system red | Recording, a destructive commit, critical battery |
| Warning | Palette.warning | system orange | A limit near, early battery warning, a burning fuse |
| Positive | Palette.positive | system green | Connected, saved, finished |

**Artwork tint** (`NotchArtworkTint`) is allowed on music surfaces only (music page, music strip, song peek band) and only on controls and indicators: the equaliser, the scrubber fill, shuffle when on, the artwork halo. Never on text, never on a plate behind text, never on another page.

**Identity colours are content, not accents:** an agent's brand colour on its mark, a calendar's colour on its event dot, an app's own icon. They never colour text, plates or controls.

**What goes:** the timer's orange (the running timer's tile and strip use the accent), keep awake's yellow (accent), the calendar's pink "today" (today is a white circle with a black numeral, `Fill.inverse` and `Ink.onInverse`), the song peek ring's pine green (the ring goes, section 12), agent tints on notice text (white text, tint on the mark only), orange text on the timer notice.

Signals always pair with a symbol or a word; colour alone never carries meaning `[HIG color.md › Inclusive color]`.

---

## 7. Materials and borders

- **Black is the ground.** The island at rest and every surface that touches the camera stays black, so it is indistinguishable from the cutout.
- **Liquid Glass (macOS 26, opt-in setting)** belongs to the functional layer only: the island shell as it opens (`NotchSurfaceBackground`, clear variant with the black shade) and the floating quick-access buttons (`notchGlass(in:)`, regular variant). Cards, rows, tiles and fields inside the island never get glass; glass cannot sample glass `[HIG liquid-glass.md › Review checklist 1 and 2]` `[swiftui-expert liquid-glass.md › GlassEffectContainer]`.
- **Dimming on glass:** under any text, keep at least `Glass.textDim` (0.72) black, which holds secondary text at 4.5 to 1 over a white desktop; only the bottom 16 pt lip may open to `Glass.lipDim` (0.55). Increase Contrast raises it to `Glass.increasedContrastDim` (0.9) everywhere. Today's shade reaches 0.55 at the bottom, where the last row of text sits.
- **Before macOS 26, or glass off:** black, or the translucent behind-window material (`NotchTranslucentMaterial`, `.hudWindow`) when that setting is on; floating controls fall back to `Glass.fallbackMaterial` (ultra thin).
- **Reduce Transparency:** everything black, no blur, no material. `notchGlass(in:)` already does this.
- **Fills:** a card is `Fill.card` (0.06); a control plate `Fill.control` (0.10); the hover wash `Fill.hover` (0.08); a chosen option `Fill.selected` (0.16).
- **Borders:** hairlines only. `Stroke.hairline` (0.5 pt) at `Stroke.glassEdge` for a card on glass, `Stroke.artworkEdge` round artwork. On black, cards have no edge at all. No 1 pt white borders anywhere: keyboard highlight is `Fill.selected`, a focused field is `Fill.selected` plus the system focus ring. The one dashed stroke is the drop target (`Stroke.dropTarget`).
- **Increase Contrast:** every card and plate gains a 1 pt edge at `Stroke.increasedContrast` (white 0.5); secondary text stays 0.6 (it already passes) and hints rise to 0.6.
- **Shadows:** none inside the black island. `Shadow.floating` under floating buttons; `Shadow.halo(tint)` once, behind the music page artwork. No text shadows and no glows: the lyrics' white glow on the sung line goes.

---

## 8. Motion

Content motion tokens are in `NotchDesign.Motion`; the silhouette's are in `Geometry` (section 2.2).

| Token | Spring or curve | For |
| --- | --- | --- |
| Motion.snappy | response 0.25, damping 1 | Press release, toggles, hover lift, a selection moving |
| Motion.smooth | response 0.4, damping 1 | Rows and content that move or resize, a thumb settling |
| Motion.bouncy | response 0.4, damping 0.8 | Only after momentum or a commit: launch, success landing, a released swipe |
| Motion.fade | ease out 0.18 s | Every opacity cross-fade; the one motion Reduce Motion keeps |
| Motion.exit | ease out 0.12 s | Anything leaving: always faster than it arrived |
| Motion.easeOut(_:) | cubic (0.23, 1, 0.32, 1) | Fixed-time entrances that are not springs |
| Motion.ceiling | 2 s | Nothing transient runs longer `[HIG live-activities.md]` |

**What animates:** the silhouette; content arriving and leaving (opacity, small blur); a press; a toggle's symbol (`.contentTransition(.symbolEffect(.replace))`); numbers rolling (`NotchRollingDigits`); a commit's burst; a fuse burning; a slider's thumb and rubberband; live indicators that report something (equaliser bars from audio, a progress ring filling).

**What never animates:** anything a keyboard shortcut triggers (Command K, arrow keys in the gallery and lists, Escape): the change lands at once `[Emil: never animate keyboard-initiated actions]`. Today the gallery springs 0.3 s on arrow-key row steps; make it instant for keys and keep the spring for the scroll wheel. Hover on any control: the wash only, nothing lifts or scales. Colour changes on text. Layout properties in a hot path. Anything while the island is shut, or not on screen (`NotchEqualizerView` already stops when occluded; every new animated view must too).

**Rules:** ease out for entering, never ease in `[Emil]`. Exits faster than entrances. Nothing scales from 0, and island content never scales at all. Always `.animation(_:value:)` with a value. Scope animation to the smallest view that changes `[swiftui-expert animation-basics.md › Narrow Animation Scope]`. Prefer transforms and opacity to frame changes. Use `Motion.animation(_:reduceMotion:)` instead of writing `reduceMotion ? nil : ...` by hand.

**Reduce Motion:** springs, scales, slides, bursts, rubberbands and blurs go; the change lands at once and opacity cross-fades on `Motion.fade`. Live indicators hold still (the equaliser shows static bars, a ring steps instead of sweeping). Haptics and sounds are unaffected.

---

## 9. Feel

The owner: "each button should be responsive to reflect what is done and make it satisfying and good to use." The principle, taken from `SlingButton` and `FuseButton` in the Experiment repo but not copied from them: **feedback matches consequence.** There are five classes, one component each, built by the interaction library agent against these exact names and the `NotchDesign.Interaction` tokens.

| Class | Component | Feel | Reduce Motion |
| --- | --- | --- | --- |
| Tap | `NotchPressStyle` (ButtonStyle) | On mouse down the control lands at `Interaction.pressScale` 0.97 within `pressDuration` 0.1 s, ease out; release springs back on `Motion.snappy`. Under the pointer: the `Fill.hover` wash only, on every control. Nothing scales on hover (`Interaction.hoverScale` is 1): macOS highlights, the lift is an iPadOS pointer effect `[HIG pointing-devices.md › iPadOS]`, and hover happens tens of times a day. Disabled: `Opacity.disabled`, no press. | No scale; the wash deepens to `Fill.selected` while pressed. |
| Toggle | `NotchToggleStyle` (ToggleStyle) | The symbol morphs between its off and on forms with SF Symbols `.contentTransition(.symbolEffect(.replace))` and the plate fades to `Palette.accent` (on) or clear (off) on `Motion.snappy`. The press is NotchPressStyle's. | Symbol swaps with a cross-fade; plate colour changes on `Motion.fade`. |
| Commit or send | `NotchCommitButton` | Something leaves or starts. Press as a tap; on fire, the glyph launches (a short travel in the action's direction on `Motion.bouncy`) and `burstParticleCount` (8) particles of `burstParticleSize` 3 pt fly `burstReach` 18 pt within a `burstSpread` 60 degree cone over `burstDuration` 0.3 s, in white or the music tint. Holding and pulling past `dragThreshold` arms it (`armedScale` 1.04); a plain click still fires. Results that are not otherwise visible end in `NotchSuccessMorph`. Pointer-initiated only: a keyboard shortcut fires with no burst. | No travel, no burst, no armed scale; the glyph cross-fades to its result. |
| Destructive | `NotchFuseButton` | Pressing does not act yet. A fuse of `fuseLineWidth` 1.5 pt in `Palette.warning` burns round the control's rim for `fuseDuration` 2.5 s, linear, while the control reads Undo in `Palette.accent`. Click it or press Escape and nothing happened. The pointer resting on it pauses the burn. When it burns out the action commits and the control morphs to done (`NotchSuccessMorph`). Replaces the `NSAlert` confirmations for undoable actions; a truly irreversible action keeps the alert `[HIG alerts.md]`. | The rim does not sweep: it shows static and the label counts down in whole seconds ("Undo 2", "Undo 1"); commit timing and Escape are unchanged. |
| Slider | `NotchSlider` | Tracks the pointer 1:1 from where it was grabbed. Past either end the track stretches with `Interaction.rubberbanded(_:dimension:)` (Apple's 0.55, at most `rubberbandLimit` 6 pt) and springs back on `Motion.snappy` on release. Within `detentSnap` (2% of the range) of a detent it snaps and plays `detentHaptic` on the trackpad on the same frame. Drawn track `Control.sliderTrack` 6 pt in `Fill.track`, fill white or the music tint; hit area `Control.rowHeight` 28 pt. | No stretch: a hard stop at the ends. Snap and haptic stay. |

`NotchSuccessMorph` (a ViewModifier, applied as `.notchSuccessMorph(...)`): the control's glyph morphs to `checkmark` (symbol replace effect, `Motion.bouncy`), holds `successMorphDuration` 1.2 s, then morphs back. Under Reduce Motion it cross-fades. Use it where the result is not otherwise visible: copied, saved, exported, sent to a device.

Timing asymmetry `[Emil]`: slow where the person decides (the fuse, 2.5 s linear), fast where the system answers (press 0.1 s, release on a 0.25 s spring, exit 0.12 s).

**By control kind.** Builders follow this table literally; the next one lists every control page by page.

| Control kind | Interaction class |
| --- | --- |
| Icon button that navigates or opens (back, sections, settings, collapse, overflow, Finder, open in app) | `NotchPressStyle` |
| Icon button that holds a state (pin, shuffle, mute, lyrics, queue, customise, follow along) | `NotchToggleStyle` |
| Row, card, tile or cover that opens something | `NotchPressStyle` |
| Tile whose job is a state (keep awake, microphone, a watch switch) | `NotchToggleStyle` |
| Play and pause | `NotchCommitButton`: the launch and burst fire on play; pause only morphs its symbol |
| Next and previous | `NotchCommitButton`, burst in the skip direction |
| Send, route or start (output device, AirPlay, paste, share, Start timer, start recording, install update, notification action) | `NotchCommitButton` |
| Copy, save, export, choose folder: an action whose result is not otherwise visible | `NotchPressStyle` plus `.notchSuccessMorph(...)` |
| Delete, remove, clear, reset, cancel a running session | `NotchFuseButton` |
| Dismiss one notification, clear a scratchpad (Command Z restores it) | `NotchPressStyle` with an exit on `Motion.exit` |
| Volume, brightness, keyboard light, scrubber, fader, timer ruler | `NotchSlider` |
| Segmented choice, menu button, chip | `NotchPressStyle`; the chosen segment moves on `Motion.snappy` |
| Text field, search | system field; focus is `Fill.selected`, no stroke |

**Every notch control, by class**

| Page | Tap (NotchPressStyle) | Toggle (NotchToggleStyle) | Commit (NotchCommitButton) | Destructive (NotchFuseButton) | Slider (NotchSlider) |
| --- | --- | --- | --- | --- | --- |
| Header | Sections grid, back, settings, collapse, overflow menu, update dot | Pin, customise tools | Install update | | |
| Closed island and strips | Open (click anywhere) | Strip bars become play and pause under the pointer | | | |
| Music | Artwork (opens the player), source menu, lyrics and queue openers, idle cover (opens the app) | Shuffle, mute, lyrics, queue | Play and pause (burst on play), next and previous (burst in the skip direction), output device switch (AirPlay) with success morph | | Scrubber, inline volume |
| Lyrics | Lines (seek to a line), add lyrics file | Follow along | | | |
| Queue | Rows (open the song), refresh | | Play a queued song | | |
| Controls | Panel, mixer and scratchpad tiles, brightness setup | Keep awake, microphone, timer and calendar tiles when they toggle | Recording start and stop (critical), music card transport | | Volume, brightness, keyboard light |
| Mixer | Options, app menus, typed level | Mute per app, output and microphone mute | Route an app to a device, with success morph | Reset levels | Per-app faders, output, microphone (detent at unity) |
| Calendar | Day cells, event rows (open), allow access, open Calendar | Countdown choice | | | |
| Timer | Mode chips, preset menus | Pause and resume | Start, next phase | Cancel a running session | Ruler (detents at whole minutes, rubberband at the ends) |
| Watch | Area chooser, rule menus | Watch switches | Start watching | Stop and discard a result | |
| Agents | Cards (open the agent), set up limits, refresh | Chips that filter | | | |
| Files | Shelf tiles (open), Finder | Selection | Share or AirDrop a file, copy path with success morph | Remove selected, clear shelf | |
| Clipboard | Cards, search, move up and down | Pin an entry | Paste into the front app; copy with success morph | Delete an entry, clear recent | |
| Downloads | Rows (open), Finder, Files | Folder watch switches | Choose folder, with success morph | Forget folder, delete a download | |
| Scratchpad | Tabs, rename, open, the actions menu | Preview and edit | Export, copy all with success morph | Close a pad that has text; clear stays a tap because Command Z restores it | |
| Camera and mirror | Start camera, open settings | Mirror | | | |
| Capture | Tool choice | Audio sources, options | Capture, start recording, stop and save | | |
| Notifications | Rows (open the app), expand | | Notification actions (reply, open) | Clear all; a single dismiss stays a tap with an exit | |
| Quick access | Every floating button | Pin, keep awake when placed there | | | |
| Lock screen | None: it shows, it does not take clicks | | | | |

---

## 10. Controls

One style per kind. Hit targets are never under `Control.minimumHit` (28 pt) whatever is drawn.

```
Icon button (28 x 28)          Pill (28 tall)                 Transport
 +------+                        (  Start timer  )             <<   (>)   >>
 |  [] |  r6 plate on select     capsule, 14 pt sides          36 / 44 pt circles, no plates
 +------+  glyph Icon.button     label Typography.callout      glyphs Icon.transport / transportPrimary
                                 prominent: Palette.accent     one prominent per page at most

Tile (rail)                     Card                          Segmented choice
   ( O )   40 pt glyph circle    +---------------------+       [ Timer | Pomodoro | Stopwatch ]
  Label    Fill.control,         | 12 padding, r12     |       track Fill.control r6, chosen
  2 lines  accent fill when on   | Fill.card, no edge  |       segment Fill.selected r6 inset 2
           Typography.label      +---------------------+       labels Typography.label

Slider                          Meter (read only)             Menu button
 (o)======o------------   (o)    ===========-------            Name v
 track 6 pt Fill.track, fill     4 pt capsule, no thumb        Typography.callout, Ink.secondary,
 white or tint, no knob drawn    Fill.track, white fill        chevron Icon at caption size
```

- **Icon button:** 28 by 28, glyph `Icon.button` in `Ink.secondary`, primary when selected; selected plate `Fill.control` at `Radius.control`. Tap or Toggle class.
- **Pill:** 28 tall, capsule, `Typography.callout`, 14 pt horizontal padding. Default plain (`Ink.secondary`, no plate); the one prominent pill per page is `Palette.accent` fill with white text.
- **Transport:** circles of `Control.transportCompact` 36 or `Control.transport` 44, no plates, white glyphs; play and pause one step larger. Spacing 12 compact, 16 roomy.
- **Tile:** 40 pt glyph circle in `Fill.control`, `Palette.accent` with a white glyph when on (Control Center's on state), label in `Typography.label` up to two lines. The whole tile is the hit target; under the pointer it takes the `Fill.hover` wash.
- **Card:** `Fill.card`, `Radius.card`, `Spacing.cardPadding`, no edge on black, hairline on glass.
- **Segmented choice:** one track, the chosen segment slides with `matchedGeometryEffect` on `Motion.snappy` (instant when chosen by keyboard).
- **Slider and meter:** one drawing for both, `NotchSlider` for input, the meter for output; the same track colour and thickness family across volume, brightness, scrubber, mixer and HUDs.
- **Menus:** native `NSMenu` in dark appearance through `NotchMenuButton`, entries with their glyphs. No custom popovers.
- **Empty state:** glyph `Icon.hero` in a `Control.heroGlyph` 56 pt plate at `Fill.card`, `Radius.card`; sentence in `Typography.body` `Ink.secondary`; at most one prominent pill.

---

## 11. Peeks

A peek is any moment the closed island widens or grows on its own to say something. Every peek uses one anatomy, like Dynamic Island's compact and expanded presentations.

### 11.1 The list

Words in quotes give the English sense; every string comes from the language's strings file.

| Peek | Variant | Leading | Primary line | Secondary line | Trailing | Dwell |
| --- | --- | --- | --- | --- | --- | --- |
| Volume, brightness, keyboard light | compact | Symbol (fills with level) | | | Meter, 4 pt, plus percent | hudDwell 1.5 s after the last change |
| Microphone muted or live | compact | `mic.slash` or `mic` | Muted or Live | | | infoDwell 2.5 s |
| Song change | tall | Cover 32 | Title | Artist | Live equaliser | tallDwell 4 s; replaces the compact `.track` notice and the up-next band |
| Agent wrap-up | tall | Agent mark | "Claude finished" | Time taken · cost | | tallDwell 4 s |
| Agent limit near or reset | tall | Agent mark, warning glyph when near | "Claude · Weekly" | "20% left" or "Renewed" | | tallDwell 4 s |
| Notification | tall | App icon 32 | Sender or title | One line of the message | | tallDwell 4 s, held while the pointer rests on it |
| Download finished | tall | File icon 32 | File name | "Downloaded" · size | | tallDwell 4 s |
| Device connected | compact | Device symbol | Name, truncated in the middle | | Battery percent when known | infoDwell 2.5 s |
| Charger and battery | compact | Battery symbol | | | Percent | infoDwell 2.5 s |
| Timer ended | tall | `timer` in accent | "Timer done" | The timer's name or length | | attentionDwell 8 s, held while pointed at |
| Watch fired | tall | `eye` | What changed | Where | | attentionDwell 8 s |
| Keep awake on or off | compact | `cup.and.saucer` | | | Time left or infinity | infoDwell 2.5 s |
| Calendar soon | tall | Calendar colour dot in a 32 plate | Event title | "In 5 min" · place | | tallDwell 4 s |
| Copied | compact | `doc.on.clipboard` | Copied | | | infoDwell 2.5 s |
| Capture taken | tall | Thumbnail 32 | "Screenshot" | Saved where | | 12 s, it carries a draggable thumbnail |

### 11.2 Shared anatomy

```
Compact (strip height, wings only)
  [wing <= 96]  [ camera ]  [wing <= 96]
   glyph 20  primary 12        secondary or live element

Tall (strip + band 60)
  [          strip, black, unchanged         ]
  | 16 [cover 32 r12] 12  Primary 12 semibold      [live 20] 16 |
  |                       Secondary 10 medium 0.6               |
   \_______________________ 16 bottom, corners 28 _____________/
```

- **Compact:** wings beside the camera at the strip's height, each at most `Peek.wingMaximum` 96 pt and at least `wingMinimum` 36 pt, glyph or cover `Peek.wingArtwork` 20 pt, one word or number per side in `Typography.stripPrimary` or `readout`. Snug to the camera: no padding between content and the housing beyond `NotchLayout.compactEdgeGap` `[HIG live-activities.md › Compact presentation]`. Anything that does not fit 96 pt uses the tall variant; text never pushes the wings wider.
- **Tall:** the strip stays exactly as it was; a band of `Peek.bandHeight` 60 pt grows below it, as wide as the closed island at rest (camera plus resting wings), at least `Peek.bandMinimumWidth` 300 pt and at most `bandMaximumWidth` 360 pt. Band: `bandTop` 12 pt under the strip, 16 pt sides and bottom (`Geometry.margin`). Leading `Peek.artwork` 32 pt cover or glyph plate at `Radius.card` 12 (concentric: 28 minus 16). Text column: primary `Typography.stripPrimary` in `Ink.primary`, secondary `Typography.stripSecondary` in `Ink.secondary`, `Spacing.line` between, one line each, tail truncation. Optional trailing live element `Peek.trailingSide` 20 pt: equaliser, a progress ring, or a short amount in `Typography.readout`.
- **No chrome:** no eyebrows, no uppercase, no plates behind text, no borders, no buttons. Clicking a peek opens its page. A notification may expand in place (the notification preview), nothing else does.
- **Enter:** the silhouette grows on `Peek.grow` (0.36 s, damping 0.88) from the top centre; content waits for the shape (`Geometry.contentRevealDelay`) and fades in from a 4 pt blur, never scaled. **Exit:** content leaves on `Motion.exit` (0.12 s), then the island shrinks on `Geometry.shrinkSpring` back to rest, the same path it came out on.
- **Dwell:** as the table; the clock pauses while the pointer rests on the peek and while the screen is locked or the display asleep, and restarts at `minimumRead` after the pointer leaves.
- **Queue:** one peek at a time. Priority, high to low: HUDs, attention (timer ended, watch fired), capture, notifications and agent limits, agent wrap-up and downloads, calendar soon, song change, devices and battery, copied and keep awake. A higher peek replaces the current one only after the current has shown `Peek.minimumRead` 1 s; the same kind updates in place (a HUD moving from 40% to 45% never re-enters). Lower or equal peeks wait, at most `Peek.queueLimit` 3; older ones of a kind merge into the newest ("3 downloads finished"). Between two queued peeks the island does not return to rest: the shape springs straight to the next size and the content cross-fades through black (`notchFadeThrough`).
- **Reduce Motion:** the island resizes on the `reducedMotionResize` ease out with no spring; content cross-fades on `Motion.fade` with no blur; the equaliser holds still; a ring steps. Dwell and queue are unchanged.

### 11.3 The agent wrap-up

The owner: "when Claude wraps up the notch goes wider and shows amount spent and all but doesn't really look good." Today it is a compact notice whose wings grow to fit "Claude finished" on the left and "4m 12s · $0.42" on the right at the same 11 pt medium weight, up to 240 pt a side.

**Show (tall peek), exactly this:**

```
  [   compact wings, unchanged   ][camera][   unchanged   ]
| 16 [Claude mark 32]  12  Claude finished                16 |
|                          4 min · $0.42                     |
```

| Slot | Content | Token |
| --- | --- | --- |
| Leading | The agent's mark at 32 pt in its identity colour, no container `[HIG live-activities.md › If you include a logo mark, display it without a container]` | Peek.artwork |
| Primary | The agent's name and "finished": "Claude finished" | Typography.stripPrimary, Ink.primary |
| Secondary | Time taken, then the cost, joined by " · ": "4 min · $0.42". Time in whole minutes from one minute up, seconds below it. Cost only when known exactly and at least one cent; otherwise the line is the time alone | Typography.stripSecondary, Ink.secondary |
| Trailing | Nothing | |
| Width | The closed island's resting width, at least 300 pt and at most 360 pt. Text truncates at the tail; the island never widens for it, and the wings beside the camera do not change | Peek.bandMinimumWidth, Peek.bandMaximumWidth; Peek.bandHeight 60 below the strip |
| Dwell | 4 s, held while the pointer rests on it; a click opens the AI page | Peek.tallDwell |

**Never show:** token counts, input and output or cache splits, per-model breakdowns, the day's running total, limit percentages (the limit peek says those, on its own), request counts, "≥" estimates for unpriced usage (leave the cost out instead), project paths, the agent's colour on any text, more than two lines, or anything that widens the wings.

---

## 12. The song peek band

The owner called it out. It should feel like Dynamic Island on iPhone when a track changes: the new song's cover, its title and artist, a tiny live equaliser, no chrome.

**Becomes:** the tall peek anatomy exactly.

```
| [cover 32 r12]  Title of the song               |||  |
|                 Artist                               |
```

- **When:** at the track change, showing the song that just started, for `Peek.tallDwell` 4 s (Spotify and every player, from `NotchMusicService.trackChanges`). The current pre-roll ("up next" during the last 10 s) becomes an option that is off by default; when on it uses the same band with "Up next · Artist" as its second line and still no ring.
- **Leading:** the cover at `Peek.artwork` 32 pt, `Radius.card` 12, continuous, `Stroke.artworkEdge` hairline. No cover yet: `music.note` in a `Fill.card` plate, and the real cover cross-fades in when it lands.
- **Text:** title `Typography.stripPrimary` white; artist `Typography.stripSecondary` at 0.6. No eyebrow, no uppercase, no kerning, no 9 or 10.5 pt sizes.
- **Trailing:** `NotchLiveEqualizerBars`, 3 bars, 2 pt wide, 12 pt tall, in the artwork tint (white for neutral covers). Static bars under Reduce Motion and while paused.
- **Removed:** the "UP NEXT" eyebrow, the countdown ring and its pine green, the `TimelineView` that drove it under Reduce Motion, and the `.drawingGroup()` it needed.
- **Height:** the band is `Peek.bandHeight` 60 pt below the strip; `NotchSongPeekBand.height` returns that token instead of measuring three fonts.
- **Motion:** as every tall peek (section 11.2). A skip while the band is up updates it in place: the cover and the text cross-fade on `Motion.fade`, the shape does not move.
- **VoiceOver:** "Now playing: Title, Artist". Not interactive; a click opens the music page.

---

## 13. Accessibility

- **Contrast:** text at least 4.5 to 1 against what is behind it. On black, `Ink.secondary` is 7.4 to 1 and `Ink.primary` 21 to 1. On glass, `Glass.textDim` keeps secondary text at 4.5 to 1 over a white desktop. `Ink.tertiary` (2.5 to 1) is for text that need not be read; never put information in it.
- **Increase Contrast** (`colorSchemeContrast == .increased`): a 1 pt `Stroke.increasedContrast` edge on every card and plate, `Glass.increasedContrastDim` on glass, hints at 0.6, the gallery's dots at 0.5.
- **Reduce Transparency:** black everywhere; `notchGlass(in:)` and `NotchSurfaceBackground` already fall back.
- **Reduce Motion:** section 8, and the fallback column of section 9.
- **VoiceOver:** every icon-only control has `.accessibilityLabel` (and `.help` for the tooltip); toggles report `.isSelected`; strips and peeks read as one element with a sentence ("Claude finished, 4 minutes, 42 cents"); decorative glyphs and bars are hidden; sliders expose a value and adjustable actions (NotchLevelSlider's AppKit cell already does).
- **Keyboard:** Full Keyboard Access reaches every control; Escape undoes a fuse and closes a layer before the island; keyboard changes do not animate.
- **Targets:** 28 pt minimum, about 6 pt between bezel-less icon buttons, more where they sit on different rows `[HIG accessibility.md › Mobility]`.
- **Colour alone never carries meaning:** every signal has a symbol or a word.
- **Strings:** every user-visible string comes from the language's strings file, through `L10n`, never a literal in a view.

---

## 14. Never

- No em dashes or en dashes in any user-visible string. Use a full stop, a comma, a colon or the middot. An empty value is a word, never a dash glyph.
- No hard-coded radius, padding, spacing, font size, opacity, stroke, shadow, colour or spring in a notch view. If a token is missing, add it to NotchDesign.swift with its doc comment, then use it.
- No font families beyond the system font. SF Pro Rounded only for numbers that change.
- No type under 10 pt, no light, thin or ultralight weights.
- No accent other than `Palette.accent`; no signal colour without its symbol or word; no artwork tint off the music surfaces or on text.
- No gradients on text, no text shadows, no glows.
- No 1 pt or heavier white borders; no strokes on cards on black.
- No glass inside the island, no glass on glass.
- No content scaling while the island grows or shrinks; nothing from scale 0.
- No ease in, no animation over 2 s, no animation on keyboard-initiated changes, no `.animation(_:)` without a value.
- No uppercase eyebrows, no decorative rings, no bars that do not report a level.
- No polling, timers or animation while the notch is shut or the view is off screen.
- No modal confirmation for something the fuse can undo.

---

## 15. Per-page checklist

Every page gets every box in the common list, then its own. Tick in the PR description.

**Common to every page**

- [ ] Every value comes from `NotchDesign`; the style gate shows no hits in the files touched.
- [ ] Type uses the section 5 tokens only; nothing under 10 pt; no light weights.
- [ ] Colour: Ink alphas, one accent, signals with symbols; no hues from the "what goes" list.
- [ ] Corners follow the ladder; cards `Radius.card`, plates `Radius.control`.
- [ ] Spacing: margins 16, gutter 8, card padding 12, header to page 12.
- [ ] Every control is in its section 9 class and uses that component.
- [ ] Reduce Motion, Reduce Transparency and Increase Contrast each checked by hand on a `--dev` build.
- [ ] VoiceOver labels on icon-only controls; decorative views hidden.
- [ ] The page fills the fixed canvas and never resizes the island.
- [ ] Nothing runs while the page is not on screen.

**Music:** player artwork `Radius.card` 12 with `Shadow.halo` once (two halo layers today); title `Typography.hero`, artist `callout` at 0.6; equaliser 3 bars in tint beside the title; scrubber `NotchSlider` with times in `caption` monospaced; transport per section 10; shuffle a toggle in tint when on; idle state's 30 pt light note goes to `Icon.hero` medium in a 56 plate; source menu `callout` secondary; lyrics and queue open inside the canvas.

**Lyrics:** sung line `Typography.hero` white, other lines `Typography.body` at 0.6 (Apple Music style), no glow (`shadow(color: .white.opacity(0.45))` goes), progress hairline under the sung line in `Fill.track`; backdrop washes stay in the content layer, black dims to `Glass.textDim` under text.

**Queue:** rows 28 tall minimum with a 28 cover at `Radius.control`, title `title`, artist `callout` 0.6; play a row is a commit.

**Controls:** music card and level cards at `Radius.card` 12 (18 today) with padding 12; level rows 28; tiles per section 10 with accent "on" fill, never yellow or orange; the `NotchTileAccent` enum collapses to selection (accent) and alert (critical).

**Mixer:** faders `NotchSlider` vertical with a detent at unity; app rows with 20 pt icons; mute toggles; the reset is a fuse; typed levels in `readout`.

**Calendar:** today is a white circle with a black numeral (no pink); selected day `Fill.selected`; weekday letters `caption` at 0.6 (9 pt today); event dots in the calendar's colour, text white; countdown chips `label`.

**Timer:** readout `Typography.display`; ruler with whole-minute detents and rubberband; mode segmented choice; Start is the page's one prominent pill in accent; cancel is a fuse; no orange anywhere.

**Watch:** area card `Radius.card`; focus without a 1 pt stroke (`Fill.selected`); rule menus `callout`; results as a tall peek.

**Agents:** the densest page (104 literal hits): cards `Radius.card`, figures in `readout`, labels in `caption`, every 9.5 pt line to `caption` 10; agent colour on marks only; no "≥" estimates or dash glyphs for missing figures (`NotchAgentsView.swift` line 282 returns an em dash glyph for an unpriced cost today: replace it with a word from the strings file; it is the one hit the dash gate finds).

**Files:** shelf tiles `Radius.card` with thumbnails at `Radius.control`; remove and clear are fuses; footer `caption`.

**Clipboard:** search field `Fill.control` `Radius.control`, focus `Fill.selected` not a 0.34 stroke; cards `Radius.card`; pin a toggle; delete and clear recent are fuses; copy morphs to a checkmark.

**Downloads:** rows with a 28 file icon; progress as a meter; the setup empty state per section 10; forget folder a fuse.

**Scratchpad:** tabs as a segmented row at `Radius.control`; tab close glyph 8 pt today goes to `caption`; editor text `body`; actions in one native menu.

**Camera and mirror:** preview at `Radius.card` with `Stroke.artworkEdge`; permission and error states per the empty state; the mirror on other displays matches the closed island exactly.

**Capture:** toolbar buttons 28 icon buttons with the chosen tool on `Fill.selected`; record is a commit in critical red; the collapsed strip's chevron at `Icon.strip`.

**Lock screen:** padlock glyph `Icon.strip`, bars per the strip; the clear Liquid Glass player keeps the 35% dimming over bright wallpaper `[HIG materials.md]`; artwork shadow from `Shadow.halo` only.

**Notifications:** cards `Radius.card`, app icon 20, sender `title`, body `body` up to the card's lines, time `caption` 0.6; dismiss a tap with `Motion.exit`; clear all a fuse in the header; banner as a tall peek.

**Notice and alerts (compact peeks, HUDs):** section 11; level glyph and meter in white, never orange; `NotchExpandedLevelView` in the header uses the same meter; `NSAlert` only for irreversible actions.

**Quick access:** floating buttons with `notchGlass(in: Circle())` and `Shadow.floating`; 44 pt (`NotchQuickAccessLayout.diameter`); press per NotchPressStyle; their drop motion uses `Geometry.growSpring`.

**Update control:** the dot is `Palette.accent` (blue today; orange for a prerelease goes to `Palette.warning` with a word in the tooltip); install is a commit with a progress meter; the header slot never resizes.

---

## 16. Migration table

Apply the same mapping everywhere so parallel builders converge. Context decides between neighbours: a value hugging a corner follows the ladder, everything else the nearest token.

| Old literal (uses) | Context | Token |
| --- | --- | --- |
| `cornerRadius: 18` (15), `24` (4), `16` (4) | cards, tiles, big artwork, music card | `NotchDesign.Radius.card` (12) |
| `cornerRadius: 14` (20), `12` (7), `11` (4), `10` (2) | NotchButtonStyle on tiles and pills, smaller cards | `Radius.card` for a tile or card, `Capsule()` for a pill, `Radius.control` inside a card |
| `cornerRadius: 9` (9), `8` (9), `7` (3), `6` (13), `5` (3) | icon buttons, chips, menus, thumbnails | `Radius.control` (6) |
| `cornerRadius: height / 2`, `size * 0.19` | pills, round buttons, artwork | `Capsule()`, `Circle()`, `Radius.artwork(side:)` |
| `.padding(12)` (19), `.padding(.horizontal, 12)` | card insides | `Spacing.cardPadding` |
| `.padding(10)` (11), `.padding(.horizontal, 10)` | buttons, cards | `Spacing.medium` (12) for cards, `Spacing.small` (8) for button insets |
| `.padding(4)` (13), `.padding(6)` (5), `.padding(8)` (6) | small insets | `Spacing.xxSmall`, `xSmall`, `small` |
| `.padding(14)`, `.padding(18)`, `16` | page edges | `Geometry.margin` (16) |
| `spacing: 5` (21), `spacing: 7` (12), `spacing: 3` (7) | stacks | `Spacing.xSmall` (6), `Spacing.small` (8), `Spacing.xxSmall` (4) |
| `spacing: 1`, `spacing: 2` | title over subtitle | `Spacing.line` |
| `spacing: 10`, `NotchLayout.rowSpacing` (10) | between rows and cards | `Spacing.gutter` (8) |
| `spacing: 14`, `spacing: 9` | icon to text | `Spacing.medium` (12), `Spacing.small` (8) |
| `size: 16 / 15, .semibold` | header and detail titles | `Typography.pageTitle` (15) |
| `size: 20, .semibold`, `17, .semibold` | music title, empty title | `Typography.hero` |
| `size: 13, .semibold`, `size: 12, .semibold` in titles | card and row titles | `Typography.title` |
| `size: 12` (51), `size: 13, .regular` | body text, second lines | `Typography.body` or `Typography.callout` |
| `size: 11` (42), `size: 11, .medium` | tile labels, chips, strip text | `Typography.label`; strips `Typography.stripPrimary` |
| `size: 10` (26), `10.5` (12), `9.5` (18), `9` (15), `8` (3), `7` (3) | metadata, hints, captions | `Typography.caption` (10) |
| `size: 26`, `size: 30, .light` | readouts, empty glyphs | `Typography.display`, `Icon.hero` |
| `size: 12/13, .medium` on SF Symbols in buttons | icon glyphs | `Icon.button` |
| `size: 14/16/17/19, .semibold` on transport | transport glyphs | `Icon.transport`, `Icon.transportPrimary` |
| `.opacity(0.85)` (13), `0.9` (11), `0.8` on text | near-white text | `Ink.primary` |
| `.opacity(0.7)` (12), `0.65` (8), `0.6` (12), `0.62`, `0.55` (7), `0.5` (8) on text | second lines | `Ink.secondary` |
| `.opacity(0.45)` (9), `0.35`, `0.3` on text | hints | `Ink.tertiary` |
| `.white.opacity(0.045)`, `0.05` (6), `0.065`, `0.075` | card and tile grounds | `Fill.card` |
| `.white.opacity(0.08)` (4), `0.09` | hover | `Fill.hover` |
| `.white.opacity(0.1)`, `0.12` (6) | plates | `Fill.control` |
| `.white.opacity(0.14)` (6), `0.18` (5), `withAlphaComponent(0.14)` | tracks, chosen state | `Fill.track`, `Fill.selected` |
| `lineWidth: 1` (7), `1.5` (3), `1.2`, `2` | borders and focus | remove; focus is `Fill.selected`; Increase Contrast `Stroke.increasedContrastWidth` |
| `lineWidth: 0.5` (6), `0.75` (5) | hairlines | `Stroke.hairline` |
| `.shadow(color: halo...)` two layers | artwork halo | one `Shadow.halo(tint)` |
| `.easeOut(duration: 0.14 / 0.15 / 0.16 / 0.18)` (24) | fades | `Motion.fade` |
| `.smooth(duration: 0.2 / 0.22 / 0.24 / 0.25 / 0.26)` (16) | symbol swaps, state changes | `Motion.snappy` |
| `.smooth(duration: 0.3 / 0.35 / 0.45 / 0.5)` | content moves | `Motion.smooth` |
| `.spring(response: 0.28, dampingFraction: 0.7)`, `.spring(response: 0.32, dampingFraction: 0.75)` | press and hover in NotchButtonStyle | `NotchPressStyle` with `Interaction.pressScale`, `Motion.snappy` |
| `.spring(duration: 0.3, bounce: 0)` | gallery paging | `Motion.smooth`; none for keyboard steps |
| `reduceMotion ? nil : X` | any | `Motion.animation(X, reduceMotion:)` |
| `.orange`, `.yellow` on timer and keep awake | "on" states | `Palette.accent` |
| `Color(red: 1, green: 0.36, blue: 0.39)` | calendar today | `Fill.inverse` with `Ink.onInverse` |
| `Color(red: 0.42, green: 0.71, blue: 0.56)` | song peek ring | removed |
| `NotchButtonStyle(cornerRadius:lifts:highlights:)` | every button | `NotchPressStyle` |
| `NotchLayout.horizontalInset` 28 | page margins | shoulder plus `Geometry.margin` (30) |
| `NotchLayout.headerTitleFont` 16 semibold, `detailTitleFont` 15 | header measuring | `Typography.pageTitle.nsFont` |
| `NotchNotice` wing cap 240 / 160 | peeks | `Peek.wingMaximum` (96) |
| `NotchMotion.growingWidth` / `growingHeight` | silhouette | `Geometry.growSpring` for both |
| `NotchMotion.shrinkingWidth` / `shrinkingHeight` | silhouette | `Geometry.shrinkSpring` for both |
| content reveal keyframes `[0, 0.35, 1]`, blur 12, scale 0.86 | opening | `Geometry.contentRevealDelay`, `contentRevealDuration`, `contentRevealBlur`; no scale |
| `NotchEvent.duration` 1.6 / 2.5 / 3 / 4 / 5 / 6 | peek dwell | `Peek.hudDwell`, `infoDwell`, `tallDwell`, `attentionDwell` |
