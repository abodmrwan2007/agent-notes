import AgentNotesCore
import SwiftUI

/// Full-text search across all notes: titles, PDF text and typed text. Also answers
/// "Where have I studied this?" when opened from a text selection in the editor.
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var isSearching = false
    @State private var searchedQuery = ""
    @FocusState private var isFieldFocused: Bool

    private struct DocumentGroup: Identifiable {
        let id: UUID
        let title: String
        let hits: [SearchHit]
    }

    private var groups: [DocumentGroup] {
        var order: [UUID] = []
        var byDocument: [UUID: [SearchHit]] = [:]
        for hit in hits {
            if byDocument[hit.documentID] == nil { order.append(hit.documentID) }
            byDocument[hit.documentID, default: []].append(hit)
        }
        return order.map { id in
            DocumentGroup(id: id, title: byDocument[id]?.first?.documentTitle ?? "", hits: byDocument[id] ?? [])
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search all notes", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($isFieldFocused)
                        .accessibilityIdentifier("search.field")
                    if isSearching {
                        ProgressView()
                    }
                }
            } footer: {
                Text("Searches titles, the text of imported PDFs, and typed text. Handwriting is not searchable yet. Locked notebooks are not searched.")
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.hits) { hit in
                        Button {
                            open(hit)
                        } label: {
                            SearchHitRow(hit: hit)
                        }
                        .accessibilityIdentifier("search.hit")
                    }
                } header: {
                    Text(verbatim: group.title)
                }
            }
        }
        .overlay {
            if !searchedQuery.isEmpty, hits.isEmpty, !isSearching {
                ContentUnavailableView.search(text: searchedQuery)
            } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "Search your notes", systemImage: "text.magnifyingglass",
                    description: Text("Arabic and English, with or without diacritics."))
            }
        }
        .navigationTitle("Search")
        .task(id: query) {
            // Debounced: typing quickly cancels the previous search.
            let current = query
            guard !current.trimmingCharacters(in: .whitespaces).isEmpty else {
                hits = []
                searchedQuery = ""
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            let documents = app.library.documents(for: .all, search: "", sort: .modified)
            do {
                // A nonisolated async call: runs off the main thread, and is cancelled with this task.
                let results = try await app.textIndex.search(current, in: documents)
                guard !Task.isCancelled else { return }
                hits = results
                searchedQuery = current
            } catch {
                // Cancelled by a newer query.
            }
        }
        .onAppear {
            if !app.searchQuery.isEmpty {
                query = app.searchQuery
                app.searchQuery = ""
            } else {
                isFieldFocused = true
            }
        }
    }

    private func open(_ hit: SearchHit) {
        guard let row = app.library.documents(for: .all, search: "", sort: .modified)
            .first(where: { $0.documentID == hit.documentID }) else { return }
        let target = hit.pageID.map { OpenTarget(pageID: $0, highlightQuery: hit.source == .pdfText ? searchedQuery : nil) }
        app.open(row, target: target)
    }
}

private struct SearchHitRow: View {
    let hit: SearchHit

    private var sourceLabel: LocalizedStringKey {
        switch hit.source {
        case .title: return "Title"
        case .pdfText: return "PDF text"
        case .typedText: return "Typed text"
        }
    }

    private var excerpt: AttributedString {
        var before = AttributedString(hit.excerpt.before)
        var match = AttributedString(hit.excerpt.match)
        match.font = .body.bold()
        match.backgroundColor = Color.yellow.opacity(0.45)
        before.append(match)
        before.append(AttributedString(hit.excerpt.after))
        return before
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(sourceLabel)
                if let pageNumber = hit.pageNumber {
                    Text(verbatim: "·")
                    Text("Page \(pageNumber)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(excerpt)
                .foregroundStyle(Theme.text)
                .lineLimit(3)
                // Arabic excerpts lay out right to left, English left to right.
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 2)
    }
}
