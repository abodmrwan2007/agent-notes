import AgentNotesCore
import PDFKit
import PencilKit
import UIKit

/// Renders library covers and page thumbnails off the main thread, with a memory cache and an
/// on-disk cover cache. Uses its own PDFDocument instances (never the editor's).
final class ThumbnailService: @unchecked Sendable {
    private let store: DocumentStore
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "agentnotes.thumbnails", qos: .utility)
    private let coversDirectory: URL

    // Confined to `queue`: the most recently used PDF, so consecutive pages don't reopen the file.
    private var openPDFKey: String?
    private var openPDF: PDFDocument?

    init(store: DocumentStore) {
        self.store = store
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        coversDirectory = caches.appendingPathComponent("AgentNotes/Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
        cache.countLimit = 300
    }

    /// Cover of the first page. `stamp` is the document's modification date: a new date yields a new cover.
    func cover(for documentID: UUID, stamp: Date) async -> UIImage? {
        let name = "\(documentID.uuidString)-\(Int(stamp.timeIntervalSince1970))"
        if let cached = cache.object(forKey: name as NSString) { return cached }
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = self.loadOrRenderCover(documentID: documentID, name: name)
                if let image { self.cache.setObject(image, forKey: name as NSString) }
                continuation.resume(returning: image)
            }
        }
    }

    /// `revision` changes whenever the page's ink is saved, which invalidates the cached thumbnail.
    func pageThumbnail(manifest: DocumentManifest, page: PageRecord, revision: Int) async -> UIImage? {
        let key = "\(page.id.uuidString)-\(revision)-\(page.template.rawValue)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = self.render(manifest: manifest, page: page, maxDimension: 220)
                self.cache.setObject(image, forKey: key)
                continuation.resume(returning: image)
            }
        }
    }

    func removeCovers(for documentID: UUID) {
        queue.async {
            self.deleteCoverFiles(prefix: documentID.uuidString, keeping: nil)
        }
    }

    // MARK: Queue-confined work

    private func loadOrRenderCover(documentID: UUID, name: String) -> UIImage? {
        let file = coversDirectory.appendingPathComponent(name + ".jpg", isDirectory: false)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            return image
        }
        guard let manifest = try? store.loadManifest(id: documentID), let first = manifest.pages.first else {
            return nil
        }
        let image = render(manifest: manifest, page: first, maxDimension: 420)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: file, options: .atomic)
            deleteCoverFiles(prefix: documentID.uuidString, keeping: file.lastPathComponent)
        }
        return image
    }

    private func render(manifest: DocumentManifest, page: PageRecord, maxDimension: CGFloat) -> UIImage {
        var pdfPage: PDFPage?
        if let reference = page.pdf {
            let key = "\(manifest.id.uuidString)/\(reference.sourceID.uuidString)"
            if openPDFKey != key {
                openPDF = store.openPDF(manifest: manifest, sourceID: reference.sourceID)
                openPDFKey = key
            }
            pdfPage = openPDF?.page(at: reference.pageIndex)
        }
        let ink = store.loadInkData(documentID: manifest.id, pageID: page.id).flatMap { try? PKDrawing(data: $0) }
        return PageRenderer.image(page: page, pdfPage: pdfPage, ink: ink, maxDimension: maxDimension)
    }

    private func deleteCoverFiles(prefix: String, keeping: String?) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: coversDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(prefix) && file.lastPathComponent != keeping {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
