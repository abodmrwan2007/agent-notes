import Foundation

/// File locations inside one native document package directory.
public struct DocumentPackageLayout: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var manifestURL: URL {
        root.appendingPathComponent(DocumentFormat.manifestFileName, isDirectory: false)
    }

    public var sourcesDirectory: URL {
        root.appendingPathComponent(DocumentFormat.sourcesDirectoryName, isDirectory: true)
    }

    public var inkDirectory: URL {
        root.appendingPathComponent(DocumentFormat.inkDirectoryName, isDirectory: true)
    }

    public func sourceURL(fileName: String) -> URL {
        sourcesDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// One ink payload per page, addressed by the stable page identifier.
    public func inkURL(pageID: UUID) -> URL {
        inkDirectory.appendingPathComponent(pageID.uuidString + ".ink", isDirectory: false)
    }

    public var objectsDirectory: URL {
        root.appendingPathComponent(DocumentFormat.objectsDirectoryName, isDirectory: true)
    }

    public var assetsDirectory: URL {
        root.appendingPathComponent(DocumentFormat.assetsDirectoryName, isDirectory: true)
    }

    public var audioDirectory: URL {
        root.appendingPathComponent(DocumentFormat.audioDirectoryName, isDirectory: true)
    }

    public func audioURL(fileName: String) -> URL {
        audioDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Typed text, sticky notes, shapes and image placements of one page.
    public func objectsURL(pageID: UUID) -> URL {
        objectsDirectory.appendingPathComponent(pageID.uuidString + ".json", isDirectory: false)
    }

    /// A binary asset (an inserted image) referenced by page objects.
    public func assetURL(fileName: String) -> URL {
        assetsDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Safe to call on an existing package: also creates directories added by newer format versions.
    public func createDirectories(using fileManager: FileManager = .default) throws {
        for directory in [root, sourcesDirectory, inkDirectory, objectsDirectory, assetsDirectory, audioDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Missing file means "no objects on this page".
    public func readObjects(pageID: UUID) throws -> PageObjectLayer {
        let url = objectsURL(pageID: pageID)
        guard FileManager.default.fileExists(atPath: url.path) else { return PageObjectLayer() }
        return try PageObjectCodec.decode(Data(contentsOf: url))
    }

    /// Atomic. An empty layer removes the file.
    public func writeObjects(_ layer: PageObjectLayer, pageID: UUID) throws {
        let url = objectsURL(pageID: pageID)
        if layer.isEmpty {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        try FileManager.default.createDirectory(at: objectsDirectory, withIntermediateDirectories: true)
        try PageObjectCodec.encode(layer).write(to: url, options: .atomic)
    }

    public func readManifest() throws -> DocumentManifest {
        try ManifestCodec.decode(Data(contentsOf: manifestURL))
    }

    /// Atomic: written to a temporary file and renamed, so a crash never leaves a half-written manifest.
    public func writeManifest(_ manifest: DocumentManifest) throws {
        try ManifestCodec.encode(manifest).write(to: manifestURL, options: .atomic)
    }
}

public enum ManifestCodecError: Error, Equatable {
    case malformed
    /// The package was written by a newer app version than this one understands.
    case newerFormat(found: Int, supported: Int)
    case missingMigration(from: Int)
}

/// Encodes/decodes `manifest.json` and upgrades older format versions step by step.
public enum ManifestCodec {
    public typealias Migration = (inout [String: Any]) throws -> Void

    /// Keyed by the version being upgraded FROM.
    static let migrations: [Int: Migration] = [
        // 1 -> 2: page objects and assets were added as new, optional files. The manifest itself
        // is unchanged, so there is nothing to rewrite; the version bump stops older app
        // versions from opening (and silently ignoring the objects of) newer documents.
        1: { _ in },
        // 2 -> 3: new optional page field `backgroundAsset` and the `planner` template value.
        // Nothing to rewrite; the bump keeps older versions from dropping them on save.
        2: { _ in },
        // 3 -> 4: optional `noteStyle` on sticky notes; old notes are plain.
        3: { _ in },
        // 4 -> 5: optional `recordings` list; older documents have none.
        4: { _ in }
    ]

    public static func encode(_ manifest: DocumentManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    public static func decode(_ data: Data) throws -> DocumentManifest {
        try decode(data, migrations: migrations, currentVersion: DocumentFormat.currentVersion)
    }

    static func decode(
        _ data: Data,
        migrations: [Int: Migration],
        currentVersion: Int
    ) throws -> DocumentManifest {
        guard
            var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let found = object["formatVersion"] as? Int
        else {
            throw ManifestCodecError.malformed
        }
        guard found <= currentVersion else {
            throw ManifestCodecError.newerFormat(found: found, supported: currentVersion)
        }

        var version = found
        while version < currentVersion {
            guard let step = migrations[version] else {
                throw ManifestCodecError.missingMigration(from: version)
            }
            try step(&object)
            version += 1
            object["formatVersion"] = version
        }

        let payload = found == currentVersion ? data : try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(DocumentManifest.self, from: payload)
        } catch {
            throw ManifestCodecError.malformed
        }
    }
}
