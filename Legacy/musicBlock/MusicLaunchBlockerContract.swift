import AppKit
import Foundation

/// The production lifecycle and event handlers are extracted into Service.
/// These doubles replace the workspace, permission, event tap and application
/// endpoints; no test observes real input, opens an app or terminates a process.
enum MusicLaunchBlockerContract {
    enum Environment {
        static var enabled = true
        static var playReplacement = true
        static var available = true
        static var trusted = true
        static var createsTap = true
        static var enablesTap = true
        static var now: TimeInterval = 10
        static var gestureAge: TimeInterval = 3
        static var running: [NSRunningApplication] = []
    }
    enum AppFeature {
        case musicBlock
        var isAvailable: Bool { Environment.available }
    }
    enum UserDefaults {
        static let standard = Store()
        final class Store {
            func bool(forKey key: String) -> Bool {
                key == DefaultsKey.musicBlockPlayReplacement
                    ? Environment.playReplacement : Environment.enabled
            }
        }
    }
    static func AXIsProcessTrusted() -> Bool { Environment.trusted }
    enum ProcessInfo {
        static let processInfo = Clock()
        struct Clock { var systemUptime: TimeInterval { Environment.now } }
    }
    final class Tap { var enabled = true }
    final class CGEvent {
        let timestamp: TimeInterval
        let subtype: Int
        let data1: Int
        init(at timestamp: TimeInterval, subtype: Int = 8, key: UInt16 = 16,
             state: Int = 10, repeats: Bool = false) {
            self.timestamp = timestamp
            self.subtype = subtype
            data1 = Int((UInt32(key) << 16) | (UInt32(state) << 8) | (repeats ? 1 : 0))
        }
        static func tapIsEnabled(tap: Tap) -> Bool { tap.enabled }
        static func tapEnable(tap: Tap, enable: Bool) { tap.enabled = enable && Environment.enablesTap }
    }
    struct NSEvent {
        struct Subtype { let rawValue: Int }
        let subtype: Subtype
        let data1: Int
        let timestamp: TimeInterval
        init?(cgEvent: CGEvent) {
            subtype = Subtype(rawValue: cgEvent.subtype)
            data1 = cgEvent.data1
            timestamp = cgEvent.timestamp
        }
    }
    final class NSRunningApplication {
        let bundleIdentifier: String?
        let processIdentifier: pid_t
        var forceSucceeds = true
        var terminateSucceeds = true
        var forceCalls = 0
        var terminateCalls = 0
        init(_ pid: pid_t, bundle: String? = "com.apple.Music") {
            processIdentifier = pid
            bundleIdentifier = bundle
        }
        static func runningApplications(withBundleIdentifier bundle: String) -> [NSRunningApplication] {
            Environment.running.filter { $0.bundleIdentifier == bundle }
        }
        func forceTerminate() -> Bool { forceCalls += 1; return forceSucceeds }
        func terminate() -> Bool { terminateCalls += 1; return terminateSucceeds }
    }
    enum NSWorkspace {
        static let shared = Workspace()
        static let willLaunchApplicationNotification = Notification.Name("fixture.willLaunch")
        static let didLaunchApplicationNotification = Notification.Name("fixture.didLaunch")
        static let applicationUserInfoKey = "application"
        final class Workspace { let notificationCenter = NotificationCenter() }
    }
    class Fixture {
        static let blockedBundleIDs: Set<String> = ["com.apple.Music", "com.apple.iTunes"]
        static var secondsSinceUserGesture: TimeInterval { Environment.gestureAge }
        var isEnabled: Bool { Environment.enabled && Environment.available }
        var isMonitoring = false
        var observers: [NSObjectProtocol] = []
        var mediaKeyTap: Tap?
        var lastMediaKeyAt: TimeInterval?
        var lastMediaKeyCode: UInt16?
        var judgedLaunchPID: pid_t?
        var replacementCalls = 0
        var replacementPlays: [Bool] = []
        func installMediaKeyTap() {
            if mediaKeyTap == nil, Environment.createsTap { mediaKeyTap = Tap() }
        }
        func removeMediaKeyTap() { mediaKeyTap?.enabled = false; mediaKeyTap = nil }
        func openReplacementIfConfigured(startingPlayback: Bool) {
            replacementCalls += 1
            replacementPlays.append(startingPlayback)
        }
    }

    static func run(_ suite: TestSuite) {
        let service = Service()
        defer { service.stop() }
        func reset() {
            service.stop()
            service.replacementCalls = 0
            service.replacementPlays = []
            Environment.enabled = true
            Environment.playReplacement = true
            Environment.available = true
            Environment.trusted = true
            Environment.createsTap = true
            Environment.enablesTap = true
            Environment.now = 10
            Environment.gestureAge = 3
            Environment.running = []
        }
        func launch(_ app: NSRunningApplication, did: Bool = false) {
            service.handleLaunch(Notification(name: did ? NSWorkspace.didLaunchApplicationNotification
                                                : NSWorkspace.willLaunchApplicationNotification,
                                               userInfo: [NSWorkspace.applicationUserInfoKey: app]))
        }
        func key(at: TimeInterval = 9.5, code: UInt16 = 16, state: Int = 10, repeats: Bool = false,
                 type: CGEventType = CGEventType(rawValue: 14)!) {
            let event = CGEvent(at: at, key: code, state: state, repeats: repeats)
            let passed = service.handleMediaKeyEvent(type: type, event: event)?.takeUnretainedValue()
            suite.expect(passed === event, "the blocker observes events without swallowing or replacing them")
        }
        reset()
        Environment.trusted = false
        service.syncWithPreferences()
        suite.expect(!service.isMonitoring && service.mediaKeyTap == nil && service.observers.isEmpty,
                     "without Accessibility the blocker has no tap, observer or claimed protection")
        launch(NSRunningApplication(1))
        Environment.trusted = true
        Environment.createsTap = false
        service.syncWithPreferences()
        suite.expect(!service.isMonitoring && service.observers.isEmpty,
                     "a failed tap cannot leave a launch observer making unsupported decisions")
        Environment.createsTap = true
        service.syncWithPreferences()
        let installed = service.observers.count
        service.syncWithPreferences()
        suite.expect(service.isMonitoring && service.mediaKeyTap != nil && installed == 2
                     && service.observers.count == installed,
                     "granting access starts one observer pair and repeated syncs do not duplicate it")
        let automatic = NSRunningApplication(2)
        key()
        launch(automatic)
        launch(automatic, did: true)
        suite.expect(automatic.forceCalls == 1 && automatic.terminateCalls == 0 && service.replacementCalls == 1,
                     "a detected key blocks one launch and its did-launch cannot repeat termination or replacement")
        key(code: MusicLaunchSupport.nextTrackKeyCode)
        launch(NSRunningApplication(50))
        suite.expect(service.replacementPlays == [true, false],
                     "only Play/Pause asks the replacement to play; the other media keys only open it")
        Environment.playReplacement = false
        key()
        launch(NSRunningApplication(51))
        suite.expect(service.replacementPlays == [true, false, false],
                     "turning off replacement playback still opens it without sending play")
        Environment.playReplacement = true
        let second = NSRunningApplication(3)
        launch(second)
        suite.expect(second.forceCalls == 0 && service.lastMediaKeyAt == nil,
                     "the same media key cannot terminate a second launch within its arm window")
        let manual = NSRunningApplication(4)
        key()
        Environment.gestureAge = 0.1
        launch(manual)
        Environment.gestureAge = 100
        launch(manual, did: true)
        suite.expect(manual.forceCalls == 0 && service.lastMediaKeyAt == nil,
                     "a later deliberate gesture wins and did-launch cannot reverse that decision")
        for pid: pid_t in 5...7 {
            let deliberate = NSRunningApplication(pid)
            launch(deliberate)
            suite.expect(deliberate.forceCalls == 0, "voice, automation and login without a media key are left alone")
        }
        let delayed = NSRunningApplication(8)
        key(at: 7)
        launch(delayed)
        suite.expect(delayed.forceCalls == 0, "delayed event delivery does not refresh an expired trigger")
        Environment.running = [NSRunningApplication(40)]
        key()
        Environment.running = []
        let afterExistingPlayer = NSRunningApplication(41)
        launch(afterExistingPlayer)
        suite.expect(afterExistingPlayer.forceCalls == 0 && service.lastMediaKeyAt == nil,
                     "a key sent to a running player cannot arm its later deliberate relaunch")
        for type in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            key()
            service.mediaKeyTap?.enabled = false
            key(type: type)
            let afterGap = NSRunningApplication(type == .tapDisabledByTimeout ? 9 : 10)
            launch(afterGap)
            suite.expect(afterGap.forceCalls == 0 && service.lastMediaKeyAt == nil && service.isMonitoring,
                         "recovering a disabled tap starts with no stale key evidence")
        }
        key()
        service.mediaKeyTap?.enabled = false
        let disabled = NSRunningApplication(11)
        launch(disabled)
        suite.expect(disabled.forceCalls == 0 && !service.isMonitoring && service.lastMediaKeyAt == nil,
                     "an untrusted gap detected at launch drops the trigger and reports unavailable")
        Environment.enablesTap = false
        key(type: .tapDisabledByTimeout)
        suite.expect(!service.isMonitoring && service.lastMediaKeyAt == nil,
                     "a failed recovery never advertises active protection")
        for missing in ["preference", "feature", "permission"] {
            reset()
            service.syncWithPreferences()
            key()
            if missing == "preference" { Environment.enabled = false }
            if missing == "feature" { Environment.available = false }
            if missing == "permission" { Environment.trusted = false }
            let afterDisable = NSRunningApplication(20)
            launch(afterDisable)
            key()
            suite.expect(afterDisable.forceCalls == 0 && service.observers.isEmpty
                         && service.mediaKeyTap == nil && service.lastMediaKeyAt == nil && !service.isMonitoring,
                         "losing the \(missing) prevents queued launch/event callbacks and tears down resources")
        }
        reset()
        service.syncWithPreferences()
        key()
        service.stop()
        service.syncWithPreferences()
        let restarted = NSRunningApplication(30)
        launch(restarted)
        suite.expect(restarted.forceCalls == 0, "reenabling the feature cannot reuse the prior activation's trigger")
        for event in [(UInt16(0), 10, false), (16, 11, false), (16, 10, true)] {
            key(code: event.0, state: event.1, repeats: event.2)
            suite.expect(service.lastMediaKeyAt == nil, "volume, release and repeat events do not arm a launch")
        }
        key()
        let unrelated = NSRunningApplication(31, bundle: "org.example.other")
        launch(unrelated)
        suite.expect(unrelated.forceCalls == 0 && service.lastMediaKeyAt != nil,
                     "another app's launch is never terminated and does not consume the music trigger")
        let failed = NSRunningApplication(32)
        failed.forceSucceeds = false
        failed.terminateSucceeds = false
        launch(failed)
        suite.expect(failed.forceCalls == 1 && failed.terminateCalls == 1 && service.replacementCalls == 0,
                     "a failed termination does not open a competing replacement app")
        key()
        let fallback = NSRunningApplication(33, bundle: "com.apple.iTunes")
        fallback.forceSucceeds = false
        launch(fallback)
        suite.expect(fallback.forceCalls == 1 && fallback.terminateCalls == 1 && service.replacementCalls == 1,
                     "a successful normal termination still opens the configured replacement once")
    }
}
