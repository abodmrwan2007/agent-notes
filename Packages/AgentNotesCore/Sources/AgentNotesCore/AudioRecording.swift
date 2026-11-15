import Foundation

/// One audio recording made while taking notes. The audio file lives in the package's `audio/`
/// directory. Handwriting is linked to recordings by time: every stroke carries the moment it was
/// drawn, so a stroke written during a recording maps to a position inside it.
public struct AudioRecording: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// File name inside `audio/`.
    public var fileName: String
    public var title: String
    public var startedAt: Date
    /// Seconds of audio actually recorded (pauses excluded).
    public var duration: Double

    public init(id: UUID = UUID(), fileName: String, title: String, startedAt: Date, duration: Double) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.startedAt = startedAt
        self.duration = duration
    }

    public var endedAt: Date { startedAt.addingTimeInterval(duration) }
}

public enum AudioTimeline {
    /// How many seconds before the moment of writing playback starts, so the sentence that led to
    /// the note is heard from its beginning.
    public static let leadIn = 3.0

    /// The recording that was running when `moment` happened, and where to start playing it.
    /// When several overlap (not normally possible), the most recent wins.
    public static func locate(_ moment: Date, in recordings: [AudioRecording]) -> (recording: AudioRecording, offset: Double)? {
        let candidates = recordings.filter { moment >= $0.startedAt && moment <= $0.endedAt.addingTimeInterval(1) }
        guard let recording = candidates.max(by: { $0.startedAt < $1.startedAt }) else { return nil }
        let offset = moment.timeIntervalSince(recording.startedAt) - leadIn
        return (recording, min(max(offset, 0), max(recording.duration - 0.5, 0)))
    }

    /// "1:05" or "1:02:03".
    public static func clock(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%ld:%02ld:%02ld", hours, minutes, secs)
            : String(format: "%ld:%02ld", minutes, secs)
    }
}
