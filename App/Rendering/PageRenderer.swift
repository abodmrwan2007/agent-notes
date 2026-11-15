import AgentNotesCore
import PDFKit
import PencilKit
import UIKit

extension PageSize {
    var cgSize: CGSize { CGSize(width: width, height: height) }
    var cgRect: CGRect { CGRect(origin: .zero, size: cgSize) }
}

extension PageRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

extension UIColor {
    /// "RRGGBB" (an optional leading # is ignored). Anything unreadable becomes black.
    convenience init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1)
    }

    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ component: CGFloat) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "%02lX%02lX%02lX", byte(red), byte(green), byte(blue))
    }
}

/// Draws a page (background + ink) in canonical page coordinates. The same code feeds the
/// on-screen tiles, thumbnails, and PDF export, so they cannot drift apart.
enum PageRenderer {
    private static let ruleColor = UIColor(red: 0.72, green: 0.80, blue: 0.88, alpha: 1)
    private static let dividerColor = UIColor(red: 0.35, green: 0.66, blue: 0.80, alpha: 1)

    /// Expects a UIKit-style context: origin top-left, y down, 1 unit = 1 point, page at the origin.
    static func drawBackground(page: PageRecord, pdfPage: PDFPage?, backgroundImage: UIImage? = nil, in context: CGContext) {
        let rect = page.size.cgRect
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        if let pdfPage {
            // PDFKit draws in PDF space (y up) and applies the page's crop box and rotation itself,
            // placing the displayed page at the origin. Flip to match our top-left convention.
            context.saveGState()
            context.translateBy(x: 0, y: rect.height)
            context.scaleBy(x: 1, y: -1)
            pdfPage.draw(with: .cropBox, to: context)
            context.restoreGState()
        } else if let backgroundImage, backgroundImage.size.width > 0, backgroundImage.size.height > 0 {
            // Custom paper: fills the page (aspect fill, centred), replacing the template.
            let scale = max(rect.width / backgroundImage.size.width, rect.height / backgroundImage.size.height)
            let size = CGSize(width: backgroundImage.size.width * scale, height: backgroundImage.size.height * scale)
            let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
            context.saveGState()
            context.clip(to: rect)
            UIGraphicsPushContext(context)
            backgroundImage.draw(in: CGRect(origin: origin, size: size))
            UIGraphicsPopContext()
            context.restoreGState()
        } else {
            drawTemplate(page.template, size: page.size, in: context)
        }
    }

    static func drawTemplate(_ template: PageTemplate, size: PageSize, in context: CGContext) {
        let layout = TemplateGeometry.layout(for: template, size: size)
        guard !layout.lines.isEmpty || !layout.dots.isEmpty else { return }
        context.saveGState()

        for emphasized in [false, true] {
            let lines = layout.lines.filter { $0.isEmphasized == emphasized }
            guard !lines.isEmpty else { continue }
            context.setStrokeColor((emphasized ? dividerColor : ruleColor).cgColor)
            context.setLineWidth(emphasized ? 1 : 0.6)
            for line in lines {
                context.move(to: CGPoint(x: line.start.x, y: line.start.y))
                context.addLine(to: CGPoint(x: line.end.x, y: line.end.y))
            }
            context.strokePath()
        }

        if !layout.dots.isEmpty {
            let radius = TemplateGeometry.dotRadius
            context.setFillColor(ruleColor.cgColor)
            for dot in layout.dots {
                context.addEllipse(in: CGRect(
                    x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2))
            }
            context.fillPath()
        }
        context.restoreGState()
    }

    /// Ink is rasterized by PencilKit. Forced to the light appearance so dark ink stays dark on
    /// white paper regardless of the device theme.
    static func drawInk(_ drawing: PKDrawing, pageSize: PageSize, scale: CGFloat) {
        guard !drawing.strokes.isEmpty else { return }
        let rect = pageSize.cgRect
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        image?.draw(in: rect)
    }

    // MARK: Page objects (text, sticky notes, shapes, images)

    private static let stickyDefaultColor = "FFE066"
    private static let inkDefaultColor = "122145"

    /// Draws into the CURRENT UIKit graphics context, in page coordinates. Used by the editor,
    /// thumbnails and PDF export alike. In PDF export text stays real, selectable text.
    static func drawObjects(_ layer: PageObjectLayer, image: (String) -> UIImage?) {
        guard !layer.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        for object in layer.objects {
            context.saveGState()
            let rect = object.frame.cgRect
            if object.rotation != 0 {
                context.translateBy(x: rect.midX, y: rect.midY)
                context.rotate(by: CGFloat(object.rotation) * .pi / 180)
                context.translateBy(x: -rect.midX, y: -rect.midY)
            }
            switch object.kind {
            case .stickyNote:
                drawStickyNote(object, in: rect, context: context)
            case .text:
                drawText(object.text ?? "", in: rect.insetBy(dx: 4, dy: 4),
                         size: object.fontSize ?? 18, color: UIColor(hex: object.colorHex ?? inkDefaultColor))
            case .image:
                if let name = object.assetFileName, let picture = image(name) {
                    picture.draw(in: rect)
                } else {
                    // The image file is missing: say so on the page instead of drawing nothing.
                    UIColor(white: 0.92, alpha: 1).setFill()
                    context.fill(rect)
                    UIColor(white: 0.6, alpha: 1).setStroke()
                    let cross = UIBezierPath(rect: rect)
                    cross.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    cross.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    cross.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                    cross.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    cross.lineWidth = 1
                    cross.stroke()
                }
            case .shape:
                drawShape(object.shape ?? .rectangle, in: rect,
                          color: UIColor(hex: object.colorHex ?? inkDefaultColor),
                          lineWidth: CGFloat(object.lineWidth ?? 2))
            }
            context.restoreGState()
        }
    }

    private static func drawStickyNote(_ object: PageObject, in rect: CGRect, context: CGContext) {
        let style = object.noteStyle ?? .plain
        let paperColor = UIColor(hex: object.colorHex ?? stickyDefaultColor)

        // Soft shadow so the note sits on the page.
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        let paper = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        paperColor.setFill()
        paper.fill()
        context.restoreGState()

        let lineColor = UIColor.black.withAlphaComponent(0.10)
        var textTop = rect.minY + 10
        switch style {
        case .lined:
            lineColor.setStroke()
            var y = rect.minY + 34
            while y < rect.maxY - 8 {
                let line = UIBezierPath()
                line.move(to: CGPoint(x: rect.minX + 8, y: y))
                line.addLine(to: CGPoint(x: rect.maxX - 8, y: y))
                line.lineWidth = 0.7
                line.stroke()
                y += 22
            }
            textTop = rect.minY + 14
        case .grid:
            lineColor.setStroke()
            let grid = UIBezierPath()
            var x = rect.minX + 14
            while x < rect.maxX - 4 { grid.move(to: CGPoint(x: x, y: rect.minY + 4)); grid.addLine(to: CGPoint(x: x, y: rect.maxY - 4)); x += 14 }
            var y = rect.minY + 14
            while y < rect.maxY - 4 { grid.move(to: CGPoint(x: rect.minX + 4, y: y)); grid.addLine(to: CGPoint(x: rect.maxX - 4, y: y)); y += 14 }
            grid.lineWidth = 0.5
            grid.stroke()
        case .taped:
            // A translucent strip of tape, slightly tilted, across the top edge.
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.minY + 2)
            context.rotate(by: -0.06)
            let tape = UIBezierPath(rect: CGRect(x: -rect.width * 0.22, y: -11, width: rect.width * 0.44, height: 22))
            UIColor(white: 0.92, alpha: 0.75).setFill()
            tape.fill()
            context.restoreGState()
            textTop = rect.minY + 22
        case .pinned:
            let pin = CGRect(x: rect.midX - 8, y: rect.minY + 4, width: 16, height: 16)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 1, height: 2), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            UIColor(red: 0.88, green: 0.22, blue: 0.25, alpha: 1).setFill()
            UIBezierPath(ovalIn: pin).fill()
            context.restoreGState()
            UIColor.white.withAlphaComponent(0.7).setFill()
            UIBezierPath(ovalIn: CGRect(x: pin.minX + 4, y: pin.minY + 3, width: 5, height: 4)).fill()
            textTop = rect.minY + 26
        case .plain:
            break
        }

        let textRect = CGRect(x: rect.minX + 10, y: textTop, width: rect.width - 20, height: rect.maxY - textTop - 8)
        drawText(object.text ?? "", in: textRect, size: object.fontSize ?? 15, color: UIColor(hex: inkDefaultColor))
    }

    private static func drawText(_ text: String, in rect: CGRect, size: Double, color: UIColor) {
        guard !text.isEmpty, rect.width > 1, rect.height > 1 else { return }
        let paragraph = NSMutableParagraphStyle()
        // Natural alignment and direction: Arabic lines start on the right, English on the left.
        paragraph.alignment = .natural
        paragraph.baseWritingDirection = .natural
        paragraph.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: CGFloat(size)),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    private static func drawShape(_ shape: ShapeKind, in rect: CGRect, color: UIColor, lineWidth: CGFloat) {
        let path: UIBezierPath
        switch shape {
        case .rectangle:
            path = UIBezierPath(rect: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        case .ellipse:
            path = UIBezierPath(ovalIn: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        case .line, .arrow:
            let start = CGPoint(x: rect.minX, y: rect.minY)
            let end = CGPoint(x: rect.maxX, y: rect.maxY)
            path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: end)
            if shape == .arrow {
                let angle = atan2(end.y - start.y, end.x - start.x)
                let head = max(10, lineWidth * 4)
                for side in [CGFloat.pi * 5 / 6, -CGFloat.pi * 5 / 6] {
                    path.move(to: end)
                    path.addLine(to: CGPoint(
                        x: end.x + head * cos(angle + side), y: end.y + head * sin(angle + side)))
                }
            }
            path.lineCapStyle = .round
        }
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    /// Renders a whole page into a bitmap whose longest side is at most `maxDimension` points.
    static func image(
        page: PageRecord,
        pdfPage: PDFPage?,
        backgroundImage: UIImage? = nil,
        objects: PageObjectLayer = PageObjectLayer(),
        asset: (String) -> UIImage? = { _ in nil },
        ink: PKDrawing?,
        maxDimension: CGFloat
    ) -> UIImage {
        let longest = max(page.size.width, page.size.height, 1)
        let scale = min(maxDimension / longest, 1)
        let target = CGSize(width: page.size.width * scale, height: page.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: scale, y: scale)
            drawBackground(page: page, pdfPage: pdfPage, backgroundImage: backgroundImage, in: context)
            // Stacking order everywhere: background, then objects, then handwriting on top.
            drawObjects(objects, image: asset)
            if let ink {
                drawInk(ink, pageSize: page.size, scale: max(scale * 2, 1))
            }
        }
    }
}
