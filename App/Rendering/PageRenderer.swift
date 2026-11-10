import AgentNotesCore
import PDFKit
import PencilKit
import UIKit

extension PageSize {
    var cgSize: CGSize { CGSize(width: width, height: height) }
    var cgRect: CGRect { CGRect(origin: .zero, size: cgSize) }
}

/// Draws a page (background + ink) in canonical page coordinates. The same code feeds the
/// on-screen tiles, thumbnails, and PDF export, so they cannot drift apart.
enum PageRenderer {
    private static let ruleColor = UIColor(red: 0.72, green: 0.80, blue: 0.88, alpha: 1)
    private static let dividerColor = UIColor(red: 0.35, green: 0.66, blue: 0.80, alpha: 1)

    /// Expects a UIKit-style context: origin top-left, y down, 1 unit = 1 point, page at the origin.
    static func drawBackground(page: PageRecord, pdfPage: PDFPage?, in context: CGContext) {
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

    /// Renders a whole page into a bitmap whose longest side is at most `maxDimension` points.
    static func image(page: PageRecord, pdfPage: PDFPage?, ink: PKDrawing?, maxDimension: CGFloat) -> UIImage {
        let longest = max(page.size.width, page.size.height, 1)
        let scale = min(maxDimension / longest, 1)
        let target = CGSize(width: page.size.width * scale, height: page.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: scale, y: scale)
            drawBackground(page: page, pdfPage: pdfPage, in: context)
            if let ink {
                drawInk(ink, pageSize: page.size, scale: max(scale * 2, 1))
            }
        }
    }
}
