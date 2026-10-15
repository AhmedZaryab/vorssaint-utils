---
name: nb
description: Fast feature build for the Vorssaint notch repo. Worktree off local ours, one Sonnet builder, quick gate, merge into ours, push. Use when the owner types /nb <feature>.
---

# /nb <feature in his words>

Typing `/nb` is standing approval to build, merge into `ours` and push `origin ours`. No PR, no board card, no review agent, no full test suite, no screenshots unless his words say "show me". No em or en dashes in anything written. Everything below runs through `scripts/nb.sh` (repo root of the main checkout `/Users/zaryabahmed/Desktop/projects/vorssaint`).

## Flow
1. **Start.** `scripts/nb.sh start <slug>` (short kebab slug). It fetches, fast-forwards `ours` if origin is ahead, stops if they diverged, falls back to local `ours` offline, creates `../vorssaint-wt-<slug>` on `nb/<slug>`, and clones the incremental test build cache in. Prints the worktree path.
2. **Build.** ONE Sonnet builder (`model: sonnet`, medium effort) works only inside that worktree. Brief = his words verbatim plus the rules below. Commit when done, named files only. Serve nothing; never launch /Applications/Vorssaint.app (a dev app started for a check gets quit).
3. **Gate.** From the worktree: `/Users/zaryabahmed/Desktop/projects/vorssaint/scripts/nb.sh gate`. It runs `swift build`, then `./build.sh --test-suite=<x>` for only the suites mapped from the changed files, then the dash grep on added lines. Red means fix and rerun, never skip.
4. **Land.** From the worktree: `scripts/nb.sh land` (add `--after <slug>` to hold until that slug has landed; exit 5 means report READY and stop). Under `lockf`: rebase on local `ours`, rebuild only if `ours` moved, `merge --no-ff` in the main checkout, `git push origin ours` (fast-forward only, origin only, never force, never `upstream`), then removes the worktree. Exit 3 is a rebase conflict: resolve it in the worktree, `swift build`, rerun land. Never auto resolve.
5. **Install** only if his words include "install" or "go live": `scripts/nb.sh install` (backs up /Applications/Vorssaint.app to `~/Desktop/projects/Legacy-notch/Vorssaint-before-<date>.app`, `./build.sh --install`, `open -a Vorssaint` once, checks one process).

## Builder brief, always include
- Visual work uses NotchDesign tokens, never raw values. Respect Reduce Motion. Only enabled features.
- No em or en dashes in code, comments, copy or commits.
- Skills are untracked in the main checkout: read them by absolute path under `/Users/zaryabahmed/Desktop/projects/vorssaint/.claude/skills/`.
- Do not run `./build.sh` without a flag, the full test suite, or anything that pushes. Do not touch other worktrees.

## Running it from a subagent
Agent call, `model: sonnet`, prompt: "Run /nb for this brief: <brief or path to brief file>. Use `/Users/zaryabahmed/Desktop/projects/vorssaint/scripts/nb.sh`: start <slug>, build only in the printed worktree, gate, commit, land. Report the merge commit or the failing step."

## What was removed versus Bedside /nb, and why that is safe here
- Board card, ticket ticking, release checklist: this repo has no board.
- run-log and `pr_merge_dev.sh` away-mode hold: nothing here reads them; the lock plus fast-forward push is the only guard needed.
- PR, GitHub issue, squash opener: `ours` is an integration branch with one remote, history shows the merge.
- E2E, lint, modularity, pnpm install and venv relinking: none exist; `swift build` plus touched suites is the whole gate.
- `EnterWorktree` and a session switch: the builder gets absolute paths instead, no extra tool round trip.
- Separate fetch/report steps: folded into `start` and the final line.

## Build cache (tested)
- `build/objects` (swiftc incremental, relative paths) clones with `cp -Rc` in about 1s; a test build drops from 29s to 3s.
- `.build` (SwiftPM) does NOT carry over: absolute paths force a full rebuild (about 75s), so it is not cloned. Do not share one `--scratch-path` between parallel worktrees.
