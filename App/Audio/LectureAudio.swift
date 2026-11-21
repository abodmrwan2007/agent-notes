import AVFoundation
import Observation

/// Records lecture audio while the person writes, and plays recordings back.
///
/// Honest limits: recording stops when the app leaves the foreground or when the system
/// interrupts audio (a phone call, Siri); what was recorded up to then is kept. There is no
/// background recording yet (it needs the "audio" background mode and more testing).
@MainActor
@Observable
final class LectureAudio: NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    enum RecordingError: LocalizedError {
        case permissionDenied
        case couldNotStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(localized: "Microphone access is off for this app. Turn it on in Settings ▸ Privacy ▸ Microphone.")
            case .couldNotStart:
                return String(localized: "Recording could not start.")
            }
        }
    }

    private(set) var isRecording = false
    private(set) var recordingStartedAt: Date?
    /// The recording being played, if any.
    private(set) var playingID: UUID?
    private(set) var isPlaying = false
    /// Set when recording stopped by itself (interruption); shown once, then cleared.
    var notice: String?
    /// Playback speed, 0.25× to 3×. Pitch is kept.
    var rate: Float = 1 {
        didSet { player?.rate = rate }
    }

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var onRecordingFinished: ((Date, TimeInterval) -> Void)?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    // MARK: Recording

    var currentRecordingTime: TimeInterval { recorder?.currentTime ?? 0 }

    /// Starts recording into `url`. `finished` receives the start date and the recorded duration
    /// when recording stops for any reason, so the caller can save it.
    func startRecording(to url: URL, finished: @escaping (Date, TimeInterval) -> Void) async throws {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else { throw RecordingError.permissionDenied }

        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 32_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        guard recorder.record() else { throw RecordingError.couldNotStart }
        self.recorder = recorder
        onRecordingFinished = finished
        recordingStartedAt = Date()
        isRecording = true
    }

    func stopRecording() {
        guard let recorder, let startedAt = recordingStartedAt else { return }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let finished = onRecordingFinished
        onRecordingFinished = nil
        finished?(startedAt, duration)
    }

    // Posted on an arbitrary thread; hops to the main actor.
    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        Task { @MainActor in
            if self.isRecording {
                self.stopRecording()
                self.notice = String(localized: "Recording stopped because another app or a call used the audio. What was recorded is saved.")
            }
            self.stopPlayback()
        }
    }

    // MARK: Playback

    func play(url: URL, recordingID: UUID, from offset: TimeInterval) {
        guard !isRecording else { return }
        do {
            if playingID != recordingID || player == nil {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.enableRate = true
                player.prepareToPlay()
                self.player = player
                playingID = recordingID
            }
            player?.currentTime = min(max(offset, 0), player?.duration ?? 0)
            player?.rate = rate
            player?.play()
            isPlaying = true
        } catch {
            notice = String(localized: "This recording could not be played.")
            stopPlayback()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
        isPlaying = false
    }

    var playbackTime: TimeInterval { player?.currentTime ?? 0 }
    var playbackDuration: TimeInterval { player?.duration ?? 0 }

    func seek(to time: TimeInterval) {
        player?.currentTime = min(max(time, 0), player?.duration ?? 0)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}
