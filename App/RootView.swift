import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(WhatsNewView.seenKey) private var whatsNewSeen = 0
    @State private var showsWhatsNew = false

    var body: some View {
        @Bindable var app = app
        if let documentID = app.openDocumentID {
            EditorHost(documentID: documentID)
                .id(documentID)
        } else {
            NavigationSplitView {
                SidebarView(selection: $app.sidebarSelection)
            } detail: {
                NavigationStack {
                    detail(for: app.sidebarSelection ?? .all)
                }
                .id(app.sidebarSelection)
            }
            .sheet(isPresented: $showsWhatsNew) {
                WhatsNewView()
            }
            .onAppear {
                if whatsNewSeen < WhatsNewView.contentVersion {
                    whatsNewSeen = WhatsNewView.contentVersion
                    showsWhatsNew = true
                }
            }
        }
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .search:
            SearchView()
        case .study:
            StudyHomeView()
        case .atlas:
            HeartAtlasView()
        case .community:
            PlannedAreaView(
                title: "Community",
                symbol: "person.2",
                milestone: "E",
                summary: "Opt-in sharing stays disabled until reporting, blocking and moderation services exist.")
        case .settings:
            SettingsView()
        default:
            LibraryView(item: item)
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var app
    @Binding var selection: SidebarItem?
    @State private var prompt: NamePrompt?
    @State private var folderPendingDeletion: FolderNode?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label { Text("All Notes") } icon: { IconBadge(symbol: "square.grid.2x2.fill", color: .blue) }
                    .tag(SidebarItem.all)
                Label { Text("Search") } icon: { IconBadge(symbol: "magnifyingglass", color: .indigo) }
                    .tag(SidebarItem.search)
                    .accessibilityIdentifier("sidebar.search")
                Label { Text("Recents") } icon: { IconBadge(symbol: "clock.fill", color: .teal) }
                    .tag(SidebarItem.recents)
                Label { Text("Favorites") } icon: { IconBadge(symbol: "star.fill", color: .orange) }
                    .tag(SidebarItem.favorites)
                Label { Text("Trash") } icon: { IconBadge(symbol: "trash.fill", color: .gray) }
                    .badge(app.library.trashCount)
                    .tag(SidebarItem.trash)
            }

            Section("Folders") {
                OutlineGroup(app.library.folderTree, children: \.children) { node in
                    Label { Text(verbatim: node.name) } icon: { IconBadge(symbol: "folder.fill", color: .cyan) }
                        .tag(SidebarItem.folder(node.id))
                        .contextMenu {
                            Button {
                                promptNewFolder(parentID: node.id)
                            } label: {
                                Label("New Subfolder", systemImage: "folder.badge.plus")
                            }
                            Button {
                                prompt = NamePrompt(title: "Rename Folder", initialText: node.name) { name in
                                    app.library.renameFolder(id: node.id, to: name)
                                }
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                folderPendingDeletion = node
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                }
                Button {
                    promptNewFolder(parentID: nil)
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }

            if !app.library.allTags.isEmpty {
                Section("Tags") {
                    ForEach(app.library.allTags, id: \.self) { tag in
                        Label {
                            Text(verbatim: tag)
                        } icon: {
                            IconBadge(symbol: "number", color: .pink)
                        }
                        .tag(SidebarItem.tag(tag))
                    }
                }
            }

            Section("Workspace") {
                Label { Text("Study") } icon: { IconBadge(symbol: "graduationcap.fill", color: .green) }
                    .tag(SidebarItem.study)
                    .accessibilityIdentifier("sidebar.study")
                Label { Text("Atlas") } icon: { IconBadge(symbol: "heart.fill", color: .red) }
                    .tag(SidebarItem.atlas)
                Label { Text("Community") } icon: { IconBadge(symbol: "person.2.fill", color: .purple) }
                    .tag(SidebarItem.community)
                Label { Text("Settings") } icon: { IconBadge(symbol: "gearshape.fill", color: .gray) }
                    .tag(SidebarItem.settings)
            }
        }
        .navigationTitle(Text(verbatim: AppConfig.displayName))
        .namePrompt($prompt)
        .confirmationDialog(
            "Delete this folder?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { node in
            Button("Delete Folder", role: .destructive) {
                if selection == .folder(node.id) { selection = .all }
                app.library.deleteFolder(id: node.id)
            }
        } message: { _ in
            Text("Subfolders are removed. Notes inside are kept and moved to All Notes.")
        }
    }

    private func promptNewFolder(parentID: String?) {
        prompt = NamePrompt(title: "New Folder", initialText: "") { name in
            app.library.createFolder(name: name, parentID: parentID)
        }
    }
}

/// An area of the product that is not built yet. States that plainly instead of faking a screen.
struct PlannedAreaView: View {
    let title: LocalizedStringKey
    let symbol: String
    let milestone: String
    let summary: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text("Not available in this build.")
            Text(summary)
            Text("Planned for milestone \(milestone).")
        }
        .navigationTitle(title)
    }
}
