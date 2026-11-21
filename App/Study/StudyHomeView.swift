import Observation
import SwiftUI

enum StudyTool: String, CaseIterable, Identifiable, Hashable {
    case calculator
    case graph
    case periodicTable
    case focusTimer
    case flashcards
    case translator

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .calculator: return "Scientific Calculator"
        case .graph: return "Graphing Calculator"
        case .periodicTable: return "Periodic Table"
        case .focusTimer: return "Focus Timer"
        case .flashcards: return "Flashcards"
        case .translator: return "Translator and Dictionary"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .calculator: return "Trigonometry, logarithms, powers and factorials, computed on this device."
        case .graph: return "Plot up to three functions of x. Drag to move, pinch to zoom."
        case .periodicTable: return "All 118 elements with symbols, masses and groups."
        case .focusTimer: return "Work and break sessions that keep counting in the background."
        case .flashcards: return "Decks you make or save from the AI, reviewed when they are due."
        case .translator: return "Translate, look up and hear Arabic and English text."
        }
    }

    var symbol: String {
        switch self {
        case .calculator: return "function"
        case .graph: return "chart.xyaxis.line"
        case .periodicTable: return "tablecells"
        case .focusTimer: return "timer"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .translator: return "character.bubble"
        }
    }

    @ViewBuilder
    func destination(compact: Bool, insert: ((String) -> Void)? = nil) -> some View {
        switch self {
        case .calculator: CalculatorView(compact: compact, onInsert: insert)
        case .graph: GraphView(compact: compact)
        case .periodicTable: PeriodicTableView()
        case .focusTimer: FocusTimerView()
        case .flashcards: FlashcardDecksView()
        case .translator: TranslatorView(onInsert: insert)
        }
    }
}

/// Tools from the product plan that are not built yet. Listed so the plan is visible, never tappable.
private struct PlannedTool: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let reason: LocalizedStringKey
    let symbol: String

    static let all: [PlannedTool] = [
        PlannedTool(
            id: "solver", title: "Step-by-step Math Solver",
            reason: "Needs a symbolic engine or a verified AI explanation.", symbol: "list.number"),
        PlannedTool(
            id: "handwriting", title: "Handwriting Calculator",
            reason: "Needs handwriting recognition, which is not chosen yet.", symbol: "scribble"),
        PlannedTool(
            id: "games", title: "Study Games",
            reason: "Needs reviewed study content.", symbol: "gamecontroller")
    ]
}

/// The user's arrangement of the tools panel: order, favorites and removed tools.
@MainActor
@Observable
final class StudyToolsStore {
    private(set) var order: [StudyTool]
    private(set) var favorites: Set<StudyTool>
    private(set) var removed: Set<StudyTool>

    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let orderKey = "studyTools.order"
    private static let favoritesKey = "studyTools.favorites"
    private static let removedKey = "studyTools.removed"

    init() {
        let saved = (defaults.stringArray(forKey: Self.orderKey) ?? []).compactMap(StudyTool.init(rawValue:))
        // Tools added in a later version appear at the end of a saved order.
        order = saved + StudyTool.allCases.filter { !saved.contains($0) }
        favorites = Set((defaults.stringArray(forKey: Self.favoritesKey) ?? []).compactMap(StudyTool.init(rawValue:)))
        removed = Set((defaults.stringArray(forKey: Self.removedKey) ?? []).compactMap(StudyTool.init(rawValue:)))
    }

    func visibleTools(favoritesOnly: Bool) -> [StudyTool] {
        order.filter { !removed.contains($0) && (!favoritesOnly || favorites.contains($0)) }
    }

    var removedTools: [StudyTool] {
        order.filter { removed.contains($0) }
    }

    func toggleFavorite(_ tool: StudyTool) {
        if !favorites.insert(tool).inserted { favorites.remove(tool) }
        save()
    }

    func remove(_ tool: StudyTool) {
        removed.insert(tool)
        save()
    }

    func restore(_ tool: StudyTool) {
        removed.remove(tool)
        save()
    }

    /// `offsets` and `destination` refer to the visible list; they are mapped back to the full order.
    func move(visible: [StudyTool], fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var reordered = visible
        reordered.move(fromOffsets: offsets, toOffset: destination)
        var iterator = reordered.makeIterator()
        let shown = Set(visible)
        order = order.map { shown.contains($0) ? (iterator.next() ?? $0) : $0 }
        save()
    }

    private func save() {
        defaults.set(order.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(favorites.map(\.rawValue), forKey: Self.favoritesKey)
        defaults.set(removed.map(\.rawValue), forKey: Self.removedKey)
    }
}

struct StudyHomeView: View {
    @State private var store = StudyToolsStore()
    @State private var favoritesOnly = false

    var body: some View {
        let tools = store.visibleTools(favoritesOnly: favoritesOnly)

        List {
            Section {
                ForEach(tools) { tool in
                    NavigationLink(value: tool) {
                        StudyToolRow(tool: tool, isFavorite: store.favorites.contains(tool))
                    }
                    .accessibilityIdentifier("study.tool.\(tool.rawValue)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.remove(tool)
                        } label: {
                            Label("Remove from Panel", systemImage: "minus.circle")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        favoriteButton(for: tool)
                    }
                    .contextMenu {
                        favoriteButton(for: tool)
                        Button(role: .destructive) {
                            store.remove(tool)
                        } label: {
                            Label("Remove from Panel", systemImage: "minus.circle")
                        }
                    }
                }
                .onMove { offsets, destination in
                    store.move(visible: tools, fromOffsets: offsets, toOffset: destination)
                }
            } header: {
                Text("Tools")
            } footer: {
                if tools.isEmpty {
                    let message: LocalizedStringKey = favoritesOnly
                        ? "No favorite tools yet. Swipe a tool to the right to add it."
                        : "All tools were removed. Add them back below."
                    Text(message)
                }
            }

            if !store.removedTools.isEmpty {
                Section("Removed") {
                    ForEach(store.removedTools) { tool in
                        HStack {
                            Label(tool.title, systemImage: tool.symbol)
                            Spacer()
                            Button("Add Back") { store.restore(tool) }
                        }
                    }
                }
            }

            Section {
                ForEach(PlannedTool.all) { tool in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(tool.title, systemImage: tool.symbol)
                        Text(tool.reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Not available yet")
            }
        }
        .navigationTitle("Study")
        .navigationDestination(for: StudyTool.self) { tool in
            tool.destination(compact: false)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $favoritesOnly) {
                    Label("Favorites Only", systemImage: favoritesOnly ? "star.fill" : "star")
                }
                EditButton()
            }
        }
    }

    private func favoriteButton(for tool: StudyTool) -> some View {
        let isFavorite = store.favorites.contains(tool)
        let title: LocalizedStringKey = isFavorite ? "Remove Favorite" : "Favorite"
        return Button {
            store.toggleFavorite(tool)
        } label: {
            Label(title, systemImage: isFavorite ? "star.slash" : "star")
        }
        .tint(.yellow)
    }
}

private struct StudyToolRow: View {
    let tool: StudyTool
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tool.symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text(tool.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 4)
    }
}
