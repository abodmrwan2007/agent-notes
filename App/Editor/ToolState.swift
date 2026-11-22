import PencilKit
import SwiftUI
import UIKit

enum InkToolKind: String, CaseIterable, Identifiable {
    case pen
    case fountain
    case pencil
    case highlighter
    /// Watercolor and brush pen.
    case brush
    case eraser
    case lasso
    /// Circle handwriting or printed text to translate it, look it up or search for it.
    case lookup
    /// Select the text of PDF pages.
    case text
    /// Select, move and resize page objects (text, notes, shapes, images) instead of drawing.
    case objects

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pen: return "Pen"
        case .fountain: return "Fountain Pen"
        case .pencil: return "Pencil"
        case .highlighter: return "Highlighter"
        case .brush: return "Brushes"
        case .eraser: return "Eraser"
        case .lasso: return "Lasso"
        case .lookup: return "Circle to Translate"
        case .text: return "Select Text"
        case .objects: return "Objects"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .fountain: return "signature"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .brush: return "paintbrush.pointed"
        case .eraser: return "eraser.fill"
        case .lasso: return "lasso"
        case .lookup: return "character.magnify"
        case .text: return "character.textbox"
        case .objects: return "cursorarrow"
        }
    }

    /// Colour of the tool's button, so every tool is easy to tell apart.
    var tint: Color {
        switch self {
        case .eraser: return Vivid.pink
        case .lasso: return Vivid.purple
        case .lookup: return Vivid.orange
        case .text: return Vivid.blue
        case .objects: return Vivid.indigo
        default: return Vivid.teal
        }
    }

    /// Writing tools (drawn as pens in the toolbar).
    var isPen: Bool { !styles.isEmpty }

    /// The pen types offered for this tool (empty for tools that do not write).
    var styles: [PenStyle] {
        PenStyle.allCases.filter { $0.family == self }
    }

    var pageInteraction: PageInteraction {
        switch self {
        case .objects: return .objects
        case .text: return .text
        default: return .ink
        }
    }
}

/// A kind of pen. Every one is a native PencilKit ink (iPadOS 17+), so strokes stay editable,
/// searchable and export like any other ink; some differ only in their starting thickness.
enum PenStyle: String, CaseIterable, Identifiable {
    case ballpoint
    case fineliner
    case fountainPen
    case calligraphy
    case pencil
    case crayon
    case marker
    case watercolor
    case brushPen

    var id: String { rawValue }

    var family: InkToolKind {
        switch self {
        case .ballpoint, .fineliner: return .pen
        case .fountainPen, .calligraphy: return .fountain
        case .pencil, .crayon: return .pencil
        case .marker: return .highlighter
        case .watercolor, .brushPen: return .brush
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .ballpoint: return "Ballpoint"
        case .fineliner: return "Fineliner"
        case .fountainPen: return "Fountain Pen"
        case .calligraphy: return "Calligraphy"
        case .pencil: return "Pencil"
        case .crayon: return "Crayon"
        case .marker: return "Marker"
        case .watercolor: return "Watercolor"
        case .brushPen: return "Brush Pen"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .ballpoint: return .pen
        case .fineliner: return .monoline
        case .fountainPen, .calligraphy, .brushPen: return .fountainPen
        case .pencil: return .pencil
        case .crayon: return .crayon
        case .marker: return .marker
        case .watercolor: return .watercolor
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .ballpoint: return 3
        case .fineliner: return 2
        case .fountainPen: return 4
        case .calligraphy: return 12
        case .pencil: return 3
        case .crayon: return 10
        case .marker: return 18
        case .watercolor: return 20
        case .brushPen: return 9
        }
    }

    var validWidthRange: ClosedRange<CGFloat> { inkType.validWidthRange }
}

/// Bright colours used across the interface (tool buttons, badges, headers).
enum Vivid {
    static let pink = Color(red: 0.96, green: 0.27, blue: 0.53)
    static let red = Color(red: 0.93, green: 0.26, blue: 0.24)
    static let orange = Color(red: 0.98, green: 0.55, blue: 0.13)
    static let yellow = Color(red: 0.98, green: 0.76, blue: 0.10)
    static let green = Color(red: 0.20, green: 0.74, blue: 0.40)
    static let teal = Color(red: 0.00, green: 0.66, blue: 0.72)
    static let blue = Color(red: 0.13, green: 0.47, blue: 0.96)
    static let indigo = Color(red: 0.36, green: 0.36, blue: 0.90)
    static let purple = Color(red: 0.62, green: 0.32, blue: 0.90)

    static let rainbow: [Color] = [pink, orange, yellow, green, teal, blue, purple]
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
        UIColor(white: 0.45, alpha: 1),
        UIColor(red: 0.80, green: 0.13, blue: 0.16, alpha: 1),
        UIColor(red: 0.96, green: 0.27, blue: 0.53, alpha: 1),
        UIColor(red: 0.93, green: 0.49, blue: 0.05, alpha: 1),
        UIColor(red: 0.95, green: 0.72, blue: 0.05, alpha: 1),
        UIColor(red: 0.10, green: 0.56, blue: 0.30, alpha: 1),
        UIColor(red: 0.00, green: 0.62, blue: 0.66, alpha: 1),
        UIColor(red: 0.05, green: 0.42, blue: 0.85, alpha: 1),
        UIColor(red: 0.33, green: 0.30, blue: 0.85, alpha: 1),
        UIColor(red: 0.58, green: 0.25, blue: 0.82, alpha: 1),
        UIColor(red: 0.55, green: 0.33, blue: 0.18, alpha: 1),
        .white
    ]
    static let highlighterColors: [UIColor] = [
        UIColor(red: 1.00, green: 0.90, blue: 0.20, alpha: 1),
        UIColor(red: 0.45, green: 0.93, blue: 0.55, alpha: 1),
        UIColor(red: 0.40, green: 0.85, blue: 1.00, alpha: 1),
        UIColor(red: 1.00, green: 0.60, blue: 0.75, alpha: 1),
        UIColor(red: 1.00, green: 0.70, blue: 0.35, alpha: 1),
        UIColor(red: 0.78, green: 0.65, blue: 1.00, alpha: 1),
        UIColor(red: 0.70, green: 0.95, blue: 0.30, alpha: 1)
    ]

    var kind: InkToolKind = .pen
    var eraserMode: EraserMode = .stroke
    private var styles: [InkToolKind: PenStyle] = [
        .pen: .ballpoint, .fountain: .fountainPen, .pencil: .pencil, .highlighter: .marker, .brush: .watercolor
    ]
    private var colors: [InkToolKind: UIColor] = [
        .pen: ToolState.presetColors[0],
        .fountain: ToolState.presetColors[9],
        .pencil: ToolState.presetColors[2],
        .highlighter: ToolState.highlighterColors[0],
        .brush: ToolState.presetColors[4]
    ]
    private var widths: [InkToolKind: CGFloat] = [:]

    /// The pen type of a writing tool.
    func style(of kind: InkToolKind) -> PenStyle? {
        styles[kind] ?? kind.styles.first
    }

    /// Pen type of the active tool (nil for tools that do not write).
    var style: PenStyle? { style(of: kind) }

    mutating func setStyle(_ style: PenStyle) {
        styles[style.family] = style
        widths[style.family] = style.defaultWidth
    }

    func color(of kind: InkToolKind) -> UIColor {
        colors[kind] ?? ToolState.presetColors[0]
    }

    /// Color of the active drawing tool. Each tool remembers its own.
    var color: UIColor {
        get { color(of: kind) }
        set { colors[kind] = newValue }
    }

    var width: CGFloat {
        get {
            let value = widths[kind] ?? style?.defaultWidth ?? 3
            guard let range = widthRange else { return value }
            return min(max(value, range.lowerBound), range.upperBound)
        }
        set { widths[kind] = newValue }
    }

    /// Valid stroke widths for the active tool (nil for tools that do not draw).
    var widthRange: ClosedRange<CGFloat>? {
        style?.validWidthRange
    }

    /// Colour given to newly inserted text and shapes: the current pen colour.
    var objectColorHex: String {
        color(of: .pen).hexString
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
        case .lookup:
            // A thin orange line while circling; the stroke is removed as soon as it ends.
            return PKInkingTool(.monoline, color: UIColor(red: 0.98, green: 0.55, blue: 0.13, alpha: 1), width: 3)
        case .objects, .text:
            // The ink canvas ignores touches in these modes; this tool is never used to draw.
            return PKInkingTool(.pen, color: color(of: .pen), width: 3)
        default:
            let pen = self.style ?? .ballpoint
            return PKInkingTool(pen.inkType, color: color, width: width)
        }
    }
}
