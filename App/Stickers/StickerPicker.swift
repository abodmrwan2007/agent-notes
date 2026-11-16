import PhotosUI
import SwiftUI

/// The sticker sheet opened from Insert ▸ Sticker….
struct StickerPicker: View {
    /// PNG data and the size to give it on the page.
    let onPick: (Data, CGSize) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                StickerGrid { data, size in
                    onPick(data, size)
                    dismiss()
                }
                .padding(20)
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// The built-in pack and the user's own stickers. Used by the sheet and by the editor's side
/// panel, where it stays open while writing so several stickers can be placed in a row.
struct StickerGrid: View {
    let onPick: (Data, CGSize) -> Void
    var minimumCell: CGFloat = 84

    @State private var custom = CustomStickerStore()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pendingRemoval: CustomStickerStore.Item?
    @State private var diagramLabels = MedicalDiagrams.LabelMode.preferred

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumCell, maximum: minimumCell + 26), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            diagramSection
            twemojiSection("Medical", group: .medical)
            twemojiSection("Study", group: .study)

            Text("Banners")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Sticker.allCases.filter(\.isBanner)) { sticker in
                    Button {
                        if let data = sticker.pngData() {
                            onPick(data, sticker.pageSize)
                        }
                    } label: {
                        Image(uiImage: sticker.image(scale: 2))
                            .resizable()
                            .scaledToFit()
                            .frame(height: minimumCell - 12)
                            .frame(maxWidth: .infinity)
                            .padding(6)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: sticker.accessibilityName))
                    .accessibilityIdentifier("sticker.\(sticker.rawValue)")
                }
            }

            HStack {
                Text("My Stickers")
                    .font(.headline)
                Spacer()
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label("Add from Photos", systemImage: "plus")
                }
            }
            if custom.items.isEmpty {
                Text("Add your own pictures to use them as stickers. Cut-outs with transparent backgrounds work best.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(custom.items) { item in
                        Button {
                            pick(item)
                        } label: {
                            CustomStickerThumbnail(url: item.url, height: minimumCell - 12)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingRemoval = item
                            } label: {
                                Label("Remove from My Stickers", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Text("Medical and study stickers: Twemoji by Twitter, Inc and other contributors, licensed under CC BY 4.0. Banners are original artwork made for this app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    custom.add(imageData: data)
                } else {
                    custom.errorMessage = String(localized: "This picture could not be read.")
                }
                pickedPhoto = nil
            }
        }
        .confirmationDialog(
            "Remove this sticker?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button("Remove from My Stickers", role: .destructive) { custom.remove(item) }
        } message: { _ in
            Text("Notebooks that already use it keep their copy.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { custom.errorMessage != nil }, set: { if !$0 { custom.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: custom.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var diagramSection: some View {
        Text("Labelled Diagrams")
            .font(.headline)
        Picker("Labels", selection: $diagramLabels) {
            Text("English").tag(MedicalDiagrams.LabelMode.english)
            Text("Arabic").tag(MedicalDiagrams.LabelMode.arabic)
            Text("Blank (quiz)").tag(MedicalDiagrams.LabelMode.blank)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("diagram.labels")
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCell * 1.6, maximum: minimumCell * 2.4), spacing: 12)], spacing: 12) {
            ForEach(MedicalDiagrams.all) { spec in
                Button {
                    if let rendered = MedicalDiagrams.render(spec, mode: diagramLabels) {
                        onPick(rendered.0, rendered.1)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Group {
                            if let image = MedicalDiagrams.artwork(for: spec) {
                                Image(uiImage: image).resizable().scaledToFit()
                            } else {
                                Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: minimumCell)
                        Text(verbatim: MedicalDiagrams.title(of: spec))
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("diagram.\(spec.id)")
            }
        }
        Text("Simplified study drawings made for this app, not to scale. Choose Blank to test yourself: write the names in the empty boxes.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func twemojiSection(_ title: LocalizedStringKey, group: TwemojiSticker.Group) -> some View {
        Text(title)
            .font(.headline)
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(TwemojiSticker.stickers(in: group)) { sticker in
                Button {
                    if let data = sticker.pngData() {
                        onPick(data, CGSize(width: 96, height: 96))
                    }
                } label: {
                    Group {
                        if let image = sticker.vectorImage {
                            Image(uiImage: image).resizable().scaledToFit()
                        } else {
                            Image(systemName: "questionmark.square.dashed").foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: minimumCell - 24)
                    .frame(maxWidth: .infinity, minHeight: minimumCell - 12)
                    .padding(6)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: sticker.accessibilityName))
                .accessibilityIdentifier("sticker.tw-\(sticker.code)")
            }
        }
    }

    private func pick(_ item: CustomStickerStore.Item) {
        guard let data = try? Data(contentsOf: item.url), let image = UIImage(data: data) else { return }
        // Longest side 120 pt on the page, proportions kept.
        let longest = max(image.size.width, image.size.height, 1)
        let scale = 120 / longest
        onPick(data, CGSize(width: image.size.width * scale, height: image.size.height * scale))
    }
}

private struct CustomStickerThumbnail: View {
    let url: URL
    let height: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .task(id: url) {
            image = UIImage(contentsOfFile: url.path)
        }
    }
}
