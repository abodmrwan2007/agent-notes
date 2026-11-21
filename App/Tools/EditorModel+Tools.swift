import AgentNotesCore
import CoreImage
import Foundation
import PencilKit
import UIKit
import Vision

/// Page pictures, text recognition, scans, background removal and image export.
extension EditorModel {
    /// A picture of a page. With `inkOnly`, just the handwriting on white (better for reading it).
    func renderPage(_ page: PageRecord, inkOnly: Bool, maxDimension: CGFloat) -> UIImage {
        var ink: PKDrawing?
        if case .drawing(let drawing) = loadInk(for: page.id) { ink = drawing }
        if inkOnly {
            var plain = page
            plain.template = .blank
            plain.pdf = nil
            plain.backgroundAsset = nil
            return PageRenderer.image(page: plain, pdfPage: nil, ink: ink, maxDimension: maxDimension)
        }
        let layer = objects(for: page.id)
        var pictures: [String: UIImage] = [:]
        for name in layer.objects.compactMap(\.assetFileName) {
            pictures[name] = asset(named: name)
        }
        return PageRenderer.image(
            page: page,
            pdfPage: pdfPage(for: page),
            backgroundImage: page.backgroundAsset.flatMap { asset(named: $0) },
            objects: layer,
            asset: { pictures[$0] },
            ink: ink,
            maxDimension: maxDimension)
    }

    /// Text found on the current page: handwriting only, or everything (for scans and photos).
    func recognizeTextOnCurrentPage(handwritingOnly: Bool) async throws -> String {
        guard let page = currentPage else { throw TextRecognizer.Failure.nothingFound }
        persistNow()
        let image = renderPage(page, inkOnly: handwritingOnly, maxDimension: 1600)
        return try await TextRecognizer.recognize(image)
    }

    /// Cuts the subject of the selected picture out of its background (iPadOS 17 and later).
    func removeBackgroundOfSelectedImage() async {
        guard let object = selectedObject, object.kind == .image,
              let name = object.assetFileName, let image = asset(named: name), let cgImage = image.cgImage else { return }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
            guard let result = request.results?.first else {
                alertMessage = String(localized: "No subject was found in this picture.")
                return
            }
            let buffer = try result.generateMaskedImage(
                ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let output = CIContext().createCGImage(ciImage, from: ciImage.extent),
                  let png = UIImage(cgImage: output).pngData() else { return }
            let fileName = try store.addAsset(png, fileExtension: "png", documentID: documentID)
            let aspect = Double(output.height) / Double(max(output.width, 1))
            updateSelected { item in
                item.assetFileName = fileName
                item.frame.height = item.frame.width * aspect
            }
        } catch {
            alertMessage = String(localized: "The background could not be removed.") + "\n" + error.localizedDescription
        }
    }

    /// Every page as a PNG file, for sharing as pictures.
    func exportPageImages() async throws -> [URL] {
        persistNow()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("page-images-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var urls: [URL] = []
        let base = manifest.title.isEmpty ? "Page" : manifest.title
        for (index, page) in manifest.pages.enumerated() {
            let image = renderPage(page, inkOnly: false, maxDimension: 1400)
            guard let data = image.pngData() else { continue }
            let url = folder.appendingPathComponent("\(base) \(index + 1).png")
            try data.write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }
}
