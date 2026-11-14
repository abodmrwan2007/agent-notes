import XCTest
@testable import AgentNotesCore

final class TextMatcherTests: XCTestCase {
    func testFindsEveryOccurrenceAndMapsBackToTheOriginal() {
        let text = "Mitral VALVE prolapse. The mitral valve has two cusps."
        let ranges = TextMatcher.ranges(of: "mitral valve", in: text)
        XCTAssertEqual(ranges.map { String(text[$0]) }, ["Mitral VALVE", "mitral valve"])
        XCTAssertEqual(TextMatcher.ranges(of: "mitral valve", in: text, limit: 1).count, 1)
    }

    func testArabicMatchKeepsTheOriginalDiacritics() {
        let text = "يفصل الصِّمَامُ التَّاجِي بين الأذين والبطين"
        let ranges = TextMatcher.ranges(of: "الصمام التاجي", in: text)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges.first.map { String(text[$0]) }, "الصِّمَامُ التَّاجِي")

        // Alef variants: a query without hamza finds the word written with it.
        XCTAssertEqual(TextMatcher.ranges(of: "الاذين", in: text).first.map { String(text[$0]) }, "الأذين")
    }

    func testMatchesAcrossLineBreaksOfAPDFTextLayer() {
        let text = "the left\natrium and the\n\nleft ventricle"
        let ranges = TextMatcher.ranges(of: "left atrium", in: text)
        XCTAssertEqual(ranges.first.map { String(text[$0]) }, "left\natrium")
    }

    func testMixedScriptLineAndDigits() {
        let text = "Lecture ٣: Mitral valve = الصمام التاجي (MV)"
        XCTAssertEqual(TextMatcher.ranges(of: "lecture 3", in: text).count, 1)
        XCTAssertEqual(TextMatcher.ranges(of: "التاجي (mv", in: text).count, 1)
    }

    func testNoFalsePositives() {
        XCTAssertTrue(TextMatcher.ranges(of: "aorta", in: "Mitral valve").isEmpty)
        XCTAssertTrue(TextMatcher.ranges(of: "  ", in: "anything").isEmpty)
        XCTAssertTrue(TextMatcher.ranges(of: "long query", in: "short").isEmpty)
        XCTAssertTrue(TextMatcher.ranges(of: "x", in: "").isEmpty)
    }

    func testExcerptCutsAtWordsAndCollapsesWhitespace() {
        let text = String(repeating: "word ", count: 40) + "the mitral\nvalve closes during systole " + String(repeating: "tail ", count: 40)
        let range = TextMatcher.ranges(of: "mitral valve", in: text)[0]
        let excerpt = TextMatcher.excerpt(of: range, in: text, context: 20)
        XCTAssertEqual(excerpt.match, "mitral valve")
        XCTAssertTrue(excerpt.before.hasPrefix("…"))
        XCTAssertTrue(excerpt.before.hasSuffix("the "))
        XCTAssertTrue(excerpt.after.hasPrefix(" closes"))
        XCTAssertTrue(excerpt.after.hasSuffix("…"))
        XCTAssertFalse(excerpt.before.contains("\n"))
        XCTAssertLessThanOrEqual(excerpt.before.count, 22)
    }

    func testExcerptAtTheEdgesHasNoEllipsis() {
        let text = "Mitral valve"
        let excerpt = TextMatcher.excerpt(of: TextMatcher.ranges(of: "mitral", in: text)[0], in: text)
        XCTAssertEqual(excerpt, TextExcerpt(before: "", match: "Mitral", after: " valve"))
    }
}
