import Foundation

// The study assistant talks to the Claude Messages API (POST https://api.anthropic.com/v1/messages)
// over plain HTTPS: there is no official Anthropic SDK for Swift. This file holds everything that
// does not need the network or UIKit: request bodies, prompts, response parsing, the study-card
// format and the daily limit. The app adds the key storage, page rendering and URLSession.

/// The Claude model the assistant uses. The owner chooses; Opus is the default.
public enum AIModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .opus: return "Claude Opus 5.5"
        case .sonnet: return "Claude Sonnet 5.5"
        case .haiku: return "Claude Haiku 5.5"
        }
    }

    /// Opus 5.5 and Sonnet 5.5 can be re-run on another model when a safety check declines a
    /// request (server-side fallback, a beta feature). Haiku has no server-side fallback.
    var supportsFallback: Bool { self != .haiku }
}

/// The language the answer is written in.
public enum AILanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case arabic
    case english

    public var id: String { rawValue }
}

/// What the assistant is asked to do.
public enum AITask: Equatable, Sendable {
    case summarize
    case studySet
    case explain(selection: String)
    /// A question about the material. `history` holds the earlier questions and answers.
    case ask(question: String, history: [AITurn])
}

public struct AITurn: Codable, Equatable, Sendable {
    public var question: String
    public var answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

/// One notebook page as sent to the model: its readable text (PDF text, text boxes, sticky
/// notes) and a picture of the page (JPEG), so handwriting and drawings can be read too.
public struct AIPage: Equatable, Sendable {
    public var number: Int
    public var text: String
    public var jpeg: Data?

    public init(number: Int, text: String, jpeg: Data?) {
        self.number = number
        self.text = text
        self.jpeg = jpeg
    }
}

public enum StudyAssistant {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    /// Most pages sent in one request.
    public static let maxPages = 20
    /// Characters of extracted text kept per page (PDF pages can hold a lot of text).
    public static let maxCharactersPerPage = 12_000
    public static let maxTokens = 16_000
    public static let flashcardCount = 10
    public static let quizCount = 8

    // MARK: Request

    /// HTTP headers for a request. The key is the owner's own key, stored in the Keychain.
    public static func headers(apiKey: String, model: AIModel) -> [String: String] {
        var headers = [
            "content-type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": apiVersion
        ]
        if model.supportsFallback {
            headers["anthropic-beta"] = fallbackBeta
        }
        return headers
    }

    /// The JSON body for the Messages API.
    public static func body(task: AITask, pages: [AIPage], language: AILanguage, model: AIModel) throws -> Data {
        var request: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "system": systemPrompt(language: language),
            "messages": messages(task: task, pages: pages, language: language)
        ]
        var output: [String: Any] = ["effort": "medium"]
        if task == .studySet {
            output["format"] = ["type": "json_schema", "schema": StudySet.jsonSchema]
        }
        request["output_config"] = output
        if model.supportsFallback {
            request["fallbacks"] = "default"
        }
        return try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func systemPrompt(language: AILanguage) -> String {
        let languageRule: String
        switch language {
        case .arabic:
            languageRule = "Write your answer in Arabic (Modern Standard Arabic). After each important medical or scientific term, give the English term in parentheses, because the student studies from English sources."
        case .english:
            languageRule = "Write your answer in English."
        }
        // Single-line literals only: tools/check_strings.py does not parse multi-line strings.
        return [
            "You are the study assistant inside a note-taking app used by medical and science students.",
            "The student's notebook pages are attached as pictures, some with extracted text.",
            "Pages may hold handwriting in Arabic or English, lecture slides, PDF pages and drawings: read all of it.",
            "",
            languageRule,
            "",
            "Rules:",
            "- Use only what is on the pages, plus well-established textbook knowledge where the task asks for an explanation.",
            "- Say clearly when something on the page is unreadable or missing instead of guessing.",
            "- If the pages contain something that looks medically wrong, point it out politely.",
            "- Write plain text for a notebook page: no Markdown (no #, **, tables or code blocks).",
            "- Use short paragraphs, and start list lines with the bullet character • followed by a space.",
            "- Start directly with the content, without a preamble such as ‘Here is’.",
            "- This is for studying, not for treating patients."
        ].joined(separator: "\n")
    }

    static func messages(task: AITask, pages: [AIPage], language: AILanguage) -> [[String: Any]] {
        var material = materialBlocks(pages)
        switch task {
        case .summarize:
            material.append(text: [
                "Summarize these pages for revision before an exam.",
                "Begin with one or two sentences on what the pages are about, then the key points as a list,",
                "then any definitions, numbers or classifications worth memorizing.",
                "Keep it to what fits on one or two notebook pages."
            ].joined(separator: " "))
            return [["role": "user", "content": material]]
        case .studySet:
            material.append(text: [
                "Make study material from these pages: \(flashcardCount) flashcards",
                "(a short question or term on the front, a concise answer on the back)",
                "and \(quizCount) multiple-choice questions with four choices each,",
                "the index of the correct choice (0 to 3), and a one-sentence explanation.",
                "Cover the most important points, not trivia."
            ].joined(separator: " "))
            return [["role": "user", "content": material]]
        case .explain(let selection):
            material.append(text: [
                "The student selected this text on the pages and wants it explained:",
                "<selection>",
                selection,
                "</selection>",
                "Explain it simply and accurately: what it means, why it matters, and one example or clinical link if there is a natural one.",
                "Translate key terms. Keep it short."
            ].joined(separator: "\n"))
            return [["role": "user", "content": material]]
        case .ask(let question, let history):
            var result: [[String: Any]] = []
            var first = material
            first.append(text: "Answer the student's questions about these pages.\n\nQuestion: " + (history.first?.question ?? question))
            result.append(["role": "user", "content": first])
            if let opening = history.first {
                result.append(["role": "assistant", "content": opening.answer])
                for turn in history.dropFirst() {
                    result.append(["role": "user", "content": turn.question])
                    result.append(["role": "assistant", "content": turn.answer])
                }
                result.append(["role": "user", "content": question])
            }
            return result
        }
    }

    /// Text and picture blocks for the pages. The last one is marked for prompt caching, so
    /// follow-up questions about the same pages cost less.
    static func materialBlocks(_ pages: [AIPage]) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        for page in pages.prefix(maxPages) {
            var header = "Page \(page.number)"
            let text = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                header += " (extracted text):\n" + String(text.prefix(maxCharactersPerPage))
            } else {
                header += ":"
            }
            blocks.append(["type": "text", "text": header])
            if let jpeg = page.jpeg {
                blocks.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]
                ])
            }
        }
        if !blocks.isEmpty {
            blocks[blocks.count - 1]["cache_control"] = ["type": "ephemeral"]
        }
        return blocks
    }

    // MARK: Response

    /// The model's answer: its text blocks joined, and whether it was cut off at the length limit.
    public struct Reply: Equatable, Sendable {
        public var text: String
        public var isTruncated: Bool
        public var inputTokens: Int
        public var outputTokens: Int

        public init(text: String, isTruncated: Bool, inputTokens: Int, outputTokens: Int) {
            self.text = text
            self.isTruncated = isTruncated
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
        }
    }

    public enum Failure: Error, Equatable, Sendable {
        /// The key is missing, wrong or revoked (401/403).
        case invalidKey
        /// Too many requests or the account's spending limit was reached (429).
        case rateLimited
        /// The service is busy (529) or failing (5xx). Trying again later may work.
        case unavailable
        /// The request was too large or otherwise rejected (400/413). Carries the API's message.
        case rejected(String)
        /// A safety check declined the request.
        case refused
        /// The response could not be read.
        case unreadable
    }

    public static func parse(data: Data, statusCode: Int) throws -> Reply {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(statusCode) else {
            let message = ((object?["error"] as? [String: Any])?["message"] as? String) ?? ""
            switch statusCode {
            case 401, 403: throw Failure.invalidKey
            case 429: throw Failure.rateLimited
            case 400, 404, 413, 422: throw Failure.rejected(message)
            default: throw Failure.unavailable
            }
        }
        guard let object, let content = object["content"] as? [[String: Any]] else { throw Failure.unreadable }
        let stopReason = object["stop_reason"] as? String
        if stopReason == "refusal" { throw Failure.refused }
        // Only text blocks are the answer; thinking and fallback blocks are skipped.
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.unreadable }
        let usage = object["usage"] as? [String: Any]
        return Reply(
            text: text,
            isTruncated: stopReason == "max_tokens",
            inputTokens: usage?["input_tokens"] as? Int ?? 0,
            outputTokens: usage?["output_tokens"] as? Int ?? 0)
    }
}

private extension Array where Element == [String: Any] {
    mutating func append(text: String) {
        append(["type": "text", "text": text])
    }
}

/// Flashcards and quiz questions made from notebook pages.
public struct StudySet: Codable, Equatable, Sendable {
    public struct Card: Codable, Equatable, Hashable, Sendable {
        public var front: String
        public var back: String

        public init(front: String, back: String) {
            self.front = front
            self.back = back
        }
    }

    public struct Question: Codable, Equatable, Hashable, Sendable {
        public var question: String
        public var choices: [String]
        /// Index into `choices`.
        public var answer: Int
        public var explanation: String

        public init(question: String, choices: [String], answer: Int, explanation: String) {
            self.question = question
            self.choices = choices
            self.answer = answer
            self.explanation = explanation
        }
    }

    public var cards: [Card]
    public var quiz: [Question]

    public init(cards: [Card], quiz: [Question]) {
        self.cards = cards
        self.quiz = quiz
    }

    /// The structured-output schema sent with the request.
    static var jsonSchema: [String: Any] { [
        "type": "object",
        "additionalProperties": false,
        "required": ["cards", "quiz"],
        "properties": [
            "cards": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["front", "back"],
                    "properties": ["front": ["type": "string"], "back": ["type": "string"]]
                ]
            ],
            "quiz": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["question", "choices", "answer", "explanation"],
                    "properties": [
                        "question": ["type": "string"],
                        "choices": ["type": "array", "items": ["type": "string"]],
                        "answer": ["type": "integer"],
                        "explanation": ["type": "string"]
                    ]
                ]
            ]
        ]
    ] }

    /// Decodes the model's JSON answer, dropping empty cards and questions whose answer index is
    /// out of range. Returns nil when nothing usable is left.
    public static func decode(_ text: String) -> StudySet? {
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StudySet.self, from: data) else { return nil }
        let cards = decoded.cards.filter {
            !$0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let quiz = decoded.quiz.filter {
            $0.choices.count >= 2 && $0.choices.indices.contains($0.answer)
                && !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !cards.isEmpty || !quiz.isEmpty else { return nil }
        return StudySet(cards: cards, quiz: quiz)
    }

    /// Plain text for a notebook page.
    public func pageText(cardsTitle: String, quizTitle: String) -> String {
        var lines: [String] = []
        if !cards.isEmpty {
            lines.append(cardsTitle)
            for (index, card) in cards.enumerated() {
                lines.append("\(index + 1). \(card.front)\n   → \(card.back)")
            }
        }
        if !quiz.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append(quizTitle)
            for (index, question) in quiz.enumerated() {
                lines.append("\(index + 1). \(question.question)")
                for (choiceIndex, choice) in question.choices.enumerated() {
                    let mark = choiceIndex == question.answer ? "✓" : " "
                    lines.append("   \(mark) \(choice)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Counts requests per calendar day so the owner's spending stays predictable.
public struct AIDailyUsage: Codable, Equatable, Sendable {
    public var day: String
    public var count: Int

    public init(day: String = "", count: Int = 0) {
        self.day = day
        self.count = count
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Requests already made on the day of `date`.
    public func used(on date: Date, calendar: Calendar = .current) -> Int {
        day == Self.dayKey(date, calendar: calendar) ? count : 0
    }

    public func remaining(limit: Int, on date: Date, calendar: Calendar = .current) -> Int {
        max(limit - used(on: date, calendar: calendar), 0)
    }

    public mutating func record(on date: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(date, calendar: calendar)
        if day == key {
            count += 1
        } else {
            day = key
            count = 1
        }
    }
}
