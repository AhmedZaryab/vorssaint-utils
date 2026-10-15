# Vorssaint: rules for AI agents

Vorssaint is a macOS utility app whose centre is the notch island: music, timer, calendar, AI usage, files, clipboard and more, drawn around the camera housing. Swift Package, SwiftUI with AppKit where needed, macOS 14 and later, Liquid Glass on macOS 26. Origin is the owner's fork; `upstream` is the original project and is never pushed to.

## Build and test

```sh
swift build              # compile check of the whole package (about a minute); run before claiming done
./build.sh               # builds, assembles and signs the release bundle into build/stage/
./build.sh --dev         # "Vorssaint (Developer)", bundle com.vorssaint.utils.dev, into build/stage.noindex/
./build.sh --test        # standalone tests: compiles TEST_SOURCES in build.sh plus Tests/generate_sources.py output
```

- `--install` copies into /Applications and replaces the app the owner uses. Agents never pass it unless the owner asks in that turn.
- **Never launch /Applications/Vorssaint.app from an agent.** To see a change, build `--dev`, launch `build/stage.noindex/Vorssaint (Developer).app`, screenshot that, then quit it. It has its own bundle id, so it sits beside the real app without touching its settings or permissions.
- The test build compiles a fixed list of sources (`TEST_SOURCES` in build.sh), and `Tests/generate_sources.py` lifts some declarations verbatim out of views (NotchShape, NotchActivityPicker, NotchRail, calendar rows, NotchView.pageSize and more). If a file in that list or a lifted declaration starts using a new type, add that type's file to `TEST_SOURCES`. NotchDesign.swift is already there.
- **Legacy/** holds parked features that are not compiled. Never edit it, never add it back to build.sh, never add new reads of it to Tests/generate_sources.py. The one existing read (the quick preview's key handling in Legacy/capture) stays as it is. Bringing a feature back is the owner's call and its own change.

## Signing and permissions

- Local builds sign with the stable self-signed identity "Vorssaint Utils Signing", created once by `Tools/setup-signing.sh` (idempotent). macOS ties Accessibility, Screen Recording and Automation grants to that signature.
- Never rename the identity, never sign with another one, never ad-hoc sign: every grant would be lost and the owner re-prompted.
- Nothing in an agent's build should trigger a permission prompt on the owner's Mac. If a change needs a new permission, say so in one line instead of triggering it.

## The design rule (notch)

- **Every visual value in the notch comes from `Sources/Vorssaint/UI/Notch/NotchDesign.swift`**: spacing, radii, type, alphas, fills, strokes, shadows, springs, control sizes, peek anatomy. A missing token is added there, with its one-line doc comment, then used. Never a literal in a view.
- **Read `docs/design/NOTCH-DESIGN.md` before any notch UI change.** It holds the principles, geometry, layout grid, the five interaction classes, the peek anatomy, the per-page checklist and the old-literal to token migration table. Tick the page's checklist in the PR.
- Button feel is one of five classes, one component each: `NotchPressStyle` (tap), `NotchToggleStyle` (toggle), `NotchCommitButton` (commit or send), `NotchFuseButton` (destructive, with undo), `NotchSlider` (slider), plus `.notchSuccessMorph(...)`. The spec's control kind table decides which.
- **Skills, mandatory on every notch UI change** (in `.claude/skills/`):
  - `apple-swiftui-specialist` while writing the code (Apple's own guidance; it supersedes training).
  - `swiftui-expert` to review it (view structure, performance, Liquid Glass, macOS, accessibility, animations).
  - `apple-design` for a HIG pass on the result (cite `references/hig/<page>.md`).
  - `emil-apple-design` and `emil-design-eng` for anything that moves or responds: motion, button feel, geometry, peeks.
  - `.claude/` is local and untracked. In a fresh worktree, copy it from the main checkout before starting.
- The island is always dark. One accent (the system accent), three signals (red, orange, green) always beside a symbol or word, artwork tint only on music controls, never on text.
- Nothing under 10 pt, no light weights, no 1 pt white borders, no glass inside the island, no content scaling while the island grows, no ease in, no animation on keyboard-initiated changes.

## The lightness rule

The owner: Vorssaint must be very lightweight, only features he uses.

- Nothing polls, ticks or animates while the notch is shut, or while a view is off screen or occluded. Timers and display links stop with their view; live indicators pause when hidden (see `NotchEqualizerView`).
- Observe the smallest subtree: a view that reads a fast-changing value is its own small view (`NotchLiveEqualizerBars` is the pattern). Never put a high-frequency `@ObservedObject` on NotchView or a page root.
- Pass views only the values they read. Prefer a separate `View` struct to a computed property for any section with its own inputs.
- No new background work, dependency or feature without the owner asking for it. Removed features go to Legacy/, not back into the build.

## Words

- **No em dashes or en dashes in any user-visible string.** Use a full stop, a comma, a colon or a middot. An empty value is a word, never a dash glyph.
- Every user-visible string comes from the strings files in `Sources/Vorssaint/Core/*Strings.swift` through `L10n`, never a literal in a view.

## Gates before handing work back

```sh
swift build
grep -rnE '[—–]' Sources/Vorssaint/UI/Notch Sources/Vorssaint/Core/Notch*Strings.swift
grep -rnE 'cornerRadius: [0-9]|\.padding\([0-9]|\.font\(\.system\(size:' Sources/Vorssaint/UI/Notch --include='*.swift' | grep -v NotchDesign.swift | wc -l
```

- The dash grep must print nothing. On 2026-10-14 it found one line (`NotchAgentsView.swift`, an em dash glyph for an unpriced cost).
- The style count trends to zero and never grows. It was 353 on 2026-10-14. A change to a notch file must not add a hit; a page migration should leave its files at zero.
- Run `./build.sh --test` when you touch anything in `TEST_SOURCES` or a declaration Tests/generate_sources.py lifts.

## Git

- Conventional commits (`feat(design):`, `fix(notch):`, `refactor:`, `docs:`). Branch per task; never push to `upstream`; never merge to `main` unless the owner says so.
- Never commit build output, secrets or the local `.claude/` folder.
