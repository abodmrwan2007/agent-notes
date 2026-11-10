import Foundation
import Observation

/// Root dependency container and navigation state.
@MainActor
@Observable
final class AppModel {
    let store: DocumentStore
    let thumbnails: ThumbnailService
    let library: LibraryModel

    /// The document shown in the editor, or nil while the library is visible.
    var openDocumentID: UUID?

    init() throws {
        let store = try DocumentStore()
        let database = try LibraryDatabase(url: DocumentStore.libraryDatabaseURL())
        let thumbnails = ThumbnailService(store: store)
        self.store = store
        self.thumbnails = thumbnails
        self.library = LibraryModel(store: store, database: database, thumbnails: thumbnails)
        library.reconcileWithDisk()
        library.reload()
    }

    func open(_ document: DocumentRow) {
        guard !document.isTrashed, let id = document.documentID else { return }
        library.markOpened(document)
        openDocumentID = id
    }

    func closeDocument() {
        openDocumentID = nil
        library.reload()
    }
}
