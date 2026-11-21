import Foundation
import Speech

/// Turns a lecture recording into text with Apple's speech recognition.
///
/// On-device recognition is used when this iPad supports it for the language; otherwise the audio
/// is sent to Apple, which the person is told before starting. Long recordings may stop early
/// when recognition runs on Apple's servers.
enum Transcriber {
    enum Failure: LocalizedError {
        case notAllowed
        case unavailable
        case nothingHeard

        var errorDescription: String? {
            switch self {
            case .notAllowed:
                return String(localized: "Speech recognition is off for this app. Turn it on in Settings ▸ Privacy ▸ Speech Recognition.")
            case .unavailable:
                return String(localized: "Speech recognition for this language is not available on this iPad right now.")
            case .nothingHeard:
                return String(localized: "No speech was recognized in this recording.")
            }
        }
    }

    static func isOnDevice(arabic: Bool) -> Bool {
        SFSpeechRecognizer(locale: locale(arabic))?.supportsOnDeviceRecognition ?? false
    }

    private static func locale(_ arabic: Bool) -> Locale {
        Locale(identifier: arabic ? "ar-SA" : "en-US")
    }

    static func transcribe(url: URL, arabic: Bool) async throws -> String {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw Failure.notAllowed }
        guard let recognizer = SFSpeechRecognizer(locale: locale(arabic)), recognizer.isAvailable else {
            throw Failure.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        let text: String = try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error {
                    finished = true
                    continuation.resume(throwing: error)
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.nothingHeard }
        return trimmed
    }
}
