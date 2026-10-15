// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Every control of the interaction library in each of its states, frozen
/// beside a live copy, for the design review. `--interactions-gallery` opens
/// it in a plain window that quits when closed; `--snapshot <path.png>` after
/// it writes the frozen states to a PNG and exits without a window. Nothing
/// here touches preferences, files or hardware.
struct NotchInteractionsGallery: View {
    @State private var shuffle = false
    @State private var muted = false
    @State private var playing = false
    @State private var volume = 0.62
    @State private var position = 0.3
    @State private var copies = 0
    @State private var log = "Nothing fired yet"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notch interactions").font(.system(size: 15, weight: .semibold))
            GallerySection(title: "NotchPressStyle", note: "Tap: open, choose, show. Hover washes, press settles.") {
                GalleryCell("idle") { folder }
                GalleryCell("hover") { folder.environment(\.notchInteractionPreview, .hover) }
                GalleryCell("pressed") { folder.environment(\.notchInteractionPreview, .pressed) }
                GalleryCell("disabled") { folder.disabled(true) }
                GalleryCell("capsule", width: 128) { pill.environment(\.notchInteractionPreview, .hover) }
                GalleryCell("live", width: 128) { Button { log = "Opened" } label: { pillLabel }.buttonStyle(NotchPressStyle(shape: .capsule)) }
            }
            GallerySection(title: "NotchToggleStyle", note: "On and off: the symbol morphs, the fill crossfades.") {
                GalleryCell("off") { toggle("Shuffle", .constant(false), NotchToggleStyle(symbol: "shuffle")) }
                GalleryCell("on") { toggle("Shuffle", .constant(true), NotchToggleStyle(symbol: "shuffle")) }
                GalleryCell("hover") {
                    toggle("Shuffle", .constant(true), NotchToggleStyle(symbol: "shuffle"))
                        .environment(\.notchInteractionPreview, .hover)
                }
                GalleryCell("morph off") { toggle("Mute", .constant(false), mute) }
                GalleryCell("morph on") { toggle("Mute", .constant(true), mute) }
                GalleryCell("live") {
                    HStack(spacing: 6) {
                        toggle("Shuffle", $shuffle, NotchToggleStyle(symbol: "shuffle"))
                        toggle("Mute", $muted, mute)
                    }
                }
            }
            GallerySection(title: "NotchCommitButton", note: "Commit: fires on tap with a kick and a burst; can be slung.") {
                GalleryCell("idle") { play(.constant(false)) }
                GalleryCell("pressed") { play(.constant(false)).environment(\.notchInteractionPreview, .pressed) }
                GalleryCell("armed") {
                    NotchCommitButton("Next", symbol: "forward.fill", kick: .forward, dragToFire: true, size: 40) {}
                        .environment(\.notchInteractionPreview, .armed)
                }
                GalleryCell("up") { NotchCommitButton("AirPlay", symbol: "airplay.audio", kick: .up, size: 32) {} }
                GalleryCell("live play") { play($playing) }
                GalleryCell("live sling") {
                    HStack(spacing: 4) {
                        NotchCommitButton("Previous", symbol: "backward.fill", kick: .backward, dragToFire: true,
                                          size: 36) { log = "Previous" }
                        NotchCommitButton("Next", symbol: "forward.fill", kick: .forward, dragToFire: true,
                                          size: 36) { log = "Next" }
                    }
                }
            }
            GallerySection(title: "NotchFuseButton", note: "Destructive: a press lights a fuse; press again or Escape to keep.") {
                GalleryCell("idle") { trash }
                GalleryCell("burning") { trash.environment(\.notchInteractionPreview, .burning(0.65)) }
                GalleryCell("titled", width: 150) { clear }
                GalleryCell("titled burning", width: 150) { clear.environment(\.notchInteractionPreview, .burning(0.35)) }
                GalleryCell("live", width: 150) {
                    NotchFuseButton("Clear history", symbol: "trash", showsTitle: true,
                                    onUndo: { log = "Kept" }) { log = "Cleared" }
                }
            }
            GallerySection(title: "NotchSlider", note: "Level: rubber band past the ends, a tick at each detent.") {
                GalleryCell("idle", width: 150) { slider(.constant(0.4)) }
                GalleryCell("dragging", width: 150) {
                    slider(.constant(0.72)).environment(\.notchInteractionPreview, .pressed)
                }
                GalleryCell("live, detent at 50%", width: 170) { slider($volume) }
                GalleryCell("live position", width: 170) {
                    NotchSlider(value: $position, label: "Position", valueText: "\(Int(position * 240)) s")
                }
            }
            GallerySection(title: "notchSuccessMorph", note: "Success in place: the glyph turns into a checkmark for 1.2 s.") {
                GalleryCell("idle") { copy(0) }
                GalleryCell("success") { copy(0).environment(\.notchInteractionPreview, .success) }
                GalleryCell("live") {
                    Button { copies += 1; log = "Copied \(copies)" } label: { copy(copies) }
                        .buttonStyle(NotchPressStyle(shape: .rounded(9)))
                }
            }
            Text(log).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 760, alignment: .leading)
        .foregroundStyle(.white)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    private var mute: NotchToggleStyle { NotchToggleStyle(on: "speaker.slash.fill", off: "speaker.wave.2.fill") }

    private var folder: some View {
        Button {} label: {
            Image(systemName: "folder").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(9)))
    }

    private var pillLabel: some View {
        Text("Open player").font(.system(size: 12, weight: .medium)).padding(.horizontal, 14).frame(height: 28)
    }

    private var pill: some View { Button {} label: { pillLabel }.buttonStyle(NotchPressStyle(shape: .capsule)) }

    private var trash: some View { NotchFuseButton("Delete", symbol: "trash") {} }

    private var clear: some View { NotchFuseButton("Clear history", symbol: "trash", showsTitle: true) {} }

    private func toggle(_ title: String, _ isOn: Binding<Bool>, _ style: NotchToggleStyle) -> some View {
        Toggle(title, isOn: isOn).toggleStyle(style).help(title)
    }

    private func play(_ playing: Binding<Bool>) -> some View {
        NotchCommitButton("Play or pause", symbol: playing.wrappedValue ? "pause.fill" : "play.fill", kick: .morph,
                          size: 44, filled: true) {
            playing.wrappedValue.toggle()
            log = playing.wrappedValue ? "Playing" : "Paused"
        }
    }

    private func slider(_ value: Binding<Double>) -> some View {
        NotchSlider(value: value, label: "Volume", detents: [0.5])
    }

    private func copy(_ count: Int) -> some View {
        Image(systemName: "doc.on.doc")
            .foregroundStyle(.white.opacity(0.8))
            .notchSuccessMorph(trigger: count)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 28, height: 28)
    }
}

private struct GallerySection<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 14) { content }
        }
    }
}

private struct GalleryCell<Content: View>: View {
    let caption: String
    var width: CGFloat = 92
    let content: Content

    init(_ caption: String, width: CGFloat = 92, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 8) {
            content.frame(height: 64)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(width: width)
        .padding(.vertical, 6)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension NotchInteractionsGallery {
    @MainActor static func runAndExit() -> Never {
        let app = NSApplication.shared
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(index + 1) {
            app.setActivationPolicy(.prohibited)
            let renderer = ImageRenderer(content: NotchInteractionsGallery())
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                print("INTERACTIONS GALLERY SNAPSHOT FAILED: nothing rendered")
                exit(1)
            }
            do {
                try png.write(to: URL(fileURLWithPath: arguments[index + 1]))
            } catch {
                print("INTERACTIONS GALLERY SNAPSHOT FAILED: \(error.localizedDescription)")
                exit(1)
            }
            print("INTERACTIONS GALLERY SNAPSHOT OK \(arguments[index + 1])")
            exit(0)
        }
        app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 808, height: 860),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Notch interactions"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ScrollView { NotchInteractionsGallery() }.background(Color.black))
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                               queue: .main) { _ in exit(0) }
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
        exit(0)
    }
}
#endif
