import AgentNotesCore
import Foundation
import PencilKit

/// Debounced, crash-safe ink persistence.
///
/// Every stroke change is handed over as a PKDrawing value (cheap, copy-on-write). Writes happen
/// on a serial background queue, one atomic file per page, so an interrupted save leaves the
/// previous version of that page intact and never touches other pages.
/// Main-thread only, except for the I/O closure.
final class InkAutosaver {
    private let layout: DocumentPackageLayout
    private let delay: TimeInterval
    private let maxLatency: TimeInterval
    private let ioQueue = DispatchQueue(label: "agentnotes.ink-io", qos: .utility)

    private var pending: [UUID: PKDrawing] = [:]
    private var firstPendingAt: Date?
    private var timer: Timer?

    /// Called on the main thread with the pages that were written.
    var onSaved: (([UUID]) -> Void)?
    /// Called on the main thread when a page could not be written. The drawing stays in memory.
    var onError: ((Error) -> Void)?

    init(layout: DocumentPackageLayout, delay: TimeInterval, maxLatency: TimeInterval) {
        self.layout = layout
        self.delay = delay
        self.maxLatency = maxLatency
    }

    /// The newest unsaved drawing for a page, if any. Must win over what is on disk.
    func pendingDrawing(for pageID: UUID) -> PKDrawing? {
        pending[pageID]
    }

    func schedule(pageID: UUID, drawing: PKDrawing) {
        pending[pageID] = drawing
        let now = Date()
        if firstPendingAt == nil { firstPendingAt = now }

        if let first = firstPendingAt, now.timeIntervalSince(first) >= maxLatency {
            flush(wait: false)
            return
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.flush(wait: false)
        }
    }

    /// Drops unsaved changes for a page that is being deleted.
    func discard(pageID: UUID) {
        pending[pageID] = nil
    }

    /// Writes everything pending. With `wait`, returns only after the data is on disk
    /// (used when the app is backgrounded, the document closes, or before export).
    func flush(wait: Bool) {
        timer?.invalidate()
        timer = nil
        firstPendingAt = nil
        let batch = pending
        pending = [:]

        let layout = self.layout
        let work = { [weak self] in
            guard !batch.isEmpty else { return }
            var saved: [UUID] = []
            var failed: [UUID: PKDrawing] = [:]
            var failure: Error?
            for (pageID, drawing) in batch {
                let url = layout.inkURL(pageID: pageID)
                do {
                    if drawing.strokes.isEmpty {
                        if FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.removeItem(at: url)
                        }
                    } else {
                        try drawing.dataRepresentation().write(to: url, options: .atomic)
                    }
                    saved.append(pageID)
                } catch {
                    failed[pageID] = drawing
                    failure = error
                }
            }
            let savedIDs = saved
            let unsaved = failed
            let lastError = failure
            DispatchQueue.main.async {
                guard let self else { return }
                // Keep failed pages pending (unless newer ink arrived) so the next flush retries them.
                for (pageID, drawing) in unsaved where self.pending[pageID] == nil {
                    self.pending[pageID] = drawing
                }
                if !savedIDs.isEmpty { self.onSaved?(savedIDs) }
                if let lastError { self.onError?(lastError) }
            }
        }

        if wait {
            ioQueue.sync(execute: work)
        } else {
            ioQueue.async(execute: work)
        }
    }
}
