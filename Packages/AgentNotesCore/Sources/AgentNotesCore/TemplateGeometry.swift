import Foundation

public struct TemplateLine: Hashable, Sendable {
    public var start: PagePoint
    public var end: PagePoint
    /// Structural lines (Cornell cue/summary dividers) are drawn stronger than ruling.
    public var isEmphasized: Bool

    public init(start: PagePoint, end: PagePoint, isEmphasized: Bool = false) {
        self.start = start
        self.end = end
        self.isEmphasized = isEmphasized
    }
}

public struct TemplateLayout: Hashable, Sendable {
    public var lines: [TemplateLine] = []
    public var dots: [PagePoint] = []

    public init(lines: [TemplateLine] = [], dots: [PagePoint] = []) {
        self.lines = lines
        self.dots = dots
    }
}

/// Describes page templates as plain geometry in canonical page coordinates, so the on-screen
/// renderer, the PDF exporter, and other clients all draw exactly the same background.
public enum TemplateGeometry {
    public static let ruledSpacing = 28.0
    public static let ruledTopMargin = 72.0
    public static let gridSpacing = 20.0
    public static let dotSpacing = 20.0
    public static let dotRadius = 0.9
    public static let cornellCueFraction = 0.28
    public static let cornellSummaryFraction = 0.80

    public static func layout(for template: PageTemplate, size: PageSize) -> TemplateLayout {
        switch template {
        case .blank:
            return TemplateLayout()
        case .ruled:
            return TemplateLayout(lines: horizontalLines(from: ruledTopMargin, to: size.height, x0: 0, x1: size.width))
        case .grid:
            var lines = horizontalLines(
                from: gridSpacing, to: size.height, x0: 0, x1: size.width, spacing: gridSpacing)
            var x = gridSpacing
            while x < size.width {
                lines.append(TemplateLine(start: PagePoint(x: x, y: 0), end: PagePoint(x: x, y: size.height)))
                x += gridSpacing
            }
            return TemplateLayout(lines: lines)
        case .dotGrid:
            var dots: [PagePoint] = []
            var y = dotSpacing
            while y < size.height {
                var x = dotSpacing
                while x < size.width {
                    dots.append(PagePoint(x: x, y: y))
                    x += dotSpacing
                }
                y += dotSpacing
            }
            return TemplateLayout(dots: dots)
        case .cornell:
            let cueX = (size.width * cornellCueFraction).rounded()
            let summaryY = (size.height * cornellSummaryFraction).rounded()
            var lines = horizontalLines(from: ruledTopMargin, to: summaryY, x0: cueX, x1: size.width)
            lines.append(TemplateLine(
                start: PagePoint(x: cueX, y: 0), end: PagePoint(x: cueX, y: summaryY), isEmphasized: true))
            lines.append(TemplateLine(
                start: PagePoint(x: 0, y: summaryY), end: PagePoint(x: size.width, y: summaryY), isEmphasized: true))
            return TemplateLayout(lines: lines)
        }
    }

    private static func horizontalLines(
        from top: Double, to bottom: Double, x0: Double, x1: Double, spacing: Double = ruledSpacing
    ) -> [TemplateLine] {
        var lines: [TemplateLine] = []
        var y = top
        while y < bottom {
            lines.append(TemplateLine(start: PagePoint(x: x0, y: y), end: PagePoint(x: x1, y: y)))
            y += spacing
        }
        return lines
    }
}
