import AgentNotesCore
import XCTest

final class AnatomyModelTests: XCTestCase {
    private var atlasDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // AgentNotesCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // AgentNotesCore
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repository root
            .appendingPathComponent("App/Resources/Atlas.xcassets")
    }

    func testShippedHeartModelIsConsistent() throws {
        let manifestData = try Data(contentsOf: atlasDirectory.appendingPathComponent("heart-parts.dataset/parts.json"))
        let binary = try Data(contentsOf: atlasDirectory.appendingPathComponent("heart-model.dataset/heart.bin"))
        let manifest = try AnatomyModelManifest.decode(manifestData)
        XCTAssertGreaterThanOrEqual(manifest.parts.count, 12)
        XCTAssertTrue(manifest.source.contains("BodyParts3D"), "attribution must travel with the model")
        XCTAssertEqual(manifest.problems(binary: binary), [])
        for group in AnatomyPart.Group.allCases {
            XCTAssertTrue(manifest.parts.contains { $0.group == group }, "no part in \(group)")
        }
        for required in ["rightAtrium", "leftAtrium", "rightVentricle", "leftVentricle",
                         "mitralValve", "tricuspidValve", "aorticValve", "pulmonaryValve", "aorta"] {
            XCTAssertTrue(manifest.parts.contains { $0.id == required }, "missing \(required)")
        }
    }

    func testProblemsAreReported() throws {
        // One triangle: 3 vertices (72 bytes) then 3 indices (12 bytes), the last one out of range.
        var binary = Data(count: 72)
        for index: UInt32 in [0, 1, 5] {
            withUnsafeBytes(of: index.littleEndian) { binary.append(contentsOf: $0) }
        }
        let part = AnatomyPart(id: "x", en: "X", ar: "س", group: .chambers, color: "FFFFFF",
                               vertexOffset: 0, vertexCount: 3, indexOffset: 72, indexCount: 3, sources: [])
        let manifest = AnatomyModelManifest(source: "test", parts: [part, part])
        let problems = manifest.problems(binary: binary)
        XCTAssertTrue(problems.contains("duplicate id x"))
        XCTAssertTrue(problems.contains { $0.contains("index 5 past 3 vertices") })

        var tooShort = part
        tooShort.indexOffset = 200
        XCTAssertEqual(AnatomyModelManifest(source: "t", parts: [tooShort]).problems(binary: binary),
                       ["x: range outside the binary file"])
    }
}
