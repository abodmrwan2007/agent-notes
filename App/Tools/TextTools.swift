import AVFoundation
import NaturalLanguage
import SwiftUI
import UIKit
import Vision
#if canImport(Translation)
import Translation
#endif

/// Reads text aloud with the system voices, in the text's own language (Arabic or English).
@MainActor
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechReader()
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    var onChange: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage == .arabic ? "ar-SA" : "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        synthesizer.speak(utterance)
        isSpeaking = true
        onChange?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onChange?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onChange?()
        }
    }
}

/// Finds printed and handwritten text in a picture with Apple's on-device Vision framework.
enum TextRecognizer {
    enum Failure: LocalizedError {
        case nothingFound
        var errorDescription: String? { String(localized: "No text was found on this page.") }
    }

    /// Lines of text, top to bottom. Arabic is used when this iPad's Vision supports it.
    static func recognize(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw Failure.nothingFound }
        let text: String = try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Vision's y axis points up: sort by the top of each line, then left to right.
                let lines = observations
                    .sorted { lhs, rhs in
                        abs(lhs.boundingBox.maxY - rhs.boundingBox.maxY) > 0.01
                            ? lhs.boundingBox.maxY > rhs.boundingBox.maxY
                            : lhs.boundingBox.minX < rhs.boundingBox.minX
                    }
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let wanted = supported.filter { $0.hasPrefix("ar") } + supported.filter { $0.hasPrefix("en") }
            if !wanted.isEmpty { request.recognitionLanguages = wanted }
            request.automaticallyDetectsLanguage = true
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.nothingFound }
        return trimmed
    }

    /// Whether this iPad's Vision can read Arabic text (it depends on the iPadOS version).
    static var supportsArabic: Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return ((try? request.supportedRecognitionLanguages()) ?? []).contains { $0.hasPrefix("ar") }
    }
}

/// The system dictionary ("Look Up") for a word or phrase.
struct DictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}

/// An extra button in the text tools sheet. It runs after the sheet closes.
struct TextToolAction: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let perform: (String) -> Void
}

/// What can be done with a piece of text: recognized from a page or selected on a PDF.
struct TextToolsSheet: View {
    let title: LocalizedStringKey
    @State var text: String
    /// Puts the (possibly edited) text on the page. Nil hides the button.
    var onInsert: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showsDictionary = false
    @State private var showsTranslation = false
    @State private var isSpeaking = false
    @State private var copied = false
    var note: LocalizedStringKey?
    /// Shown inside an existing navigation stack (Study) instead of as a sheet.
    var embedded = false
    /// More things to do with the text (for example after Circle to Translate).
    var extraActions: [TextToolAction] = []

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                                .accessibilityIdentifier("textTools.done")
                        }
                    }
            }
        }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 12) {
                if let note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("textTools.text")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    if let onInsert {
                        Button {
                            onInsert(text)
                            dismiss()
                        } label: {
                            Label("Put on Page", systemImage: "text.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Vivid.green)
                        .accessibilityIdentifier("textTools.insert")
                    }
                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                    } label: {
                        let copyTitle: LocalizedStringKey = copied ? "Copied" : "Copy"
                        Label(copyTitle, systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Vivid.teal)
                    translateButton
                    Button {
                        showsDictionary = true
                    } label: {
                        Label("Look Up", systemImage: "character.book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Vivid.indigo)
                    .accessibilityIdentifier("textTools.lookUp")
                    Button {
                        SpeechReader.shared.toggle(text)
                    } label: {
                        let speakTitle: LocalizedStringKey = isSpeaking ? "Stop" : "Read Aloud"
                        Label(speakTitle, systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Vivid.yellow)
                    .accessibilityIdentifier("textTools.speak")
                    ForEach(extraActions) { action in
                        Button {
                            let current = text
                            dismiss()
                            // After the sheet has gone, so actions that leave the notebook work.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { action.perform(current) }
                        } label: {
                            Label(action.title, systemImage: action.symbol)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(action.tint)
                        .accessibilityIdentifier("textTools.\(action.id)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsDictionary) {
                DictionaryView(term: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .onAppear {
                SpeechReader.shared.onChange = { isSpeaking = SpeechReader.shared.isSpeaking }
            }
            .onDisappear {
                if SpeechReader.shared.isSpeaking { SpeechReader.shared.toggle("") }
            }
            .modifier(TranslationSheet(isPresented: $showsTranslation, text: text))
    }

    @ViewBuilder
    private var translateButton: some View {
        if TranslationSheet.isAvailable {
            Button {
                showsTranslation = true
            } label: {
                Label("Translate", systemImage: "translate")
                    .frame(maxWidth: .infinity)
            }
            .tint(Vivid.orange)
            .accessibilityIdentifier("textTools.translate")
        }
    }
}

/// Apple's Translation sheet (on-device after the languages are downloaded), iPadOS 17.4 and later.
private struct TranslationSheet: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    static var isAvailable: Bool {
        #if canImport(Translation)
        if #available(iOS 17.4, *) { return true }
        #endif
        return false
    }

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
