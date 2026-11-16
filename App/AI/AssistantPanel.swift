import AgentNotesCore
import SwiftUI

/// The AI tab of the side panel: summaries, flashcards and quizzes, explanations of selected
/// text, and questions about the notebook. Answers can be added to the notebook as new pages.
struct AssistantPanel: View {
    let model: EditorModel

    private enum Output {
        case text(String, truncated: Bool)
        case studySet(StudySet)
        case conversation
    }

    @State private var scope = EditorModel.AssistantScope.currentPage
    @State private var language = StudyAssistantService.language
    @State private var question = ""
    @State private var turns: [AITurn] = []
    @State private var output: Output?
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var remaining = StudyAssistantService.remainingToday
    @State private var didAdd = false
    @State private var isReady = StudyAssistantService.isReady

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !isReady {
                    setupNotice
                }
                Picker("Pages", selection: $scope) {
                    Text("This page").tag(EditorModel.AssistantScope.currentPage)
                    Text("Whole notebook").tag(EditorModel.AssistantScope.notebook)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("assistant.scope")

                Picker("Answer language", selection: $language) {
                    Text(verbatim: "العربية").tag(AILanguage.arabic)
                    Text(verbatim: "English").tag(AILanguage.english)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("assistant.language")

                HStack(spacing: 10) {
                    actionButton(title: "Summarize", symbol: "text.append", id: "assistant.summarize") {
                        run(.summarize)
                    }
                    actionButton(title: "Flashcards & quiz", symbol: "rectangle.on.rectangle.angled", id: "assistant.studySet") {
                        run(.studySet)
                    }
                }

                HStack {
                    TextField("Ask about these pages", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("assistant.question")
                        .onSubmit(ask)
                    Button(action: ask) {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Ask")
                    .accessibilityIdentifier("assistant.ask")
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                }
                Text("Tip: select text on a PDF page with the Select Text tool, then tap Explain.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                if isWorking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading your pages…")
                    }
                    .accessibilityIdentifier("assistant.working")
                }
                if let errorText {
                    Label {
                        Text(verbatim: errorText)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .foregroundStyle(.red)
                    .font(.callout)
                    .accessibilityIdentifier("assistant.error")
                }
                outputView

                footer
            }
            .padding(14)
        }
        .onAppear {
            isReady = StudyAssistantService.isReady
            remaining = StudyAssistantService.remainingToday
            consumeExplainRequest()
        }
        .onChange(of: model.explainRequest) { _, _ in consumeExplainRequest() }
        .onChange(of: language) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: SettingsKey.aiLanguage)
        }
    }

    private var setupNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI needs your Claude API key", systemImage: "key")
                .font(.headline)
            Text("Open Settings ▸ AI Assistant and paste a key from console.anthropic.com. Each request is billed to that account.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("assistant.setup")
    }

    private func actionButton(title: LocalizedStringKey, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isWorking)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var outputView: some View {
        switch output {
        case .text(let text, let truncated):
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("assistant.answer")
                if truncated {
                    Text("The answer was cut off because it was very long.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                resultButtons(text: text)
            }
        case .studySet(let set):
            StudySetView(set: set)
            resultButtons(text: set.pageText(
                cardsTitle: String(localized: "Flashcards"),
                quizTitle: String(localized: "Quiz")))
        case .conversation:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(turns.enumerated()), id: \.offset) { _, turn in
                    Text(verbatim: turn.question)
                        .font(.callout.weight(.semibold))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    Text(verbatim: turn.answer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("assistant.answer")
                }
                resultButtons(text: turns.map { "• " + $0.question + "\n" + $0.answer }.joined(separator: "\n\n"))
                Button("New conversation") {
                    turns = []
                    output = nil
                }
                .font(.footnote)
            }
        case nil:
            EmptyView()
        }
    }

    private func resultButtons(text: String) -> some View {
        let addTitle: LocalizedStringKey = didAdd ? "Added" : "Add to notebook"
        return HStack {
            Button {
                model.addTextPages(text)
                didAdd = true
            } label: {
                Label(addTitle, systemImage: didAdd ? "checkmark" : "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("assistant.addToNotebook")
            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Requests left today: \(remaining)")
                .accessibilityIdentifier("assistant.remaining")
            Text("Your pages are sent to Anthropic (Claude) to answer. Check important medical facts against your textbook.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    // MARK: Actions

    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }
        let history: [AITurn]
        if case .conversation = output { history = turns } else { history = [] }
        run(.ask(question: text, history: history))
    }

    private func consumeExplainRequest() {
        guard let request = model.explainRequest else { return }
        model.explainRequest = nil
        scope = .currentPage
        run(.explain(selection: request.text))
    }

    private func run(_ task: AITask) {
        guard !isWorking else { return }
        errorText = nil
        didAdd = false
        isWorking = true
        let pages = model.assistantPages(scope: scope)
        let language = language
        Task {
            defer {
                isWorking = false
                remaining = StudyAssistantService.remainingToday
            }
            do {
                let reply = try await StudyAssistantService.run(task, pages: pages, language: language)
                switch task {
                case .studySet:
                    if let set = StudySet.decode(reply.text) {
                        output = .studySet(set)
                    } else {
                        errorText = String(localized: "The answer could not be read. Try again.")
                    }
                case .ask(let text, let history):
                    turns = history + [AITurn(question: text, answer: reply.text)]
                    question = ""
                    output = .conversation
                case .summarize, .explain:
                    output = .text(reply.text, truncated: reply.isTruncated)
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

/// Flip cards and a multiple-choice quiz.
private struct StudySetView: View {
    let set: StudySet
    @State private var flipped: Set<Int> = []
    @State private var chosen: [Int: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !set.cards.isEmpty {
                Text("Flashcards").font(.headline)
                Text("Tap a card to see the answer.").font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(set.cards.enumerated()), id: \.offset) { index, card in
                    let isFlipped = flipped.contains(index)
                    Button {
                        if isFlipped { flipped.remove(index) } else { flipped.insert(index) }
                    } label: {
                        Text(verbatim: isFlipped ? card.back : card.front)
                            .font(isFlipped ? .callout : .callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .padding(10)
                            .background(isFlipped ? Theme.accent.opacity(0.15) : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("assistant.card.\(index)")
                }
            }
            if !set.quiz.isEmpty {
                Text("Quiz").font(.headline).padding(.top, 6)
                ForEach(Array(set.quiz.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "\(index + 1). " + item.question).font(.callout.weight(.semibold))
                        ForEach(Array(item.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                            Button {
                                chosen[index] = choiceIndex
                            } label: {
                                HStack {
                                    Image(systemName: symbol(question: index, choice: choiceIndex, answer: item.answer))
                                    Text(verbatim: choice)
                                    Spacer()
                                }
                                .padding(6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("assistant.quiz.\(index).\(choiceIndex)")
                        }
                        if chosen[index] != nil {
                            Text(verbatim: item.explanation)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func symbol(question: Int, choice: Int, answer: Int) -> String {
        guard let picked = chosen[question] else { return "circle" }
        if choice == answer { return "checkmark.circle.fill" }
        return choice == picked ? "xmark.circle.fill" : "circle"
    }
}
