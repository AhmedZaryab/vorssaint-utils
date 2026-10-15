# Notch geometry

How the island sits on the hardware notch, how it grows, and the canvas every
page and peek lays out in. Owner of this file: the geometry stream
(`NotchSupport.swift` NotchLayout, NotchGeometry and NotchMotion;
`NotchWindowHost.swift`; `NotchCapsuleViews.swift`). Visual tokens live in
`NotchDesign.swift` and `docs/design/NOTCH-DESIGN.md`; this file is the
measured truth those geometry tokens follow.

## 1. The hardware, measured

Machine: 14 inch MacBook Pro, Mac17,9, M5 Pro, built-in Liquid Retina XDR,
macOS 26. Display mode 1512 x 982 pt at 2x (3024 x 1964 px).

Read with a Swift script from `NSScreen.main`: the public frame, safe area and
auxiliary areas, and the private `bezelPath` (the panel's lit outline, which
traces the cutout curve by curve) and `_notchFrame`.

| Reading | Points | Pixels |
| --- | --- | --- |
| frame | 1512 x 982 | 3024 x 1964 |
| visibleFrame top (menu bar) | 33 below the top | 66 |
| safeAreaInsets.top | 32 | 64 |
| auxiliaryTopLeftArea | x 0 to 663, 32 tall | |
| auxiliaryTopRightArea | x 848 to 1512, 32 tall | |
| notch from the aux areas (and `_notchFrame`) | x 663 to 848, 185 wide | 370 |
| notch body from `bezelPath` | x 663.48 to 848.45, 184.97 wide | 369.9 |
| notch body centre | 755.97 (screen midX 756.00) | |
| notch bottom from `bezelPath` | 32.07 below the top | 64.1 |
| top shoulder (concave fillet) | 6.81 wide, 6.81 tall, one cubic, handles 0.776 of its extent | 13.6 |
| bottom corner | spans 14.44 each way, two cubics, G2 continuous | 28.9 |
| bottom corner, best fit | SwiftUI `.continuous` radius 10.3, within 0.046 pt (0.09 px) | |
| outline across the top, with shoulders | x 656.67 to 855.27, 198.6 wide | 397 |
| display top corners | continuous, 37 pt extent | |
| backingScaleFactor | 2 | |

As ratios of the notch height h = 32 (they hold across display modes, since
the housing is physical and every number scales with points per millimetre):
shoulder 0.2129 h, bottom corner continuous radius 0.322 h, body = the
auxiliary gap. Fits tried for the bottom corner, as the largest distance from
the hardware curve: continuous 10.3 pt 0.046; continuous 10.9 pt (0.34 h)
0.17; circular 10.88 pt (today) 0.24; circular 13.55 pt 1.35.

Two traps: the aux areas are whole points, so their centre (755.5) sits half
a point left of the housing; the island must centre on `screen.midX`, which it
does (`NotchGeometry.frame(for:)`). And the menu bar is 33 pt while the
housing is 32.07: anything 33 pt tall at rest shows a 0.93 pt black lip under
the notch.

## 2. The software today, and every mismatch

Inputs on this Mac: cameraWidth 185, safe top 32, menu bar 33, preset
spacious. The owner's install has "cover the menu bar gap" off (strip 32);
the default and the Developer build have it on (strip 33).

| State | Size today (pt) | Mismatch |
| --- | --- | --- |
| Closed, bare | 185 x 32 (33 with gap cover) | The rect includes the shoulders, so the body is 185 - 2 x 6.08 = 172.8: 6.1 pt inside the housing on each side, and the top is 185, not 198.6. Hidden at rest, but every growth starts hidden: for the first 12 pt of width the visible outline is the hardware's sides over a narrower software band, a step at both bottom corners. With gap cover on, a 0.93 pt black lip under the notch at rest. |
| Corners | shoulder min(14, 0.19 h) = 6.08 circular (handle 0.552); bottom min(28, 0.34 h) = 10.88 circular | Hardware shoulder is 6.81 with handle 0.776; hardware bottom is continuous, 10.3. Circular corners are a different curve family from the cutout and from every `.continuous` plate inside. |
| Closed, idle content | 273 x 32 (44 pt resting wings) | Fine. |
| Hover pulse | resting + 20 wide, + 5 tall | Fine once the resting island is the hardware outline. |
| Hover peek | 340 x 94 | Fine; it is the tall peek's size already. |
| Song peek | 200.8 x 92 (body kept at 172.8 under a 60 pt band) | A different anatomy from every other peek, and narrower than the housing's own body. |
| Agent wrap-up | 422 x 32 for "Claude finished" and "4m 12s · $1.23", centre 13.5 pt left of the camera; "Codex finished" and "52s": 356 wide, 42.5 pt off centre | Too wide (2.3 notches), lopsided, title and numbers both 11 pt medium white, text pushed to the far ends with dead black beside the camera, no shared anatomy with the song peek. |
| Expanded | 560 wide; height by page: music 254, timer 190 to 226, budget pages 328, details 384, lyrics 470 | The island springs to a new height on every page flip. |

Window and growth today: the window reserves the whole motion's envelope once
(both ends plus the overshoot), the content is laid out at the target size on
the first frame and masked by the moving silhouette, so nothing squishes. The
silhouette is a 120 Hz keyframed path. Width and height ride different
springs (0.44 s at 0.25 bounce, 0.38 s at 0.22), so height arrives first and
the island reads tall and narrow mid-grow; overshoot is capped at 12 pt.
Content starts fading at 0.16 s with the shape at 78 percent of its width,
under a 12 pt blur and a 0.86 scale. An interruption starts the new spring
from what is on screen (no jump), but at zero velocity: a hover that leaves
mid-grow stops the island dead, then shrinks it.

## 3. The proposal (implemented in this stream)

### 3.1 Closed island = the hardware outline

- Body width: `cameraWidth` (aux gap plus the camera fit). Height: the cutout,
  `safeAreaTop` plus the fit, never the menu bar cover. Shoulders sit outside
  the body, so the bare resting surface is `cameraWidth + 2 x shoulder(h)` by
  `cutoutHeight`: 198.6 x 32 here. Every growing frame is then a superset of
  the housing, so only the software outline is ever seen and there is no step.
- Strips beside the camera keep `stripHeight` (32, or 33 with gap cover) and
  their wing rules; they already contain the housing.
- `bareCutout` (full screen, Lock Screen) keeps its meaning, the camera body.

### 3.2 The radii ladder

All island corners are continuous, drawn by `NotchLayout.islandPath`, which
`NotchShape` uses everywhere (window mask, backdrop, Settings previews, Lock
Screen). Every size has the same path elements, so any two frames blend.

| Height | Shoulder `NotchLayout.shoulder(height:)` | Bottom `NotchLayout.surfaceRadius(height:)` |
| --- | --- | --- |
| 32 (closed) | 6.81 | 10.3 (the cutout) |
| 37 (hover pulse) | 7.9 | 11.9 |
| 66 and up | 14 (cap) | 21.2 at 66 |
| 87 and up (peeks, panel) | 14 | 28 (cap, `panelCornerRadius`) |

Shoulder = min(14, 0.2129 h), handle 0.776. Bottom = min(28, 0.322 h),
continuous. Inner corners nest: `inner = outer - inset` (28 - 16 = 12 for
cards). The cap of 28 matches the open panel token.

### 3.3 Growth choreography

- One spring for both axes, so the aspect changes in a straight line:
  growing `Geometry.growSpring` (response 0.40, damping 0.85), shrinking
  `Geometry.shrinkSpring` (0.30, damping 1). Overshoot at most 8 pt.
  Anchor: top centre. Each side keeps its own distance to travel.
- Interruptible with velocity: a new target starts from the presented size
  and inherits the current velocity of each side, so a hover that leaves
  mid-grow carries on a few points, turns and closes. A shrink never passes
  its target (the incoming speed is capped so a critically damped spring
  cannot cross it), so a collapse never dips inside the housing.
- Content: laid out at its final size from the first frame, masked by the
  shape, never scaled. It starts while the shape is still growing
  (`Geometry.contentRevealDelay`, 0.12 s, while the shape is still growing,
  the Dynamic Island way; peeks use `Peek.contentRevealDelay`, 0) and fades in
  from a 4 pt blur over 0.18 s, sharp at 0.30 s. Leaving content fades out over 0.12 s on an
  ease out. All four numbers are NotchDesign tokens.
- Reduce Motion: the shape lands at its size at once and content cross-fades;
  no blur, no overshoot.

### 3.4 Canvases

| Canvas | Size on this Mac (spacious) | Rule |
| --- | --- | --- |
| Closed | 198.6 x 32 | 3.1 |
| Compact peek | strip height (32 or 33) | wings 36 to 96 pt a side, symmetric, snug to the camera |
| Tall peek | 300 to 360 wide, strip + 60 tall (92) | the band below the strip; song, agent wrap-up, downloads, calendar |
| Expanded page | 560 x 328 (content 500 x 264) | one fixed canvas per preset (compact 480 x 244) |

One fixed expanded canvas, because pages flip tens of times a day and a
silhouette that springs on every flip spends motion where nothing physical
happened; a fixed canvas also keeps the bottom edge still under the pointer,
so a page change can never become a hover exit. Growth stays only where the
person asked for more: a drill-in detail (the tall page, 320 content), and
the sections gallery. `NotchCanvas.page` is that canvas; pages lay out for
it now. The switch of `expandedSize` to the fixed canvas lands once the five
content-fitted pages (controls, music, tools, timer, agents) fill it, so no
page shows a black band in between.

### 3.5 One peek anatomy

Compact and tall are the Dynamic Island's compact and expanded
presentations. Compact: leading glyph or cover (20 pt), trailing one value,
both wings the same width, at most 96. Tall: the strip unchanged, a 60 pt
band below it, 16 pt margins, leading 32 pt mark or cover (radius 12),
primary line 12 pt semibold, secondary 10 pt medium in the secondary ink,
optional 20 pt trailing element. The agent wrap-up moves to the tall peek:
"Claude finished" over "4 min · $0.42", the Claude mark leading, nothing
trailing, the wings beside the camera unchanged.

## 4. Contract for page and peek builders

Read the canvas, never recompute it:

```swift
@Environment(\.notchCanvas) private var canvas
```

`NotchWindowHost` publishes it for every presentation (Settings previews can
build one with `NotchCanvas(geometry:size:)`). Fields, all in points:

| Field | Meaning |
| --- | --- |
| `size` | The surface the island is presenting or heading to (the final size from the first frame of a transition). |
| `camera` | The housing body: width `cameraWidth`, height the cutout. Nothing draws over it in a strip. |
| `stripHeight` | One row beside the camera; the compact peek's height. |
| `leadingWing`, `trailingWing` | Room left and right of the camera at `size`, including the shoulder. |
| `shoulder`, `cornerRadius` | The silhouette's shoulder and continuous bottom radius at `size`. |
| `margin` | 16, the body margin on the sides and bottom. |
| `compactWing` | 36...96, the compact peek's wing range. |
| `tallPeek` | The tall peek's surface (strip + 60, 300 to 360 wide). `tallPeekBand` is the band's height, 60. |
| `page` | The fixed expanded canvas for the preset; `pageContent` is its content area (minus header chrome and insets). |
| `contentInsets` | Insets from the island's edge to page content: top = header chrome, sides = `NotchLayout.horizontalInset` (30 = shoulder 14 + margin 16), bottom 16. |
| `concentricRadius(inset:)` | The radius of a plate inset that far inside the island's bottom corner. |

Rules: lay out for `canvas.size` from the first frame, never animate your own
frame to follow the shape; never draw past `contentInsets`; never scale on
enter; keep wings symmetric; text truncates, the island never widens for it.
