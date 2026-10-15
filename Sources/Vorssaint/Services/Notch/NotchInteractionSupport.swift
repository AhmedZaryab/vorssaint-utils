// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The arithmetic behind the island's interaction library, apart from
/// SwiftUI so tests can drive it with explicit values and times.
enum NotchInteractionMath {
    /// Apple's rubber band: the further past a bound, the less the control
    /// follows, so an edge resists instead of stopping dead. The result keeps
    /// the overshoot's sign and never reaches `dimension`.
    static func rubberband(_ overshoot: Double, dimension: Double, constant: Double = 0.55) -> Double {
        guard overshoot.isFinite, dimension.isFinite, dimension > 0, constant > 0 else { return 0 }
        return overshoot * dimension * constant / (dimension + constant * abs(overshoot))
    }

    /// A pull that resists harder the further it goes and never reaches `limit`.
    static func resistedPull(_ raw: Double, limit: Double) -> Double {
        guard raw.isFinite, limit.isFinite, raw > 0, limit > 0 else { return 0 }
        return limit * raw / (limit + raw)
    }

    /// The raw pull `resistedPull` turns into `pull`, so a grab mid flight
    /// continues from where the control is drawn, not from its seat.
    static func rawPull(forResisted pull: Double, limit: Double) -> Double {
        guard pull.isFinite, limit.isFinite, pull > 0, limit > 0 else { return 0 }
        let held = min(pull, limit * 0.95)
        return limit * held / (limit - held)
    }

    static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }

    /// The value under a point `x` along a track whose ends sit at `start`
    /// and `end`, before clamping.
    static func trackValue(at x: Double, start: Double, end: Double, range: ClosedRange<Double>) -> Double {
        let span = end - start
        guard span > 0, x.isFinite else { return range.lowerBound }
        return range.lowerBound + (x - start) / span * (range.upperBound - range.lowerBound)
    }

    /// How far a point lies past the nearer end of a track, signed, zero on it.
    static func trackOvershoot(at x: Double, start: Double, end: Double) -> Double {
        guard x.isFinite else { return 0 }
        return x < start ? x - start : x > end ? x - end : 0
    }

    /// A value within `distance` of a detent lands on it, the nearest one.
    static func snapped(_ value: Double, to detents: [Double], within distance: Double) -> Double {
        guard value.isFinite, distance > 0,
              let nearest = detents.filter(\.isFinite).min(by: { abs($0 - value) < abs($1 - value) }),
              abs(nearest - value) <= distance else { return value }
        return nearest
    }

    /// One arrow press: `step` is a fraction of the range, `direction` its sign.
    static func stepped(_ value: Double, step: Double, direction: Int, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, step.isFinite, step > 0 else { return clamp(value, to: range) }
        return clamp(value + Double(direction.signum()) * step * span, to: range)
    }

    /// One particle of a burst at `progress` (0 to 1), as a unit offset to
    /// scale by the burst's reach, a size factor and an opacity that ends at
    /// zero. A zero direction throws the particles all around. The same index,
    /// seed and progress always give the same particle.
    static func particle(_ index: Int, of count: Int, seed: Int, directionX: Double, directionY: Double,
                         spreadDegrees: Double = 60,
                         progress: Double) -> (x: Double, y: Double, size: Double, opacity: Double) {
        let t = min(1, max(0, progress.isFinite ? progress : 1))
        let jitter = noise(index, seed)
        let radial = directionX == 0 && directionY == 0
        let lead = index == 0 && !radial
        let base = radial ? 0 : atan2(directionY, directionX)
        let spread = spreadDegrees * Double.pi / 180
        let angle = radial
            ? 2 * .pi * (Double(index) + jitter * 0.6) / Double(max(1, count))
            : base + (lead ? 0 : (jitter - 0.5) * spread)
        let reach = lead ? 1 : 0.45 + 0.55 * noise(index + 31, seed)
        // A strong ease out: fast off the rim, settling as it fades.
        let travel = (1 - pow(1 - t, 3)) * reach
        let opacity = t < 0.5 ? 1 : max(0, 1 - (t - 0.5) / 0.5)
        return (cos(angle) * travel, sin(angle) * travel, (lead ? 1 : 0.6 + 0.4 * jitter) * (1 - 0.6 * t), opacity)
    }

    /// A deterministic value in 0..<1 for an index and seed.
    private static func noise(_ index: Int, _ seed: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(seed % 997) * 78.233) * 43_758.5453
        return value - floor(value)
    }
}

/// Reports a detent once each time the value crosses it, however fast it
/// arrives, and never again while the value rests on it.
struct NotchDetentTracker {
    let detents: [Double]
    private var last: Double?

    init(detents: [Double]) {
        self.detents = detents.filter(\.isFinite).sorted()
    }

    /// Starts a gesture at `value` without reporting anything.
    mutating func begin(at value: Double) {
        last = value.isFinite ? value : nil
    }

    /// The detent crossed on the way to `value`, the last one passed when a
    /// single move jumps several.
    mutating func move(to value: Double) -> Double? {
        guard value.isFinite else { return nil }
        defer { last = value }
        guard let last, last != value else { return nil }
        let crossed = detents.filter { last < $0 ? value >= $0 : last > $0 && value <= $0 }
        return value > last ? crossed.last : crossed.first
    }
}

/// A destructive action's fuse runs on time, not on its drawing: lighting it
/// records when, and settling reads the clock. A burnt fuse commits whatever
/// the animation did, and a blown out one never does. It can be paused while
/// the pointer rests on it; a paused fuse never commits.
struct NotchFuseClock {
    enum Outcome: Equatable {
        case idle
        case burning(remaining: TimeInterval)
        case committed
    }

    let duration: TimeInterval
    private(set) var litAt: TimeInterval?
    private var pausedAt: TimeInterval?
    private var pausedFor: TimeInterval = 0
    var isBurning: Bool { litAt != nil }
    var isPaused: Bool { pausedAt != nil }

    init(duration: TimeInterval) {
        self.duration = duration.isFinite ? max(0, duration) : 0
    }

    /// Lights the fuse. A lit fuse keeps burning from when it was first lit.
    @discardableResult mutating func light(at now: TimeInterval) -> Bool {
        guard litAt == nil, now.isFinite else { return false }
        litAt = now
        pausedAt = nil
        pausedFor = 0
        return true
    }

    /// Holds the burn where it is. A fuse that has burnt down stays due.
    mutating func pause(at now: TimeInterval) {
        guard isBurning, pausedAt == nil, remaining(at: now) > 0 else { return }
        pausedAt = now
    }

    mutating func resume(at now: TimeInterval) {
        guard let pausedAt else { return }
        pausedFor += max(0, now - pausedAt)
        self.pausedAt = nil
    }

    /// True when this stopped a commit. A fuse that has already burnt down
    /// cannot be blown out; settling it commits.
    mutating func blowOut(at now: TimeInterval) -> Bool {
        guard isBurning, remaining(at: now) > 0 else { return false }
        reset()
        return true
    }

    func remaining(at now: TimeInterval) -> TimeInterval {
        guard let litAt else { return 0 }
        let burnt = max(0, (pausedAt ?? now) - litAt - pausedFor)
        return max(0, duration - burnt)
    }

    /// How much fuse is left: 1 when lit, 0 once it has burnt down.
    func fraction(at now: TimeInterval) -> Double {
        guard isBurning else { return 1 }
        return duration > 0 ? remaining(at: now) / duration : 0
    }

    /// Commits a fuse that has burnt down, exactly once.
    mutating func settle(at now: TimeInterval) -> Outcome {
        guard isBurning else { return .idle }
        let left = remaining(at: now)
        if left > 0 || isPaused { return .burning(remaining: left) }
        reset()
        return .committed
    }

    private mutating func reset() {
        litAt = nil
        pausedAt = nil
        pausedFor = 0
    }
}

/// A commit you can pull away from its seat: the pull resists toward a limit,
/// arms past a point and disarms a little inside it so the edge never flickers.
struct NotchSlingTracker {
    enum Release: Equatable {
        /// Never left the press slop: a plain click, which fires.
        case tap
        /// Released while armed.
        case fire
        /// Dragged, but let go inside the arm point.
        case cancel
    }

    let armAt: Double
    let limit: Double
    let slop: Double
    private(set) var moved = false
    private(set) var armed = false
    private var originX = 0.0
    private var originY = 0.0

    init(armAt: Double, limit: Double, slop: Double) {
        self.limit = max(1, limit)
        self.armAt = min(max(1, armAt), self.limit * 0.8)
        self.slop = max(0, slop)
    }

    /// Starts a grab with the control drawn `x`, `y` from its seat, which is
    /// not zero when it is caught on its way back.
    mutating func begin(presentedX x: Double, y: Double) {
        moved = false
        armed = false
        let pull = hypot(x, y)
        guard pull > 0.5 else { originX = 0; originY = 0; return }
        let raw = NotchInteractionMath.rawPull(forResisted: pull, limit: limit)
        originX = x / pull * raw
        originY = y / pull * raw
    }

    /// Where the control sits for a pointer `dx`, `dy` from where it was grabbed.
    mutating func pull(dx: Double, dy: Double) -> (x: Double, y: Double) {
        if !moved, hypot(dx, dy) > slop { moved = true }
        let rawX = originX + dx
        let rawY = originY + dy
        let raw = hypot(rawX, rawY)
        guard raw > 0.01 else { armed = false; return (0, 0) }
        let pull = NotchInteractionMath.resistedPull(raw, limit: limit)
        if armed ? pull < armAt - 3 : pull >= armAt { armed.toggle() }
        return (rawX / raw * pull, rawY / raw * pull)
    }

    func release() -> Release { !moved ? .tap : armed ? .fire : .cancel }
}
