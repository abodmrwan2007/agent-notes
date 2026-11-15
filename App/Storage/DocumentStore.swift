import AgentNotesCore
import Foundation
import PDFKit
import UIKit

enum DocumentStoreError: LocalizedError {
    case unreadablePDF
    case lockedPDF
    case emptyPDF
    case notAPackage
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return String(localized: "This file could not be read as a PDF.")
        case .lockedPDF:
            return String(localized: "Password-protected PDFs are not supported yet.")
        case .emptyPDF:
            return String(localized: "This PDF has no pages.")
        case .notAPackage:
            return String(localized: "This file is not a valid notebook package.")
        case .unreadableImage:
            return String(localized: "None of the selected images could be read.")
        }
    }
}

/// Owns the document packages on disk. Each document is a directory:
///   <Application Support>/AgentNotes/Documents/<document-id>.agentnote/
/// New packages are assembled in a staging directory and moved into place in one step,
/// so a crash during import never leaves a half-built document in the library.
final class DocumentStore: @unchecked Sendable {
    let documentsDirectory: URL
    private var fileManager: FileManager { .default }

    init() throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        documentsDirectory = support.appendingPathComponent("AgentNotes/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        removeLeftoverStagingDirectories()
    }

    static func libraryDatabaseURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("AgentNotes", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("library.sqlite", isDirectory: false)
    }

    // MARK: Locations

    func packageURL(for id: UUID) -> URL {
        documentsDirectory.appendingPathComponent(
            id.uuidString + "." + DocumentFormat.packageExtension, isDirectory: true)
    }

    func layout(for id: UUID) -> DocumentPackageLayout {
        DocumentPackageLayout(root: packageURL(for: id))
    }

    /// Identifiers of every package present on disk (used to rebuild a lost index).
    func documentIDsOnDisk() -> [UUID] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension == DocumentFormat.packageExtension }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
    }

    // MARK: Manifest and ink

    func loadManifest(id: UUID) throws -> DocumentManifest {
        try layout(for: id).readManifest()
    }

    func saveManifest(_ manifest: DocumentManifest) throws {
        try layout(for: manifest.id).writeManifest(manifest)
    }

    func loadInkData(documentID: UUID, pageID: UUID) -> Data? {
        try? Data(contentsOf: layout(for: documentID).inkURL(pageID: pageID))
    }

    func deleteInk(documentID: UUID, pageID: UUID) {
        try? fileManager.removeItem(at: layout(for: documentID).inkURL(pageID: pageID))
    }

    func copyInk(documentID: UUID, from sourcePageID: UUID, to targetPageID: UUID) throws {
        let files = self.layout(for: documentID)
        let source = files.inkURL(pageID: sourcePageID)
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(at: source, to: files.inkURL(pageID: targetPageID))
    }

    // MARK: Page objects and assets

    /// Throws when the file exists but cannot be decoded, so callers never overwrite it blindly.
    func loadObjects(documentID: UUID, pageID: UUID) throws -> PageObjectLayer {
        try layout(for: documentID).readObjects(pageID: pageID)
    }

    func saveObjects(_ layer: PageObjectLayer, documentID: UUID, pageID: UUID) throws {
        try layout(for: documentID).writeObjects(layer, pageID: pageID)
    }

    func deleteObjects(documentID: UUID, pageID: UUID) {
        try? fileManager.removeItem(at: layout(for: documentID).objectsURL(pageID: pageID))
    }

    func copyObjects(documentID: UUID, from sourcePageID: UUID, to targetPageID: UUID) throws {
        let files = self.layout(for: documentID)
        let source = files.objectsURL(pageID: sourcePageID)
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(at: source, to: files.objectsURL(pageID: targetPageID))
    }

    func assetURL(documentID: UUID, fileName: String) -> URL {
        layout(for: documentID).assetURL(fileName: fileName)
    }

    func audioURL(documentID: UUID, fileName: String) -> URL {
        layout(for: documentID).audioURL(fileName: fileName)
    }

    /// A new, empty location for a recording inside the package.
    func newAudioURL(documentID: UUID) throws -> (fileName: String, url: URL) {
        let files = self.layout(for: documentID)
        try fileManager.createDirectory(at: files.audioDirectory, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".m4a"
        return (fileName, files.audioURL(fileName: fileName))
    }

    func deleteAudio(documentID: UUID, fileName: String) {
        try? fileManager.removeItem(at: layout(for: documentID).audioURL(fileName: fileName))
    }

    /// Stores image data inside the package and returns its file name.
    func addAsset(_ data: Data, fileExtension: String, documentID: UUID) throws -> String {
        let files = self.layout(for: documentID)
        try fileManager.createDirectory(at: files.assetsDirectory, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + "." + fileExtension
        try data.write(to: files.assetURL(fileName: fileName), options: .atomic)
        return fileName
    }

    /// Opens a fresh PDFDocument instance. Callers on different threads must not share one.
    func openPDF(manifest: DocumentManifest, sourceID: UUID) -> PDFDocument? {
        guard let source = manifest.sources.first(where: { $0.id == sourceID }) else { return nil }
        return PDFDocument(url: layout(for: manifest.id).sourceURL(fileName: source.fileName))
    }

    // MARK: Creating documents

    func createNotebook(title: String, template: PageTemplate, size: PageSize) throws -> DocumentManifest {
        let manifest = DocumentManifest(title: title, pages: [PageRecord(size: size, template: template)])
        try assemblePackage(for: manifest.id) { layout in
            try layout.writeManifest(manifest)
        }
        return manifest
    }

    /// Copies the original PDF into the package untouched and creates one page per PDF page.
    func importPDF(from url: URL) throws -> DocumentManifest {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let source = SourceRecord(kind: .pdf, fileName: UUID().uuidString + ".pdf", originalFileName: url.lastPathComponent)
        var manifest = DocumentManifest(
            title: url.deletingPathExtension().lastPathComponent, sources: [source], pages: [])

        try assemblePackage(for: manifest.id) { layout in
            let destination = layout.sourceURL(fileName: source.fileName)
            try self.fileManager.copyItem(at: url, to: destination)

            guard let pdf = PDFDocument(url: destination) else { throw DocumentStoreError.unreadablePDF }
            guard !pdf.isLocked else { throw DocumentStoreError.lockedPDF }
            guard pdf.pageCount > 0 else { throw DocumentStoreError.emptyPDF }

            var pages: [PageRecord] = []
            pages.reserveCapacity(pdf.pageCount)
            for index in 0..<pdf.pageCount {
                guard let page = pdf.page(at: index) else { continue }
                let crop = page.bounds(for: .cropBox)
                let geometry = PDFPageGeometry(
                    cropBox: PDFBox(x: crop.origin.x, y: crop.origin.y, width: crop.width, height: crop.height),
                    rotationDegrees: page.rotation)
                var size = geometry.canonicalSize
                if size.width < 1 || size.height < 1 { size = AppConfig.defaultPageSize }
                pages.append(PageRecord(size: size, pdf: PDFPageReference(sourceID: source.id, pageIndex: index)))
            }
            guard !pages.isEmpty else { throw DocumentStoreError.emptyPDF }
            manifest.pages = pages
            try layout.writeManifest(manifest)
        }
        return manifest
    }

    /// One notebook from photos or scans: one page per image, sized to the image's proportions at
    /// the default page width. Each image is stored in the package and placed as a locked,
    /// full-page object, so it cannot be moved by accident and ink goes on top of it.
    func importImages(from urls: [URL], title: String) throws -> DocumentManifest {
        var manifest = DocumentManifest(title: title, pages: [])
        try assemblePackage(for: manifest.id) { layout in
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), let image = UIImage(data: data),
                      image.size.width > 0, image.size.height > 0 else { continue }

                let jpeg = Self.normalizedJPEG(image, maxPixels: 2400)
                let fileName = UUID().uuidString + ".jpg"
                try jpeg.write(to: layout.assetURL(fileName: fileName), options: .atomic)

                let width = AppConfig.defaultPageSize.width
                let height = (width * Double(image.size.height / image.size.width)).rounded()
                let page = PageRecord(size: PageSize(width: width, height: height), template: .blank)
                var objects = PageObjectLayer()
                objects.add(PageObject(
                    kind: .image, frame: PageRect(x: 0, y: 0, width: width, height: height),
                    isLocked: true, assetFileName: fileName))
                try layout.writeObjects(objects, pageID: page.id)
                manifest.pages.append(page)
            }
            guard !manifest.pages.isEmpty else { throw DocumentStoreError.unreadableImage }
            try layout.writeManifest(manifest)
        }
        return manifest
    }

    /// Bakes in the photo's orientation and limits the size; returns JPEG data.
    private static func normalizedJPEG(_ image: UIImage, maxPixels: CGFloat) -> Data {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let factor = min(maxPixels / max(pixelWidth, pixelHeight), 1)
        let target = CGSize(width: pixelWidth * factor, height: pixelHeight * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85) ?? Data()
    }

    /// Imports a native package exported from this app. Keeps its identifier unless it collides.
    func importPackage(from url: URL) throws -> DocumentManifest {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard var manifest = try? DocumentPackageLayout(root: url).readManifest() else {
            throw DocumentStoreError.notAPackage
        }
        if fileManager.fileExists(atPath: packageURL(for: manifest.id).path) {
            manifest.id = UUID()
        }
        try copyPackage(from: url, as: manifest)
        return manifest
    }

    func duplicateDocument(id: UUID, title: String) throws -> DocumentManifest {
        var manifest = try loadManifest(id: id)
        manifest.id = UUID()
        manifest.title = title
        manifest.createdAt = Date()
        manifest.modifiedAt = manifest.createdAt
        try copyPackage(from: packageURL(for: id), as: manifest)
        return manifest
    }

    func deleteDocument(id: UUID) throws {
        let url = packageURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    /// Copies the package to a temporary location under a readable name, for sharing.
    func exportPackageCopy(id: UUID, fileName: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("export-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(
            fileName + "." + DocumentFormat.packageExtension, isDirectory: true)
        try fileManager.copyItem(at: packageURL(for: id), to: destination)
        return destination
    }

    // MARK: Staging

    private static let stagingPrefix = ".staging-"

    private func assemblePackage(for id: UUID, build: (DocumentPackageLayout) throws -> Void) throws {
        let staging = documentsDirectory.appendingPathComponent(
            Self.stagingPrefix + UUID().uuidString, isDirectory: true)
        do {
            let layout = DocumentPackageLayout(root: staging)
            try layout.createDirectories(using: fileManager)
            try build(layout)
            try fileManager.moveItem(at: staging, to: packageURL(for: id))
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func copyPackage(from source: URL, as manifest: DocumentManifest) throws {
        let staging = documentsDirectory.appendingPathComponent(
            Self.stagingPrefix + UUID().uuidString, isDirectory: true)
        do {
            try fileManager.copyItem(at: source, to: staging)
            let layout = DocumentPackageLayout(root: staging)
            try layout.createDirectories(using: fileManager)
            try layout.writeManifest(manifest)
            try fileManager.moveItem(at: staging, to: packageURL(for: manifest.id))
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func removeLeftoverStagingDirectories() {
        let contents = (try? fileManager.contentsOfDirectory(
            at: documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent.hasPrefix(Self.stagingPrefix) {
            try? fileManager.removeItem(at: url)
        }
    }
}
