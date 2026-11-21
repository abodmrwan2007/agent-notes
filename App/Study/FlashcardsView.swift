import AgentNotesCore
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// All flashcard decks, kept in one JSON file in the app's Documents folder.
@MainActor
@Observable
final class FlashcardStore {
    static let shared = FlashcardStore()

    private(set) var decks: [FlashcardDeck] = []
    var errorMessage: String?

    @ObservationIgnored private let url: URL = {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flashcards", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("decks.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url) {
            if let library = try? JSONDecoder().decode(FlashcardLibrary.self, from: data) {
                decks = library.decks
            } else {
                // Keep the unreadable file instead of overwriting it with an empty library.
                let backup = url.deletingLastPathComponent().appendingPathComponent("decks-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: url, to: backup)
                errorMessage = String(localized: "The flashcards file could not be read. It was kept as a copy and a new one was started.")
            }
        }
    }

    func deck(id: UUID) -> FlashcardDeck? { decks.first { $0.id == id } }

    @discardableResult
    func addDeck(title: String, cards: [Flashcard] = []) -> FlashcardDeck {
        let deck = FlashcardDeck(title: title, cards: cards)
        decks.insert(deck, at: 0)
        save()
        return deck
    }

    func update(_ deck: FlashcardDeck) {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return }
        decks[index] = deck
        save()
    }

    func delete(_ deck: FlashcardDeck) {
        decks.removeAll { $0.id == deck.id }
        save()
    }

    func review(_ card: Flashcard, in deckID: UUID, grade: ReviewGrade) {
        guard var deck = deck(id: deckID), let index = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        deck.cards[index] = SpacedReview.review(deck.cards[index], grade: grade, at: Date())
        update(deck)
    }

    var dueToday: Int { decks.reduce(0) { $0 + $1.dueCards(at: Date()).count } }

    private func save() {
        do {
            let data = try JSONEncoder().encode(FlashcardLibrary(decks: decks))
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = String(localized: "The flashcards could not be saved.") + "\n" + error.localizedDescription
        }
    }
}

/// Study ▸ Flashcards: the list of decks.
struct FlashcardDecksView: View {
    @State private var store = FlashcardStore.shared
    @State private var prompt: NamePrompt?

    var body: some View {
        List {
            if store.decks.isEmpty {
                Text("No decks yet. Tap + to make one, or save the cards the AI makes in Tools ▸ AI.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.decks) { deck in
                NavigationLink {
                    FlashcardDeckView(deckID: deck.id)
                } label: {
                    let due = deck.dueCards(at: Date()).count
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: deck.title).font(.headline)
                        Text("\(deck.cards.count) cards · \(due) due · \(deck.masteredCount) learned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("deck.row")
            }
            .onDelete { offsets in
                offsets.map { store.decks[$0] }.forEach(store.delete)
            }
        }
        .navigationTitle("Flashcards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    prompt = NamePrompt(title: "New Deck", initialText: "") { title in
                        store.addDeck(title: title.isEmpty ? String(localized: "New Deck") : title)
                    }
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
                .accessibilityIdentifier("deck.new")
            }
        }
        .namePrompt($prompt)
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: store.errorMessage ?? "")
        }
    }
}

/// One deck: study the due cards, add, edit, import and export cards.
struct FlashcardDeckView: View {
    let deckID: UUID
    @State private var store = FlashcardStore.shared
    @State private var editing: Flashcard?
    @State private var isStudying = false
    @State private var isImporting = false
    @State private var export: ExportedDeck?

    private struct ExportedDeck: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        if let deck = store.deck(id: deckID) {
            List {
                Section {
                    Button {
                        isStudying = true
                    } label: {
                        let due = deck.dueCards(at: Date()).count
                        let studyTitle: LocalizedStringKey = due > 0 ? "Study \(due) due cards" : "Nothing due: study all cards"
                        Label(studyTitle, systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                    .disabled(deck.cards.isEmpty)
                    .accessibilityIdentifier("deck.study")
                }
                Section("Cards") {
                    ForEach(deck.cards) { card in
                        Button {
                            editing = card
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: card.front).foregroundStyle(Theme.text)
                                Text(verbatim: card.back).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var changed = deck
                        changed.cards.remove(atOffsets: offsets)
                        store.update(changed)
                    }
                    Button {
                        editing = Flashcard(front: "", back: "")
                    } label: {
                        Label("Add Card", systemImage: "plus")
                    }
                    .accessibilityIdentifier("deck.addCard")
                }
            }
            .navigationTitle(Text(verbatim: deck.title))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button {
                            isImporting = true
                        } label: {
                            Label("Import Cards (TSV or CSV)", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            exportDeck(deck)
                        } label: {
                            Label("Export Cards (TSV)", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Deck actions")
                }
            }
            .sheet(item: $editing) { card in
                CardEditor(card: card) { edited in
                    var changed = deck
                    if let index = changed.cards.firstIndex(where: { $0.id == edited.id }) {
                        changed.cards[index] = edited
                    } else {
                        changed.cards.append(edited)
                    }
                    store.update(changed)
                }
            }
            .fullScreenCover(isPresented: $isStudying) {
                StudySessionView(deckID: deckID)
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.plainText, .commaSeparatedText, .tabSeparatedText]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    store.errorMessage = String(localized: "This file could not be read.")
                    return
                }
                var changed = deck
                changed.cards += FlashcardLibrary.cards(fromDelimited: text)
                store.update(changed)
            }
            .sheet(item: $export) { file in
                ActivityView(items: [file.url])
            }
        } else {
            ContentUnavailableView("This deck was deleted.", systemImage: "rectangle.on.rectangle.slash")
        }
    }

    private func exportDeck(_ deck: FlashcardDeck) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(deck.title + ".tsv")
        do {
            try FlashcardLibrary.tsv(deck).write(to: url, atomically: true, encoding: .utf8)
            export = ExportedDeck(url: url)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private struct CardEditor: View {
    @State var card: Flashcard
    let onSave: (Flashcard) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Front") {
                    TextField("Question or term", text: $card.front, axis: .vertical)
                        .accessibilityIdentifier("card.front")
                }
                Section("Back") {
                    TextField("Answer", text: $card.back, axis: .vertical)
                        .accessibilityIdentifier("card.back")
                }
            }
            .navigationTitle("Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(card)
                        dismiss()
                    }
                    .disabled(card.front.trimmingCharacters(in: .whitespaces).isEmpty
                              || card.back.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("card.save")
                }
            }
        }
    }
}

/// Review session: tap the card to turn it, then say how well you remembered it.
struct StudySessionView: View {
    let deckID: UUID
    @State private var store = FlashcardStore.shared
    @State private var queue: [Flashcard] = []
    @State private var showsBack = false
    @State private var backFirst = false
    @State private var reviewed = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let card = queue.first {
                    Text("\(reviewed) reviewed · \(queue.count) left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showsBack.toggle() }
                    } label: {
                        let side = showsBack != backFirst ? card.back : card.front
                        Text(verbatim: side)
                            .font(.title2.weight(showsBack ? .regular : .semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 640, minHeight: 280)
                            .padding(28)
                            .background(showsBack ? Theme.accent.opacity(0.12) : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session.card")

                    if showsBack {
                        HStack(spacing: 16) {
                            grade(.hard, title: "Hard", color: .red)
                            grade(.remembered, title: "Remembered", color: .blue)
                            grade(.easy, title: "Easy", color: .green)
                        }
                    } else {
                        Text("Tap the card to see the answer.")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        SpeechReader.shared.toggle(showsBack != backFirst ? card.back : card.front)
                    } label: {
                        Label("Read Aloud", systemImage: "speaker.wave.2")
                    }
                } else {
                    ContentUnavailableView {
                        Label("All done", systemImage: "checkmark.seal")
                    } description: {
                        Text("\(reviewed) cards reviewed. Cards come back when they are due.")
                    }
                    .accessibilityIdentifier("session.done")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.backdrop)
            .navigationTitle(Text(verbatim: store.deck(id: deckID)?.title ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("session.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $backFirst) {
                        Label("Answer first", systemImage: "arrow.left.arrow.right")
                    }
                }
            }
        }
        .onAppear {
            guard let deck = store.deck(id: deckID) else { return }
            let due = deck.dueCards(at: Date())
            queue = due.isEmpty ? deck.cards.shuffled() : due
        }
    }

    private func grade(_ grade: ReviewGrade, title: LocalizedStringKey, color: Color) -> some View {
        Button {
            guard let card = queue.first else { return }
            store.review(card, in: deckID, grade: grade)
            reviewed += 1
            queue.removeFirst()
            // Forgotten cards come back at the end of this session.
            if grade == .hard { queue.append(card) }
            showsBack = false
        } label: {
            Text(title)
                .font(.headline)
                .frame(minWidth: 120, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .accessibilityIdentifier("session.\(grade.rawValue)")
    }
}

/// Study ▸ Translator and Dictionary.
struct TranslatorView: View {
    var onInsert: ((String) -> Void)?

    var body: some View {
        TextToolsSheet(
            title: "Translator and Dictionary", text: "", onInsert: onInsert,
            note: "Type or paste Arabic or English text, then Translate, Look Up or Read Aloud. Translation uses Apple's translation, which can download languages to work offline.",
            embedded: true)
    }
}
