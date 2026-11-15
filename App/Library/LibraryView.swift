import AgentNotesCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let item: SidebarItem

    @Environment(AppModel.self) private var app
    @AppStorage(SettingsKey.librarySort) private var sortRaw = LibrarySort.modified.rawValue
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplateRaw = PageTemplate.ruled.rawValue
    @State private var search = ""
    @State private var isImporting = false
    @State private var prompt: NamePrompt?
    @State private var pendingDeletion: DocumentRow?
    @State private var isConfirmingEmptyTrash = false
    @State private var taggedDocument: DocumentRow?

    private var library: LibraryModel { app.library }
    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .modified }
    private var isTrash: Bool { item == .trash }

    private var folderID: String? {
        if case .folder(let id) = item { return id }
        return nil
    }

    private var title: Text {
        switch item {
        case .recents: return Text("Recents")
        case .favorites: return Text("Favorites")
        case .trash: return Text("Trash")
        case .folder(let id): return Text(verbatim: library.folderName(id: id) ?? "")
        case .tag(let tag): return Text(verbatim: "#" + tag)
        default: return Text("All Notes")
        }
    }

    var body: some View {
        let documents = library.documents(for: item, search: search, sort: sort)

        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 20)], spacing: 24) {
                ForEach(documents) { document in
                    DocumentCard(document: document)
                        .onTapGesture { app.open(document) }
                        .contextMenu { menu(for: document) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("library.card")
                }
            }
            .padding(24)
        }
        .background(Theme.backdrop)
        .overlay {
            if documents.isEmpty { emptyState }
        }
        .overlay {
            if let message = library.busyMessage {
                ProgressView(message)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .navigationTitle(title)
        .searchable(text: $search, prompt: Text("Search titles"))
        .toolbar { toolbar }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .image, .agentNote],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await library.importFiles(urls, folderID: folderID) }
            case .failure(let error):
                library.errorMessage = error.localizedDescription
            }
        }
        .namePrompt($prompt)
        .sheet(item: $taggedDocument) { document in
            TagEditor(document: document)
        }
        .confirmationDialog(
            "Delete permanently?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { document in
            Button("Delete Permanently", role: .destructive) {
                library.deletePermanently(document)
            }
        } message: { _ in
            Text("This notebook and its handwriting will be removed from this device. This cannot be undone.")
        }
        .confirmationDialog("Empty the trash?", isPresented: $isConfirmingEmptyTrash, titleVisibility: .visible) {
            Button("Empty Trash", role: .destructive) { library.emptyTrash() }
        } message: {
            Text("All notebooks in the trash will be removed from this device. This cannot be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: library.errorMessage ?? "")
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var emptyState: some View {
        if !search.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            switch item {
            case .trash:
                ContentUnavailableView(
                    "Trash is empty", systemImage: "trash",
                    description: Text("Notebooks you delete stay here until you remove them permanently."))
            case .favorites:
                ContentUnavailableView(
                    "No favorites yet", systemImage: "star",
                    description: Text("Touch and hold a notebook and choose Favorite."))
            case .recents:
                ContentUnavailableView(
                    "Nothing opened yet", systemImage: "clock",
                    description: Text("Notebooks you open will appear here."))
            default:
                ContentUnavailableView {
                    Label("No notebooks here", systemImage: "square.and.pencil")
                } description: {
                    Text("Create a notebook or import a PDF to start writing.")
                } actions: {
                    Button("New Notebook") { createNotebook(defaultTemplate) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("library.empty.newNotebook")
                    Button("Import PDF") { isImporting = true }
                }
            }
        }
    }

    private var defaultTemplate: PageTemplate {
        PageTemplate(rawValue: defaultTemplateRaw) ?? .ruled
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if isTrash {
                Button("Empty Trash", role: .destructive) { isConfirmingEmptyTrash = true }
                    .disabled(library.trashCount == 0)
            } else {
                Menu {
                    ForEach(PageTemplate.allCases, id: \.self) { template in
                        Button {
                            createNotebook(template)
                        } label: {
                            Label(template.title, systemImage: template.symbol)
                        }
                    }
                } label: {
                    Label("New Notebook", systemImage: "plus")
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }

            Menu {
                Picker("Sort by", selection: $sortRaw) {
                    Text("Date Modified").tag(LibrarySort.modified.rawValue)
                    Text("Date Created").tag(LibrarySort.created.rawValue)
                    Text("Title").tag(LibrarySort.title.rawValue)
                }
            } label: {
                Label("Sort by", systemImage: "arrow.up.arrow.down")
            }
            .disabled(item == .recents)
        }
    }

    @ViewBuilder
    private func menu(for document: DocumentRow) -> some View {
        if document.isTrashed {
            Button {
                library.restore(document)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                pendingDeletion = document
            } label: {
                Label("Delete Permanently", systemImage: "trash.slash")
            }
        } else {
            Button {
                app.open(document)
            } label: {
                Label("Open", systemImage: "square.and.pencil")
            }
            Button {
                prompt = NamePrompt(title: "Rename Notebook", initialText: document.title) { name in
                    library.rename(document, to: name)
                }
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                library.toggleFavorite(document)
            } label: {
                let favoriteTitle: LocalizedStringKey = document.isFavorite ? "Remove Favorite" : "Favorite"
                Label(favoriteTitle, systemImage: document.isFavorite ? "star.slash" : "star")
            }
            Button {
                Task { await library.duplicate(document) }
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button {
                taggedDocument = document
            } label: {
                Label("Tags…", systemImage: "tag")
            }
            Menu {
                Button("First Page") { library.setCover(nil, for: document) }
                ForEach(NotebookCover.allCases) { cover in
                    Button {
                        library.setCover(cover, for: document)
                    } label: {
                        Text(cover.title)
                    }
                }
            } label: {
                Label("Cover", systemImage: "book.closed")
            }
            Button {
                Task { await library.setProtected(!document.isProtected, for: document) }
            } label: {
                let title: LocalizedStringKey = document.isProtected ? "Remove Lock" : "Lock…"
                Label(title, systemImage: document.isProtected ? "lock.open" : "lock")
            }
            Menu {
                Button("All Notes (no folder)") { library.move(document, toFolder: nil) }
                ForEach(library.folderPaths, id: \.id) { entry in
                    Button(entry.path) { library.move(document, toFolder: entry.id) }
                }
            } label: {
                Label("Move to", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                library.moveToTrash(document)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    private func createNotebook(_ template: PageTemplate) {
        if let row = library.createNotebook(template: template, folderID: folderID) {
            app.open(row)
        }
    }
}

struct DocumentCard: View {
    let document: DocumentRow

    @Environment(AppModel.self) private var app
    @State private var cover: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(.white)
                if document.isProtected {
                    LockedCoverView()
                } else if let style = document.coverStyle.flatMap(NotebookCover.init(rawValue:)) {
                    NotebookCoverView(cover: style, title: document.title)
                } else if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                } else {
                    Image(systemName: document.hasPDF ? "doc.richtext" : "note.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(.quaternary))
            .overlay(alignment: .topTrailing) {
                if document.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .padding(8)
                        .accessibilityLabel("Favorite")
                }
            }
            .opacity(document.isTrashed ? 0.6 : 1)

            Text(verbatim: document.title)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .lineLimit(2)

            if !document.tags.isEmpty {
                Text(verbatim: document.tags.map { "#" + $0 }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(document.modifiedAt, format: .dateTime.day().month().year())
                Text(verbatim: "·")
                Text("\(document.pageCount) pages")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .task(id: document.modifiedAt) {
            // A locked notebook's pages are never rendered in the library.
            guard !document.isProtected, let id = document.documentID else { return }
            cover = await app.thumbnails.cover(for: id, stamp: document.modifiedAt)
        }
    }
}

/// Adds and removes tags on one notebook. Existing tags from the whole library are offered.
struct TagEditor: View {
    let document: DocumentRow

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var newTag = ""

    private var choices: [String] {
        Array(Set(app.library.allTags).union(selected))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("New tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)
                            .accessibilityIdentifier("tags.newTag")
                        Button("Add", action: addTag)
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if !choices.isEmpty {
                    Section("Tags") {
                        ForEach(choices, id: \.self) { tag in
                            Button {
                                if !selected.insert(tag).inserted { selected.remove(tag) }
                            } label: {
                                HStack {
                                    Text(verbatim: "#" + tag).foregroundStyle(Theme.text)
                                    Spacer()
                                    if selected.contains(tag) {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: document.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        addTag()
                        app.library.setTags(Array(selected), for: document)
                        dismiss()
                    }
                    .accessibilityIdentifier("tags.done")
                }
            }
        }
        .onAppear { selected = Set(document.tags) }
    }

    private func addTag() {
        // "#anatomy" and "anatomy" are the same tag.
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !tag.isEmpty else { return }
        selected.insert(tag)
        newTag = ""
    }
}
