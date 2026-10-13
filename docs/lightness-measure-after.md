# Vorssaint idle cost: after perf/idle-burners

Measured 2026-10-13 on build of ours at dcea2832 (perf/idle-burners merged, peek-band-look included), installed to /Applications, pid 25421. Same method as lightness-measure-before.md: 60 s settle, notch closed, Spotify paused, ps three times 10 s apart, top x3, log last 5 min, 5 s sample.
Caveats: the app had been launched about 60 s earlier, so RSS was still climbing from a cold start (145, 227, 254 MB; 117 MB a minute later). The before run had music playing, this one has it paused, so part of the delta is state, not code. A first attempt measured the old binary (the old process survived pkill); it was discarded and the app relaunched.

| Metric | Before | After |
| --- | --- | --- |
| RSS (MB) | 418, 461, 461 | 145, 227, 254 (settled to 117 afterwards) |
| Idle CPU % (ps) | 3.3, 4.7, 3.6 | 1.0, 2.7, 0.1 (top: 0.0, 0.0, 0.1) |
| Wakeups/s (top IDLEW) | about 4 to 6 | 0 |
| Log lines/min (Vorssaint process, 5 min) | about 208 (1039 per 5 min) | about 425 (2126 per 5 min); includes launch noise, predicate may differ from before |
| Perl now-playing helper | 28 MB, 0.0 to 0.1 % | not running (nothing playing) |
| Top hot function (5 s sample) | NotchPlayerClock.follow, 77 samples of 4018 | stat 101, then AgentUsageService.pollOpenLogs 22 (main thread idle otherwise) |

Changed: the player clock, decorative display link and per-read compactActivity cost no longer show in the sample, and wakeups dropped to 0.
Still hot: AgentUsageService.pollOpenLogs stat()ing log files (use a file watcher or stop when no agent session is active); log volume did not fall, so re-measure it after a longer settle.

## Wave 2 (spacesOrder, musicBlock, smoothScroll, audioPriority cut; agent-log poll fix)

Measured 2026-10-13 on ours-cuts-wave2, installed to /Applications, pid 91516. 90 s settle, notch closed, no call window open. Caveat: Xcode builds were running on the Mac during part of the run.

| Metric | Previous after | Wave 2 |
| --- | --- | --- |
| RSS (MB) | 145, 227, 254 (settled 117) | 267, 267, 298 (start-up still settling) |
| Idle CPU % (ps) | 1.0, 2.7, 0.1 | 0.9, 0.2, 3.8 (top: 0.0, 0.2, 0.6) |
| Wakeups/s (top IDLEW) | 0 | 0 to 30 per interval, low |
| Log lines in 5 min | 2126 | 768 |
| Top hot function (5 s sample, non-idle) | stat 101, AgentUsageService.pollOpenLogs 22 | Hasher.combine(bytes:) 90, newJSONString 26 |
| Binary size (MacOS/Vorssaint) | 78,116,256 B | 77,624,736 B (-491,520 B, -0.6%) |
