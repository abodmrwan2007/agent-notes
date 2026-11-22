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
    @State private var historyDocument: DocumentRow?

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
            VStack(alignment: .leading, spacing: 22) {
                if showsQuickActions, !documents.isEmpty {
                    LibraryQuickActions(
                        onQuickNote: quickNote,
                        onImport: { isImporting = true },
                        onStudy: { app.sidebarSelection = .study },
                        onAtlas: { app.sidebarSelection = .atlas })
                }
                if !documents.isEmpty {
                    let sectionTitle: LocalizedStringKey = isTrash ? "In the Trash" : "Notebooks"
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(sectionTitle)
                            .font(.system(.title2, design: .rounded).weight(.heavy))
                            .foregroundStyle(LinearGradient(
                                colors: [Vivid.purple, Vivid.pink, Vivid.orange],
                                startPoint: .leading, endPoint: .trailing))
                        Text(verbatim: "\(documents.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(LinearGradient(
                                colors: [Vivid.pink, Vivid.orange], startPoint: .leading, endPoint: .trailing)))
                    }
                    .padding(.horizontal, 28)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 26)], spacing: 30) {
                    ForEach(documents) { document in
                        DocumentCard(document: document)
                            .onTapGesture { app.open(document) }
                            .contextMenu { menu(for: document) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("library.card")
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.vertical, 20)
        }
        .background(Theme.libraryBackground)
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
        .sheet(item: $historyDocument) { document in
            VersionHistorySheet(document: document)
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
            Button {
                historyDocument = document
            } label: {
                Label("Version History…", systemImage: "clock.arrow.circlepath")
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

    private var showsQuickActions: Bool {
        search.isEmpty && (item == .all || folderID != nil)
    }

    /// One tap to a fresh notebook with a cheerful cover.
    private func quickNote() {
        guard let row = library.createNotebook(template: defaultTemplate, folderID: folderID) else { return }
        if let cover = NotebookCover.allCases.randomElement() {
            library.setCover(cover, for: row)
        }
        app.open(row)
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

    private var coverStyle: NotebookCover? {
        document.coverStyle.flatMap(NotebookCover.init(rawValue:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if document.isProtected {
                    LockedCoverView()
                        .shadow(color: .black.opacity(0.22), radius: 10, x: 2, y: 8)
                } else if let coverStyle {
                    NotebookCoverView(cover: coverStyle, title: document.title)
                        .shadow(color: coverStyle.colors.last?.opacity(0.45) ?? .black.opacity(0.2), radius: 12, x: 2, y: 9)
                } else {
                    paperStack
                }
            }
            .aspectRatio(0.74, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                if document.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.orange.gradient))
                        .shadow(color: .orange.opacity(0.4), radius: 4, y: 2)
                        .padding(8)
                        .accessibilityLabel("Favorite")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if document.hasPDF, !document.isProtected {
                    Text(verbatim: "PDF")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.gradient))
                        .padding(8)
                }
            }
            .opacity(document.isTrashed ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                if !document.tags.isEmpty {
                    Text(verbatim: document.tags.map { "#" + $0 }.joined(separator: " "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Vivid.pink)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Text(document.modifiedAt, format: .dateTime.day().month().year())
                        .foregroundStyle(.secondary)
                    Text(verbatim: "·")
                        .foregroundStyle(.secondary)
                    Text("\(document.pageCount) pages")
                        .fontWeight(.semibold)
                        .foregroundStyle(Vivid.blue)
                }
                .font(.caption)
            }
            .padding(.horizontal, 2)
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

extension DocumentCard {
    /// The first page as a sheet of paper with two more sheets peeking out behind it.
    @ViewBuilder
    fileprivate var paperStack: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { layer in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: layer == 0 ? 0.90 : 0.95))
                    .rotationEffect(.degrees(layer == 0 ? 4 : -2.5))
                    .offset(x: layer == 0 ? 6 : -3, y: layer == 0 ? 4 : 2)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white)
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: document.hasPDF ? "doc.richtext" : "note.text")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.accent.opacity(0.5))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.black.opacity(0.06)))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
        }
    }
}

/// Big colourful shortcuts at the top of the library.
struct LibraryQuickActions: View {
    let onQuickNote: () -> Void
    let onImport: () -> Void
    let onStudy: () -> Void
    let onAtlas: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickActionTile(
                    title: "Quick Note", subtitle: "Start writing now", symbol: "square.and.pencil",
                    colors: [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.55, green: 0.36, blue: 0.98)],
                    action: onQuickNote)
                    .accessibilityIdentifier("library.quickNote")
                QuickActionTile(
                    title: "Import Files", subtitle: "PDFs, pictures, notebooks", symbol: "tray.and.arrow.down.fill",
                    colors: [Color(red: 1.0, green: 0.62, blue: 0.35), Color(red: 0.98, green: 0.38, blue: 0.48)],
                    action: onImport)
                    .accessibilityIdentifier("library.quickImport")
                QuickActionTile(
                    title: "Study Tools", subtitle: "Flashcards, calculator, timer", symbol: "graduationcap.fill",
                    colors: [Color(red: 0.20, green: 0.80, blue: 0.62), Color(red: 0.05, green: 0.58, blue: 0.70)],
                    action: onStudy)
                    .accessibilityIdentifier("library.quickStudy")
                QuickActionTile(
                    title: "3D Heart", subtitle: "Explore the anatomy atlas", symbol: "heart.fill",
                    colors: [Color(red: 1.0, green: 0.42, blue: 0.52), Color(red: 0.80, green: 0.18, blue: 0.40)],
                    action: onAtlas)
                    .accessibilityIdentifier("library.quickAtlas")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
        }
    }
}

struct QuickActionTile: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.22)))
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(16)
            .frame(width: 200, height: 130, alignment: .leading)
            .background(
                ZStack(alignment: .topTrailing) {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .offset(x: 40, y: -40)
                })
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: (colors.last ?? .black).opacity(0.35), radius: 12, y: 7)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Shrinks slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
