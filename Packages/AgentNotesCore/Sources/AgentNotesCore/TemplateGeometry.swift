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
        case .planner:
            // Header band for the week's title, then seven equal day rows with a narrow
            // left column for the day's name.
            let top = plannerHeaderHeight
            let bottom = size.height - plannerBottomMargin
            let rowHeight = (bottom - top) / 7
            var lines: [TemplateLine] = []
            for row in 0...7 {
                let y = (top + Double(row) * rowHeight).rounded()
                lines.append(TemplateLine(start: PagePoint(x: 0, y: y), end: PagePoint(x: size.width, y: y), isEmphasized: true))
            }
            lines.append(TemplateLine(
                start: PagePoint(x: plannerDayColumn, y: top), end: PagePoint(x: plannerDayColumn, y: bottom), isEmphasized: true))
            for row in 0..<7 {
                let rowTop = top + Double(row) * rowHeight
                lines += horizontalLines(
                    from: rowTop + ruledSpacing, to: rowTop + rowHeight - 4, x0: plannerDayColumn, x1: size.width)
            }
            return TemplateLayout(lines: lines)
        case .narrowRuled:
            var lines = horizontalLines(from: ruledTopMargin, to: size.height, x0: 0, x1: size.width, spacing: narrowSpacing)
            lines.append(TemplateLine(
                start: PagePoint(x: narrowMargin, y: 0), end: PagePoint(x: narrowMargin, y: size.height), isEmphasized: true))
            return TemplateLayout(lines: lines)
        case .smallGrid:
            var lines = horizontalLines(from: smallGridSpacing, to: size.height, x0: 0, x1: size.width, spacing: smallGridSpacing)
            var x = smallGridSpacing
            while x < size.width {
                lines.append(TemplateLine(start: PagePoint(x: x, y: 0), end: PagePoint(x: x, y: size.height)))
                x += smallGridSpacing
            }
            return TemplateLayout(lines: lines)
        case .music:
            // Staves of five lines, `musicLineGap` apart, separated by `musicStaffGap`.
            var lines: [TemplateLine] = []
            var top = ruledTopMargin
            let staffHeight = 4 * musicLineGap
            while top + staffHeight <= size.height - 40 {
                for line in 0..<5 {
                    let y = top + Double(line) * musicLineGap
                    lines.append(TemplateLine(start: PagePoint(x: 40, y: y), end: PagePoint(x: size.width - 40, y: y)))
                }
                top += staffHeight + musicStaffGap
            }
            return TemplateLayout(lines: lines)
        case .isometric:
            // Rows `isometricSpacing × √3/2` apart, every other row shifted by half a step.
            var dots: [PagePoint] = []
            let rowHeight = isometricSpacing * 3.0.squareRoot() / 2
            var row = 0
            var y = rowHeight
            while y < size.height {
                var x = row % 2 == 0 ? isometricSpacing : isometricSpacing / 2
                while x < size.width {
                    dots.append(PagePoint(x: x, y: y))
                    x += isometricSpacing
                }
                y += rowHeight
                row += 1
            }
            return TemplateLayout(dots: dots)
        case .checklist:
            var lines = horizontalLines(from: ruledTopMargin, to: size.height, x0: 0, x1: size.width, spacing: checklistSpacing)
            // A square box sitting on each line, near the left edge.
            var y = ruledTopMargin + checklistSpacing
            while y < size.height {
                let side = checklistBox
                let left = 34.0, bottom = y - 6, top = bottom - side
                lines += [
                    TemplateLine(start: PagePoint(x: left, y: top), end: PagePoint(x: left + side, y: top), isEmphasized: true),
                    TemplateLine(start: PagePoint(x: left + side, y: top), end: PagePoint(x: left + side, y: bottom), isEmphasized: true),
                    TemplateLine(start: PagePoint(x: left + side, y: bottom), end: PagePoint(x: left, y: bottom), isEmphasized: true),
                    TemplateLine(start: PagePoint(x: left, y: bottom), end: PagePoint(x: left, y: top), isEmphasized: true)
                ]
                y += checklistSpacing
            }
            return TemplateLayout(lines: lines)
        }
    }

    public static let narrowSpacing = 22.0
    public static let narrowMargin = 64.0
    public static let smallGridSpacing = 10.0
    public static let musicLineGap = 8.0
    public static let musicStaffGap = 44.0
    public static let isometricSpacing = 20.0
    public static let checklistSpacing = 34.0
    public static let checklistBox = 14.0

    public static let plannerHeaderHeight = 90.0
    public static let plannerBottomMargin = 30.0
    public static let plannerDayColumn = 70.0

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
