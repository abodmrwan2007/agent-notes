import AgentNotesCore
import Foundation
import PDFKit

/// One result of a search across notes.
struct SearchHit: Identifiable, Hashable {
    enum Source: Hashable {
        case title
        case pdfText
        case typedText
    }

    let id = UUID()
    let documentID: UUID
    let documentTitle: String
    let source: Source
    /// nil for title matches.
    let pageID: UUID?
    /// One-based, for display.
    let pageNumber: Int?
    let excerpt: TextExcerpt
}

/// Search across the library: titles, the text layer of imported PDFs, and typed text
/// (text boxes and sticky notes). Handwriting is NOT searchable yet (no recognizer).
///
/// PDF text is extracted once per source PDF (originals never change) and cached on disk in
/// Caches; a lost cache is simply rebuilt. Everything runs off the main thread.
final class TextIndexService: @unchecked Sendable {
    private let store: DocumentStore
    private let cacheDirectory: URL
    private let lock = NSLock()
    /// Normalized PDF page text, kept in memory between searches. Key: "<document>/<source>".
    private var normalizedPDFText: [String: [String]] = [:]

    private static let maxHitsPerDocument = 30
    private static let maxHits = 400

    init(store: DocumentStore) {
        self.store = store
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("AgentNotes/TextIndex", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: PDF text

    private struct CachedPDFText: Codable {
        static let currentVersion = 1
        var version: Int
        /// Raw text of each page of the source PDF, by zero-based page index.
        var pages: [String]
    }

    private func cacheURL(documentID: UUID, sourceID: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(documentID.uuidString)-\(sourceID.uuidString).json")
    }

    /// Raw text of every page of one source PDF. Extracted on first use, then read from the cache.
    func pdfPageTexts(manifest: DocumentManifest, sourceID: UUID) -> [String] {
        let url = cacheURL(documentID: manifest.id, sourceID: sourceID)
        if let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode(CachedPDFText.self, from: data),
           cached.version == CachedPDFText.currentVersion {
            return cached.pages
        }
        guard let pdf = store.openPDF(manifest: manifest, sourceID: sourceID) else { return [] }
        var pages: [String] = []
        pages.reserveCapacity(pdf.pageCount)
        for index in 0..<pdf.pageCount {
            autoreleasepool {
                pages.append(pdf.page(at: index)?.string ?? "")
            }
        }
        if let data = try? JSONEncoder().encode(CachedPDFText(version: CachedPDFText.currentVersion, pages: pages)) {
            try? data.write(to: url, options: .atomic)
        }
        return pages
    }

    /// Extracts the text of a newly imported document ahead of the first search.
    func prepare(documentID: UUID) {
        guard let manifest = try? store.loadManifest(id: documentID) else { return }
        for source in manifest.sources {
            _ = normalizedPages(manifest: manifest, sourceID: source.id)
        }
    }

    func removeCache(documentID: UUID) {
        lock.lock()
        normalizedPDFText = normalizedPDFText.filter { !$0.key.hasPrefix(documentID.uuidString) }
        lock.unlock()
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(documentID.uuidString) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func normalizedPages(manifest: DocumentManifest, sourceID: UUID) -> [String] {
        let key = "\(manifest.id.uuidString)/\(sourceID.uuidString)"
        lock.lock()
        let cached = normalizedPDFText[key]
        lock.unlock()
        if let cached { return cached }
        let normalized = pdfPageTexts(manifest: manifest, sourceID: sourceID).map(SearchNormalizer.normalize)
        lock.lock()
        normalizedPDFText[key] = normalized
        lock.unlock()
        return normalized
    }

    // MARK: Search

    /// Searches the given (non-trashed) documents. Cancels promptly when the calling task is cancelled.
    func search(_ query: String, in documents: [DocumentRow]) async throws -> [SearchHit] {
        let key = SearchNormalizer.normalize(query)
        guard !key.isEmpty else { return [] }
        var hits: [SearchHit] = []

        // Locked notebooks are never searched: results would show their content.
        for row in documents where !row.isTrashed && !row.isProtected {
            try Task.checkCancellation()
            guard let documentID = row.documentID,
                  let manifest = try? store.loadManifest(id: documentID) else { continue }
            var documentHits: [SearchHit] = []

            for range in TextMatcher.ranges(of: query, in: manifest.title, limit: 1) {
                documentHits.append(SearchHit(
                    documentID: documentID, documentTitle: manifest.title, source: .title,
                    pageID: nil, pageNumber: nil, excerpt: TextMatcher.excerpt(of: range, in: manifest.title)))
            }

            var pdfTexts: [UUID: [String]] = [:]
            var normalizedTexts: [UUID: [String]] = [:]
            for (index, page) in manifest.pages.enumerated() {
                if documentHits.count >= Self.maxHitsPerDocument { break }
                if index % 50 == 0 { try Task.checkCancellation() }

                if let reference = page.pdf {
                    if normalizedTexts[reference.sourceID] == nil {
                        normalizedTexts[reference.sourceID] = normalizedPages(manifest: manifest, sourceID: reference.sourceID)
                    }
                    let normalized = normalizedTexts[reference.sourceID] ?? []
                    // Cheap check on the cached normalized text first; map back only on a hit.
                    if normalized.indices.contains(reference.pageIndex), normalized[reference.pageIndex].contains(key) {
                        if pdfTexts[reference.sourceID] == nil {
                            pdfTexts[reference.sourceID] = pdfPageTexts(manifest: manifest, sourceID: reference.sourceID)
                        }
                        let raw = pdfTexts[reference.sourceID]?[safe: reference.pageIndex] ?? ""
                        for range in TextMatcher.ranges(of: query, in: raw, limit: 3) {
                            documentHits.append(SearchHit(
                                documentID: documentID, documentTitle: manifest.title, source: .pdfText,
                                pageID: page.id, pageNumber: index + 1,
                                excerpt: TextMatcher.excerpt(of: range, in: raw)))
                        }
                    }
                }

                let objects = (try? store.loadObjects(documentID: documentID, pageID: page.id)) ?? PageObjectLayer()
                for object in objects.objects {
                    guard let text = object.text, !text.isEmpty else { continue }
                    for range in TextMatcher.ranges(of: query, in: text, limit: 3) {
                        documentHits.append(SearchHit(
                            documentID: documentID, documentTitle: manifest.title, source: .typedText,
                            pageID: page.id, pageNumber: index + 1,
                            excerpt: TextMatcher.excerpt(of: range, in: text)))
                    }
                }
            }

            hits.append(contentsOf: documentHits.prefix(Self.maxHitsPerDocument))
            if hits.count >= Self.maxHits { break }
        }
        return Array(hits.prefix(Self.maxHits))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
