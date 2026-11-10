import Foundation

// SWIFT PLAYGROUNDS VARIANT ONLY. Replaces App/Storage/LibraryDatabase.swift when
// tools/build_playground.py assembles the .swiftpm package.
//
// Same interface and same behaviour as the SQLite/GRDB store, but backed by one JSON file,
// so the playground needs no third-party package (nothing to download or compile on the iPad).
// The Xcode app keeps using SQLite. The index is derived data in both cases: documents live in
// their own packages and the index is rebuilt from them if this file is lost.

final class LibraryDatabase: @unchecked Sendable {
    private struct Snapshot: Codable {
        var folders: [FolderRow] = []
        var documents: [DocumentRow] = []
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var snapshot = Snapshot()

    init(url: URL) throws {
        fileURL = url.deletingPathExtension().appendingPathExtension("json")
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            // An unreadable index is not fatal: documents are re-indexed from their packages.
            snapshot = (try? decoder.decode(Snapshot.self, from: data)) ?? Snapshot()
        }
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func allFolders() throws -> [FolderRow] {
        locked { snapshot.folders }
    }

    func allDocuments() throws -> [DocumentRow] {
        locked { snapshot.documents }
    }

    func document(id: String) throws -> DocumentRow? {
        locked { snapshot.documents.first { $0.id == id } }
    }

    func save(_ row: DocumentRow) throws {
        try locked {
            if let index = snapshot.documents.firstIndex(where: { $0.id == row.id }) {
                snapshot.documents[index] = row
            } else {
                snapshot.documents.append(row)
            }
            try persist()
        }
    }

    func save(_ row: FolderRow) throws {
        try locked {
            if let index = snapshot.folders.firstIndex(where: { $0.id == row.id }) {
                snapshot.folders[index] = row
            } else {
                snapshot.folders.append(row)
            }
            try persist()
        }
    }

    func deleteDocument(id: String) throws {
        try locked {
            snapshot.documents.removeAll { $0.id == id }
            try persist()
        }
    }

    /// Subfolders are removed with it; notes inside fall back to the library root.
    func deleteFolder(id: String) throws {
        try locked {
            var removed: Set<String> = [id]
            var grew = true
            while grew {
                grew = false
                for folder in snapshot.folders {
                    if let parent = folder.parentID, removed.contains(parent), !removed.contains(folder.id) {
                        removed.insert(folder.id)
                        grew = true
                    }
                }
            }
            snapshot.folders.removeAll { removed.contains($0.id) }
            for index in snapshot.documents.indices {
                if let folderID = snapshot.documents[index].folderID, removed.contains(folderID) {
                    snapshot.documents[index].folderID = nil
                }
            }
            try persist()
        }
    }
}
