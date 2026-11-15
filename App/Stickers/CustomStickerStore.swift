import Foundation
import Observation
import UIKit

/// The user's own stickers, imported from Photos. Kept per device in Application Support
/// (not inside any notebook); inserting one copies it into the notebook, so deleting a custom
/// sticker never changes notebooks that already use it.
@MainActor
@Observable
final class CustomStickerStore {
    struct Item: Identifiable, Hashable {
        let id: String
        let url: URL
    }

    private(set) var items: [Item] = []
    var errorMessage: String?

    @ObservationIgnored private let directory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("AgentNotes/Stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        items = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a < b
            }
            .map { Item(id: $0.deletingPathExtension().lastPathComponent, url: $0) }
    }

    /// Stores a picture as a sticker: at most 600 px on its longest side, PNG so transparency
    /// in the original (for example a cut-out) is kept.
    func add(imageData: Data) {
        guard let image = UIImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
            errorMessage = String(localized: "This picture could not be read.")
            return
        }
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let factor = min(600 / longest, 1)
        let target = CGSize(width: image.size.width * image.scale * factor, height: image.size.height * image.scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let png = rendered.pngData() else {
            errorMessage = String(localized: "This picture could not be read.")
            return
        }
        do {
            try png.write(to: directory.appendingPathComponent(UUID().uuidString + ".png"), options: .atomic)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: item.url)
        reload()
    }
}
