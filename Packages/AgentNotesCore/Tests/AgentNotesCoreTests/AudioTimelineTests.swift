import XCTest
@testable import AgentNotesCore

final class AudioTimelineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func recording(startOffset: Double, duration: Double, title: String = "r") -> AudioRecording {
        AudioRecording(fileName: title + ".m4a", title: title, startedAt: start.addingTimeInterval(startOffset), duration: duration)
    }

    func testStrokeDuringARecordingMapsToItsMomentWithLeadIn() {
        let lecture = recording(startOffset: 0, duration: 3600)
        let hit = AudioTimeline.locate(start.addingTimeInterval(125), in: [lecture])
        XCTAssertEqual(hit?.recording.id, lecture.id)
        XCTAssertEqual(hit?.offset ?? -1, 125 - AudioTimeline.leadIn, accuracy: 1e-9)
    }

    func testEarlyStrokeDoesNotGoNegativeAndLateStrokeStaysInside() {
        let lecture = recording(startOffset: 0, duration: 60)
        XCTAssertEqual(AudioTimeline.locate(start.addingTimeInterval(1), in: [lecture])?.offset, 0)
        let late = AudioTimeline.locate(start.addingTimeInterval(60.5), in: [lecture])
        XCTAssertNotNil(late)
        XCTAssertLessThanOrEqual(late?.offset ?? 99, 59.5)
    }

    func testStrokesOutsideEveryRecordingAreNotLinked() {
        let first = recording(startOffset: 0, duration: 60, title: "a")
        let second = recording(startOffset: 600, duration: 60, title: "b")
        XCTAssertNil(AudioTimeline.locate(start.addingTimeInterval(300), in: [first, second]))
        XCTAssertNil(AudioTimeline.locate(start.addingTimeInterval(-5), in: [first, second]))
        XCTAssertEqual(AudioTimeline.locate(start.addingTimeInterval(630), in: [first, second])?.recording.title, "b")
        XCTAssertNil(AudioTimeline.locate(start, in: []))
    }

    func testClock() {
        XCTAssertEqual(AudioTimeline.clock(0), "0:00")
        XCTAssertEqual(AudioTimeline.clock(65.9), "1:05")
        XCTAssertEqual(AudioTimeline.clock(3723), "1:02:03")
    }

    func testOlderManifestsHaveNoRecordingsAndNewOnesRoundTrip() throws {
        var manifest = DocumentManifest(title: "t", pages: [PageRecord(size: .a4)])
        XCTAssertTrue(manifest.allRecordings.isEmpty)
        manifest.recordings = [recording(startOffset: 0, duration: 42)]
        let decoded = try ManifestCodec.decode(ManifestCodec.encode(manifest))
        XCTAssertEqual(decoded.allRecordings.count, 1)
        XCTAssertEqual(decoded.allRecordings.first?.duration, 42)

        var old = DocumentManifest(title: "v4", pages: [PageRecord(size: .a4)])
        old.formatVersion = 4
        XCTAssertTrue(try ManifestCodec.decode(ManifestCodec.encode(old)).allRecordings.isEmpty)
    }
}
