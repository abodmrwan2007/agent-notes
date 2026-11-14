#if DEBUG
import PDFKit
import UIKit

/// Development-only fixture: a small two-page PDF with a real text layer, used by the UI tests to
/// exercise PDF import, full-text search, text selection, and a rotated page. Never shipped
/// behaviour: it only runs when the app is launched with `-uiTestSeedPDF` in a Debug build.
enum UITestFixtures {
    static let pdfTitle = "Cardiology fixture"

    static func makeCardiologyPDF() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(pdfTitle + ".pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            draw("Cardiology lecture 3", size: 26, weight: .bold, at: CGRect(x: 72, y: 60, width: 451, height: 40))
            draw(
                "The mitral valve separates the left atrium from the left ventricle. "
                    + "It has two cusps and closes at the start of systole.",
                size: 18, at: CGRect(x: 72, y: 120, width: 451, height: 120))
            draw("الصمام التاجي يفصل الأذين الأيسر عن البطين الأيسر.", size: 18,
                 at: CGRect(x: 72, y: 260, width: 451, height: 60), rightToLeft: true)

            context.beginPage()
            draw("Aortic valve", size: 26, weight: .bold, at: CGRect(x: 72, y: 60, width: 451, height: 40))
            draw("The aortic valve lies between the left ventricle and the aorta.", size: 18,
                 at: CGRect(x: 72, y: 120, width: 451, height: 80))
        }

        // The second page is rotated a quarter turn, as scanned or landscape lecture slides often are.
        guard let document = PDFDocument(data: data) else { throw CocoaError(.fileWriteUnknown) }
        document.page(at: 1)?.rotation = 90
        guard document.write(to: url) else { throw CocoaError(.fileWriteUnknown) }
        dumpExtractedText(of: url)
        return url
    }

    /// Diagnostics for the UI tests: writes the text PDFKit extracts from the fixture, with the
    /// Unicode scalars of every line, next to the screenshots (the simulator can write there).
    private static func dumpExtractedText(of url: URL) {
        guard let directory = ProcessInfo.processInfo.environment["SHOTS_DIR"],
              let pdf = PDFDocument(url: url) else { return }
        var report = ""
        for index in 0..<pdf.pageCount {
            let text = pdf.page(at: index)?.string ?? "<nil>"
            report += "=== page \(index + 1) ===\n\(text)\n--- scalars ---\n"
            for line in text.split(separator: "\n") {
                report += line.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: " ") + "\n"
            }
        }
        try? report.write(
            to: URL(fileURLWithPath: directory).appendingPathComponent("fixture-extracted-text.txt"),
            atomically: true, encoding: .utf8)
    }

    private static func draw(
        _ text: String, size: CGFloat, weight: UIFont.Weight = .regular, at rect: CGRect, rightToLeft: Bool = false
    ) {
        let paragraph = NSMutableParagraphStyle()
        // The system font's Arabic glyphs come out of PDF text extraction garbled (missing
        // dots, stray symbols); Geeza Pro keeps a correct glyph-to-character mapping.
        let font = rightToLeft
            ? (UIFont(name: "GeezaPro", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight))
            : UIFont.systemFont(ofSize: size, weight: weight)
        paragraph.alignment = rightToLeft ? .right : .left
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]).draw(with: rect, options: .usesLineFragmentOrigin, context: nil)
    }
}
#endif
