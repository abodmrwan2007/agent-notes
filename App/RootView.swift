import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var selection: SidebarItem? = .all

    var body: some View {
        if let documentID = app.openDocumentID {
            EditorHost(documentID: documentID)
                .id(documentID)
        } else {
            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
                NavigationStack {
                    detail(for: selection ?? .all)
                }
            }
        }
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .study:
            PlannedAreaView(
                title: "Study",
                symbol: "graduationcap",
                milestone: "B–C",
                summary: "Flashcards, quizzes, focus timer, scientific calculators and the periodic table will live here.")
        case .atlas:
            PlannedAreaView(
                title: "Atlas",
                symbol: "heart.text.square",
                milestone: "D",
                summary: "The interactive anatomy atlas starts with a heart module. It needs reviewed 3D assets that do not exist yet.")
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
                Label("All Notes", systemImage: "square.grid.2x2").tag(SidebarItem.all)
                Label("Recents", systemImage: "clock").tag(SidebarItem.recents)
                Label("Favorites", systemImage: "star").tag(SidebarItem.favorites)
                Label("Trash", systemImage: "trash")
                    .badge(app.library.trashCount)
                    .tag(SidebarItem.trash)
            }

            Section("Folders") {
                OutlineGroup(app.library.folderTree, children: \.children) { node in
                    Label(node.name, systemImage: "folder")
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

            Section("Workspace") {
                Label("Study", systemImage: "graduationcap").tag(SidebarItem.study)
                Label("Atlas", systemImage: "heart.text.square").tag(SidebarItem.atlas)
                Label("Community", systemImage: "person.2").tag(SidebarItem.community)
                Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
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
