import AgentNotesCore
import Foundation

/// Earlier versions of a notebook: a copy of the package is kept each time the notebook is closed
/// after changes, up to `maximum` per notebook. Kept outside the Documents folder, so the library
/// never mistakes them for notebooks.
struct NotebookVersion: Identifiable, Hashable {
    let url: URL
    let savedAt: Date
    let pageCount: Int
    var id: URL { url }
}

extension DocumentStore {
    static let maximumVersions = 15

    private var historyRoot: URL {
        documentsDirectory.deletingLastPathComponent().appendingPathComponent("History", isDirectory: true)
    }

    private func historyDirectory(for id: UUID) -> URL {
        historyRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func versions(of id: UUID) -> [NotebookVersion] {
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(at: historyDirectory(for: id), includingPropertiesForKeys: nil)) ?? []
        return contents.compactMap { url -> NotebookVersion? in
            guard url.pathExtension == DocumentFormat.packageExtension,
                  let seconds = TimeInterval(url.deletingPathExtension().lastPathComponent) else { return nil }
            let pages = (try? DocumentPackageLayout(root: url).readManifest().pages.count) ?? 0
            return NotebookVersion(url: url, savedAt: Date(timeIntervalSince1970: seconds), pageCount: pages)
        }
        .sorted { $0.savedAt > $1.savedAt }
    }

    /// Keeps a copy of the notebook as it is now, unless the newest copy already matches it.
    func saveVersion(of id: UUID) throws {
        let fileManager = FileManager.default
        let manifest = try loadManifest(id: id)
        if let newest = versions(of: id).first,
           let saved = try? DocumentPackageLayout(root: newest.url).readManifest(),
           saved.modifiedAt == manifest.modifiedAt {
            return
        }
        let directory = historyDirectory(for: id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = String(Int(Date().timeIntervalSince1970)) + "." + DocumentFormat.packageExtension
        let destination = directory.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) { return }
        try fileManager.copyItem(at: packageURL(for: id), to: destination)
        for old in versions(of: id).dropFirst(Self.maximumVersions) {
            try? fileManager.removeItem(at: old.url)
        }
    }

    /// Replaces the notebook with an earlier version. The current state is kept as a version
    /// first, so restoring can itself be undone from the same list.
    func restore(_ version: NotebookVersion, of id: UUID) throws -> DocumentManifest {
        let fileManager = FileManager.default
        try saveVersion(of: id)
        let staging = documentsDirectory.appendingPathComponent(".staging-" + UUID().uuidString, isDirectory: true)
        try fileManager.copyItem(at: version.url, to: staging)
        let layout = DocumentPackageLayout(root: staging)
        var manifest = try layout.readManifest()
        manifest.id = id
        manifest.modifiedAt = Date()
        try layout.writeManifest(manifest)
        let current = packageURL(for: id)
        _ = try fileManager.replaceItemAt(current, withItemAt: staging)
        return manifest
    }

    func deleteHistory(of id: UUID) {
        try? FileManager.default.removeItem(at: historyDirectory(for: id))
    }
}
