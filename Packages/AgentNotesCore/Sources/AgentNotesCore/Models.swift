import Foundation

/// Constants describing the on-disk native document package. See docs/DATA_FORMAT.md.
public enum DocumentFormat {
    /// Bump when the manifest schema changes and add a step to `ManifestCodec.migrations`.
    /// Version 2 added page objects (`objects/`) and their binary assets (`assets/`).
    /// Version 3 added the `planner` template and per-page background images.
    /// Version 4 added sticky-note styles (`noteStyle` on page objects).
    public static let currentVersion = 4
    public static let packageExtension = "agentnote"
    public static let manifestFileName = "manifest.json"
    public static let sourcesDirectoryName = "sources"
    public static let inkDirectoryName = "ink"
    public static let objectsDirectoryName = "objects"
    public static let assetsDirectoryName = "assets"
    /// Identifier of the ink payload encoding stored per page.
    public static let pencilKitInkEncoding = "apple.pencilkit.drawing"
}

/// Page size in canonical page coordinates: points, origin top-left, y pointing down.
public struct PageSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let a4 = PageSize(width: 595, height: 842)
    public static let usLetter = PageSize(width: 612, height: 792)
}

public enum PageTemplate: String, Codable, CaseIterable, Sendable {
    case blank
    case ruled
    case grid
    case dotGrid
    case cornell
    /// A week: header band and seven day rows.
    case planner
}

/// Points a page at one page of a preserved original PDF stored in the package.
public struct PDFPageReference: Codable, Hashable, Sendable {
    public var sourceID: UUID
    /// Zero-based page index inside the source PDF.
    public var pageIndex: Int

    public init(sourceID: UUID, pageIndex: Int) {
        self.sourceID = sourceID
        self.pageIndex = pageIndex
    }
}

public struct PageRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Canonical size. For PDF pages this is the crop box after applying the page rotation.
    public var size: PageSize
    /// Background template. Ignored while `pdf` is set.
    public var template: PageTemplate
    public var pdf: PDFPageReference?
    public var isBookmarked: Bool
    /// Asset file (in `assets/`) drawn as the page background instead of the template.
    public var backgroundAsset: String?

    public init(
        id: UUID = UUID(),
        size: PageSize,
        template: PageTemplate = .blank,
        pdf: PDFPageReference? = nil,
        isBookmarked: Bool = false,
        backgroundAsset: String? = nil
    ) {
        self.id = id
        self.size = size
        self.template = template
        self.pdf = pdf
        self.isBookmarked = isBookmarked
        self.backgroundAsset = backgroundAsset
    }
}

/// An original imported file kept untouched inside the package.
public struct SourceRecord: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case pdf
    }

    public var id: UUID
    public var kind: Kind
    /// File name inside the package `sources/` directory.
    public var fileName: String
    /// Name of the file the user imported, for display and export.
    public var originalFileName: String

    public init(id: UUID = UUID(), kind: Kind, fileName: String, originalFileName: String) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.originalFileName = originalFileName
    }
}

public struct DocumentManifest: Codable, Hashable, Identifiable, Sendable {
    public var formatVersion: Int
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var inkEncoding: String
    public var sources: [SourceRecord]
    public var pages: [PageRecord]

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil,
        sources: [SourceRecord] = [],
        pages: [PageRecord]
    ) {
        self.formatVersion = DocumentFormat.currentVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.inkEncoding = DocumentFormat.pencilKitInkEncoding
        self.sources = sources
        self.pages = pages
    }
}
