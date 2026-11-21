import AgentNotesCore
import XCTest

final class HandwrittenMathTests: XCTestCase {
    func testOperatorsAndConfusions() {
        XCTAssertEqual(HandwrittenMath.normalize("12 x 3 ="), "12*3")
        XCTAssertEqual(HandwrittenMath.normalize("8 ÷ 2 − 1"), "8/2-1")
        XCTAssertEqual(HandwrittenMath.normalize("1O0 + l5"), "100+15")
        XCTAssertEqual(HandwrittenMath.normalize("(2+3)x4 = 20"), "(2+3)*4")
        XCTAssertEqual(HandwrittenMath.normalize("3²"), "3^2")
        XCTAssertEqual(HandwrittenMath.normalize("sin(30)"), "sin(30)")
    }

    func testNormalizedSumsEvaluate() throws {
        XCTAssertEqual(try MathExpression(HandwrittenMath.normalize("12 x 3")).evaluate(), 36)
        XCTAssertEqual(try MathExpression(HandwrittenMath.normalize("1O ÷ 4")).evaluate(), 2.5)
    }
}
