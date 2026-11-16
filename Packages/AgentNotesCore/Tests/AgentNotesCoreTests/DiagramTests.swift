import Foundation
import XCTest
@testable import AgentNotesCore

final class DiagramTests: XCTestCase {
    func testLabelsKeepOrderAndSpacing() {
        let ys = DiagramLayout.labelYs(anchorYs: [100, 90, 95, 300], height: 400, spacing: 30)
        // Sorted anchors 90, 95, 100 become 90, 120, 150; the order of the input is kept.
        XCTAssertEqual(ys, [150, 90, 120, 300])
    }

    func testLabelsStayInsideTheArtwork() {
        let ys = DiagramLayout.labelYs(anchorYs: [0, 390, 395, 399], height: 400, spacing: 30)
        XCTAssertEqual(ys[0], 15)
        XCTAssertEqual(ys[3], 385)
        XCTAssertEqual(ys[2], 355)
        XCTAssertEqual(ys[1], 325)
    }

    /// Checks the label data shipped with the app.
    func testShippedDiagramData() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Diagrams.xcassets/diagram-labels.dataset/labels.json")
        let specs = try DiagramSpec.decode(Data(contentsOf: file))
        XCTAssertGreaterThanOrEqual(specs.count, 6)
        XCTAssertEqual(Set(specs.map(\.id)).count, specs.count)
        for spec in specs {
            let art = file.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("\(spec.assetName).imageset/\(spec.assetName).svg")
            XCTAssertTrue(FileManager.default.fileExists(atPath: art.path), spec.id)
            XCTAssertFalse(spec.en.isEmpty || spec.ar.isEmpty, spec.id)
            for label in spec.labels {
                XCTAssertFalse(label.en.isEmpty || label.ar.isEmpty, "\(spec.id) \(label.en)")
                XCTAssertTrue((0...spec.width).contains(label.anchorX) && (0...spec.height).contains(label.anchorY),
                              "\(spec.id) \(label.en) anchor outside the artwork")
            }
            for side in [DiagramSpec.Side.left, .right] {
                let count = spec.labels.filter { $0.side == side }.count
                XCTAssertLessThanOrEqual(Double(count) * DiagramLayout.spacing, spec.height, "\(spec.id) \(side) column too full")
            }
            let ys = DiagramLayout.labelYs(for: spec)
            XCTAssertTrue(ys.allSatisfy { $0 >= 0 && $0 <= spec.height }, spec.id)
        }
    }
}
