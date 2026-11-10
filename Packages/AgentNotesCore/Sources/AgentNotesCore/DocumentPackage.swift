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

    public func createDirectories(using fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: inkDirectory, withIntermediateDirectories: true)
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

    /// Keyed by the version being upgraded FROM. Version 1 is the first format, so this is empty.
    static let migrations: [Int: Migration] = [:]

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
