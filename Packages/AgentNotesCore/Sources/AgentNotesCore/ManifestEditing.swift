import Foundation

public enum ManifestEditError: Error, Equatable {
    case pageNotFound
    case cannotRemoveLastPage
}

/// Pure page operations. Callers are responsible for ink files and for touching `modifiedAt`.
extension DocumentManifest {
    public func index(of pageID: UUID) -> Int? {
        pages.firstIndex { $0.id == pageID }
    }

    @discardableResult
    public mutating func insertBlankPage(template: PageTemplate, size: PageSize, at index: Int) -> PageRecord {
        let page = PageRecord(size: size, template: template)
        pages.insert(page, at: min(max(index, 0), pages.count))
        return page
    }

    /// Inserts a copy (new identifier, same background) directly after the original.
    @discardableResult
    public mutating func duplicatePage(_ pageID: UUID) throws -> PageRecord {
        guard let index = index(of: pageID) else { throw ManifestEditError.pageNotFound }
        var copy = pages[index]
        copy.id = UUID()
        copy.isBookmarked = false
        pages.insert(copy, at: index + 1)
        return copy
    }

    @discardableResult
    public mutating func removePage(_ pageID: UUID) throws -> PageRecord {
        guard let index = index(of: pageID) else { throw ManifestEditError.pageNotFound }
        guard pages.count > 1 else { throw ManifestEditError.cannotRemoveLastPage }
        return pages.remove(at: index)
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`: `destination` is expressed
    /// in the indices of the array BEFORE the move.
    public mutating func movePages(fromOffsets offsets: [Int], toOffset destination: Int) {
        let sources = Set(offsets).filter { pages.indices.contains($0) }.sorted()
        guard !sources.isEmpty else { return }
        let moving = sources.map { pages[$0] }
        let clamped = min(max(destination, 0), pages.count)
        let insertionIndex = clamped - sources.filter { $0 < clamped }.count
        for index in sources.reversed() {
            pages.remove(at: index)
        }
        pages.insert(contentsOf: moving, at: insertionIndex)
    }

    public mutating func setTemplate(_ template: PageTemplate, forPage pageID: UUID) throws {
        guard let index = index(of: pageID) else { throw ManifestEditError.pageNotFound }
        pages[index].template = template
    }

    public mutating func toggleBookmark(forPage pageID: UUID) throws {
        guard let index = index(of: pageID) else { throw ManifestEditError.pageNotFound }
        pages[index].isBookmarked.toggle()
    }
}
