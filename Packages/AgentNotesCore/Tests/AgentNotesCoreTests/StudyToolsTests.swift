import XCTest
@testable import AgentNotesCore

final class MathExpressionTests: XCTestCase {
    private func value(_ source: String, _ mode: AngleMode = .radians, _ variables: [String: Double] = [:]) throws -> Double {
        try MathExpression(source).evaluate(variables: variables, angleMode: mode)
    }

    private func assertError(_ source: String, _ expected: MathError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try value(source), file: file, line: line) { error in
            XCTAssertEqual(error as? MathError, expected, file: file, line: line)
        }
    }

    func testPrecedenceAndAssociativity() throws {
        XCTAssertEqual(try value("2+3*4"), 14)
        XCTAssertEqual(try value("(2+3)*4"), 20)
        XCTAssertEqual(try value("10-4-3"), 3)
        XCTAssertEqual(try value("100/10/2"), 5)
        XCTAssertEqual(try value("2^3^2"), 512)
        XCTAssertEqual(try value("-2^2"), -4)
        XCTAssertEqual(try value("(-2)^2"), 4)
        XCTAssertEqual(try value("2^-1"), 0.5)
        XCTAssertEqual(try value("2*-3"), -6)
        XCTAssertEqual(try value("--3"), 3)
    }

    func testNumbersAndNotation() throws {
        XCTAssertEqual(try value("1.5e3"), 1500)
        XCTAssertEqual(try value("2E-2"), 0.02)
        XCTAssertEqual(try value(".5+.5"), 1)
        XCTAssertEqual(try value("٣+٤"), 7)
        XCTAssertEqual(try value("6×7"), 42)
        XCTAssertEqual(try value("8÷2"), 4)
        XCTAssertEqual(try value("7−2"), 5)
        XCTAssertEqual(try value("50%"), 0.5)
        XCTAssertEqual(try value("200*10%"), 20)
        XCTAssertEqual(try value("5!"), 120)
        XCTAssertEqual(try value("0!"), 1)
    }

    func testImplicitMultiplication() throws {
        XCTAssertEqual(try value("2(3+4)"), 14)
        XCTAssertEqual(try value("(1+1)(2+3)"), 10)
        XCTAssertEqual(try value("2pi"), 2 * Double.pi, accuracy: 1e-12)
        XCTAssertEqual(try value("3x", .radians, ["x": 4]), 12)
        XCTAssertEqual(try value("2x^2", .radians, ["x": 3]), 18)
        XCTAssertEqual(try value("2e"), 2 * exp(1.0), accuracy: 1e-12)
        XCTAssertEqual(try value("2 -3"), -1)
    }

    func testFunctionsAndConstants() throws {
        XCTAssertEqual(try value("sqrt(16)"), 4)
        XCTAssertEqual(try value("√9"), 3)
        XCTAssertEqual(try value("abs(-3.5)"), 3.5)
        XCTAssertEqual(try value("ln(e)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try value("log(1000)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try value("log2(8)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try value("max(1, 5, 3)"), 5)
        XCTAssertEqual(try value("min(4; 2)"), 2)
        XCTAssertEqual(try value("mod(-7, 3)"), 2)
        XCTAssertEqual(try value("root(27, 3)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try value("root(-8, 3)"), -2, accuracy: 1e-12)
        XCTAssertEqual(try value("cbrt(-27)"), -3, accuracy: 1e-12)
        XCTAssertEqual(try value("SIN(0)"), 0)
        XCTAssertEqual(try value("round(2.5)"), 3)
        XCTAssertEqual(try value("floor(-1.5)"), -2)
    }

    func testAngleModes() throws {
        XCTAssertEqual(try value("sin(pi/2)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try value("sin(30)", .degrees), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try value("sin(180)", .degrees), 0)
        XCTAssertEqual(try value("cos(90)", .degrees), 0)
        XCTAssertEqual(try value("cos(360)", .degrees), 1)
        XCTAssertEqual(try value("tan(45)", .degrees), 1, accuracy: 1e-12)
        XCTAssertEqual(try value("asin(1)", .degrees), 90, accuracy: 1e-12)
        XCTAssertEqual(try value("atan(1)", .degrees), 45, accuracy: 1e-12)
        XCTAssertThrowsError(try value("tan(90)", .degrees)) { error in
            XCTAssertEqual(error as? MathError, .outsideDomain(function: "tan"))
        }
    }

    func testErrors() {
        assertError("", .empty)
        assertError("   ", .empty)
        assertError("1/0", .divisionByZero)
        assertError("0^-1", .divisionByZero)
        assertError("sqrt(-1)", .outsideDomain(function: "sqrt"))
        assertError("ln(0)", .outsideDomain(function: "ln"))
        assertError("acos(2)", .outsideDomain(function: "acos"))
        assertError("(-8)^0.5", .outsideDomain(function: "^"))
        assertError("3.5!", .outsideDomain(function: "!"))
        assertError("(1+2", .missingClosingParenthesis)
        assertError("1+", .unexpectedEnd)
        assertError("1+*2", .unexpectedToken("*"))
        assertError("2)", .unexpectedToken(")"))
        assertError("2 $ 3", .unexpectedCharacter("$"))
        assertError("y+1", .unknownName("y"))
        assertError("mod(1)", .wrongArgumentCount(function: "mod"))
        assertError("10^400", .resultTooLarge)
    }

    func testVariablesAreReported() throws {
        XCTAssertEqual(try MathExpression("a*x^2 + sin(pi*x) + e").variables, ["a", "x"])
    }

    func testFormatting() {
        XCTAssertEqual(MathFormatter.format(0.1 + 0.2), "0.3")
        XCTAssertEqual(MathFormatter.format(14), "14")
        XCTAssertEqual(MathFormatter.format(-0.0), "0")
        XCTAssertEqual(MathFormatter.format(1.0 / 3.0), "0.333333333333")
        XCTAssertEqual(MathFormatter.format(1.5e20), "1.5×10^20")
        XCTAssertEqual(MathFormatter.format(2.5e-7), "2.5×10^-7")
    }
}

final class GraphSamplerTests: XCTestCase {
    func testBranchesReachTheEdgeEvenWhenThePoleIsSampledExactly() throws {
        // 401 samples on -10...10 put a sample exactly on x = 0, where 1/x is undefined.
        let yRange = -30.0...30.0
        let segments = GraphSampler.segments(
            for: try MathExpression("1/x"), xRange: -10...10, yRange: yRange, samples: 401)
        XCTAssertEqual(segments.count, 2)
        XCTAssertLessThan(segments[0].map(\.y).min() ?? 0, yRange.lowerBound)
        XCTAssertGreaterThan(segments[1].map(\.y).max() ?? 0, yRange.upperBound)
        XCTAssertTrue(segments[0].allSatisfy { $0.x < 0 })
        XCTAssertTrue(segments[1].allSatisfy { $0.x > 0 })
        // Points stay ordered left to right after the extra points are added.
        for segment in segments {
            XCTAssertEqual(segment.map(\.x), segment.map(\.x).sorted())
        }
    }

    func testCurveReachesTheEdgeOfItsDomain() throws {
        let segments = GraphSampler.segments(
            for: try MathExpression("sqrt(x)"), xRange: -4...4, yRange: -1...3, samples: 200)
        XCTAssertEqual(segments.count, 1)
        XCTAssertLessThan(segments[0].first?.x ?? 1, 0.001)
        XCTAssertGreaterThanOrEqual(segments[0].first?.x ?? -1, 0)
    }

    func testContinuousFunctionIsOneSegment() throws {
        let segments = GraphSampler.segments(
            for: try MathExpression("sin(x)"), xRange: -10...10, yRange: -2...2, samples: 400)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].count, 400)
    }

    func testPoleSplitsTheCurveAndNeverCrossesIt() throws {
        // Odd counts sample x = 0 exactly; even counts straddle it. Window sizes mimic real screens.
        let cases: [(samples: Int, x: ClosedRange<Double>, y: ClosedRange<Double>)] = [
            (501, -5...5, -5...5),
            (500, -5...5, -5...5),
            (414, -10...10, -32...32),
            (1000, -10...10, -7...7),
            (37, -1...1, -1...1)
        ]
        for testCase in cases {
            let segments = GraphSampler.segments(
                for: try MathExpression("1/x"), xRange: testCase.x, yRange: testCase.y, samples: testCase.samples)
            XCTAssertEqual(segments.count, 2, "\(testCase.samples) samples")
            for segment in segments {
                let signs = Set(segment.map { $0.x > 0 })
                XCTAssertEqual(signs.count, 1, "a segment crosses the pole at x = 0 (\(testCase.samples) samples)")
            }
        }
    }

    func testBranchesReachTheEdgeOfTheWindow() throws {
        // Each branch of 1/x must run off the top or bottom of the visible window, not stop short.
        let yRange = -32.0...32.0
        let segments = GraphSampler.segments(
            for: try MathExpression("1/x"), xRange: -10...10, yRange: yRange, samples: 414)
        XCTAssertEqual(segments.count, 2)
        XCTAssertLessThan(segments[0].map(\.y).min() ?? 0, yRange.lowerBound)
        XCTAssertGreaterThan(segments[1].map(\.y).max() ?? 0, yRange.upperBound)
    }

    func testSteepButContinuousCurveStaysInOnePiece() throws {
        let segments = GraphSampler.segments(
            for: try MathExpression("x^3"), xRange: -10...10, yRange: -5...5, samples: 200)
        XCTAssertEqual(segments.count, 1)
    }

    func testTangentHasNoVerticalConnectors() throws {
        let segments = GraphSampler.segments(
            for: try MathExpression("tan(x)"), xRange: -5...5, yRange: -5...5, samples: 1000)
        XCTAssertGreaterThanOrEqual(segments.count, 3)
        for segment in segments {
            for (a, b) in zip(segment, segment.dropFirst()) {
                XCTAssertLessThan(abs(b.y - a.y), 20, "false vertical line near an asymptote")
            }
        }
    }

    func testUndefinedRegionIsSkipped() throws {
        let segments = GraphSampler.segments(
            for: try MathExpression("sqrt(x)"), xRange: -4...4, yRange: -1...3, samples: 201)
        XCTAssertEqual(segments.count, 1)
        XCTAssertTrue(segments[0].allSatisfy { $0.x >= 0 })
    }
}

final class PeriodicTableTests: XCTestCase {
    func testStructure() {
        let elements = PeriodicTable.elements
        XCTAssertEqual(elements.count, 118)
        XCTAssertEqual(elements.map(\.number), Array(1...118))
        XCTAssertEqual(Set(elements.map(\.symbol)).count, 118)
        XCTAssertEqual(Set(elements.map(\.name)).count, 118)
        XCTAssertEqual(Set(elements.map(\.arabicName)).count, 118)
        for element in elements {
            XCTAssertTrue(element.atomicWeight != nil || element.massNumber != nil, element.symbol)
            XCTAssertTrue((1...2).contains(element.symbol.count), element.symbol)
            XCTAssertEqual(String(element.symbol.prefix(1)), element.symbol.prefix(1).uppercased())
        }
    }

    func testEveryCellOfTheLayoutIsUsedAtMostOnce() {
        var seen = Set<String>()
        for element in PeriodicTable.elements {
            let position = element.gridPosition
            XCTAssertTrue((1...9).contains(position.row), element.symbol)
            XCTAssertTrue((1...18).contains(position.column), element.symbol)
            XCTAssertTrue(seen.insert("\(position.row)-\(position.column)").inserted, element.symbol)
        }
    }

    func testSpotValues() {
        let iron = PeriodicTable.element(number: 26)
        XCTAssertEqual(iron?.symbol, "Fe")
        XCTAssertEqual(iron?.group, 8)
        XCTAssertEqual(iron?.period, 4)
        XCTAssertEqual(iron?.category, .transitionMetal)

        XCTAssertEqual(PeriodicTable.element(number: 1)?.gridPosition.column, 1)
        XCTAssertEqual(PeriodicTable.element(number: 2)?.gridPosition.column, 18)
        XCTAssertEqual(PeriodicTable.element(number: 6)?.group, 14)
        XCTAssertEqual(PeriodicTable.element(number: 17)?.category, .halogen)
        XCTAssertEqual(PeriodicTable.element(number: 79)?.symbol, "Au")
        XCTAssertEqual(PeriodicTable.element(number: 79)?.group, 11)
        XCTAssertEqual(PeriodicTable.element(number: 86)?.group, 18)
        XCTAssertNil(PeriodicTable.element(number: 64)?.group)
        XCTAssertEqual(PeriodicTable.element(number: 92)?.category, .actinide)
        XCTAssertEqual(PeriodicTable.element(number: 118)?.group, 18)
        XCTAssertEqual(PeriodicTable.element(number: 43)?.massText, "[97]")
        XCTAssertNil(PeriodicTable.element(number: 0))
        XCTAssertNil(PeriodicTable.element(number: 119))
    }

    func testSearch() {
        XCTAssertEqual(PeriodicTable.search("au").map(\.symbol), ["Au"])
        XCTAssertEqual(PeriodicTable.search("Iron").map(\.symbol), ["Fe"])
        XCTAssertEqual(PeriodicTable.search("ذهب").map(\.symbol), ["Au"])
        XCTAssertEqual(PeriodicTable.search("79").map(\.symbol), ["Au"])
        XCTAssertTrue(PeriodicTable.search("ium").count > 50)
        XCTAssertEqual(PeriodicTable.search("  ").count, 118)
    }
}

final class FocusTimerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testCountsDownFromAbsoluteDates() {
        var timer = FocusTimer(workMinutes: 25, restMinutes: 5)
        XCTAssertTrue(timer.isIdle)
        XCTAssertEqual(timer.remaining(at: start), 1500)
        timer.start(at: start)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(600)), 900)
    }

    func testSurvivesLongBackgrounding() {
        var timer = FocusTimer(workMinutes: 25, restMinutes: 5)
        timer.start(at: start)
        // Come back 65 minutes later: work(25) rest(5) work(25) rest(5) -> 5 minutes into work #3.
        let crossed = timer.advance(to: start.addingTimeInterval(65 * 60))
        XCTAssertEqual(crossed, 4)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.completedWorkSessions, 2)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(65 * 60)), 20 * 60)
    }

    func testPauseAndResumeKeepRemainingTime() {
        var timer = FocusTimer(workMinutes: 10, restMinutes: 2)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(240))
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(9999)), 360)
        timer.start(at: start.addingTimeInterval(5000))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(5060)), 300)
    }

    func testResetAndCodableRoundTrip() throws {
        var timer = FocusTimer(workMinutes: 1, restMinutes: 1)
        timer.start(at: start)
        timer.advance(to: start.addingTimeInterval(61))
        XCTAssertEqual(timer.phase, .rest)
        let decoded = try JSONDecoder().decode(FocusTimer.self, from: JSONEncoder().encode(timer))
        XCTAssertEqual(decoded, timer)
        timer.reset()
        XCTAssertTrue(timer.isIdle)
        XCTAssertEqual(timer.completedWorkSessions, 0)
    }
}
