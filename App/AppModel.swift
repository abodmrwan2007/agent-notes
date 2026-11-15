import AgentNotesCore
import Foundation
import Observation

/// Where to land when a document opens from a search result.
struct OpenTarget: Equatable {
    let pageID: UUID
    /// Highlighted on the page's PDF text, when present.
    let highlightQuery: String?
}

/// Root dependency container and navigation state.
@MainActor
@Observable
final class AppModel {
    let store: DocumentStore
    let thumbnails: ThumbnailService
    let textIndex: TextIndexService
    let library: LibraryModel

    /// The document shown in the editor, or nil while the library is visible.
    var openDocumentID: UUID?
    /// Consumed by the editor when it opens.
    var openTarget: OpenTarget?
    var sidebarSelection: SidebarItem? = .all
    /// Pre-filled query for the search screen (for example from a text selection in the editor).
    var searchQuery = ""

    init() throws {
        let store = try DocumentStore()
        let database = try LibraryDatabase(url: DocumentStore.libraryDatabaseURL())
        let thumbnails = ThumbnailService(store: store)
        let textIndex = TextIndexService(store: store)
        self.store = store
        self.thumbnails = thumbnails
        self.textIndex = textIndex
        self.library = LibraryModel(store: store, database: database, thumbnails: thumbnails, textIndex: textIndex)
        library.reconcileWithDisk()
        library.reload()
        #if DEBUG
        seedUITestFixturesIfRequested()
        #endif
    }

    func open(_ document: DocumentRow, target: OpenTarget? = nil) {
        guard !document.isTrashed, let id = document.documentID else { return }
        guard document.isProtected else {
            finishOpening(document, id: id, target: target)
            return
        }
        Task {
            if let message = await NotebookLock.authenticate(reason: String(localized: "Open the locked notebook")) {
                if !message.isEmpty { library.errorMessage = message }
                return
            }
            finishOpening(document, id: id, target: target)
        }
    }

    private func finishOpening(_ document: DocumentRow, id: UUID, target: OpenTarget?) {
        library.markOpened(document)
        openTarget = target
        openDocumentID = id
    }

    func closeDocument() {
        openDocumentID = nil
        openTarget = nil
        library.reload()
    }

    /// Leaves the editor and shows the search screen with `query` ("Where have I studied this?").
    func showSearch(for query: String) {
        searchQuery = query
        sidebarSelection = .search
        closeDocument()
    }

    #if DEBUG
    /// UI tests pass `-uiTestSeedPDF` to get a known PDF without driving the file picker.
    private func seedUITestFixturesIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestSeedPDF") else { return }
        let existing = Set(library.documents(for: .all, search: "", sort: .title).map(\.title))
        if !existing.contains(UITestFixtures.pdfTitle), let url = try? UITestFixtures.makeCardiologyPDF() {
            library.importSynchronously(url)
        }
        if !existing.contains(UITestFixtures.imagesTitle), let urls = try? UITestFixtures.makeWhiteboardImages() {
            library.importImagesSynchronously(urls, title: UITestFixtures.imagesTitle)
        }
    }
    #endif
}
