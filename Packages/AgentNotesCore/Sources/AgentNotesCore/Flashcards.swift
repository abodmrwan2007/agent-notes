import Foundation

/// A study card with its place in the spaced-review schedule (Leitner boxes).
public struct Flashcard: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var front: String
    public var back: String
    /// 0 = new or forgotten; each successful review moves the card up one or two boxes.
    public var box: Int
    /// When the card should be shown again.
    public var due: Date
    public var reviews: Int

    public init(id: UUID = UUID(), front: String, back: String, box: Int = 0, due: Date = .distantPast, reviews: Int = 0) {
        self.id = id
        self.front = front
        self.back = back
        self.box = box
        self.due = due
        self.reviews = reviews
    }
}

public struct FlashcardDeck: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var cards: [Flashcard]

    public init(id: UUID = UUID(), title: String, createdAt: Date = Date(), cards: [Flashcard] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.cards = cards
    }

    /// Cards due at `date`, the longest overdue first.
    public func dueCards(at date: Date) -> [Flashcard] {
        cards.filter { $0.due <= date }.sorted { $0.due < $1.due }
    }

    /// Cards in the top box: reviewed successfully many times in a row.
    public var masteredCount: Int { cards.filter { $0.box >= SpacedReview.intervals.count - 1 }.count }
}

/// How well the card was remembered, as in the study buttons.
public enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    /// Not remembered: back to the first box, shown again in a few minutes.
    case hard
    /// Remembered: up one box.
    case remembered
    /// Remembered easily: up two boxes.
    case easy
}

public enum SpacedReview {
    /// Waiting time after a review, by box: minutes for box 0, then days.
    public static let intervals: [TimeInterval] = [
        10 * 60, 1 * 86_400, 3 * 86_400, 7 * 86_400, 14 * 86_400, 30 * 86_400, 60 * 86_400
    ]

    public static func review(_ card: Flashcard, grade: ReviewGrade, at date: Date) -> Flashcard {
        var card = card
        let top = intervals.count - 1
        switch grade {
        case .hard: card.box = 0
        case .remembered: card.box = min(card.box + 1, top)
        case .easy: card.box = min(card.box + 2, top)
        }
        card.due = date.addingTimeInterval(intervals[card.box])
        card.reviews += 1
        return card
    }
}

/// All decks, as stored in one JSON file.
public struct FlashcardLibrary: Codable, Sendable {
    public static let currentVersion = 1
    public var version: Int
    public var decks: [FlashcardDeck]

    public init(decks: [FlashcardDeck] = []) {
        self.version = Self.currentVersion
        self.decks = decks
    }

    /// Cards for a spreadsheet or another flashcard app: front TAB back, one card per line.
    public static func tsv(_ deck: FlashcardDeck) -> String {
        func clean(_ text: String) -> String {
            text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
        }
        return deck.cards.map { clean($0.front) + "\t" + clean($0.back) }.joined(separator: "\n") + "\n"
    }

    /// Cards from tab- or comma-separated lines (front, back). Lines without a back are skipped.
    public static func cards(fromDelimited text: String) -> [Flashcard] {
        text.components(separatedBy: .newlines).compactMap { line in
            let separator: Character = line.contains("\t") ? "\t" : ","
            let parts = line.split(separator: separator, maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
            return Flashcard(front: parts[0], back: parts[1])
        }
    }
}
