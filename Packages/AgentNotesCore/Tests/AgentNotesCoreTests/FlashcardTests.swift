import AgentNotesCore
import XCTest

final class FlashcardTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewCardsAreDue() {
        let deck = FlashcardDeck(title: "Heart", cards: [Flashcard(front: "SA node", back: "Pacemaker")])
        XCTAssertEqual(deck.dueCards(at: now).count, 1)
    }

    func testGradesMoveTheCard() {
        let card = Flashcard(front: "a", back: "b", box: 2)
        let hard = SpacedReview.review(card, grade: .hard, at: now)
        XCTAssertEqual(hard.box, 0)
        XCTAssertEqual(hard.due, now.addingTimeInterval(600))
        XCTAssertEqual(hard.reviews, 1)

        let remembered = SpacedReview.review(card, grade: .remembered, at: now)
        XCTAssertEqual(remembered.box, 3)
        XCTAssertEqual(remembered.due, now.addingTimeInterval(7 * 86_400))

        let easy = SpacedReview.review(card, grade: .easy, at: now)
        XCTAssertEqual(easy.box, 4)
    }

    func testTopBoxIsTheLimit() {
        var card = Flashcard(front: "a", back: "b", box: SpacedReview.intervals.count - 1)
        card = SpacedReview.review(card, grade: .easy, at: now)
        XCTAssertEqual(card.box, SpacedReview.intervals.count - 1)
        let deck = FlashcardDeck(title: "t", cards: [card])
        XCTAssertEqual(deck.masteredCount, 1)
        XCTAssertTrue(deck.dueCards(at: now).isEmpty)
        XCTAssertEqual(deck.dueCards(at: now.addingTimeInterval(61 * 86_400)).count, 1)
    }

    func testDueOrderIsMostOverdueFirst() {
        let early = Flashcard(front: "1", back: "1", due: now.addingTimeInterval(-500))
        let late = Flashcard(front: "2", back: "2", due: now.addingTimeInterval(-100))
        let future = Flashcard(front: "3", back: "3", due: now.addingTimeInterval(100))
        let deck = FlashcardDeck(title: "t", cards: [late, future, early])
        XCTAssertEqual(deck.dueCards(at: now).map(\.front), ["1", "2"])
    }

    func testDelimitedImportAndExport() {
        let cards = FlashcardLibrary.cards(fromDelimited: "Systole\tContraction\nDiastole, Relaxation\nno back\n\n")
        XCTAssertEqual(cards.map(\.front), ["Systole", "Diastole"])
        XCTAssertEqual(cards.map(\.back), ["Contraction", "Relaxation"])
        let deck = FlashcardDeck(title: "t", cards: [Flashcard(front: "a\tx", back: "line\nbreak")])
        XCTAssertEqual(FlashcardLibrary.tsv(deck), "a x\tline break\n")
    }

    func testLibraryRoundTrip() throws {
        let library = FlashcardLibrary(decks: [FlashcardDeck(title: "Heart", cards: [Flashcard(front: "f", back: "b")])])
        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(FlashcardLibrary.self, from: data)
        XCTAssertEqual(decoded.decks, library.decks)
        XCTAssertEqual(decoded.version, FlashcardLibrary.currentVersion)
    }
}
