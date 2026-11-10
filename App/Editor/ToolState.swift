import PencilKit
import SwiftUI
import UIKit

enum InkToolKind: String, CaseIterable, Identifiable {
    case pen
    case pencil
    case highlighter
    case eraser
    case lasso

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pen: return "Pen"
        case .pencil: return "Pencil"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .lasso: return "Lasso"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        }
    }

    /// The native PencilKit ink behind each drawing tool. Only native inks are offered for now.
    var inkType: PKInkingTool.InkType? {
        switch self {
        case .pen: return .pen
        case .pencil: return .pencil
        case .highlighter: return .marker
        case .eraser, .lasso: return nil
        }
    }

    var widthRange: ClosedRange<CGFloat>? {
        inkType?.validWidthRange
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
            guard let range = kind.widthRange else { return value }
            return min(max(value, range.lowerBound), range.upperBound)
        }
        set { widths[kind] = newValue }
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
        }
    }
}
