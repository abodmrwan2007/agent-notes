import Foundation

/// A rectangle in PDF user space (origin bottom-left, y pointing up).
public struct PDFBox: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PagePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Maps between PDF user space and canonical page coordinates.
///
/// Canonical coordinates are what ink and annotations are stored in: points, origin at the
/// top-left of the page AS DISPLAYED (crop box applied, rotation applied), y pointing down.
/// They are independent of zoom and of the device, so annotations stay aligned when the
/// view is zoomed, rotated, or the page background changes.
public struct PDFPageGeometry: Hashable, Sendable {
    public let cropBox: PDFBox
    /// Clockwise display rotation, normalized to 0, 90, 180 or 270.
    public let rotation: Int

    public init(cropBox: PDFBox, rotationDegrees: Int) {
        self.cropBox = cropBox
        let normalized = ((rotationDegrees % 360) + 360) % 360
        self.rotation = (normalized / 90) * 90
    }

    private var isQuarterTurn: Bool { rotation == 90 || rotation == 270 }

    public var canonicalSize: PageSize {
        isQuarterTurn
            ? PageSize(width: cropBox.height, height: cropBox.width)
            : PageSize(width: cropBox.width, height: cropBox.height)
    }

    public func canonicalPoint(fromPDF point: PagePoint) -> PagePoint {
        // (u, v): top-left based position inside the unrotated crop box.
        let u = point.x - cropBox.x
        let v = cropBox.y + cropBox.height - point.y
        switch rotation {
        case 90: return PagePoint(x: cropBox.height - v, y: u)
        case 180: return PagePoint(x: cropBox.width - u, y: cropBox.height - v)
        case 270: return PagePoint(x: v, y: cropBox.width - u)
        default: return PagePoint(x: u, y: v)
        }
    }

    public func pdfPoint(fromCanonical point: PagePoint) -> PagePoint {
        let u: Double
        let v: Double
        switch rotation {
        case 90:
            u = point.y
            v = cropBox.height - point.x
        case 180:
            u = cropBox.width - point.x
            v = cropBox.height - point.y
        case 270:
            u = cropBox.width - point.y
            v = point.x
        default:
            u = point.x
            v = point.y
        }
        return PagePoint(x: cropBox.x + u, y: cropBox.y + cropBox.height - v)
    }
}
