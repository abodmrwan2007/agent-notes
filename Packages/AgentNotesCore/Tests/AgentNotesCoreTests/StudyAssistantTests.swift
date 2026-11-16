import AgentNotesCore
import XCTest

final class StudyAssistantTests: XCTestCase {
    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let pages = [
        AIPage(number: 1, text: "Cardiac cycle", jpeg: Data([1, 2, 3])),
        AIPage(number: 2, text: "", jpeg: Data([4]))
    ]

    func testSummaryRequestShape() throws {
        let body = try json(StudyAssistant.body(task: .summarize, pages: pages, language: .arabic, model: .opus))
        XCTAssertEqual(body["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual(body["max_tokens"] as? Int, StudyAssistant.maxTokens)
        XCTAssertEqual(body["fallbacks"] as? String, "default")
        XCTAssertNil(body["thinking"], "Opus 5.5 rejects a disabled thinking setting; it is left out")
        XCTAssertNil(body["temperature"])
        let output = try XCTUnwrap(body["output_config"] as? [String: Any])
        XCTAssertEqual(output["effort"] as? String, "medium")
        XCTAssertNil(output["format"])
        XCTAssertTrue((body["system"] as? String ?? "").contains("Arabic"))

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        // page 1 text, page 1 image, page 2 text, page 2 image, instruction
        XCTAssertEqual(content.map { $0["type"] as? String }, ["text", "image", "text", "image", "text"])
        XCTAssertTrue((content[0]["text"] as? String ?? "").contains("Cardiac cycle"))
        let source = try XCTUnwrap(content[1]["source"] as? [String: Any])
        XCTAssertEqual(source["media_type"] as? String, "image/jpeg")
        XCTAssertEqual(source["data"] as? String, Data([1, 2, 3]).base64EncodedString())
        XCTAssertNotNil(content[3]["cache_control"], "the last page block is cached")
        XCTAssertNil(content[4]["cache_control"])
    }

    func testHeaders() {
        let opus = StudyAssistant.headers(apiKey: "test-key", model: .opus)
        XCTAssertEqual(opus["x-api-key"], "test-key")
        XCTAssertEqual(opus["anthropic-version"], "2026-10-21")
        XCTAssertEqual(opus["anthropic-beta"], "server-side-fallback-2026-07-01")
        XCTAssertNil(StudyAssistant.headers(apiKey: "k", model: .haiku)["anthropic-beta"])
    }

    func testHaikuHasNoFallback() throws {
        let body = try json(StudyAssistant.body(task: .summarize, pages: pages, language: .english, model: .haiku))
        XCTAssertNil(body["fallbacks"])
        XCTAssertEqual(body["model"] as? String, "claude-haiku-5-5")
    }

    func testStudySetRequestHasSchema() throws {
        let body = try json(StudyAssistant.body(task: .studySet, pages: pages, language: .english, model: .sonnet))
        let output = try XCTUnwrap(body["output_config"] as? [String: Any])
        let format = try XCTUnwrap(output["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
    }

    func testFollowUpQuestionsAlternateRoles() throws {
        let history = [AITurn(question: "What is systole?", answer: "Contraction."),
                       AITurn(question: "And diastole?", answer: "Relaxation.")]
        let body = try json(StudyAssistant.body(
            task: .ask(question: "Which is longer?", history: history), pages: pages, language: .english, model: .opus))
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String },
                       ["user", "assistant", "user", "assistant", "user"])
        let first = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        XCTAssertTrue((first.last?["text"] as? String ?? "").contains("What is systole?"))
        XCTAssertEqual(messages[4]["content"] as? String, "Which is longer?")
    }

    func testExplainIncludesSelection() throws {
        let body = try json(StudyAssistant.body(
            task: .explain(selection: "Frank-Starling law"), pages: pages, language: .english, model: .opus))
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        XCTAssertTrue((content.last?["text"] as? String ?? "").contains("Frank-Starling law"))
    }

    func testPageLimitAndTextLimit() throws {
        let many = (1...30).map { AIPage(number: $0, text: String(repeating: "a", count: 20_000), jpeg: nil) }
        let body = try json(StudyAssistant.body(task: .summarize, pages: many, language: .english, model: .opus))
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, StudyAssistant.maxPages + 1)
        XCTAssertLessThan((content[0]["text"] as? String ?? "").count, StudyAssistant.maxCharactersPerPage + 100)
    }

    /// JSON built from a dictionary (tools/check_strings.py cannot parse JSON inside raw strings).
    private func encode(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    func testParseSuccessSkipsNonTextBlocks() throws {
        let data = try encode([
            "content": [
                ["type": "thinking", "thinking": ""],
                ["type": "text", "text": "Hello "],
                ["type": "text", "text": "world"]
            ],
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 120, "output_tokens": 8]
        ])
        let reply = try StudyAssistant.parse(data: data, statusCode: 200)
        XCTAssertEqual(reply.text, "Hello world")
        XCTAssertFalse(reply.isTruncated)
        XCTAssertEqual(reply.inputTokens, 120)
        XCTAssertEqual(reply.outputTokens, 8)
    }

    func testParseTruncatedAndRefusal() throws {
        let truncated = try encode(["content": [["type": "text", "text": "Part"]], "stop_reason": "max_tokens"])
        XCTAssertTrue(try StudyAssistant.parse(data: truncated, statusCode: 200).isTruncated)
        let refusal = try encode(["content": [Any](), "stop_reason": "refusal"])
        XCTAssertThrowsError(try StudyAssistant.parse(data: refusal, statusCode: 200)) {
            XCTAssertEqual($0 as? StudyAssistant.Failure, .refused)
        }
    }

    func testParseErrors() throws {
        let errorBody = try encode(["type": "error", "error": ["type": "x", "message": "too big"]])
        func failure(_ status: Int, _ body: Data) -> StudyAssistant.Failure? {
            do {
                _ = try StudyAssistant.parse(data: body, statusCode: status)
                return nil
            } catch {
                return error as? StudyAssistant.Failure
            }
        }
        XCTAssertEqual(failure(401, errorBody), .invalidKey)
        XCTAssertEqual(failure(403, errorBody), .invalidKey)
        XCTAssertEqual(failure(429, errorBody), .rateLimited)
        XCTAssertEqual(failure(529, errorBody), .unavailable)
        XCTAssertEqual(failure(500, errorBody), .unavailable)
        XCTAssertEqual(failure(400, errorBody), .rejected("too big"))
        XCTAssertEqual(failure(200, Data("not json".utf8)), .unreadable)
    }

    func testStudySetDecodingDropsBrokenItems() throws {
        let json = try encode([
            "cards": [["front": "Systole", "back": "Contraction"], ["front": " ", "back": "x"]],
            "quiz": [
                ["question": "Q1", "choices": ["a", "b", "c", "d"], "answer": 2, "explanation": "e"],
                ["question": "Q2", "choices": ["a", "b"], "answer": 5, "explanation": "e"]
            ]
        ])
        let text = String(decoding: json, as: UTF8.self)
        let set = try XCTUnwrap(StudySet.decode(text))
        XCTAssertEqual(set.cards, [StudySet.Card(front: "Systole", back: "Contraction")])
        XCTAssertEqual(set.quiz.count, 1)
        XCTAssertNil(StudySet.decode(String(decoding: try encode(["cards": [Any](), "quiz": [Any]()]), as: UTF8.self)))
        XCTAssertNil(StudySet.decode("nonsense"))

        let page = set.pageText(cardsTitle: "Cards", quizTitle: "Quiz")
        XCTAssertTrue(page.contains("1. Systole\n   → Contraction"))
        XCTAssertTrue(page.contains("✓ c"))
    }

    func testDailyUsage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let monday = Date(timeIntervalSince1970: 1_700_000_000)
        let tuesday = monday.addingTimeInterval(86_400)
        var usage = AIDailyUsage()
        XCTAssertEqual(usage.remaining(limit: 3, on: monday, calendar: calendar), 3)
        usage.record(on: monday, calendar: calendar)
        usage.record(on: monday, calendar: calendar)
        XCTAssertEqual(usage.used(on: monday, calendar: calendar), 2)
        XCTAssertEqual(usage.remaining(limit: 3, on: monday, calendar: calendar), 1)
        XCTAssertEqual(usage.used(on: tuesday, calendar: calendar), 0, "a new day starts from zero")
        usage.record(on: tuesday, calendar: calendar)
        XCTAssertEqual(usage.count, 1)
        XCTAssertEqual(AIDailyUsage.dayKey(monday, calendar: calendar), "2023-11-14")
    }
}
