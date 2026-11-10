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
    }

    /// Copies the fields the document package is the source of truth for.
    mutating func apply(_ manifest: DocumentManifest) {
        title = manifest.title
        modifiedAt = manifest.modifiedAt
        pageCount = manifest.pages.count
        hasPDF = !manifest.sources.isEmpty
    }
}
