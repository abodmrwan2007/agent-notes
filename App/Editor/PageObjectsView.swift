import AgentNotesCore
import UIKit

/// Draws the objects of one page (text, sticky notes, shapes, images) and, in object mode,
/// lets the user select, move and resize them. Sits above the page background and below the
/// ink canvas. Its bounds are the canonical page coordinate space, like the canvas.
final class PageObjectsView: UIView, UIGestureRecognizerDelegate {
    private(set) var content: PageObjectLayer
    private let pageSize: PageSize
    private let assetProvider: (String) -> UIImage?

    /// Selection is owned by the editor model; this view only displays it.
    var selectedID: UUID? {
        didSet { if oldValue != selectedID { setNeedsDisplay() } }
    }

    /// Object mode: touches select and edit objects instead of going to the ink canvas.
    var isEditingEnabled = false {
        didSet { isUserInteractionEnabled = isEditingEnabled }
    }

    var onSelect: ((UUID?) -> Void)?
    /// Called once when a move or resize ends, with the resulting layer.
    var onCommit: ((PageObjectLayer) -> Void)?
    var onEditText: ((UUID) -> Void)?

    private enum Drag {
        case move(id: UUID, startOrigin: PagePoint)
        case resize(id: UUID, startWidth: Double, startHeight: Double, keepAspectRatio: Bool)
    }

    private var drag: Drag?
    private var layerBeforeDrag: PageObjectLayer?
    private static let handleSize: CGFloat = 30

    init(layer: PageObjectLayer, pageSize: PageSize, assetProvider: @escaping (String) -> UIImage?) {
        self.content = layer
        self.pageSize = pageSize
        self.assetProvider = assetProvider
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: doubleTap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        [doubleTap, tap, pan].forEach(addGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setLayer(_ layer: PageObjectLayer) {
        guard drag == nil else { return } // never replace content under the user's finger
        content = layer
        setNeedsDisplay()
    }

    /// Keeps text and shapes sharp when the page is zoomed by an ancestor transform.
    func setRenderScale(_ scale: CGFloat) {
        guard abs(contentScaleFactor - scale) > 0.01 else { return }
        contentScaleFactor = scale
        setNeedsDisplay()
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        PageRenderer.drawObjects(content, image: assetProvider)

        guard isEditingEnabled, let selectedID, let object = content.object(id: selectedID),
              let context = UIGraphicsGetCurrentContext() else { return }
        let accent = UIColor(red: 0.00, green: 0.60, blue: 0.78, alpha: 1)
        let frame = object.frame.cgRect

        context.saveGState()
        if object.rotation != 0 {
            context.translateBy(x: frame.midX, y: frame.midY)
            context.rotate(by: CGFloat(object.rotation) * .pi / 180)
            context.translateBy(x: -frame.midX, y: -frame.midY)
        }
        let outline = UIBezierPath(rect: frame.insetBy(dx: -3, dy: -3))
        outline.lineWidth = 1.5
        let dashes: [CGFloat] = object.isLocked ? [2, 3] : [6, 4]
        outline.setLineDash(dashes, count: dashes.count, phase: 0)
        (object.isLocked ? UIColor.gray : accent).setStroke()
        outline.stroke()
        context.restoreGState()

        // Resize handle (unrotated position; rotated objects are resized along their original axes).
        if !object.isLocked {
            let handle = UIBezierPath(ovalIn: handleRect(for: object).insetBy(dx: 8, dy: 8))
            UIColor.white.setFill()
            handle.fill()
            accent.setStroke()
            handle.lineWidth = 2
            handle.stroke()
        }
    }

    private func handleRect(for object: PageObject) -> CGRect {
        let frame = object.frame.cgRect
        return CGRect(
            x: frame.maxX - Self.handleSize / 2, y: frame.maxY - Self.handleSize / 2,
            width: Self.handleSize, height: Self.handleSize)
    }

    private func pagePoint(_ point: CGPoint) -> PagePoint {
        PagePoint(x: Double(point.x), y: Double(point.y))
    }

    // MARK: Gestures

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let object = content.topmostObject(at: pagePoint(recognizer.location(in: self)))
        onSelect?(object?.id)
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let object = content.topmostObject(at: pagePoint(recognizer.location(in: self))) else { return }
        onSelect?(object.id)
        if object.hasText, !object.isLocked {
            onEditText?(object.id)
        }
    }

    /// The pan only starts on an object (or the selected object's handle). Anywhere else it
    /// fails, so the page keeps scrolling normally.
    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer is UIPanGestureRecognizer else { return true }
        let location = recognizer.location(in: self)

        if let selectedID, let selected = content.object(id: selectedID), !selected.isLocked,
           handleRect(for: selected).contains(location) {
            drag = .resize(
                id: selected.id, startWidth: selected.frame.width, startHeight: selected.frame.height,
                keepAspectRatio: selected.kind == .image)
            return true
        }
        guard let object = content.topmostObject(at: pagePoint(location)), !object.isLocked else {
            return false
        }
        drag = .move(id: object.id, startOrigin: PagePoint(x: object.frame.x, y: object.frame.y))
        return true
    }

    /// Dragging an object takes priority over scrolling the page: the scroll view's pan has to
    /// wait for this one to fail, which it does at once when the touch is not on an object.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UIPanGestureRecognizer
            && otherGestureRecognizer is UIPanGestureRecognizer
            && otherGestureRecognizer.view is UIScrollView
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let drag else { return }
        let translation = recognizer.translation(in: self)

        switch recognizer.state {
        case .began:
            layerBeforeDrag = content
            if case .move(let id, _) = drag { onSelect?(id) }
        case .changed:
            guard var working = layerBeforeDrag else { return }
            switch drag {
            case .move(let id, let start):
                working.move(
                    id,
                    toOrigin: PagePoint(x: start.x + Double(translation.x), y: start.y + Double(translation.y)),
                    pageSize: pageSize)
            case .resize(let id, let width, let height, let keepAspectRatio):
                working.resize(
                    id,
                    toWidth: width + Double(translation.x),
                    height: height + Double(translation.y),
                    keepAspectRatio: keepAspectRatio)
            }
            content = working
            setNeedsDisplay()
        case .ended:
            let result = content
            self.drag = nil
            layerBeforeDrag = nil
            onCommit?(result)
        default:
            if let original = layerBeforeDrag { content = original }
            self.drag = nil
            layerBeforeDrag = nil
            setNeedsDisplay()
        }
    }
}
