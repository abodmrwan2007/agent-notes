import AgentNotesCore
import Foundation
import Observation
import PDFKit
import PencilKit

enum InkLoadResult {
    case drawing(PKDrawing)
    /// The ink file exists but cannot be decoded. The page is shown read-only so the file is not overwritten.
    case unreadable
}

/// State of one open document: its manifest, page operations, tool, and save pipeline.
@MainActor
@Observable
final class EditorModel {
    let documentID: UUID
    private(set) var manifest: DocumentManifest
    var tool = ToolState()
    var currentPageIndex = 0
    var canUndo = false
    var canRedo = false
    var alertMessage: String?
    /// Bumped per page each time its ink reaches the disk; drives thumbnail refresh.
    private(set) var inkRevisions: [UUID: Int] = [:]
    /// Bumped when pages are added, removed, reordered or restyled; drives canvas rebuild.
    private(set) var layoutVersion = 0

    @ObservationIgnored let store: DocumentStore
    @ObservationIgnored let thumbnails: ThumbnailService
    @ObservationIgnored let autosaver: InkAutosaver
    @ObservationIgnored weak var canvas: EditorCanvasController?
    @ObservationIgnored private var pdfDocuments: [UUID: PDFDocument] = [:]
    @ObservationIgnored private var hasUnrecordedChanges = false

    init(documentID: UUID, store: DocumentStore, thumbnails: ThumbnailService) throws {
        self.documentID = documentID
        self.store = store
        self.thumbnails = thumbnails
        self.manifest = try store.loadManifest(id: documentID)
        self.autosaver = InkAutosaver(
            layout: store.layout(for: documentID),
            delay: AppConfig.autosaveDelay,
            maxLatency: AppConfig.autosaveMaxLatency)

        autosaver.onSaved = { [weak self] pageIDs in
            guard let self else { return }
            for id in pageIDs { self.inkRevisions[id, default: 0] += 1 }
        }
        autosaver.onError = { [weak self] error in
            self?.alertMessage = String(localized: "Your latest strokes could not be saved.")
                + "\n" + error.localizedDescription
        }
    }

    var currentPage: PageRecord? {
        manifest.pages.indices.contains(currentPageIndex) ? manifest.pages[currentPageIndex] : nil
    }

    // MARK: Content access for the canvas

    /// The PDF page behind a notebook page. This PDFDocument instance is used only for on-screen tiles.
    func pdfPage(for page: PageRecord) -> PDFPage? {
        guard let reference = page.pdf else { return nil }
        if pdfDocuments[reference.sourceID] == nil {
            pdfDocuments[reference.sourceID] = store.openPDF(manifest: manifest, sourceID: reference.sourceID)
        }
        return pdfDocuments[reference.sourceID]?.page(at: reference.pageIndex)
    }

    /// Unsaved ink wins over the file on disk.
    func loadInk(for pageID: UUID) -> InkLoadResult {
        if let pending = autosaver.pendingDrawing(for: pageID) {
            return .drawing(pending)
        }
        guard let data = store.loadInkData(documentID: documentID, pageID: pageID) else {
            return .drawing(PKDrawing())
        }
        guard let drawing = try? PKDrawing(data: data) else {
            alertMessage = String(localized: "The handwriting on one page could not be read. That page is shown read-only to protect the saved file.")
            return .unreadable
        }
        return .drawing(drawing)
    }

    func inkChanged(pageID: UUID, drawing: PKDrawing) {
        hasUnrecordedChanges = true
        autosaver.schedule(pageID: pageID, drawing: drawing)
    }

    // MARK: Page operations

    func addPage(template: PageTemplate) {
        let insertIndex = min(currentPageIndex + 1, manifest.pages.count)
        let size = currentPage?.size ?? AppConfig.defaultPageSize
        let page = manifest.insertBlankPage(template: template, size: size, at: insertIndex)
        commitStructureChange(scrollTo: page.id)
    }

    func duplicatePage(_ pageID: UUID) {
        // The copy is made from the file on disk, so pending strokes must be written first.
        autosaver.flush(wait: true)
        do {
            let copy = try manifest.duplicatePage(pageID)
            try store.copyInk(documentID: documentID, from: pageID, to: copy.id)
            commitStructureChange(scrollTo: copy.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    /// Not undoable: the editor asks for confirmation first, and the undo history is cleared.
    func deletePage(_ pageID: UUID) {
        do {
            try manifest.removePage(pageID)
            autosaver.discard(pageID: pageID)
            store.deleteInk(documentID: documentID, pageID: pageID)
            inkRevisions[pageID] = nil
            canvas?.clearUndoHistory()
            currentPageIndex = min(currentPageIndex, manifest.pages.count - 1)
            commitStructureChange(scrollTo: nil)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func movePages(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        manifest.movePages(fromOffsets: Array(offsets), toOffset: destination)
        commitStructureChange(scrollTo: nil)
    }

    /// Changes only the background. Ink is stored in page coordinates and does not move.
    func setTemplate(_ template: PageTemplate, forPage pageID: UUID) {
        do {
            try manifest.setTemplate(template, forPage: pageID)
            commitStructureChange(scrollTo: nil)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func toggleBookmark(_ pageID: UUID) {
        do {
            try manifest.toggleBookmark(forPage: pageID)
            saveManifest()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func rename(to title: String) {
        manifest.title = title
        saveManifest()
    }

    func goToPage(_ index: Int) {
        guard manifest.pages.indices.contains(index) else { return }
        canvas?.scrollToPage(id: manifest.pages[index].id, animated: true)
    }

    // MARK: Saving

    /// Call when the app leaves the foreground: everything reaches the disk before returning.
    func persistNow() {
        autosaver.flush(wait: true)
        if hasUnrecordedChanges {
            saveManifest()
        }
    }

    /// Flushes and returns the final manifest for the library index.
    func close() -> DocumentManifest {
        persistNow()
        return manifest
    }

    func exportPDF() async throws -> URL {
        persistNow()
        let manifest = self.manifest
        let store = self.store
        let name = PDFExporter.safeFileName(manifest.title)
        return try await Task.detached(priority: .userInitiated) {
            try PDFExporter.export(manifest: manifest, store: store, fileName: name)
        }.value
    }

    func exportPackage() async throws -> URL {
        persistNow()
        let id = documentID
        let store = self.store
        let name = PDFExporter.safeFileName(manifest.title)
        return try await Task.detached(priority: .userInitiated) {
            try store.exportPackageCopy(id: id, fileName: name)
        }.value
    }

    private func commitStructureChange(scrollTo pageID: UUID?) {
        layoutVersion += 1
        saveManifest()
        canvas?.reloadIfNeeded()
        if let pageID {
            canvas?.scrollToPage(id: pageID, animated: true)
        }
    }

    private func saveManifest() {
        manifest.modifiedAt = Date()
        do {
            try store.saveManifest(manifest)
            hasUnrecordedChanges = false
        } catch {
            alertMessage = String(localized: "The notebook could not be saved.") + "\n" + error.localizedDescription
        }
    }
}
