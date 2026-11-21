import AgentNotesCore
import Foundation
import Observation
import PDFKit
import PencilKit
import UIKit

/// The selected page object, addressed by stable identifiers.
struct ObjectSelection: Equatable {
    let pageID: UUID
    let objectID: UUID
}

/// Text selected on a PDF page. An empty `text` means the page had nothing selectable there.
struct TextSelection: Equatable {
    let pageID: UUID
    let text: String
}

enum EditorPanelTab: Hashable {
    case tools
    case stickers
    case audio
    case assistant
}

struct TextToolsRequest: Identifiable {
    enum Origin {
        case recognized
        case selection
    }

    let id = UUID()
    let text: String
    let origin: Origin
}

struct ExplainRequest: Equatable, Identifiable {
    let id = UUID()
    let text: String
    /// The page the text was selected on, sent as context.
    let pageID: UUID
}

/// A request to edit the text of an object (drives the text sheet).
struct TextEditTarget: Identifiable {
    let id = UUID()
    let selection: ObjectSelection
    let text: String
}

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
    /// The selected page object (object mode).
    private(set) var selection: ObjectSelection?
    /// Bumped whenever any page's objects change, so views re-read `selectedObject`.
    private(set) var objectsRevision = 0
    var textEditTarget: TextEditTarget?
    /// Shows PencilKit's ruler on the page being written on.
    var isRulerActive = false
    /// Reading mode: toolbars hidden, nothing on the page can be changed by touch.
    var isReadingMode = false
    /// "Tap writing to hear it": a tap on a stroke plays the recording from when it was written.
    var isListening = false
    @ObservationIgnored let audio = LectureAudio()
    /// Short message shown over the canvas (for example after scribble-to-erase), with Undo.
    private(set) var notice: String?
    @ObservationIgnored private var noticeToken = UUID()
    @ObservationIgnored private var previousToolKind: InkToolKind = .eraser
    private(set) var textSelection: TextSelection?
    /// The panel beside the page (tools, stickers, audio, assistant) and its open tab.
    var isSidePanelOpen = false
    var panelTab = EditorPanelTab.tools
    /// Selected PDF text the assistant should explain; the assistant panel picks it up.
    var explainRequest: ExplainRequest?
    /// Text shown in the text tools sheet (translate, look up, read aloud, put on page).
    var textToolsRequest: TextToolsRequest?
    /// Page to show first and query to highlight, when opened from a search result.
    @ObservationIgnored var openTarget: OpenTarget?

    @ObservationIgnored private var objectLayers: [UUID: PageObjectLayer] = [:]
    /// Pages whose objects file could not be decoded: never written, to protect the file.
    @ObservationIgnored private var unreadableObjectPages: Set<UUID> = []
    @ObservationIgnored private let assetCache = NSCache<NSString, UIImage>()

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
            // Record the change in the manifest right away, so the modification date (and with
            // it the library cover) is correct even if the app is killed before an orderly close.
            self.saveManifest()
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

    // MARK: Lecture audio

    var recordings: [AudioRecording] { manifest.allRecordings }

    func startRecording() {
        do {
            let target = try store.newAudioURL(documentID: documentID)
            let title = String(localized: "Recording") + " " + Date().formatted(date: .abbreviated, time: .shortened)
            Task {
                do {
                    try await audio.startRecording(to: target.url) { [weak self] startedAt, duration in
                        self?.finishRecording(fileName: target.fileName, title: title, startedAt: startedAt, duration: duration)
                    }
                } catch {
                    alertMessage = error.localizedDescription
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        audio.stopRecording()
    }

    private func finishRecording(fileName: String, title: String, startedAt: Date, duration: TimeInterval) {
        guard duration >= 0.5 else {
            store.deleteAudio(documentID: documentID, fileName: fileName)
            return
        }
        var list = manifest.allRecordings
        list.append(AudioRecording(fileName: fileName, title: title, startedAt: startedAt, duration: duration))
        manifest.recordings = list
        saveManifest()
        showNotice(String(localized: "Recording saved"))
    }

    func play(_ recording: AudioRecording, from offset: TimeInterval = 0) {
        audio.play(url: store.audioURL(documentID: documentID, fileName: recording.fileName),
                   recordingID: recording.id, from: offset)
    }

    func deleteRecording(_ recording: AudioRecording) {
        if audio.playingID == recording.id { audio.stopPlayback() }
        manifest.recordings = manifest.allRecordings.filter { $0.id != recording.id }
        store.deleteAudio(documentID: documentID, fileName: recording.fileName)
        saveManifest()
    }

    /// A stroke was tapped in listening mode: play what was being said when it was written.
    func playAudio(writtenAt moment: Date) {
        guard let hit = AudioTimeline.locate(moment, in: manifest.allRecordings) else {
            showNotice(String(localized: "This was not written during a recording."))
            return
        }
        play(hit.recording, from: hit.offset)
    }

    // MARK: Tools and notices

    /// Selects a tool and remembers the previous one (for Apple Pencil double-tap and squeeze).
    func selectTool(_ kind: InkToolKind) {
        guard tool.kind != kind else { return }
        previousToolKind = tool.kind
        tool.kind = kind
    }

    /// Double-tap "switch to eraser": eraser, or back to the tool used before it.
    func toggleEraser() {
        selectTool(tool.kind == .eraser ? (previousToolKind == .eraser ? .pen : previousToolKind) : .eraser)
    }

    func switchToPreviousTool() {
        selectTool(previousToolKind)
    }

    func showNotice(_ text: String) {
        let token = UUID()
        noticeToken = token
        notice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.noticeToken == token else { return }
            self.notice = nil
        }
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: Page backgrounds

    /// Uses a picture as the page's paper. Ink and objects keep their positions.
    func setBackgroundImage(data: Data, pageID: UUID) {
        guard let index = manifest.index(of: pageID), manifest.pages[index].pdf == nil else { return }
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0,
              let encoded = Self.downscaled(image, maxPixels: 2400).jpegData(compressionQuality: 0.85) else {
            alertMessage = String(localized: "This picture could not be read.")
            return
        }
        do {
            let fileName = try store.addAsset(encoded, fileExtension: "jpg", documentID: documentID)
            manifest.pages[index].backgroundAsset = fileName
            inkRevisions[pageID, default: 0] += 1
            commitStructureChange(scrollTo: nil)
        } catch {
            alertMessage = String(localized: "The notebook could not be saved.") + "\n" + error.localizedDescription
        }
    }

    func removeBackgroundImage(pageID: UUID) {
        guard let index = manifest.index(of: pageID) else { return }
        manifest.pages[index].backgroundAsset = nil
        inkRevisions[pageID, default: 0] += 1
        commitStructureChange(scrollTo: nil)
    }

    // MARK: PDF text selection

    func setTextSelection(_ selection: TextSelection?) {
        textSelection = selection
    }

    // MARK: Page objects (text, sticky notes, shapes, images)

    /// Objects of a page, loaded from the package on first use.
    func objects(for pageID: UUID) -> PageObjectLayer {
        if let cached = objectLayers[pageID] { return cached }
        let layer: PageObjectLayer
        do {
            layer = try store.loadObjects(documentID: documentID, pageID: pageID)
        } catch {
            unreadableObjectPages.insert(pageID)
            layer = PageObjectLayer()
        }
        objectLayers[pageID] = layer
        return layer
    }

    var selectedObject: PageObject? {
        _ = objectsRevision
        guard let selection else { return nil }
        return objects(for: selection.pageID).object(id: selection.objectID)
    }

    func asset(named fileName: String) -> UIImage? {
        if let cached = assetCache.object(forKey: fileName as NSString) { return cached }
        let url = store.assetURL(documentID: documentID, fileName: fileName)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        assetCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    func select(_ newSelection: ObjectSelection?) {
        guard selection != newSelection else { return }
        selection = newSelection
        canvas?.refreshObjectSelection()
    }

    /// The single entry point for every change to a page's objects: saves atomically, updates
    /// thumbnails and the canvas, and registers undo (which, replayed, registers redo).
    func commitObjects(_ layer: PageObjectLayer, pageID: UUID) {
        let previous = objects(for: pageID)
        guard !unreadableObjectPages.contains(pageID) else {
            alertMessage = String(localized: "The objects on this page could not be read, so they cannot be changed.")
            canvas?.refreshObjects(pageID: pageID)
            return
        }
        guard previous != layer else {
            canvas?.refreshObjects(pageID: pageID)
            return
        }
        do {
            try store.saveObjects(layer, documentID: documentID, pageID: pageID)
        } catch {
            alertMessage = String(localized: "The notebook could not be saved.") + "\n" + error.localizedDescription
            canvas?.refreshObjects(pageID: pageID)
            return
        }
        objectLayers[pageID] = layer
        objectsRevision += 1
        inkRevisions[pageID, default: 0] += 1
        if let selection, selection.pageID == pageID, layer.object(id: selection.objectID) == nil {
            self.selection = nil
        }
        saveManifest()
        canvas?.refreshObjects(pageID: pageID)
        canvas?.registerUndo { [weak self] in
            self?.commitObjects(previous, pageID: pageID)
        }
    }

    /// Adds a new object in the middle of the visible part of the current page and selects it.
    func insertObject(kind: PageObjectKind, shape: ShapeKind? = nil, noteStyle: NoteStyle? = nil) {
        guard let page = currentPage else { return }
        let size: (width: Double, height: Double)
        var object: PageObject
        switch kind {
        case .text:
            size = (260, 64)
            object = PageObject(kind: .text, frame: placement(size, on: page),
                                text: String(localized: "Text"), fontSize: 18)
        case .stickyNote:
            size = (190, 190)
            object = PageObject(
                kind: .stickyNote, frame: placement(size, on: page), text: "", fontSize: 15,
                noteStyle: noteStyle == .plain ? nil : noteStyle)
        case .shape:
            let shapeKind = shape ?? .rectangle
            size = shapeKind == .line || shapeKind == .arrow ? (200, 90) : (200, 140)
            object = PageObject(kind: .shape, frame: placement(size, on: page), shape: shapeKind, lineWidth: 2.5)
        case .image:
            return // images come through insertImage(data:)
        }
        object.colorHex = kind == .stickyNote ? nil : tool.objectColorHex
        add(object, to: page.id)
        if object.hasText {
            beginEditingText(ObjectSelection(pageID: page.id, objectID: object.id))
        }
    }

    /// Stores the picture inside the document package (downscaled if very large) and places it.
    func insertImage(data: Data) {
        guard let page = currentPage else { return }
        guard let original = UIImage(data: data), original.size.width > 0, original.size.height > 0 else {
            alertMessage = String(localized: "This picture could not be read.")
            return
        }
        let image = Self.downscaled(original, maxPixels: 2048)
        guard let encoded = image.jpegData(compressionQuality: 0.85) else {
            alertMessage = String(localized: "This picture could not be read.")
            return
        }
        do {
            let fileName = try store.addAsset(encoded, fileExtension: "jpg", documentID: documentID)
            // Fit within 60% of the page width and half its height, keeping the proportions.
            let imageWidth = Double(image.size.width)
            let imageHeight = Double(image.size.height)
            let scale = min(page.size.width * 0.6 / imageWidth, page.size.height * 0.5 / imageHeight, 1)
            let size = (width: imageWidth * scale, height: imageHeight * scale)
            add(PageObject(kind: .image, frame: placement(size, on: page), assetFileName: fileName), to: page.id)
        } catch {
            alertMessage = String(localized: "The notebook could not be saved.") + "\n" + error.localizedDescription
        }
    }

    /// Puts plain text on the current page as a text box (for example a calculator result).
    func insertTextObject(_ text: String) {
        guard let page = currentPage, !text.isEmpty else { return }
        let width = min(max(Double(text.count) * 10 + 24, 120), page.size.width * 0.8)
        let object = PageObject(
            kind: .text, frame: placement((width: width, height: 40), on: page),
            text: text, fontSize: 18, colorHex: tool.objectColorHex)
        add(object, to: page.id)
    }

    /// Puts several lines of text (for example recognized handwriting) on the current page in a
    /// text box sized to fit; very long text goes onto new pages instead.
    func insertTextBlock(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let page = currentPage, !trimmed.isEmpty else { return }
        let fontSize = 16.0
        let width = min(page.size.width * 0.8, 440)
        let perLine = max(Int(width / (fontSize * 0.6)), 10)
        let lineCount = trimmed.components(separatedBy: "\n")
            .map { max(1, Int((Double($0.count) / Double(perLine)).rounded(.up))) }
            .reduce(0, +)
        let height = Double(lineCount) * fontSize * 1.45 + 16
        guard height < page.size.height * 0.8 else {
            addTextPages(trimmed)
            return
        }
        let object = PageObject(
            kind: .text, frame: placement((width: width, height: height), on: page),
            text: trimmed, fontSize: fontSize, colorHex: tool.objectColorHex)
        add(object, to: page.id)
    }

    /// Places a sticker (PNG, transparency kept) in the middle of the visible part of the page.
    func insertSticker(pngData: Data, size: CGSize) {
        guard let page = currentPage else { return }
        do {
            let fileName = try store.addAsset(pngData, fileExtension: "png", documentID: documentID)
            // Large pictures (diagrams) are shrunk to fit the page with a small border.
            let fitWidth: Double = (Double(page.size.width) - 24) / Double(size.width)
            let fitHeight: Double = (Double(page.size.height) - 24) / Double(size.height)
            let fit: Double = min(1.0, fitWidth, fitHeight)
            let frame = placement((width: Double(size.width) * fit, height: Double(size.height) * fit), on: page)
            add(PageObject(kind: .image, frame: frame, assetFileName: fileName), to: page.id)
        } catch {
            alertMessage = String(localized: "The notebook could not be saved.") + "\n" + error.localizedDescription
        }
    }

    private func add(_ object: PageObject, to pageID: UUID) {
        var layer = objects(for: pageID)
        layer.add(object)
        tool.kind = .objects
        commitObjects(layer, pageID: pageID)
        select(ObjectSelection(pageID: pageID, objectID: object.id))
    }

    private func placement(_ size: (width: Double, height: Double), on page: PageRecord) -> PageRect {
        let centre = canvas?.visibleCenter(ofPage: page.id)
            ?? PagePoint(x: page.size.width / 2, y: page.size.height / 2)
        let x = min(max(centre.x - size.width / 2, 0), max(page.size.width - size.width, 0))
        let y = min(max(centre.y - size.height / 2, 0), max(page.size.height - size.height, 0))
        return PageRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func downscaled(_ image: UIImage, maxPixels: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        let factor = longest > maxPixels ? maxPixels / longest : 1
        let target = CGSize(width: pixelWidth * factor, height: pixelHeight * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        // Redrawing also bakes in the photo's orientation and gives a white background.
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Changes the selected object. Does nothing when it is locked.
    func updateSelected(_ change: (inout PageObject) -> Void) {
        guard let selection else { return }
        var layer = objects(for: selection.pageID)
        guard layer.update(selection.objectID, change) else { return }
        commitObjects(layer, pageID: selection.pageID)
    }

    func deleteSelected() {
        guard let selection else { return }
        var layer = objects(for: selection.pageID)
        guard layer.remove(selection.objectID) else { return }
        commitObjects(layer, pageID: selection.pageID)
    }

    func duplicateSelected() {
        guard let selection else { return }
        var layer = objects(for: selection.pageID)
        guard let copy = layer.duplicate(selection.objectID) else { return }
        commitObjects(layer, pageID: selection.pageID)
        select(ObjectSelection(pageID: selection.pageID, objectID: copy.id))
    }

    func reorderSelected(toFront: Bool) {
        guard let selection else { return }
        var layer = objects(for: selection.pageID)
        if toFront { layer.bringToFront(selection.objectID) } else { layer.sendToBack(selection.objectID) }
        commitObjects(layer, pageID: selection.pageID)
    }

    func toggleLockSelected() {
        guard let selection, let object = selectedObject else { return }
        var layer = objects(for: selection.pageID)
        layer.setLocked(!object.isLocked, id: selection.objectID)
        commitObjects(layer, pageID: selection.pageID)
    }

    func rotateSelected() {
        updateSelected { $0.rotation = ($0.rotation + 90).truncatingRemainder(dividingBy: 360) }
    }

    func beginEditingText(_ target: ObjectSelection) {
        guard let object = objects(for: target.pageID).object(id: target.objectID),
              object.hasText, !object.isLocked else { return }
        select(target)
        textEditTarget = TextEditTarget(selection: target, text: object.text ?? "")
    }

    func applyText(_ text: String, to target: ObjectSelection) {
        var layer = objects(for: target.pageID)
        guard layer.update(target.objectID, { $0.text = text }) else { return }
        commitObjects(layer, pageID: target.pageID)
    }

    // MARK: Page operations

    func addPage(template: PageTemplate) {
        let insertIndex = min(currentPageIndex + 1, manifest.pages.count)
        let size = currentPage?.size ?? AppConfig.defaultPageSize
        let page = manifest.insertBlankPage(template: template, size: size, at: insertIndex)
        commitStructureChange(scrollTo: page.id)
    }

    /// Adds new blank pages after the current one holding `text` (for example an AI summary),
    /// split so each page's text box fits on its page. The last new page becomes current.
    func addTextPages(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let size = currentPage?.size ?? AppConfig.defaultPageSize
        let margin = 40.0
        let fontSize = 14.0
        let width = size.width - 2 * margin
        let charactersPerLine = max(Int(width / (fontSize * 0.62)), 20)
        let linesPerPage = max(Int((size.height - 2 * margin) / (fontSize * 1.45)) - 2, 10)

        // Greedy split on paragraph lines, counting wrapped lines.
        var chunks: [String] = []
        var current: [String] = []
        var used = 0
        for line in trimmed.components(separatedBy: "\n") {
            let cost = max(1, Int((Double(line.count) / Double(charactersPerLine)).rounded(.up)))
            if used + cost > linesPerPage, !current.isEmpty {
                chunks.append(current.joined(separator: "\n"))
                current = []
                used = 0
            }
            current.append(line)
            used += cost
        }
        if !current.isEmpty { chunks.append(current.joined(separator: "\n")) }

        var insertIndex = min(currentPageIndex + 1, manifest.pages.count)
        var lastPage: PageRecord?
        for chunk in chunks {
            let page = manifest.insertBlankPage(template: .blank, size: size, at: insertIndex)
            insertIndex += 1
            var layer = objects(for: page.id)
            layer.add(PageObject(
                kind: .text,
                frame: PageRect(x: margin, y: margin, width: width, height: size.height - 2 * margin),
                text: chunk, fontSize: fontSize, colorHex: "122145"))
            commitObjects(layer, pageID: page.id)
            lastPage = page
        }
        commitStructureChange(scrollTo: lastPage?.id)
    }

    /// Adds one page per scanned or photographed sheet after the current page, the picture as
    /// the page's paper so it can be written on.
    func addImagePages(_ images: [UIImage]) {
        var index = min(currentPageIndex + 1, manifest.pages.count)
        var last: PageRecord?
        for image in images where image.size.width > 0 && image.size.height > 0 {
            // A page shaped like the picture, as wide as an A4 page.
            let width = AppConfig.defaultPageSize.width
            let size = PageSize(width: width, height: (width * Double(image.size.height / image.size.width)).rounded())
            guard let data = Self.downscaled(image, maxPixels: 2400).jpegData(compressionQuality: 0.85),
                  let fileName = try? store.addAsset(data, fileExtension: "jpg", documentID: documentID) else {
                alertMessage = String(localized: "The notebook could not be saved.")
                continue
            }
            let page = manifest.insertBlankPage(template: .blank, size: size, at: index)
            if let stored = manifest.index(of: page.id) {
                manifest.pages[stored].backgroundAsset = fileName
                last = manifest.pages[stored]
            }
            index += 1
        }
        if last != nil { commitStructureChange(scrollTo: last?.id) }
    }

    func duplicatePage(_ pageID: UUID) {
        // The copy is made from the file on disk, so pending strokes must be written first.
        autosaver.flush(wait: true)
        do {
            let copy = try manifest.duplicatePage(pageID)
            try store.copyInk(documentID: documentID, from: pageID, to: copy.id)
            try store.copyObjects(documentID: documentID, from: pageID, to: copy.id)
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
            store.deleteObjects(documentID: documentID, pageID: pageID)
            objectLayers[pageID] = nil
            if selection?.pageID == pageID { selection = nil }
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
            // A chosen template replaces a custom background image.
            if let index = manifest.index(of: pageID) { manifest.pages[index].backgroundAsset = nil }
            inkRevisions[pageID, default: 0] += 1
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
    /// A running recording is stopped and saved first.
    func persistNow() {
        if audio.isRecording { audio.stopRecording() }
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
