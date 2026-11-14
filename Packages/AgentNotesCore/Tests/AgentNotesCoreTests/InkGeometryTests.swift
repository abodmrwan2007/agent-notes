import XCTest
@testable import AgentNotesCore

/// Hand-drawn strokes are simulated with a fixed, deterministic wobble so results are repeatable.
final class InkGeometryTests: XCTestCase {
    private func wobble(_ index: Int, amplitude: Double) -> Double {
        sin(Double(index) * 1.7) * amplitude * 0.6 + sin(Double(index) * 0.45) * amplitude * 0.4
    }

    private func handLine(from a: PagePoint, to b: PagePoint, count: Int = 40, amplitude: Double = 1.5) -> [PagePoint] {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let off = (index == 0 || index == count - 1) ? 0 : wobble(index, amplitude: amplitude)
            return PagePoint(x: a.x + dx * t - dy / length * off, y: a.y + dy * t + dx / length * off)
        }
    }

    private func handEllipse(cx: Double, cy: Double, rx: Double, ry: Double, count: Int = 60,
                             amplitude: Double = 2, overshoot: Double = 0.05) -> [PagePoint] {
        (0..<count).map { index in
            let angle = Double(index) / Double(count - 1) * (2 * .pi + overshoot) - .pi / 2
            let off = wobble(index, amplitude: amplitude)
            return PagePoint(x: cx + (rx + off) * cos(angle), y: cy + (ry + off) * sin(angle))
        }
    }

    private func handRectangle(x: Double, y: Double, w: Double, h: Double) -> [PagePoint] {
        let corners = [PagePoint(x: x, y: y), PagePoint(x: x + w, y: y), PagePoint(x: x + w, y: y + h),
                       PagePoint(x: x, y: y + h), PagePoint(x: x + 2, y: y + 3)]
        var points: [PagePoint] = []
        for (a, b) in zip(corners, corners.dropFirst()) {
            points += handLine(from: a, to: b, count: 15, amplitude: 1.2).dropLast()
        }
        points.append(corners.last!)
        return points
    }

    // MARK: Recognition

    func testWobblyLineBecomesAStraightLine() {
        let points = handLine(from: PagePoint(x: 50, y: 80), to: PagePoint(x: 350, y: 140))
        guard case .line(let from, let to)? = InkGeometry.recognizeShape(points) else {
            return XCTFail("not recognized as a line")
        }
        XCTAssertEqual(from, PagePoint(x: 50, y: 80))
        XCTAssertEqual(to, PagePoint(x: 350, y: 140))
    }

    func testRoughCircleBecomesATrueCircle() {
        let points = handEllipse(cx: 200, cy: 200, rx: 80, ry: 76)
        guard case .ellipse(let center, let rx, let ry)? = InkGeometry.recognizeShape(points) else {
            return XCTFail("not recognized as a circle")
        }
        XCTAssertEqual(rx, ry)
        XCTAssertEqual(center.x, 200, accuracy: 5)
        XCTAssertEqual(center.y, 200, accuracy: 5)
        XCTAssertEqual(rx, 78, accuracy: 5)
    }

    func testFlatEllipseStaysAnEllipse() {
        let points = handEllipse(cx: 300, cy: 200, rx: 150, ry: 60)
        guard case .ellipse(_, let rx, let ry)? = InkGeometry.recognizeShape(points) else {
            return XCTFail("not recognized as an ellipse")
        }
        XCTAssertGreaterThan(rx / ry, 2)
    }

    func testRoughRectangleBecomesARectangle() {
        let points = handRectangle(x: 100, y: 100, w: 220, h: 140)
        guard case .rectangle(let rect)? = InkGeometry.recognizeShape(points) else {
            return XCTFail("not recognized as a rectangle")
        }
        XCTAssertEqual(rect.width, 220, accuracy: 6)
        XCTAssertEqual(rect.height, 140, accuracy: 6)
    }

    func testHandwritingIsNotTurnedIntoAShape() {
        // A cursive-like scribble: loops travelling to the right.
        let scribble = (0..<120).map { index -> PagePoint in
            let t = Double(index) / 10
            return PagePoint(x: 50 + t * 25 + 12 * cos(t * 2.4), y: 100 + 14 * sin(t * 2.4))
        }
        XCTAssertNil(InkGeometry.recognizeShape(scribble))
        // A "U" shape: open, not a line.
        let u = (0...40).map { index -> PagePoint in
            let angle = Double(index) / 40 * .pi
            return PagePoint(x: 200 - 60 * cos(angle), y: 100 + 80 * sin(angle))
        }
        XCTAssertNil(InkGeometry.recognizeShape(u))
        // A dot.
        XCTAssertNil(InkGeometry.recognizeShape([PagePoint(x: 1, y: 1), PagePoint(x: 2, y: 2)]))
        // Two loops around the same circle: not a single clean shape.
        XCTAssertNil(InkGeometry.recognizeShape(handEllipse(cx: 200, cy: 200, rx: 80, ry: 80, count: 120, overshoot: 2 * .pi)))
    }

    func testOutlines() {
        let line = RecognizedShape.line(from: PagePoint(x: 0, y: 0), to: PagePoint(x: 10, y: 20)).outline(pointsPerSide: 4)
        XCTAssertEqual(line.first, PagePoint(x: 0, y: 0))
        XCTAssertEqual(line.last, PagePoint(x: 10, y: 20))

        let circle = RecognizedShape.ellipse(center: PagePoint(x: 50, y: 50), radiusX: 10, radiusY: 10).outline()
        for point in circle {
            XCTAssertEqual(InkGeometry.distance(point, PagePoint(x: 50, y: 50)), 10, accuracy: 1e-9)
        }
        XCTAssertEqual(InkGeometry.distance(circle.first!, circle.last!), 0, accuracy: 1e-9)

        let rect = RecognizedShape.rectangle(PageRect(x: 10, y: 20, width: 30, height: 40)).outline()
        for point in rect {
            let onEdge = abs(point.x - 10) < 1e-9 || abs(point.x - 40) < 1e-9
                || abs(point.y - 20) < 1e-9 || abs(point.y - 60) < 1e-9
            XCTAssertTrue(onEdge)
        }
    }

    // MARK: Hold detection

    func testHoldAtTheEndIsDetectedAndRemoved() {
        var samples = (0..<20).map { InkSample(x: Double($0) * 10, y: 0, time: Double($0) * 0.01) }
        XCTAssertNil(InkGeometry.strokeEndingInHold(samples), "a quick stroke is not a hold")

        // Then the pen rests at the end for 0.6 s, drifting by a point or two.
        for step in 1...30 {
            samples.append(InkSample(x: 190 + Double(step % 2), y: Double(step % 3) * 0.5, time: 0.19 + Double(step) * 0.02))
        }
        let trimmed = InkGeometry.strokeEndingInHold(samples)
        XCTAssertNotNil(trimmed)
        XCTAssertEqual(trimmed?.count, 20)
    }

    func testAShortPauseIsNotAHold() {
        var samples = (0..<20).map { InkSample(x: Double($0) * 10, y: 0, time: Double($0) * 0.01) }
        samples.append(InkSample(x: 190, y: 0, time: 0.4))
        XCTAssertNil(InkGeometry.strokeEndingInHold(samples))
    }

    // MARK: Smoothing

    func testSmoothingReducesJitterButKeepsEndsAndCount() {
        let jittery = (0..<50).map { index in
            PagePoint(x: Double(index) * 4, y: index.isMultiple(of: 2) ? 2 : -2)
        }
        let smoothed = InkGeometry.smooth(jittery, strength: 0.5)
        XCTAssertEqual(smoothed.count, jittery.count)
        XCTAssertEqual(smoothed.first, jittery.first)
        XCTAssertEqual(smoothed.last, jittery.last)
        let before = jittery.dropFirst(5).dropLast(5).map { abs($0.y) }.max() ?? 0
        let after = smoothed.dropFirst(5).dropLast(5).map { abs($0.y) }.max() ?? 0
        XCTAssertLessThan(after, before * 0.5)
    }

    func testSmoothingStrengthZeroIsIdentityAndStraightLinesStayStraight() {
        let line = (0..<20).map { PagePoint(x: Double($0) * 3, y: Double($0) * 2) }
        XCTAssertEqual(InkGeometry.smooth(line, strength: 0), line)
        for (a, b) in zip(InkGeometry.smooth(line, strength: 1), line) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
        }
    }
}
