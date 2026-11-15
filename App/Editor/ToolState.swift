import PencilKit
import SwiftUI
import UIKit

enum InkToolKind: String, CaseIterable, Identifiable {
    case pen
    case pencil
    case highlighter
    /// Fountain pen, monoline, watercolor or crayon (PencilKit's newer inks).
    case brush
    case eraser
    case lasso
    /// Select the text of PDF pages.
    case text
    /// Select, move and resize page objects (text, notes, shapes, images) instead of drawing.
    case objects

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pen: return "Pen"
        case .pencil: return "Pencil"
        case .highlighter: return "Highlighter"
        case .brush: return "Brushes"
        case .eraser: return "Eraser"
        case .lasso: return "Lasso"
        case .text: return "Select Text"
        case .objects: return "Objects"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .brush: return "paintbrush.pointed"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .text: return "character.textbox"
        case .objects: return "cursorarrow"
        }
    }

    /// The native PencilKit ink behind each drawing tool. Only native inks are offered for now.
    var inkType: PKInkingTool.InkType? {
        switch self {
        case .pen: return .pen
        case .pencil: return .pencil
        case .highlighter: return .marker
        case .brush: return .fountainPen
        case .eraser, .lasso, .text, .objects: return nil
        }
    }

    var widthRange: ClosedRange<CGFloat>? {
        inkType?.validWidthRange
    }

    var pageInteraction: PageInteraction {
        switch self {
        case .objects: return .objects
        case .text: return .text
        default: return .ink
        }
    }
}

/// The ink used by the Brushes tool. All are native PencilKit inks (iPadOS 17+), so strokes stay
/// editable and export like any other ink.
enum BrushInk: String, CaseIterable, Identifiable {
    case fountainPen
    case monoline
    case watercolor
    case crayon

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .fountainPen: return "Fountain Pen"
        case .monoline: return "Monoline"
        case .watercolor: return "Watercolor"
        case .crayon: return "Crayon"
        }
    }

    var symbol: String {
        switch self {
        case .fountainPen: return "signature"
        case .monoline: return "pencil.line"
        case .watercolor: return "paintbrush"
        case .crayon: return "scribble.variable"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .fountainPen: return .fountainPen
        case .monoline: return .monoline
        case .watercolor: return .watercolor
        case .crayon: return .crayon
        }
    }
}

enum EraserMode: String, CaseIterable, Identifiable {
    /// Removes whole strokes.
    case stroke
    /// Erases only the touched part.
    case pixel

    var id: String { rawValue }
}

/// The current writing tool. A plain value so the toolbar and the canvas cannot disagree.
struct ToolState: Equatable {
    static let presetColors: [UIColor] = [
        UIColor(red: 0.07, green: 0.13, blue: 0.27, alpha: 1),
        .black,
        UIColor(red: 0.80, green: 0.13, blue: 0.16, alpha: 1),
        UIColor(red: 0.05, green: 0.42, blue: 0.85, alpha: 1),
        UIColor(red: 0.10, green: 0.56, blue: 0.30, alpha: 1),
        UIColor(red: 0.93, green: 0.49, blue: 0.05, alpha: 1)
    ]
    static let highlighterColors: [UIColor] = [
        UIColor(red: 1.00, green: 0.90, blue: 0.20, alpha: 1),
        UIColor(red: 0.45, green: 0.93, blue: 0.55, alpha: 1),
        UIColor(red: 0.40, green: 0.85, blue: 1.00, alpha: 1),
        UIColor(red: 1.00, green: 0.60, blue: 0.75, alpha: 1)
    ]

    var kind: InkToolKind = .pen
    var eraserMode: EraserMode = .stroke
    var brushInk: BrushInk = .fountainPen
    private var colors: [InkToolKind: UIColor] = [
        .pen: ToolState.presetColors[0],
        .pencil: ToolState.presetColors[0],
        .highlighter: ToolState.highlighterColors[0]
    ]
    private var widths: [InkToolKind: CGFloat] = [.pen: 3, .pencil: 3, .highlighter: 18]

    /// Color of the active drawing tool. Each tool remembers its own.
    var color: UIColor {
        get { colors[kind] ?? ToolState.presetColors[0] }
        set { colors[kind] = newValue }
    }

    var width: CGFloat {
        get {
            let value = widths[kind] ?? 3
            guard let range = widthRange else { return value }
            return min(max(value, range.lowerBound), range.upperBound)
        }
        set { widths[kind] = newValue }
    }

    /// Valid stroke widths for the active tool (nil for tools that do not draw).
    var widthRange: ClosedRange<CGFloat>? {
        kind == .brush ? brushInk.inkType.validWidthRange : kind.widthRange
    }

    /// Colour given to newly inserted text and shapes: the current pen colour.
    var objectColorHex: String {
        (colors[.pen] ?? ToolState.presetColors[0]).hexString
    }

    var palette: [UIColor] {
        kind == .highlighter ? ToolState.highlighterColors : ToolState.presetColors
    }

    func makeTool() -> PKTool {
        switch kind {
        case .eraser:
            return PKEraserTool(eraserMode == .stroke ? .vector : .bitmap)
        case .lasso:
            return PKLassoTool()
        case .pen, .pencil, .highlighter:
            return PKInkingTool(kind.inkType ?? .pen, color: color, width: width)
        case .brush:
            return PKInkingTool(brushInk.inkType, color: color, width: width)
        case .objects, .text:
            // The ink canvas ignores touches in these modes; this tool is never used to draw.
            return PKInkingTool(.pen, color: colors[.pen] ?? ToolState.presetColors[0], width: widths[.pen] ?? 3)
        }
    }
}
