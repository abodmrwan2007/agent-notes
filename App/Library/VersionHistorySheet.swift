import SwiftUI

/// Library ▸ Version History…: earlier copies of a notebook, kept each time it was closed after changes.
struct VersionHistorySheet: View {
    let document: DocumentRow
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [NotebookVersion] = []
    @State private var pending: NotebookVersion?

    var body: some View {
        NavigationStack {
            List {
                if versions.isEmpty {
                    Text("No earlier versions yet. A version is kept each time you close this notebook after changing it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(versions) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(version.savedAt, format: .dateTime.day().month().year().hour().minute())
                                .font(.headline)
                            Text("\(version.pageCount) pages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") { pending = version }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("history.restore")
                    }
                }
            }
            .navigationTitle(Text(verbatim: document.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Restore this version?",
                isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                titleVisibility: .visible,
                presenting: pending
            ) { version in
                Button("Restore") {
                    app.library.restore(version, for: document)
                    dismiss()
                }
            } message: { _ in
                Text("The notebook goes back to this version. Its current state is kept in this list, so you can return to it.")
            }
            .onAppear { versions = app.library.versions(of: document) }
        }
    }
}
