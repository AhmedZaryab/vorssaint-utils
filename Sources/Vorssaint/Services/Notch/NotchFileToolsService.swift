// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin

final class NotchFileToolsService: ObservableObject {
    static let shared = NotchFileToolsService()
    @Published private(set) var isRunning = false
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var outputURLs: [URL] = []
    @Published private(set) var failure: String?
    @Published private(set) var wasCancelled = false
    private var operation: NotchArchiveOperation?
    private let queue = DispatchQueue(label: "com.vorssaint.notch.archive", qos: .userInitiated)
    private var generation = UUID()

    private init() {}
    deinit { operation?.cancel(immediately: true) }

    func syncWithPreferences() {
        guard NotchSupport.showsFiles(), AppFeature.shelf.isAvailable else {
            stop()
            return
        }
    }

    /// A real stop, including application termination, must not depend on the
    /// saved switches. Killing the owned child now also works when there will
    /// be no future run-loop turn to deliver a delayed cancellation fallback.
    func stop() {
        if isRunning { wasCancelled = true }
        generation = UUID()
        operation?.cancel(immediately: true)
        operation = nil
        isRunning = false
    }

    func cancel() {
        guard isRunning else { return }
        wasCancelled = true
        operation?.cancel()
    }

    func archive(_ inputs: [URL], destination: URL, directory: Bool) {
        guard !isRunning, AppFeature.notch.isAvailable, AppFeature.shelf.isAvailable,
              NotchSupport.showsFiles() else { return }
        guard destination.isFileURL, !inputs.isEmpty, inputs.allSatisfy(\.isFileURL) else {
            failure = CocoaError(.fileWriteInvalidFileName).localizedDescription
            return
        }
        let job = NotchArchiveOperation()
        operation = job
        let id = UUID()
        generation = id
        completed = 0
        total = inputs.count
        outputURLs = []
        failure = nil
        wasCancelled = false
        isRunning = true
        queue.async { [weak self] in
            var failure: String?
            let safeDestination = NotchFileToolsSupport.destinationIsOutsideInputs(destination, inputs: inputs)
            if !safeDestination { failure = CocoaError(.fileWriteInvalidFileName).localizedDescription }
            for input in inputs where safeDestination {
                let output = directory
                    ? MediaSupport.uniqueOutputURL(in: destination, baseName: input.lastPathComponent, fileExtension: "zip")
                    : destination
                do {
                    try job.archive(input, to: output)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.generation == id else { return }
                        self.completed += 1
                        self.outputURLs.append(output)
                        if AppFeature.shelf.isAvailable { _ = ShelfService.shared.addFiles([output]) }
                    }
                } catch is CancellationError { break }
                catch { failure = error.localizedDescription; break }
            }
            let finalFailure = failure
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == id else { return }
                self.failure = finalFailure
                self.operation = nil
                self.isRunning = false
            }
        }
    }
}
