import AgentNotesCore
import PhotosUI
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
                let editor = try EditorModel(documentID: documentID, store: app.store, thumbnails: app.thumbnails)
                editor.openTarget = app.openTarget
                model = editor
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
    @State private var isPickingPhoto = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isPickingBackground = false
    @State private var pickedBackground: PhotosPickerItem?

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
        .sheet(item: $model.textEditTarget) { target in
            TextEditSheet(initialText: target.text) { text in
                model.applyText(text, to: target.selection)
            }
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $pickedPhoto, matching: .images)
        .photosPicker(isPresented: $isPickingBackground, selection: $pickedBackground, matching: .images)
        .onChange(of: pickedBackground) { _, item in
            guard let item, let pageID = model.currentPage?.id else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setBackgroundImage(data: data, pageID: pageID)
                } else {
                    model.alertMessage = String(localized: "This picture could not be read.")
                }
                pickedBackground = nil
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                HStack(spacing: 16) {
                    Text(verbatim: notice)
                    Button("Undo") {
                        model.canvas?.undo()
                        model.dismissNotice()
                    }
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("editor.notice")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.notice)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.insertImage(data: data)
                } else {
                    model.alertMessage = String(localized: "This picture could not be read.")
                }
                pickedPhoto = nil
            }
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
                Button {
                    model.insertObject(kind: .text)
                } label: {
                    Label("Text Box", systemImage: "textformat")
                }
                Button {
                    model.insertObject(kind: .stickyNote)
                } label: {
                    Label("Sticky Note", systemImage: "note.text")
                }
                Menu {
                    ForEach(ShapeKind.allCases, id: \.self) { shape in
                        Button {
                            model.insertObject(kind: .shape, shape: shape)
                        } label: {
                            Label(shape.title, systemImage: shape.symbol)
                        }
                    }
                } label: {
                    Label("Shape", systemImage: "square.on.circle")
                }
                Button {
                    isPickingPhoto = true
                } label: {
                    Label("Image from Photos", systemImage: "photo")
                }
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Insert")

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
                Button {
                    isPickingBackground = true
                } label: {
                    Label("Background Image…", systemImage: "photo.on.rectangle")
                }
                if page.backgroundAsset != nil {
                    Button {
                        model.removeBackgroundImage(pageID: page.id)
                    } label: {
                        Label("Remove Background Image", systemImage: "rectangle.slash")
                    }
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
                    model.selectTool(kind)
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
        .onChange(of: model.tool.kind) { _, kind in
            // Leaving a selection mode clears its selection.
            if kind != .objects { model.select(nil) }
            if kind != .text { model.setTextSelection(nil) }
        }
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
        } else if model.tool.kind == .objects {
            ObjectOptions(model: model)
        } else if model.tool.kind == .text {
            TextSelectionOptions(model: model)
        } else {
            Text("Circle strokes to select them, then drag to move.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Page objects

extension ShapeKind {
    var title: LocalizedStringKey {
        switch self {
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .arrow: return "Arrow"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.down.right"
        }
    }
}

/// Actions for selected PDF text, shown in the toolbar while the Select Text tool is active.
struct TextSelectionOptions: View {
    let model: EditorModel
    @Environment(AppModel.self) private var app
    @State private var didCopy = false

    var body: some View {
        if let selection = model.textSelection, !selection.text.isEmpty {
            HStack(spacing: 12) {
                Text(verbatim: "“" + String(selection.text.prefix(60)) + (selection.text.count > 60 ? "…" : "") + "”")
                    .font(.footnote)
                    .lineLimit(1)
                    .frame(maxWidth: 280, alignment: .leading)
                    .accessibilityIdentifier("text.selection")
                Button {
                    UIPasteboard.general.string = selection.text
                    didCopy = true
                } label: {
                    let title: LocalizedStringKey = didCopy ? "Copied" : "Copy"
                    Label(title, systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("text.copy")
                Button {
                    let query = selection.text
                    model.persistNow()
                    app.library.refreshRow(from: model.manifest)
                    app.showSearch(for: query)
                } label: {
                    Label("Where Else?", systemImage: "text.magnifyingglass")
                }
                .accessibilityIdentifier("text.searchNotes")
            }
            .onChange(of: selection) { _, _ in didCopy = false }
        } else if model.textSelection != nil {
            Text("No selectable text here. Scanned pages need OCR, which is not available yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Drag across the text of a PDF page to select it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Actions for the selected object, shown in the toolbar while the Objects tool is active.
struct ObjectOptions: View {
    let model: EditorModel

    private static let stickyColors = ["FFE066", "B8F2C8", "A8E0FF", "FFC2D6", "FFFFFF"]

    var body: some View {
        if let object = model.selectedObject {
            HStack(spacing: 14) {
                if object.hasText {
                    Button {
                        if let selection = model.selection { model.beginEditingText(selection) }
                    } label: {
                        Image(systemName: "character.cursor.ibeam")
                    }
                    .accessibilityLabel("Edit Text")
                    .accessibilityIdentifier("object.editText")
                }

                if object.kind != .image {
                    let palette = object.kind == .stickyNote
                        ? Self.stickyColors
                        : ToolState.presetColors.map(\.hexString)
                    ForEach(palette, id: \.self) { hex in
                        Button {
                            model.updateSelected { $0.colorHex = hex }
                        } label: {
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: hex)))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(Color.gray.opacity(0.5), lineWidth: 1))
                        }
                        .accessibilityLabel("Color")
                    }
                }

                Divider().frame(height: 24)

                Button {
                    model.duplicateSelected()
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .accessibilityLabel("Duplicate")
                .accessibilityIdentifier("object.duplicate")

                Button {
                    model.reorderSelected(toFront: true)
                } label: {
                    Image(systemName: "square.3.layers.3d.top.filled")
                }
                .accessibilityLabel("Bring to Front")

                Button {
                    model.reorderSelected(toFront: false)
                } label: {
                    Image(systemName: "square.3.layers.3d.bottom.filled")
                }
                .accessibilityLabel("Send to Back")

                Button {
                    model.rotateSelected()
                } label: {
                    Image(systemName: "rotate.right")
                }
                .accessibilityLabel("Rotate")
                .accessibilityIdentifier("object.rotate")

                Button {
                    model.toggleLockSelected()
                } label: {
                    Image(systemName: object.isLocked ? "lock.fill" : "lock.open")
                }
                .accessibilityLabel(object.isLocked ? Text("Unlock") : Text("Lock"))
                .accessibilityIdentifier("object.lock")

                Button(role: .destructive) {
                    model.deleteSelected()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete")
                .accessibilityIdentifier("object.delete")
                .disabled(object.isLocked)
            }
            .disabled(false)
        } else {
            Text("Tap an object to select it. Use Insert to add text, notes, shapes and images.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Edits the text of a text box or sticky note.
struct TextEditSheet: View {
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.title3)
                .padding(12)
                .focused($isFocused)
                .accessibilityIdentifier("object.textEditor")
                .navigationTitle("Edit Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            text = initialText
            isFocused = true
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
        controller.setInteraction(tool.kind.pageInteraction)
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
