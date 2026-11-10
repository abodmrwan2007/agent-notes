import AgentNotesCore
import PDFKit
import PencilKit
import UIKit

/// Flattens a document into a readable PDF: original PDF page content is redrawn as vector,
/// templates as vector, handwriting as a high-resolution raster layer on top.
/// The editable data (separate ink layer, original PDF) is only kept by the native package export.
enum PDFExporter {
    /// Safe to call off the main thread. Opens its own PDFDocument instances.
    static func export(manifest: DocumentManifest, store: DocumentStore, fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName + ".pdf", isDirectory: false)

        var pdfSources: [UUID: PDFDocument] = [:]
        let firstBounds = manifest.pages.first?.size.cgRect ?? AppConfig.defaultPageSize.cgRect
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)

        try renderer.writePDF(to: url) { context in
            for page in manifest.pages {
                // Keep peak memory at one page regardless of document length.
                autoreleasepool {
                    var pdfPage: PDFPage?
                    if let reference = page.pdf {
                        if pdfSources[reference.sourceID] == nil {
                            pdfSources[reference.sourceID] = store.openPDF(
                                manifest: manifest, sourceID: reference.sourceID)
                        }
                        pdfPage = pdfSources[reference.sourceID]?.page(at: reference.pageIndex)
                    }

                    context.beginPage(withBounds: page.size.cgRect, pageInfo: [:])
                    PageRenderer.drawBackground(page: page, pdfPage: pdfPage, in: context.cgContext)

                    // Typed text and shapes are drawn as vector content; images at their own resolution.
                    if let objects = try? store.loadObjects(documentID: manifest.id, pageID: page.id) {
                        PageRenderer.drawObjects(objects) { name in
                            UIImage(contentsOfFile: store.assetURL(documentID: manifest.id, fileName: name).path)
                        }
                    }

                    if let data = store.loadInkData(documentID: manifest.id, pageID: page.id),
                       let drawing = try? PKDrawing(data: data) {
                        PageRenderer.drawInk(drawing, pageSize: page.size, scale: AppConfig.exportInkScale)
                    }
                }
            }
        }
        return url
    }

    /// File-system-safe version of a document title.
    static func safeFileName(_ title: String) -> String {
        let cleaned = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Notebook" : cleaned
    }
}
