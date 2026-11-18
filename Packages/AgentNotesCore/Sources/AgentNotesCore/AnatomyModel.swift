import Foundation

/// One structure of a 3D anatomy model (for example the mitral valve). Geometry lives in a
/// separate binary file; this record says where. Built by tools/build_heart_model.py.
public struct AnatomyPart: Codable, Hashable, Identifiable, Sendable {
    public enum Group: String, Codable, CaseIterable, Sendable {
        case chambers
        case valves
        case vessels
        case coronary
    }

    public var id: String
    public var en: String
    public var ar: String
    public var group: Group
    /// Hex colour, for example "D25A50".
    public var color: String
    /// Byte offset of the vertices: `vertexCount` × 6 float32 (position, normal).
    public var vertexOffset: Int
    public var vertexCount: Int
    /// Byte offset of the triangle indices: `indexCount` uint32, local to this part.
    public var indexOffset: Int
    public var indexCount: Int
    /// The BodyParts3D structures merged into this part.
    public var sources: [String]

    public init(id: String, en: String, ar: String, group: Group, color: String,
                vertexOffset: Int, vertexCount: Int, indexOffset: Int, indexCount: Int, sources: [String]) {
        self.id = id
        self.en = en
        self.ar = ar
        self.group = group
        self.color = color
        self.vertexOffset = vertexOffset
        self.vertexCount = vertexCount
        self.indexOffset = indexOffset
        self.indexCount = indexCount
        self.sources = sources
    }

    public static let bytesPerVertex = 24
    public static let bytesPerIndex = 4

    public func name(arabic: Bool) -> String { arabic ? ar : en }
}

public struct AnatomyModelManifest: Codable, Sendable {
    public var source: String
    public var parts: [AnatomyPart]

    public init(source: String, parts: [AnatomyPart]) {
        self.source = source
        self.parts = parts
    }

    public static func decode(_ data: Data) throws -> AnatomyModelManifest {
        try JSONDecoder().decode(AnatomyModelManifest.self, from: data)
    }

    /// Problems that would make the model draw wrongly or crash: ranges outside the binary file,
    /// triangle lists that are not whole triangles, indices pointing past a part's vertices.
    public func problems(binary: Data) -> [String] {
        var problems: [String] = []
        var ids = Set<String>()
        for part in parts {
            if !ids.insert(part.id).inserted { problems.append("duplicate id \(part.id)") }
            if part.en.isEmpty || part.ar.isEmpty { problems.append("\(part.id): missing name") }
            let vertexEnd = part.vertexOffset + part.vertexCount * AnatomyPart.bytesPerVertex
            let indexEnd = part.indexOffset + part.indexCount * AnatomyPart.bytesPerIndex
            guard part.vertexOffset >= 0, part.indexOffset >= 0,
                  vertexEnd <= binary.count, indexEnd <= binary.count else {
                problems.append("\(part.id): range outside the binary file")
                continue
            }
            if part.indexCount == 0 || part.indexCount % 3 != 0 {
                problems.append("\(part.id): \(part.indexCount) indices is not whole triangles")
            }
            let largest = binary.withUnsafeBytes { buffer -> UInt32 in
                var maximum: UInt32 = 0
                for i in 0..<part.indexCount {
                    let value = buffer.loadUnaligned(fromByteOffset: part.indexOffset + i * 4, as: UInt32.self)
                    maximum = Swift.max(maximum, UInt32(littleEndian: value))
                }
                return maximum
            }
            if part.indexCount > 0, Int(largest) >= part.vertexCount {
                problems.append("\(part.id): index \(largest) past \(part.vertexCount) vertices")
            }
        }
        return problems
    }
}
