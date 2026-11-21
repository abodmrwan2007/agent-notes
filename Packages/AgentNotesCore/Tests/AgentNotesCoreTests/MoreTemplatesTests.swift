import AgentNotesCore
import XCTest

final class MoreTemplatesTests: XCTestCase {
    private let a4 = PageSize.a4

    private func insidePage(_ layout: TemplateLayout) -> Bool {
        let points = layout.lines.flatMap { [$0.start, $0.end] } + layout.dots
        return points.allSatisfy { $0.x >= 0 && $0.x <= a4.width && $0.y >= 0 && $0.y <= a4.height }
    }

    func testEveryTemplateStaysOnThePage() {
        for template in PageTemplate.allCases {
            let layout = TemplateGeometry.layout(for: template, size: a4)
            XCTAssertTrue(insidePage(layout), "\(template) draws outside the page")
            if template != .blank {
                XCTAssertFalse(layout.lines.isEmpty && layout.dots.isEmpty, "\(template) draws nothing")
            }
        }
    }

    func testMusicStavesHaveFiveLines() {
        let lines = TemplateGeometry.layout(for: .music, size: a4).lines
        XCTAssertEqual(lines.count % 5, 0)
        XCTAssertGreaterThanOrEqual(lines.count / 5, 8, "an A4 page should hold at least 8 staves")
        XCTAssertEqual(lines[1].start.y - lines[0].start.y, TemplateGeometry.musicLineGap)
    }

    func testIsometricRowsAreShifted() {
        let dots = TemplateGeometry.layout(for: .isometric, size: a4).dots
        let rows = Dictionary(grouping: dots, by: { ($0.y * 1000).rounded() })
        let ys = rows.keys.sorted()
        XCTAssertGreaterThan(ys.count, 10)
        let first = rows[ys[0]]!.map(\.x).min()!
        let second = rows[ys[1]]!.map(\.x).min()!
        XCTAssertEqual(abs(first - second), TemplateGeometry.isometricSpacing / 2, accuracy: 0.001)
    }

    func testChecklistHasABoxPerLine() {
        let layout = TemplateGeometry.layout(for: .checklist, size: a4)
        let boxEdges = layout.lines.filter(\.isEmphasized).count
        let ruled = layout.lines.count - boxEdges
        XCTAssertEqual(boxEdges % 4, 0)
        XCTAssertEqual(boxEdges / 4, ruled - 1, "one box under every line except the first")
    }

    func testTemplatesRoundTripThroughJSON() throws {
        for template in PageTemplate.allCases {
            let data = try JSONEncoder().encode(template)
            XCTAssertEqual(try JSONDecoder().decode(PageTemplate.self, from: data), template)
        }
    }
}
