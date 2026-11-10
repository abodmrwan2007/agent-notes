import AgentNotesCore
import SwiftUI
import UIKit

/// Loads the document and shows either the editor or an honest failure screen.
struct EditorHost: View {
    let documentID: UUID

    @Environment(AppModel.self) private var app
    @State private var model: EditorModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let model {
                EditorScreen(model: model)
            } else if let loadError {
                ContentUnavailableView {
                    Label("This notebook could not be opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(verbatim: loadError)
                } actions: {
                    Button("Back to Library") { app.closeDocument() }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil, loadError == nil else { return }
            do {
                model = try EditorModel(documentID: documentID, store: app.store, thumbnails: app.thumbnails)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct EditorScreen: View {
    @Bindable var model: EditorModel

    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.allowsFingerDrawing) private var allowsFingerDrawing = false
    @State private var showsThumbnails = true
    @State private var prompt: NamePrompt?
    @State private var pagePendingDeletion: PageRecord?
    @State private var sharedFile: SharedFile?
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            InkToolbar(model: model, allowsFingerDrawing: $allowsFingerDrawing)
            Divider()
            HStack(spacing: 0) {
                if showsThumbnails {
                    PageSidebar(model: model) { pagePendingDeletion = $0 }
                        .frame(width: 148)
                    Divider()
                }
                EditorCanvasView(
                    model: model,
                    tool: model.tool,
                    layoutVersion: model.layoutVersion,
                    allowsFingerDrawing: allowsFingerDrawing)
            }
            // Pages scroll under the home indicator instead of leaving an empty strip.
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .overlay {
            if isExporting {
                ProgressView("Exporting…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the foreground: get everything on disk before the app can be suspended or killed.
            if phase != .active {
                model.persistNow()
                app.library.refreshRow(from: model.manifest)
            }
        }
        .namePrompt($prompt)
        .sheet(item: $sharedFile) { file in
            ActivityView(items: [file.url])
        }
        .confirmationDialog(
            "Delete this page?",
            isPresented: Binding(
                get: { pagePendingDeletion != nil },
                set: { if !$0 { pagePendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pagePendingDeletion
        ) { page in
            Button("Delete Page", role: .destructive) { model.deletePage(page.id) }
        } message: { _ in
            Text("The page and its handwriting will be removed. This cannot be undone, and it clears the undo history.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: model.alertMessage ?? "")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: close) {
                Label("Library", systemImage: "chevron.backward")
            }
            .accessibilityIdentifier("editor.back")

            Button {
                withAnimation { showsThumbnails.toggle() }
            } label: {
                Image(systemName: "sidebar.leading")
            }
            .accessibilityLabel("Page thumbnails")

            Button {
                prompt = NamePrompt(title: "Rename Notebook", initialText: model.manifest.title) { title in
                    model.rename(to: title)
                }
            } label: {
                Text(verbatim: model.manifest.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            .accessibilityHint("Rename Notebook")

            Spacer(minLength: 8)

            Text("Page \(model.currentPageIndex + 1) of \(model.manifest.pages.count)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Menu {
                ForEach(PageTemplate.allCases, id: \.self) { template in
                    Button {
                        model.addPage(template: template)
                    } label: {
                        Label(template.title, systemImage: template.symbol)
                    }
                }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
            .accessibilityLabel("Add Page")

            Menu {
                pageActions
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Page actions")

            Menu {
                Button {
                    export { try await model.exportPDF() }
                } label: {
                    Label("PDF with annotations (flattened)", systemImage: "doc.richtext")
                }
                Button {
                    export { try await model.exportPackage() }
                } label: {
                    Label("Editable notebook package", systemImage: "shippingbox")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export")
            .disabled(isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var pageActions: some View {
        if let page = model.currentPage {
            if page.pdf == nil {
                Menu {
                    ForEach(PageTemplate.allCases, id: \.self) { template in
                        Button {
                            model.setTemplate(template, forPage: page.id)
                        } label: {
                            Label(template.title, systemImage: template.symbol)
                        }
                    }
                } label: {
                    Label("Change Template", systemImage: "rectangle.dashed")
                }
            }
            Button {
                model.toggleBookmark(page.id)
            } label: {
                let title: LocalizedStringKey = page.isBookmarked ? "Remove Bookmark" : "Bookmark Page"
                Label(title, systemImage: page.isBookmarked ? "bookmark.slash" : "bookmark")
            }
            Button {
                model.duplicatePage(page.id)
            } label: {
                Label("Duplicate Page", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) {
                pagePendingDeletion = page
            } label: {
                Label("Delete Page", systemImage: "trash")
            }
            .disabled(model.manifest.pages.count <= 1)
        }
    }

    // MARK: Actions

    private func close() {
        let manifest = model.close()
        app.library.refreshRow(from: manifest)
        app.closeDocument()
    }

    private func export(_ operation: @escaping () async throws -> URL) {
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                sharedFile = SharedFile(url: try await operation())
            } catch {
                model.alertMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Toolbar

struct InkToolbar: View {
    @Bindable var model: EditorModel
    @Binding var allowsFingerDrawing: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(InkToolKind.allCases) { kind in
                let isSelected = model.tool.kind == kind
                Button {
                    model.tool.kind = kind
                } label: {
                    Image(systemName: kind.symbol)
                        .font(.title3)
                        .frame(width: 40, height: 36)
                        .background(
                            isSelected ? Theme.accent.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel(Text(kind.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }

            Divider().frame(height: 24)
            options
            Spacer(minLength: 8)

            Button {
                model.canvas?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .accessibilityLabel("Undo")

            Button {
                model.canvas?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .accessibilityLabel("Redo")

            Toggle(isOn: $allowsFingerDrawing) {
                Image(systemName: "hand.point.up.left")
            }
            .toggleStyle(.button)
            .accessibilityLabel("Draw with finger")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var options: some View {
        if let range = model.tool.kind.widthRange {
            ForEach(Array(model.tool.palette.enumerated()), id: \.offset) { _, color in
                Button {
                    model.tool.color = color
                } label: {
                    Circle()
                        .fill(Color(uiColor: color))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Theme.accent, lineWidth: model.tool.color == color ? 3 : 0))
                }
                .accessibilityLabel("Color")
                .accessibilityAddTraits(model.tool.color == color ? .isSelected : [])
            }
            ColorPicker(
                "Custom color",
                selection: Binding(
                    get: { Color(uiColor: model.tool.color) },
                    set: { model.tool.color = UIColor($0) }),
                supportsOpacity: false)
                .labelsHidden()

            Slider(
                value: Binding(get: { model.tool.width }, set: { model.tool.width = $0 }),
                in: range)
                .frame(maxWidth: 160)
                .accessibilityLabel("Thickness")
        } else if model.tool.kind == .eraser {
            Picker("Eraser mode", selection: $model.tool.eraserMode) {
                Text("Whole stroke").tag(EraserMode.stroke)
                Text("Partial").tag(EraserMode.pixel)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        } else {
            Text("Circle strokes to select them, then drag to move.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Page thumbnails

struct PageSidebar: View {
    let model: EditorModel
    let onDelete: (PageRecord) -> Void

    var body: some View {
        List {
            ForEach(Array(model.manifest.pages.enumerated()), id: \.element.id) { index, page in
                PageThumbnailCell(model: model, page: page, index: index, isCurrent: index == model.currentPageIndex)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { model.goToPage(index) }
                    .contextMenu {
                        Button {
                            model.toggleBookmark(page.id)
                        } label: {
                            let title: LocalizedStringKey = page.isBookmarked ? "Remove Bookmark" : "Bookmark Page"
                            Label(title, systemImage: page.isBookmarked ? "bookmark.slash" : "bookmark")
                        }
                        Button {
                            model.duplicatePage(page.id)
                        } label: {
                            Label("Duplicate Page", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            onDelete(page)
                        } label: {
                            Label("Delete Page", systemImage: "trash")
                        }
                        .disabled(model.manifest.pages.count <= 1)
                    }
            }
            .onMove { offsets, destination in
                model.movePages(fromOffsets: offsets, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.backdrop)
    }
}

private struct ThumbnailKey: Hashable {
    let pageID: UUID
    let revision: Int
    let template: PageTemplate
}

struct PageThumbnailCell: View {
    let model: EditorModel
    let page: PageRecord
    let index: Int
    let isCurrent: Bool

    @State private var image: UIImage?

    var body: some View {
        let revision = model.inkRevisions[page.id] ?? 0

        VStack(spacing: 4) {
            ZStack {
                Rectangle().fill(.white)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .aspectRatio(page.size.width / max(page.size.height, 1), contentMode: .fit)
            .overlay(
                Rectangle().strokeBorder(
                    isCurrent ? Theme.accent : Color.gray.opacity(0.3), lineWidth: isCurrent ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if page.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.red)
                        .padding(4)
                }
            }

            Text(index + 1, format: .number)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(index + 1)"))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .task(id: ThumbnailKey(pageID: page.id, revision: revision, template: page.template)) {
            image = await model.thumbnails.pageThumbnail(manifest: model.manifest, page: page, revision: revision)
        }
    }
}

// MARK: - UIKit bridges

struct EditorCanvasView: UIViewControllerRepresentable {
    let model: EditorModel
    let tool: ToolState
    let layoutVersion: Int
    let allowsFingerDrawing: Bool

    final class Coordinator {
        var appliedTool: ToolState?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> EditorCanvasController {
        let controller = EditorCanvasController(model: model)
        model.canvas = controller
        sync(controller, context: context)
        return controller
    }

    func updateUIViewController(_ controller: EditorCanvasController, context: Context) {
        sync(controller, context: context)
        controller.reloadIfNeeded()
    }

    private func sync(_ controller: EditorCanvasController, context: Context) {
        controller.allowsFingerDrawing = allowsFingerDrawing
        if context.coordinator.appliedTool != tool {
            context.coordinator.appliedTool = tool
            controller.apply(tool: tool.makeTool())
        }
    }
}

/// The system share sheet (AirDrop, Save to Files, other apps).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
