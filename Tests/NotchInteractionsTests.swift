// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The interaction library's deterministic parts: the fuse's clock, the
/// rubber band, the sling's arming and the slider's detents.
enum NotchInteractionsTests {
    static func run(_ suite: TestSuite) {
        rubberband(suite)
        fuse(suite)
        detents(suite)
        sling(suite)
        slider(suite)
        burst(suite)
    }

    private static func rubberband(_ suite: TestSuite) {
        let band = { NotchInteractionMath.rubberband($0, dimension: 12) }
        suite.expect(band(0) == 0, "no overshoot, no stretch")
        suite.expect(band(20) > 0 && band(-20) < 0 && band(20) == -band(-20),
                     "the rubber band keeps the overshoot's direction and is symmetric")
        suite.expect(band(10) < 10, "past an edge the control follows less than the pointer")
        for overshoot in [1.0, 50, 500, 1e6, 1e12] {
            suite.expect(abs(band(overshoot)) < 12 && abs(band(-overshoot)) < 12,
                         "the stretch never reaches its dimension at \(overshoot)")
        }
        suite.expect(band(40) > band(20) && band(400) > band(40), "pulling further always stretches a little more")
        suite.expect(NotchInteractionMath.rubberband(.nan, dimension: 12) == 0
                     && NotchInteractionMath.rubberband(.infinity, dimension: 12) == 0
                     && NotchInteractionMath.rubberband(5, dimension: 0) == 0,
                     "invalid input never stretches the control")
        let limit = 64.0
        for raw in [0.5, 10, 40, 200, 1e6] {
            let pull = NotchInteractionMath.resistedPull(raw, limit: limit)
            suite.expect(pull > 0 && pull < limit, "a pull of \(raw) stays inside the limit")
            if pull < limit * 0.95 {
                suite.expectClose(NotchInteractionMath.rawPull(forResisted: pull, limit: limit), raw,
                                  "a grab mid flight recovers the raw pull of \(raw)", tol: 1e-6)
            }
        }
        suite.expect(NotchInteractionMath.resistedPull(-5, limit: limit) == 0
                     && NotchInteractionMath.rawPull(forResisted: limit * 2, limit: limit).isFinite,
                     "a pull toward the seat or past the limit stays finite")
    }

    private static func fuse(_ suite: TestSuite) {
        var clock = NotchFuseClock(duration: 2.5)
        suite.expect(clock.settle(at: 0) == .idle && !clock.blowOut(at: 0), "an unlit fuse has nothing to commit or undo")
        suite.expect(clock.light(at: 10) && clock.isBurning, "a press lights the fuse")
        suite.expect(!clock.light(at: 11), "pressing a lit fuse never restarts its clock")
        suite.expect(clock.settle(at: 12) == .burning(remaining: 0.5), "the fuse keeps burning until its time is up")
        suite.expectClose(clock.fraction(at: 11.25), 0.5, "half the fuse is left halfway through")
        suite.expect(clock.blowOut(at: 12.4) && !clock.isBurning, "pressing again before the end blows the fuse out")
        suite.expect(clock.settle(at: 20) == .idle, "a blown out fuse never commits, however long it waits")

        var burnt = NotchFuseClock(duration: 2.5)
        burnt.light(at: 0)
        suite.expect(burnt.settle(at: 2.4999) != .committed, "nothing commits before the fuse burns down")
        suite.expect(burnt.settle(at: 2.5) == .committed, "the action commits once the fuse burns down")
        suite.expect(burnt.settle(at: 3) == .idle, "a fuse commits exactly once")
        suite.expect(burnt.fraction(at: 3) == 1, "a settled fuse is full again for next time")

        var late = NotchFuseClock(duration: 2.5)
        late.light(at: 0)
        suite.expect(!late.blowOut(at: 2.6) && late.settle(at: 2.6) == .committed,
                     "an undo after the fuse burnt down cannot strand it: the clock commits")
        var held = NotchFuseClock(duration: 2.5)
        held.light(at: 0)
        held.pause(at: 1)
        suite.expect(held.isPaused && held.remaining(at: 30) == 1.5 && held.settle(at: 30) == .burning(remaining: 1.5),
                     "the pointer resting on a fuse holds the burn, and a held fuse never commits")
        held.resume(at: 30)
        suite.expect(held.settle(at: 31.4) != .committed && held.settle(at: 31.5) == .committed,
                     "the burn picks up where it was held")
        var due = NotchFuseClock(duration: 1)
        due.light(at: 0)
        due.pause(at: 2)
        suite.expect(!due.isPaused && due.settle(at: 2) == .committed, "a fuse that is already due cannot be held")
        var instant = NotchFuseClock(duration: .nan)
        instant.light(at: 0)
        suite.expect(instant.settle(at: 0) == .committed, "an invalid duration commits at once instead of never")
    }

    private static func detents(_ suite: TestSuite) {
        var tracker = NotchDetentTracker(detents: [0.5, .nan, 0.25])
        tracker.begin(at: 0.1)
        suite.expect(tracker.move(to: 0.2) == nil, "moving between detents is silent")
        suite.expect(tracker.move(to: 0.3) == 0.25, "crossing a detent ticks")
        suite.expect(tracker.move(to: 0.4) == nil, "a detent ticks once per crossing")
        suite.expect(tracker.move(to: 0.5) == 0.5, "landing exactly on a detent counts as crossing it")
        suite.expect(tracker.move(to: 0.5) == nil && tracker.move(to: 0.55) == nil,
                     "resting on a detent and leaving it the same way never ticks again")
        suite.expect(tracker.move(to: 0.45) == 0.5, "crossing back is a new crossing")
        suite.expect(tracker.move(to: 0.9) == 0.5, "a jump over a detent still ticks")
        suite.expect(tracker.move(to: 0.1) == 0.25, "a jump over several reports the last one passed")
        suite.expect(NotchInteractionMath.snapped(0.51, to: [0.25, 0.5], within: 0.02) == 0.5
                     && NotchInteractionMath.snapped(0.53, to: [0.25, 0.5], within: 0.02) == 0.53
                     && NotchInteractionMath.snapped(0.26, to: [0.25, 0.5], within: 0) == 0.26,
                     "a value close to a detent lands on it, and only close ones do")
        var snapping = NotchDetentTracker(detents: [0.5])
        snapping.begin(at: 0.3)
        let path = [0.45, 0.5, 0.5, 0.5, 0.6, 0.5, 0.4].map { snapping.move(to: $0) != nil }
        suite.expect(path == [false, true, false, false, false, true, false],
                     "snapping onto a detent ticks once on the way in, once more on the way back")
        var fresh = NotchDetentTracker(detents: [0.5])
        fresh.begin(at: 0.5)
        suite.expect(fresh.move(to: 0.6) == nil, "a drag that starts on a detent does not tick for leaving it")
        suite.expect(fresh.move(to: .infinity) == nil, "an invalid value never ticks")
    }

    private static func sling(_ suite: TestSuite) {
        var sling = NotchSlingTracker(armAt: 26, limit: 64, slop: 4)
        sling.begin(presentedX: 0, y: 0)
        _ = sling.pull(dx: 2, dy: 1)
        suite.expect(sling.release() == .tap, "a press inside the slop is a plain click and fires")

        sling.begin(presentedX: 0, y: 0)
        var far = sling.pull(dx: -200, dy: 0)
        suite.expect(sling.armed && sling.release() == .fire, "pulled past the arm point, a release fires")
        suite.expect(abs(far.x) < 64 && far.y == 0, "the pull resists toward its limit and keeps its direction")
        _ = sling.pull(dx: -10, dy: 0)
        suite.expect(!sling.armed && sling.release() == .cancel, "dragged back inside, a release does nothing")

        sling.begin(presentedX: 0, y: 0)
        var raw = 0.0
        while NotchInteractionMath.resistedPull(raw, limit: 64) < 26 { raw += 0.25 }
        _ = sling.pull(dx: raw, dy: 0)
        suite.expect(sling.armed, "the arm point arms")
        _ = sling.pull(dx: raw - 1, dy: 0)
        suite.expect(sling.armed, "a hair inside the arm point stays armed, so the edge never flickers")

        sling.begin(presentedX: 20, y: -15)
        far = sling.pull(dx: 0, dy: 0)
        suite.expect(abs(far.x - 20) < 1e-6 && abs(far.y + 15) < 1e-6,
                     "a grab mid flight takes over from where the control is drawn")
        suite.expect(!sling.armed && sling.release() == .tap, "catching it without moving is a click")
    }

    private static func slider(_ suite: TestSuite) {
        let math = NotchInteractionMath.self
        suite.expectClose(math.trackValue(at: 57, start: 7, end: 107, range: 0...1), 0.5, "the middle of the track")
        suite.expect(math.trackValue(at: -20, start: 7, end: 107, range: 0...1) < 0
                     && math.clamp(math.trackValue(at: -20, start: 7, end: 107, range: 0...1), to: 0...1) == 0,
                     "a pointer past the start clamps the value to the minimum")
        suite.expect(math.trackOvershoot(at: -3, start: 7, end: 107) == -10
                     && math.trackOvershoot(at: 50, start: 7, end: 107) == 0
                     && math.trackOvershoot(at: 120, start: 7, end: 107) == 13,
                     "only a pointer past an end stretches the track, toward that end")
        suite.expectClose(math.stepped(0.5, step: 0.05, direction: 1, range: 0...1), 0.55, "an arrow steps up")
        suite.expect(math.stepped(0.98, step: 0.05, direction: 1, range: 0...1) == 1
                     && math.stepped(0.02, step: 0.05, direction: -1, range: 0...1) == 0,
                     "an arrow never steps past either end")
        suite.expectClose(math.stepped(50, step: 0.1, direction: -1, range: 0...200), 30,
                          "a step is a share of the range, not an absolute amount")
    }

    private static func burst(_ suite: TestSuite) {
        let math = NotchInteractionMath.self
        let first = math.particle(3, of: 8, seed: 4, directionX: 1, directionY: 0, progress: 0.4)
        let again = math.particle(3, of: 8, seed: 4, directionX: 1, directionY: 0, progress: 0.4)
        suite.expect(first == again, "a burst draws the same particles every frame")
        for index in 0..<10 {
            let end = math.particle(index, of: 10, seed: 7, directionX: 0, directionY: -1, progress: 1)
            suite.expect(end.opacity == 0, "every particle is gone when its burst ends")
            let start = math.particle(index, of: 10, seed: 7, directionX: 0, directionY: -1, progress: 0)
            suite.expect(start.x == 0 && start.y == 0 && start.opacity == 1, "particles leave from the rim")
            let mid = math.particle(index, of: 10, seed: 7, directionX: 0, directionY: -1, progress: 0.5)
            suite.expect(mid.y < 0, "a burst thrown upward travels upward")
        }
    }
}
