// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Production destination methods run against controlled delivery results.
/// Native transport and payload integrity have separate transfer tests.
enum ShelfDropRoutingContract {
    enum AppFeature {
        static var shelf = Feature()
        struct Feature { var isAvailable = true }
    }
    enum NotchSupport {
        static var enabled = true
        static var visibleModules: [NotchModule] = [.files]
        static func isEnabled() -> Bool { enabled }
        static func modules() -> [NotchModule] { visibleModules }
        static func showsFiles() -> Bool { isEnabled() && modules().contains(.files) }
    }
    enum UserDefaults {
        static var standard = Store()
        struct Store {
            var enabled = true
            func bool(forKey key: String) -> Bool { enabled }
        }
    }
    final class Window {}
    struct NSDraggingInfo {
        let draggingPasteboard: NSPasteboard
        let draggingDestinationWindow: Window?
        var draggingLocation = CGPoint.zero
        var draggingSource: AnyObject?
    }
    class ShelfState {
        var dockedPanel = Window()
        var dockCompletions = 0
        var promises: [Int] = []
        var ordinaryItems: [String] = []
        var accepts = true
        var ordinaryAccepts = 0
        var promisedAccepts = 0
        var deliveredItems: [String] = []
        func filePromiseReceivers(from board: NSPasteboard) -> [Int] { promises }
        func nonPromisedItems(from board: NSPasteboard) -> [String] { ordinaryItems }
        func accept(pasteboard: NSPasteboard) -> Bool { ordinaryAccepts += 1; return accepts }
        func beginPromisedFileReceive(_ receivers: [Int], additions: [String], mergeInto target: UUID?) -> Bool {
            promisedAccepts += 1
            deliveredItems = additions
            return accepts
        }
        var interactionNotes = 0
        func dockDidAccept() { dockCompletions += 1 }
        func noteInteraction() { interactionNotes += 1 }
    }
    class NotchState {
        var acceptsUserInteraction = true
        var captureControls: Int?
        var modules: [NotchModule] = [.files]
        var heldDrag = true
        var dragPlaceholder = true
        var pinned = false
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 32, cameraWidth: 180)
        var expandedGeometry: NotchGeometry { geometry }
        var surfaceSize: CGSize { geometry.expandedSize(module: .files) }
        var opened: [NotchModule] = []
        var reactions: [NotchMascotReaction] = []
        func refreshPresentation() {}
        func reactMascot(_ reaction: NotchMascotReaction, patience: TimeInterval = 8) { reactions.append(reaction) }
        func open(_ module: NotchModule, pinned: Bool = false, takeFocus: Bool = true) {
            opened.append(module)
            if pinned { self.pinned = true }
        }
    }
}

enum ShelfDropRoutingTests {
    private typealias Context = ShelfDropRoutingContract

    static func run(_ suite: TestSuite) {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        for promised in [false, true] {
            for accepted in [false, true] {
                Context.AppFeature.shelf.isAvailable = true
                Context.UserDefaults.standard.enabled = true
                Context.ShelfService.shared = Context.ShelfService()
                let shelf = Context.ShelfService.shared
                shelf.promises = promised ? [1, 2] : []
                shelf.ordinaryItems = ["file", "note"]
                shelf.accepts = accepted
                let notch = Context.Notch()
                let canvas = Context.Canvas()
                canvas.dropActions = Context.NotchFileDropActions(
                    canAccept: { _ in notch.canAcceptFileDrop }, enter: { _ in },
                    accept: { notch.accept($0) }, exit: {})
                suite.expect(canvas.beginDrop(board, localSource: true) == [],
                       "the island leaves internal tile drags to their merge destinations")
                suite.expect(!canvas.finishDrop(board) && shelf.promisedAccepts + shelf.ordinaryAccepts == 0,
                       "an unaccepted gesture never reaches file delivery")
                suite.expect(canvas.beginDrop(board, localSource: false) == .copy,
                       "an external drag remains accepted by the stable island destination")
                suite.expect(canvas.finishDrop(board) == accepted,
                       "the island reports the actual shelf admission result")
                suite.expect(shelf.promisedAccepts == (promised ? 1 : 0)
                       && shelf.ordinaryAccepts == (promised ? 0 : 1),
                       "promised attachments reach native delivery instead of their fallback text")
                suite.expect(!promised || shelf.deliveredItems == ["file", "note"],
                       "ordinary file and note companions remain attached to a promised delivery")
                suite.expect(notch.opened == (accepted ? [.files] : [])
                       && notch.heldDrag == !accepted && notch.dragPlaceholder == !accepted,
                       "only accepted deliveries open files and release the island placeholder")
                suite.expect(notch.reactions == (accepted ? [.celebrate] : []),
                       "the companion cheers only a file that landed")
                suite.expect(!canvas.finishDrop(board), "one gesture cannot deliver twice")

                let dockDrop = Context.NSDraggingInfo(draggingPasteboard: board,
                                                     draggingDestinationWindow: shelf.dockedPanel)
                suite.expect(shelf.accept(draggingInfo: dockDrop) == accepted
                       && shelf.dockCompletions == (accepted ? 1 : 0),
                       "the separate dock keeps its completion behavior through the shared receiver")

                // A promised file is delivered asynchronously; noteInteraction()
                // has to run at drop time or an edge peek can retract before it arrives.
                let notesBefore = shelf.interactionNotes
                let panelDrop = Context.NSDraggingInfo(draggingPasteboard: board,
                                                      draggingDestinationWindow: Context.Window())
                suite.expect(shelf.accept(draggingInfo: panelDrop) == accepted
                       && shelf.interactionNotes == notesBefore + (accepted ? 1 : 0)
                       && shelf.dockCompletions == (accepted ? 1 : 0),
                       "an accepted panel drop notes interaction at drop time, before delivery")
            }
        }
        for revoked in 0..<5 {
            Context.AppFeature.shelf.isAvailable = true
            Context.UserDefaults.standard.enabled = true
            Context.ShelfService.shared = Context.ShelfService()
            let shelf = Context.ShelfService.shared
            shelf.promises = [1]
            let notch = Context.Notch()
            let canvas = Context.Canvas()
            canvas.dropActions = Context.NotchFileDropActions(
                canAccept: { _ in notch.canAcceptFileDrop }, enter: { _ in },
                accept: { notch.accept($0) }, exit: {})
            _ = canvas.beginDrop(board, localSource: false)
            switch revoked {
            case 0: Context.AppFeature.shelf.isAvailable = false
            case 1: Context.UserDefaults.standard.enabled = false
            case 2: notch.modules = []
            case 3: notch.acceptsUserInteraction = false
            default: notch.captureControls = 1
            }
            suite.expect(!canvas.finishDrop(board) && shelf.promisedAccepts == 0 && notch.opened.isEmpty,
                   "a destination disabled after hover cannot start an attachment delivery")
        }
        Context.AppFeature.shelf.isAvailable = true
        Context.UserDefaults.standard.enabled = true
    }
}
