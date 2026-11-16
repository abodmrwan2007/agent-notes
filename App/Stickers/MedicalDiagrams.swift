import AgentNotesCore
import UIKit

/// Labelled study diagrams (original artwork drawn for this app) that are placed on a page as a
/// picture to write on. Labels can be English, Arabic, or empty boxes for self-testing.
enum MedicalDiagrams {
    enum LabelMode: String, CaseIterable, Identifiable {
        case english
        case arabic
        case blank

        var id: String { rawValue }

        static var preferred: LabelMode {
            Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true ? .arabic : .english
        }
    }

    static let all: [DiagramSpec] = {
        guard let data = dataAsset("diagram-labels")?.data, let specs = try? DiagramSpec.decode(data) else { return [] }
        return specs
    }()

    static func title(of spec: DiagramSpec) -> String {
        LabelMode.preferred == .arabic ? spec.ar : spec.en
    }

    static func artwork(for spec: DiagramSpec) -> UIImage? {
        if let image = UIImage(named: spec.assetName, in: .main, with: nil) { return image }
        #if SWIFT_PACKAGE
        return UIImage(named: spec.assetName, in: .module, with: nil)
        #else
        return nil
        #endif
    }

    private static func dataAsset(_ name: String) -> NSDataAsset? {
        if let asset = NSDataAsset(name: name, bundle: .main) { return asset }
        #if SWIFT_PACKAGE
        return NSDataAsset(name: name, bundle: .module)
        #else
        return nil
        #endif
    }

    /// The diagram with its labels as a PNG, and its size on the page (`width` points wide;
    /// the editor shrinks it further on a narrow page).
    static func render(_ spec: DiagramSpec, mode: LabelMode, width: CGFloat = 560) -> (Data, CGSize)? {
        guard let art = artwork(for: spec), spec.width > 0, spec.height > 0 else { return nil }
        let margin = CGFloat(DiagramLayout.margin)
        let artSize = CGSize(width: spec.width, height: spec.height)
        let canvas = CGSize(width: artSize.width + 2 * margin, height: artSize.height)
        let ys = DiagramLayout.labelYs(for: spec)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let cg = context.cgContext
            art.draw(in: CGRect(origin: CGPoint(x: margin, y: 0), size: artSize))

            let ink = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
            let rightEdge: CGFloat = margin + artSize.width
            for (label, labelY) in zip(spec.labels, ys) {
                let left = label.side == .left
                let y = CGFloat(labelY)
                let anchor = CGPoint(x: margin + CGFloat(label.anchorX), y: CGFloat(label.anchorY))
                let endX: CGFloat = left ? margin - 8 : rightEdge + 8
                let end = CGPoint(x: endX, y: y)

                cg.setStrokeColor(ink.withAlphaComponent(0.8).cgColor)
                cg.setLineWidth(0.8)
                cg.move(to: anchor)
                cg.addLine(to: end)
                cg.strokePath()
                cg.setFillColor(ink.cgColor)
                cg.fillEllipse(in: CGRect(x: anchor.x - 2.4, y: anchor.y - 2.4, width: 4.8, height: 4.8))

                let boxX: CGFloat = left ? 8 : rightEdge + 12
                let box = CGRect(x: boxX, y: y - 14,
                                 width: margin - 20, height: 28)
                switch mode {
                case .blank:
                    let field = box.insetBy(dx: 0, dy: 3)
                    let path = UIBezierPath(roundedRect: field, cornerRadius: 5)
                    UIColor.white.withAlphaComponent(0.9).setFill()
                    path.fill()
                    UIColor.gray.setStroke()
                    path.lineWidth = 1
                    path.stroke()
                case .english, .arabic:
                    let text = mode == .arabic ? label.ar : label.en
                    draw(text, in: box, alignRight: left, rightToLeft: mode == .arabic, color: ink)
                }
            }
        }
        guard let data = image.pngData() else { return nil }
        return (data, CGSize(width: width, height: width * canvas.height / canvas.width))
    }

    /// One or two lines, vertically centred in `box`, shrunk if a word still does not fit.
    private static func draw(_ text: String, in box: CGRect, alignRight: Bool, rightToLeft: Bool, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignRight ? .right : .left
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        paragraph.lineBreakMode = .byWordWrapping
        var size: CGFloat = 12
        var attributed = NSAttributedString()
        var bounds = CGRect.zero
        while size >= 8 {
            attributed = NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: .medium),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ])
            bounds = attributed.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            if bounds.height <= box.height + 0.5 && bounds.width <= box.width + 0.5 { break }
            size -= 1
        }
        let rect = CGRect(x: box.minX, y: box.midY - bounds.height / 2, width: box.width, height: bounds.height)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
}
