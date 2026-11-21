import AgentNotesCore
import SwiftUI

/// Top-bar button: "Record", and while recording a red "Stop" with the running time.
struct RecordButton: View {
    let model: EditorModel

    var body: some View {
        let audio = model.audio
        Group {
            if audio.isRecording {
                Button {
                    model.stopRecording()
                } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let time = AudioTimeline.clock(audio.currentRecordingTime)
                        Label {
                            Text("Stop \(time)")
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "stop.circle.fill")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
                .tint(.red)
                .accessibilityLabel("Stop Recording")
            } else {
                Button {
                    model.startRecording()
                } label: {
                    Label("Record", systemImage: "record.circle")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Record")
            }
        }
        .accessibilityIdentifier("editor.record")
        .alert(
            "Recording",
            isPresented: Binding(get: { audio.notice != nil }, set: { if !$0 { audio.notice = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: audio.notice ?? "")
        }
    }
}

/// The notebook's recordings, in the side panel's Audio tab.
struct RecordingsList: View {
    let model: EditorModel
    @State private var pendingDeletion: AudioRecording?
    @State private var isTranscribing = false

    var body: some View {
        let audio = model.audio
        @Bindable var editor = model
        @Bindable var player = audio
        List {
            Section {
                Toggle(isOn: $editor.isListening) {
                    Label("Tap writing to hear it", systemImage: "hand.tap")
                }
                .accessibilityIdentifier("audio.listen")
            } footer: {
                Text("Tap a word you wrote during a recording to play the lecture from that moment. Writing is paused while this is on. Touch and hold a recording to transcribe it.")
            }

            Section {
                Picker("Playback speed", selection: $player.rate) {
                    ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 2, 3], id: \.self) { value in
                        Text(verbatim: value.formatted(.number.precision(.fractionLength(0...2))) + "×").tag(value)
                    }
                }
                .accessibilityIdentifier("audio.speed")
            }

            Section("Recordings") {
                if model.recordings.isEmpty {
                    Text("Tap Record at the top while you write. Recordings are saved inside this notebook.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.recordings.reversed()) { recording in
                    let isCurrent = audio.playingID == recording.id
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                if isCurrent, audio.isPlaying {
                                    audio.pause()
                                } else {
                                    model.play(recording, from: isCurrent ? audio.playbackTime : 0)
                                }
                            } label: {
                                Image(systemName: isCurrent && audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel(isCurrent && audio.isPlaying ? Text("Pause") : Text("Play"))
                            .accessibilityIdentifier("audio.play")

                            VStack(alignment: .leading) {
                                Text(verbatim: recording.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(verbatim: AudioTimeline.clock(recording.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        if isCurrent {
                            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                                HStack {
                                    Text(verbatim: AudioTimeline.clock(audio.playbackTime))
                                        .monospacedDigit()
                                    ProgressView(value: min(audio.playbackTime, recording.duration), total: max(recording.duration, 0.1))
                                }
                                .font(.caption)
                                // One element, so VoiceOver reads it and tests can find it.
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("audio.nowPlaying")
                            }
                        }
                    }
                    .accessibilityIdentifier("audio.recording")
                    .contextMenu {
                        Button {
                            transcribe(recording, arabic: true)
                        } label: {
                            Label("Transcribe (Arabic)", systemImage: "text.bubble")
                        }
                        Button {
                            transcribe(recording, arabic: false)
                        } label: {
                            Label("Transcribe (English)", systemImage: "text.bubble")
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingDeletion = recording
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this recording?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { recording in
            Button("Delete", role: .destructive) { model.deleteRecording(recording) }
        } message: { _ in
            Text("The audio is removed from this notebook. Your writing stays.")
        }
        .overlay {
            if isTranscribing {
                ProgressView("Transcribing…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func transcribe(_ recording: AudioRecording, arabic: Bool) {
        isTranscribing = true
        let url = model.store.audioURL(documentID: model.documentID, fileName: recording.fileName)
        Task {
            defer { isTranscribing = false }
            do {
                let text = try await Transcriber.transcribe(url: url, arabic: arabic)
                model.textToolsRequest = TextToolsRequest(text: text, origin: .recognized)
            } catch {
                model.alertMessage = error.localizedDescription
            }
        }
    }
}
