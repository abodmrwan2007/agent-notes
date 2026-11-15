import Foundation
import GRDB

// The library index (folders, document metadata) lives in one SQLite database via GRDB.
// Document CONTENT is not stored here: each document is a package directory on disk
// (see DocumentStore). The index can always be rebuilt from the packages.

extension FolderRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "folder"
}

extension DocumentRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "document"
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
        migrator.registerMigration("v2_tags") { db in
            // JSON array of strings, written by GRDB's Codable support.
            try db.alter(table: "document") { t in
                t.add(column: "tags", .text).notNull().defaults(to: "[]")
            }
        }
        migrator.registerMigration("v3_lock_cover") { db in
            try db.alter(table: "document") { t in
                t.add(column: "isProtected", .boolean).notNull().defaults(to: false)
                t.add(column: "coverStyle", .text)
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

    /// Subfolders are removed with it (cascade); notes inside fall back to the library root.
    func deleteFolder(id: String) throws {
        _ = try queue.write { db in try FolderRow.deleteOne(db, key: id) }
    }
}
