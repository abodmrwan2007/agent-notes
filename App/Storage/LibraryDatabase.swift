import AgentNotesCore
import Foundation
import GRDB

// The library index (folders, document metadata) lives in one SQLite database via GRDB.
// Document CONTENT is not stored here: each document is a package directory on disk
// (see DocumentStore). The index can always be rebuilt from the packages.

struct FolderRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "folder"

    var id: String
    var parentID: String?
    var name: String
    var createdAt: Date
}

struct DocumentRow: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "document"

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

final class LibraryDatabase: @unchecked Sendable {
    private let queue: DatabaseQueue

    init(url: URL) throws {
        queue = try DatabaseQueue(path: url.path)
        try Self.migrator.migrate(queue)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_library") { db in
            try db.create(table: "folder") { t in
                t.column("id", .text).primaryKey()
                t.column("parentID", .text).references("folder", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "document") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                // Deleting a folder never deletes notes: they fall back to the library root.
                t.column("folderID", .text).references("folder", onDelete: .setNull)
                t.column("createdAt", .datetime).notNull()
                t.column("modifiedAt", .datetime).notNull()
                t.column("lastOpenedAt", .datetime)
                t.column("isFavorite", .boolean).notNull().defaults(to: false)
                t.column("trashedAt", .datetime)
                t.column("pageCount", .integer).notNull()
                t.column("hasPDF", .boolean).notNull().defaults(to: false)
            }
        }
        return migrator
    }

    func allFolders() throws -> [FolderRow] {
        try queue.read { db in try FolderRow.fetchAll(db) }
    }

    func allDocuments() throws -> [DocumentRow] {
        try queue.read { db in try DocumentRow.fetchAll(db) }
    }

    func document(id: String) throws -> DocumentRow? {
        try queue.read { db in try DocumentRow.fetchOne(db, key: id) }
    }

    func save(_ row: DocumentRow) throws {
        try queue.write { db in try row.save(db) }
    }

    func save(_ row: FolderRow) throws {
        try queue.write { db in try row.save(db) }
    }

    func deleteDocument(id: String) throws {
        _ = try queue.write { db in try DocumentRow.deleteOne(db, key: id) }
    }

    func deleteFolder(id: String) throws {
        _ = try queue.write { db in try FolderRow.deleteOne(db, key: id) }
    }
}
