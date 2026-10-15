// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// `--render-notch <dir>` draws every state of the island to a PNG from made-up
/// data, for before-and-after comparisons of the island's design. It needs no
/// clicks and no Screen Recording: each state is laid out in an invisible
/// window and drawn with `cacheDisplay`, at 2x on a black ground. Nothing is
/// read from this Mac's user: preferences are masked by a volatile domain that
/// is never saved, and every service that would read files, the network, the
/// camera or the hardware returns early while `isActive` is set.
enum NotchRenderHarness {
    /// Set for the whole run; services check it before any real work.
    private(set) static var isActive = false
    /// `NotchTimerService.now` while the harness draws, so the timer reads
    /// the same on every run.
    static var timerNow: TimeInterval?
    /// What a page shows over its own content when the harness opens it.
    static var subpage: Subpage?
    enum Subpage { case lyrics, queue, month }

    static let pixelScale: CGFloat = 2

    // MARK: Run

    static func runAndExit() -> Never {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--render-notch"), arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--") else {
            fail("usage: --render-notch <output directory> [--only <name or prefix,...>] [--background <hex>]")
        }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true).standardizedFileURL
        let background = value(after: "--background", in: arguments).flatMap(color(hex:)) ?? .black
        let only = value(after: "--only", in: arguments).map { Set($0.split(separator: ",").map(String.init)) }
        isActive = true
        isolatePreferences()
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            fail("cannot create \(output.path): \(error.localizedDescription)")
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.appearance = NSAppearance(named: .darkAqua)
        let status: Int32 = MainActor.assumeIsolated {
            let scenes = NotchRenderScenes.all
            let names = scenes.map(\.name)
            guard !names.isEmpty, Set(names).count == names.count else {
                fail("the scene list is empty or repeats a name: \(names)")
            }
            var failures: [String] = []
            var skipped: [String] = []
            let chosen = scenes.filter { chosen($0.name, by: only) }
            guard !chosen.isEmpty else { fail("--only matched no scene; names are: \(names.joined(separator: ", "))") }
            for scene in chosen {
                autoreleasepool {
                    do {
                        let ground = scene.background ?? background
                        guard let image = try draw(scene, background: ground) else {
                            skipped.append("\(scene.name): \(scene.skipReason ?? "not available in this build")")
                            return
                        }
                        let file = output.appendingPathComponent(scene.name + ".png")
                        try png(image).write(to: file)
                        let ink = inkFraction(image, background: ground)
                        let size = image.size
                        let label = scene.name.padding(toLength: 34, withPad: " ", startingAt: 0)
                        print(String(format: "%@  %4.0fx%-4.0f pt  ink %5.1f%%  %@", locale: Locale(identifier: "en_US_POSIX"),
                                     label, size.width, size.height, ink * 100, scene.summary))
                        if ink < 0.002 && !scene.mayBeEmpty {
                            failures.append("\(scene.name): rendered empty (no pixel differs from the background)")
                        }
                    } catch {
                        failures.append("\(scene.name): \(error)")
                    }
                }
            }
            skipped.forEach { print("skipped  \($0)") }
            if failures.isEmpty {
                print("NOTCH RENDER OK \(output.path)")
                return 0
            }
            print("NOTCH RENDER FAILED \(output.path)")
            failures.forEach { print("  \($0)") }
            return 1
        }
        exit(status)
    }

    /// A scene is picked by its whole name, by any start of it ("30-peek",
    /// "lockscreen"), or by any start of its name after the number ("music"
    /// picks 04-music, "peek" every peek).
    static func chosen(_ name: String, by tokens: Set<String>?) -> Bool {
        guard let tokens else { return true }
        let numbered = name.first?.isNumber == true
        let state = numbered ? String(name.drop { $0 != "-" }.dropFirst()) : name
        return tokens.contains { !$0.isEmpty && (name.hasPrefix($0) || state.hasPrefix($0)) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data(("NOTCH RENDER FAILED: " + message + "\n").utf8))
        exit(2)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func color(hex: String) -> NSColor? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    // MARK: Determinism

    /// Every registered default, plus the switches the pages need, lands in
    /// the argument domain: it outranks anything saved, is shared by every
    /// suite and `@AppStorage`, and is never written to disk.
    private static func isolatePreferences() {
        let defaults = UserDefaults.standard
        var masked = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        masked.merge(defaults.volatileDomain(forName: UserDefaults.argumentDomain)) { _, argument in argument }
        let overrides: [String: Any] = [
            DefaultsKey.language: AppLanguage.enUS.rawValue,
            DefaultsKey.notchEnabled: true,
            DefaultsKey.notchTimerEnabled: true,
            DefaultsKey.notchCameraEnabled: true,
            DefaultsKey.notchCalendarEnabled: true,
            DefaultsKey.notchNotificationsEnabled: true,
            DefaultsKey.notchAgentsEnabled: true,
            DefaultsKey.notchWatchEnabled: true,
            DefaultsKey.notchHiddenModules: "",
            DefaultsKey.notchCalendarCountdown: true,
            DefaultsKey.notchKeepAwakeActivity: true,
            DefaultsKey.notchLiquidGlassEnabled: false,
            DefaultsKey.brightnessControlEnabled: true,
            DefaultsKey.clipboardHistoryEnabled: true,
        ]
        masked.merge(overrides) { _, override in override }
        defaults.setVolatileDomain(masked, forName: UserDefaults.argumentDomain)
    }

    /// The clock reads 09:41 for every scene: the process's time zone is set
    /// to whatever offset puts this minute there. The date still follows the
    /// real one; only the time of day is fixed.
    static func pinClock() {
        let second = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
        // A scene never straddles a minute.
        if second > 56 { Thread.sleep(forTimeInterval: 60 - second + 0.05) }
        let utcMinute = Int((Date().timeIntervalSince1970 / 60).rounded(.down)) % 1440
        var offset = 9 * 60 + 41 - utcMinute
        if offset > 12 * 60 { offset -= 1440 }
        if offset < -12 * 60 { offset += 1440 }
        setenv("TZ", String(format: "GMT%@%02d%02d", offset < 0 ? "-" : "+", abs(offset) / 60, abs(offset) % 60), 1)
        tzset()
        NSTimeZone.resetSystemTimeZone()
    }

    // MARK: Drawing

    @MainActor private static func draw(_ scene: NotchRenderScene, background: NSColor) throws -> NSBitmapImageRep? {
        pinClock()
        let now = Date()
        subpage = scene.subpage
        defer { subpage = nil }
        NotchRenderFixtures.install(now: now, activities: scene.activities, music: scene.music)
        switch scene.content {
        case .island(let fixture):
            NotchService.shared.applyRenderFixture(fixture(now))
            try scene.check?()
            return try drawIsland(background: background)
        case .view(let make):
            guard let (view, size) = make(now) else { return nil }
            return try snapshot(size: size, background: background, content: { view })
        case .grow(let step):
            return try NotchRenderGrowth.draw(step: step, now: now, background: background)
        }
    }

    /// The island as its window shows it: the black surface in its own
    /// outline, the real `NotchView` over it, cut to that outline. A
    /// notice that reaches further to one side shifts the outline the way
    /// the window does, while the view keeps the camera at its centre.
    @MainActor static func drawIsland(background: NSColor) throws -> NSBitmapImageRep {
        let service = NotchService.shared
        var size = service.surfaceSize
        // A page can resize the island as it appears (lyrics open the music
        // page further); draw again at the size it settles on.
        for _ in 0..<3 {
            let shift = service.surfaceShift
            // Measured while the page is still on screen: leaving, a page
            // resets what it changed (the music page closes its extras).
            var settled = size
            let image = try snapshot(size: size, background: background,
                                     content: { islandView(size: size, shift: shift) },
                                     whileShown: { settled = service.surfaceSize })
            if settled == size { return image }
            size = settled
        }
        throw RenderError("the island kept changing size")
    }

    @MainActor static func islandView(size: CGSize, shift: CGFloat) -> AnyView {
        let service = NotchService.shared
        let outline = NotchShape.island(height: size.height, geometry: service.geometry)
        return AnyView(ZStack(alignment: .top) {
            outline.fill(Color.black)
            NotchView(service: service)
                .frame(width: size.width + abs(shift) * 2, height: size.height)
                .offset(x: -shift)
        }
        .frame(width: size.width, height: size.height)
        .mask(outline))
    }

    /// Lays `content` out in an invisible window and draws it at 2x.
    @MainActor static func snapshot(size: CGSize, background: NSColor, content: () -> AnyView,
                                    whileShown: () -> Void = {}) throws -> NSBitmapImageRep {
        guard size.width >= 1, size.height >= 1, size.width < 4000, size.height < 4000 else {
            throw RenderError("unusable size \(size)")
        }
        let root = content()
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(Color(nsColor: background))
            .environment(\.colorScheme, .dark)
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 0, y: 0), size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: AnyView(root))
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        NSAnimationContext.current.allowsImplicitAnimation = false
        window.orderFrontRegardless()
        NSAnimationContext.endGrouping()
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        // Appearing pages settle their own state; let them, then draw.
        for _ in 0..<3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            host.layoutSubtreeIfNeeded()
        }
        let image = bitmap(of: host, size: size)
        whileShown()
        return image
    }

    @MainActor static func bitmap(of view: NSView, size: CGSize) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((size.width * pixelScale).rounded()),
                                   pixelsHigh: Int((size.height * pixelScale).rounded()), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.displayIfNeeded()
        view.cacheDisplay(in: view.bounds, to: rep)
        CATransaction.commit()
        return rep
    }

    private static func png(_ image: NSBitmapImageRep) throws -> Data {
        let tagged = image.converting(to: .sRGB, renderingIntent: .default) ?? image
        guard let data = tagged.representation(using: .png, properties: [:]) else { throw RenderError("PNG encoding failed") }
        return data
    }

    /// The share of sampled pixels that differ from the ground.
    private static func inkFraction(_ image: NSBitmapImageRep, background: NSColor) -> Double {
        guard let ground = background.usingColorSpace(.deviceRGB) else { return 1 }
        var differing = 0, total = 0
        for y in stride(from: 0, to: image.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: image.pixelsWide, by: 3) {
                total += 1
                guard let pixel = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let distance = abs(pixel.redComponent - ground.redComponent) + abs(pixel.greenComponent - ground.greenComponent)
                    + abs(pixel.blueComponent - ground.blueComponent)
                if distance > 0.08 { differing += 1 }
            }
        }
        return total == 0 ? 0 : Double(differing) / Double(total)
    }
}

struct RenderError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
#endif
