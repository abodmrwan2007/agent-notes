import AgentNotesCore
import PDFKit
import UIKit

/// Sits on top of a PDF page. Always draws search highlights; in text mode it also lets the user
/// drag across the PDF's own text layer to select it. Works in canonical page coordinates and
/// converts to PDF page space through `PDFPageGeometry`, so crop boxes and rotation are respected.
final class PDFTextLayerView: UIView, UIGestureRecognizerDelegate {
    private let pdfPage: PDFPage
    private let geometry: PDFPageGeometry

    private var selectionRects: [CGRect] = []
    private var highlightRects: [CGRect] = []
    private var dragStart: CGPoint?

    /// Selected text (nil when cleared). Empty string: the page has no selectable text there.
    var onSelectionChange: ((String?) -> Void)?

    var isSelectionEnabled = false {
        didSet {
            isUserInteractionEnabled = isSelectionEnabled
            if !isSelectionEnabled { clearSelection(notify: false) }
        }
    }

    init(pdfPage: PDFPage) {
        self.pdfPage = pdfPage
        let crop = pdfPage.bounds(for: .cropBox)
        geometry = PDFPageGeometry(
            cropBox: PDFBox(x: crop.origin.x, y: crop.origin.y, width: crop.width, height: crop.height),
            rotationDegrees: pdfPage.rotation)
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(pan)
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// True when the page has a text layer at all (scanned pages usually do not).
    var hasText: Bool {
        !(pdfPage.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Search highlights

    /// Highlights every occurrence of `query` on this page, using the same Arabic/English
    /// normalization as search. nil clears the highlights.
    func highlight(_ query: String?) {
        highlightRects = []
        if let query, let text = pdfPage.string {
            for range in TextMatcher.ranges(of: query, in: text, limit: 20) {
                let nsRange = NSRange(range, in: text)
                if let selection = pdfPage.selection(for: nsRange) {
                    highlightRects += lineRects(of: selection)
                }
            }
        }
        setNeedsDisplay()
    }

    // MARK: Coordinates

    private func pdfPoint(_ point: CGPoint) -> CGPoint {
        let converted = geometry.pdfPoint(fromCanonical: PagePoint(x: Double(point.x), y: Double(point.y)))
        return CGPoint(x: converted.x, y: converted.y)
    }

    /// A rectangle in PDF page space -> its bounding box in canonical page coordinates.
    private func canonicalRect(_ rect: CGRect) -> CGRect {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)
        ].map { geometry.canonicalPoint(fromPDF: PagePoint(x: Double($0.x), y: Double($0.y))) }
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return CGRect(
            x: xs.min() ?? 0, y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    private func lineRects(of selection: PDFSelection) -> [CGRect] {
        selection.selectionsByLine()
            .map { canonicalRect($0.bounds(for: pdfPage)) }
            .filter { $0.width > 0.5 && $0.height > 0.5 }
    }

    // MARK: Selection

    private func clearSelection(notify: Bool) {
        guard !selectionRects.isEmpty || dragStart != nil else { return }
        selectionRects = []
        dragStart = nil
        setNeedsDisplay()
        if notify { onSelectionChange?(nil) }
    }

    /// The text selection pan wins over scrolling with one finger; two fingers still scroll.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UIPanGestureRecognizer
            && otherGestureRecognizer is UIPanGestureRecognizer
            && otherGestureRecognizer.view is UIScrollView
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        clearSelection(notify: true)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            dragStart = location
            updateSelection(to: location, finished: false)
        case .changed:
            updateSelection(to: location, finished: false)
        case .ended:
            updateSelection(to: location, finished: true)
        default:
            clearSelection(notify: true)
        }
    }

    private func updateSelection(to location: CGPoint, finished: Bool) {
        guard let start = dragStart else { return }
        let selection = pdfPage.selection(from: pdfPoint(start), to: pdfPoint(location))
        let text = selection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectionRects = selection.map(lineRects(of:)) ?? []
        setNeedsDisplay()
        if finished {
            onSelectionChange?(text)
        }
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        if !highlightRects.isEmpty {
            context.setFillColor(UIColor.systemYellow.withAlphaComponent(0.35).cgColor)
            context.fill(highlightRects)
        }
        if !selectionRects.isEmpty {
            context.setFillColor(UIColor(red: 0.00, green: 0.60, blue: 0.78, alpha: 0.28).cgColor)
            context.fill(selectionRects)
        }
    }
}
