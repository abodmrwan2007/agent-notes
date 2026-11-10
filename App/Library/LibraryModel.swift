import AgentNotesCore
import Foundation
import Observation

enum SidebarItem: Hashable {
    case all
    case recents
    case favorites
    case trash
    case folder(String)
    case study
    case atlas
    case community
    case settings

    var isLibrarySection: Bool {
        switch self {
        case .all, .recents, .favorites, .trash, .folder: return true
        case .study, .atlas, .community, .settings: return false
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case modified
    case created
    case title

    var id: String { rawValue }
}

struct FolderNode: Identifiable, Hashable {
    let id: String
    let name: String
    var children: [FolderNode]?
}

/// Library state and actions. The SQLite index is the source of truth for organization
/// (folders, favorites, trash); document packages are the source of truth for content.
@MainActor
@Observable
final class LibraryModel {
    private(set) var folders: [FolderRow] = []
    private(set) var documents: [DocumentRow] = []
    var errorMessage: String?
    /// Non-nil while a long operation (import, duplicate) is running.
    private(set) var busyMessage: String?

    @ObservationIgnored private let store: DocumentStore
    @ObservationIgnored private let database: LibraryDatabase
    @ObservationIgnored private let thumbnails: ThumbnailService

    init(store: DocumentStore, database: LibraryDatabase, thumbnails: ThumbnailService) {
        self.store = store
        self.database = database
        self.thumbnails = thumbnails
    }

    // MARK: Loading

    func reload() {
        do {
            folders = try database.allFolders()
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            documents = try database.allDocuments()
        } catch {
            report(error)
        }
    }

    /// Recovery at launch. The packages are the source of truth for content:
    /// - a package without an index row (lost or reset database) is re-indexed;
    /// - a row that is behind its package (the app was killed before the editor closed) is refreshed.
    func reconcileWithDisk() {
        do {
            let rows = Dictionary(
                try database.allDocuments().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for id in store.documentIDsOnDisk() {
                guard let manifest = try? store.loadManifest(id: id) else { continue }
                if var row = rows[id.uuidString] {
                    let isStale = abs(row.modifiedAt.timeIntervalSince(manifest.modifiedAt)) > 1
                        || row.pageCount != manifest.pages.count
                        || row.title != manifest.title
                    if isStale {
                        row.apply(manifest)
                        try database.save(row)
                    }
                } else {
                    try database.save(DocumentRow(manifest: manifest, folderID: nil))
                }
            }
        } catch {
            report(error)
        }
    }

    // MARK: Queries

    func documents(for item: SidebarItem, search: String, sort: LibrarySort) -> [DocumentRow] {
        let active = documents.filter { !$0.isTrashed }
        var result: [DocumentRow]
        switch item {
        case .trash:
            result = documents.filter(\.isTrashed)
        case .favorites:
            result = active.filter(\.isFavorite)
        case .recents:
            result = Array(
                active
                    .filter { $0.lastOpenedAt != nil }
                    .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
                    .prefix(30))
        case .folder(let id):
            result = active.filter { $0.folderID == id }
        default:
            result = active
        }

        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            result = result.filter { SearchNormalizer.matches($0.title, query: search) }
        }
        guard item != .recents else { return result }

        switch sort {
        case .modified: return result.sorted { $0.modifiedAt > $1.modifiedAt }
        case .created: return result.sorted { $0.createdAt > $1.createdAt }
        case .title: return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    var trashCount: Int { documents.filter(\.isTrashed).count }

    var folderTree: [FolderNode] {
        func nodes(parent: String?) -> [FolderNode] {
            folders.filter { $0.parentID == parent }.map { folder in
                let children = nodes(parent: folder.id)
                return FolderNode(id: folder.id, name: folder.name, children: children.isEmpty ? nil : children)
            }
        }
        return nodes(parent: nil)
    }

    /// Every folder with its full path ("Anatomy / Heart"), for "Move to" menus.
    var folderPaths: [(id: String, path: String)] {
        func walk(_ nodes: [FolderNode], prefix: String) -> [(id: String, path: String)] {
            nodes.flatMap { node -> [(id: String, path: String)] in
                let path = prefix.isEmpty ? node.name : prefix + " / " + node.name
                return [(id: node.id, path: path)] + walk(node.children ?? [], prefix: path)
            }
        }
        return walk(folderTree, prefix: "")
    }

    func folderName(id: String) -> String? {
        folders.first { $0.id == id }?.name
    }

    // MARK: Document actions

    @discardableResult
    func createNotebook(template: PageTemplate, folderID: String?) -> DocumentRow? {
        do {
            let manifest = try store.createNotebook(
                title: String(localized: "Untitled notebook"), template: template, size: AppConfig.defaultPageSize)
            let row = DocumentRow(manifest: manifest, folderID: folderID)
            try database.save(row)
            reload()
            return row
        } catch {
            report(error)
            return nil
        }
    }

    /// Imports PDFs and native packages. Each file is processed off the main thread.
    func importFiles(_ urls: [URL], folderID: String?) async {
        busyMessage = String(localized: "Importing…")
        defer { busyMessage = nil }
        let store = self.store
        for url in urls {
            let isPackage = url.pathExtension.lowercased() == DocumentFormat.packageExtension
            do {
                let manifest = try await Task.detached(priority: .userInitiated) {
                    try isPackage ? store.importPackage(from: url) : store.importPDF(from: url)
                }.value
                try database.save(DocumentRow(manifest: manifest, folderID: folderID))
            } catch {
                report(error)
            }
        }
        reload()
    }

    func duplicate(_ document: DocumentRow) async {
        guard let id = document.documentID else { return }
        busyMessage = String(localized: "Duplicating…")
        defer { busyMessage = nil }
        let store = self.store
        let title = document.title + " " + String(localized: "copy")
        do {
            let manifest = try await Task.detached(priority: .userInitiated) {
                try store.duplicateDocument(id: id, title: title)
            }.value
            try database.save(DocumentRow(manifest: manifest, folderID: document.folderID))
        } catch {
            report(error)
        }
        reload()
    }

    func rename(_ document: DocumentRow, to title: String) {
        guard let id = document.documentID else { return }
        do {
            var manifest = try store.loadManifest(id: id)
            manifest.title = title
            manifest.modifiedAt = Date()
            try store.saveManifest(manifest)
            refreshRow(from: manifest)
        } catch {
            report(error)
        }
    }

    func toggleFavorite(_ document: DocumentRow) {
        update(document) { $0.isFavorite.toggle() }
    }

    func move(_ document: DocumentRow, toFolder folderID: String?) {
        update(document) { $0.folderID = folderID }
    }

    func moveToTrash(_ document: DocumentRow) {
        update(document) { $0.trashedAt = Date() }
    }

    func restore(_ document: DocumentRow) {
        update(document) { $0.trashedAt = nil }
    }

    func markOpened(_ document: DocumentRow) {
        update(document) { $0.lastOpenedAt = Date() }
    }

    func deletePermanently(_ document: DocumentRow) {
        do {
            if let id = document.documentID {
                try store.deleteDocument(id: id)
                thumbnails.removeCovers(for: id)
            }
            try database.deleteDocument(id: document.id)
        } catch {
            report(error)
        }
        reload()
    }

    func emptyTrash() {
        for document in documents where document.isTrashed {
            deletePermanently(document)
        }
    }

    /// Called by the editor after it saved: copies title, dates and page count into the index.
    func refreshRow(from manifest: DocumentManifest) {
        do {
            guard var row = try database.document(id: manifest.id.uuidString) else { return }
            row.apply(manifest)
            try database.save(row)
        } catch {
            report(error)
        }
        reload()
    }

    // MARK: Folder actions

    func createFolder(name: String, parentID: String?) {
        do {
            try database.save(FolderRow(id: UUID().uuidString, parentID: parentID, name: name, createdAt: Date()))
        } catch {
            report(error)
        }
        reload()
    }

    func renameFolder(id: String, to name: String) {
        guard var folder = folders.first(where: { $0.id == id }) else { return }
        folder.name = name
        do {
            try database.save(folder)
        } catch {
            report(error)
        }
        reload()
    }

    /// Removes the folder and its subfolders. Notes inside are kept and return to the library root.
    func deleteFolder(id: String) {
        do {
            try database.deleteFolder(id: id)
        } catch {
            report(error)
        }
        reload()
    }

    // MARK: Helpers

    private func update(_ document: DocumentRow, _ change: (inout DocumentRow) -> Void) {
        do {
            guard var row = try database.document(id: document.id) else { return }
            change(&row)
            try database.save(row)
        } catch {
            report(error)
        }
        reload()
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
