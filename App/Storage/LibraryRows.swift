import AgentNotesCore
import Foundation

// Rows of the library index. Plain Codable values with no database dependency, so the same
// types work with the SQLite store (LibraryDatabase.swift) and with the JSON store used by the
// Swift Playgrounds variant (playground/LibraryDatabase.swift).

struct FolderRow: Codable, Identifiable, Hashable {
    var id: String
    var parentID: String?
    var name: String
    var createdAt: Date
}

struct DocumentRow: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var folderID: String?
    var createdAt: Date
    var modifiedAt: Date
    var lastOpenedAt: Date?
    var isFavorite: Bool
    var trashedAt: Date?
    var pageCount: Int
    var hasPDF: Bool
    /// User tags, kept sorted and unique. Stored as JSON in the index.
    var tags: [String] = []
    /// Opening requires Face ID / Touch ID or the device passcode. Not encryption: see NotebookLock.
    var isProtected = false
    /// A `NotebookCover` raw value, or nil to show the first page.
    var coverStyle: String?

    var documentID: UUID? { UUID(uuidString: id) }
    var isTrashed: Bool { trashedAt != nil }

    init(manifest: DocumentManifest, folderID: String?) {
        self.id = manifest.id.uuidString
        self.title = manifest.title
        self.folderID = folderID
        self.createdAt = manifest.createdAt
        self.modifiedAt = manifest.modifiedAt
        self.lastOpenedAt = nil
        self.isFavorite = false
        self.trashedAt = nil
        self.pageCount = manifest.pages.count
        self.hasPDF = !manifest.sources.isEmpty
        self.tags = []
    }

    // Rows written before tags existed have no `tags` value.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        folderID = try container.decodeIfPresent(String.self, forKey: .folderID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        trashedAt = try container.decodeIfPresent(Date.self, forKey: .trashedAt)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        hasPDF = try container.decode(Bool.self, forKey: .hasPDF)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isProtected = try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false
        coverStyle = try container.decodeIfPresent(String.self, forKey: .coverStyle)
    }

    /// Copies the fields the document package is the source of truth for.
    mutating func apply(_ manifest: DocumentManifest) {
        title = manifest.title
        modifiedAt = manifest.modifiedAt
        pageCount = manifest.pages.count
        hasPDF = !manifest.sources.isEmpty
    }
}
