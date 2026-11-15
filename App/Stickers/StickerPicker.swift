import PhotosUI
import SwiftUI

/// Chooses a sticker to place on the current page: the built-in pack or the user's own.
struct StickerPicker: View {
    /// PNG data and the size to give it on the page.
    let onPick: (Data, CGSize) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var custom = CustomStickerStore()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var pendingRemoval: CustomStickerStore.Item?

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Built-in")
                        .font(.headline)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Sticker.allCases) { sticker in
                            Button {
                                if let data = sticker.pngData() {
                                    onPick(data, sticker.pageSize)
                                    dismiss()
                                }
                            } label: {
                                Image(uiImage: sticker.image(scale: 2))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 72)
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
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(custom.items) { item in
                                Button {
                                    pick(item)
                                } label: {
                                    AsyncStickerThumbnail(url: item.url)
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

                    Text("The built-in stickers are original artwork made for this app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
    }

    private func pick(_ item: CustomStickerStore.Item) {
        guard let data = try? Data(contentsOf: item.url), let image = UIImage(data: data) else { return }
        // Longest side 120 pt on the page, proportions kept.
        let longest = max(image.size.width, image.size.height, 1)
        let scale = 120 / longest
        onPick(data, CGSize(width: image.size.width * scale, height: image.size.height * scale))
        dismiss()
    }
}

private struct AsyncStickerThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .task(id: url) {
            image = UIImage(contentsOfFile: url.path)
        }
    }
}
