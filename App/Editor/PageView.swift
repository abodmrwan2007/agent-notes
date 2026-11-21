import AgentNotesCore
import PDFKit
import PencilKit
import UIKit

/// Draws a page background (PDF page or template) in tiles, so it stays sharp at any zoom and
/// only the visible region is ever rasterized.
final class PageBackgroundView: UIView {
    override class var layerClass: AnyClass { CATiledLayer.self }

    // Tiles are drawn on background threads; guard the content they read.
    private let lock = NSLock()
    private var page: PageRecord
    private var pdfPage: PDFPage?
    private var backgroundImage: UIImage?

    init(page: PageRecord, pdfPage: PDFPage?, backgroundImage: UIImage?) {
        self.page = page
        self.pdfPage = pdfPage
        self.backgroundImage = backgroundImage
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = .white
        isUserInteractionEnabled = false
        if let tiled = layer as? CATiledLayer {
            tiled.tileSize = CGSize(width: 512, height: 512)
            tiled.levelsOfDetail = 4
            tiled.levelsOfDetailBias = 3
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(page: PageRecord, pdfPage: PDFPage?, backgroundImage: UIImage?) {
        lock.lock()
        self.page = page
        self.pdfPage = pdfPage
        self.backgroundImage = backgroundImage
        lock.unlock()
        layer.contents = nil
        layer.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        lock.lock()
        let page = self.page
        let pdfPage = self.pdfPage
        let backgroundImage = self.backgroundImage
        lock.unlock()
        PageRenderer.drawBackground(page: page, pdfPage: pdfPage, backgroundImage: backgroundImage, in: context)
    }
}

/// One notebook page in the editor. Its bounds ARE the canonical page coordinate space:
/// the ink canvas covers it 1:1, and zooming is applied by an ancestor view's transform,
/// so stored stroke coordinates never depend on zoom or device.
///
/// Until `load` is called this is a lightweight white placeholder, which is what keeps
/// very long documents cheap.
/// What touches on a page do.
enum PageInteraction {
    /// Draw, erase and lasso ink.
    case ink
    /// Select, move and resize page objects.
    case objects
    /// Select the PDF's own text.
    case text
    /// Reading mode: nothing on the page reacts to touch except scrolling and zooming.
    case read
    /// A tap on a stroke plays the audio recorded when it was written.
    case listen
}

final class PageView: UIView {
    let pageID: UUID
    private(set) var page: PageRecord
    private var pdfPage: PDFPage?
    private var backgroundImage: UIImage?
    private var background: PageBackgroundView?
    private(set) var objectsView: PageObjectsView?
    private(set) var canvas: PKCanvasView?
    /// Only on PDF pages: search highlights and text selection.
    private(set) var textLayer: PDFTextLayerView?
    /// False when the page's ink file could not be read (shown read-only).
    private var isInkEditable = true
    private var interaction: PageInteraction = .ink

    /// Pages edited in this session keep their canvas alive so undo keeps working on them.
    var hasSessionEdits = false
    /// True while a drawing is being assigned programmatically (not a user edit).
    private(set) var isApplyingDrawing = false
    /// Strokes on the canvas after the last change; tells a newly drawn stroke from other edits.
    var strokeCount = 0
    /// Listening mode: called with the time the tapped stroke was written.
    var onListenTap: ((Date) -> Void)?
    private lazy var listenTap = UITapGestureRecognizer(target: self, action: #selector(handleListenTap))
    /// Reading mode: called with the tapped point (page coordinates), to open links.
    var onReadTap: ((CGPoint) -> Void)?
    private lazy var readTap = UITapGestureRecognizer(target: self, action: #selector(handleReadTap))

    var isLoaded: Bool { canvas != nil }

    init(page: PageRecord, pdfPage: PDFPage?, backgroundImage: UIImage?) {
        self.pageID = page.id
        self.page = page
        self.pdfPage = pdfPage
        self.backgroundImage = backgroundImage
        super.init(frame: .zero)
        backgroundColor = .white
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(page: PageRecord, pdfPage: PDFPage?, backgroundImage: UIImage?) {
        let backgroundChanged = page.template != self.page.template || page.pdf != self.page.pdf
            || page.backgroundAsset != self.page.backgroundAsset
        self.page = page
        self.pdfPage = pdfPage
        self.backgroundImage = backgroundImage
        if backgroundChanged {
            background?.configure(page: page, pdfPage: pdfPage, backgroundImage: backgroundImage)
        }
    }

    func load(
        drawing: PKDrawing,
        isEditable: Bool,
        objectsView: PageObjectsView,
        interaction: PageInteraction,
        tool: PKTool,
        policy: PKCanvasViewDrawingPolicy,
        delegate: PKCanvasViewDelegate
    ) {
        guard canvas == nil else { return }

        let background = PageBackgroundView(page: page, pdfPage: pdfPage, backgroundImage: backgroundImage)
        background.frame = bounds
        addSubview(background)
        self.background = background

        // Stacking order: background, objects, then the ink canvas on top.
        objectsView.frame = bounds
        addSubview(objectsView)
        self.objectsView = objectsView
        isInkEditable = isEditable

        let canvas = PKCanvasView(frame: bounds)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // The paper is always white, so ink must not adapt to dark mode.
        canvas.overrideUserInterfaceStyle = .light
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.contentSize = bounds.size
        canvas.drawingPolicy = policy
        canvas.tool = tool
        canvas.isUserInteractionEnabled = isEditable

        isApplyingDrawing = true
        canvas.drawing = drawing
        strokeCount = drawing.strokes.count
        canvas.delegate = delegate
        addSubview(canvas)
        self.canvas = canvas
        // PencilKit may report the programmatic assignment on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingDrawing = false
        }

        // The text layer is on top so it can receive touches in text mode.
        if let pdfPage {
            let textLayer = PDFTextLayerView(pdfPage: pdfPage)
            textLayer.frame = bounds
            addSubview(textLayer)
            self.textLayer = textLayer
        }
        setInteraction(interaction)
    }

    /// Programmatic replacement (snapped or smoothed stroke) that is not reported as a user edit.
    func replaceDrawing(_ drawing: PKDrawing) {
        guard let canvas else { return }
        isApplyingDrawing = true
        canvas.drawing = drawing
        strokeCount = drawing.strokes.count
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingDrawing = false
        }
    }

    /// Only the layer that matches the mode receives touches; the others let them through.
    func setInteraction(_ mode: PageInteraction) {
        interaction = mode
        if mode == .listen, listenTap.view == nil { addGestureRecognizer(listenTap) }
        listenTap.isEnabled = mode == .listen
        if mode == .read, readTap.view == nil { addGestureRecognizer(readTap) }
        readTap.isEnabled = mode == .read
        canvas?.isUserInteractionEnabled = isInkEditable && mode == .ink
        objectsView?.isEditingEnabled = mode == .objects
        objectsView?.setNeedsDisplay()
        textLayer?.isSelectionEnabled = mode == .text
    }

    @objc private func handleReadTap(_ recognizer: UITapGestureRecognizer) {
        onReadTap?(recognizer.location(in: self))
    }

    @objc private func handleListenTap(_ recognizer: UITapGestureRecognizer) {
        guard let drawing = canvas?.drawing else { return }
        let point = recognizer.location(in: self)
        // The most recent stroke under the finger (generous margin: strokes are thin).
        if let stroke = drawing.strokes.last(where: { $0.renderBounds.insetBy(dx: -10, dy: -10).contains(point) }) {
            onListenTap?(stroke.path.creationDate)
        }
    }

    func unload() {
        canvas?.delegate = nil
        canvas?.removeFromSuperview()
        canvas = nil
        textLayer?.removeFromSuperview()
        textLayer = nil
        objectsView?.removeFromSuperview()
        objectsView = nil
        background?.removeFromSuperview()
        background = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        background?.frame = bounds
        objectsView?.frame = bounds
        textLayer?.frame = bounds
        canvas?.frame = bounds
        canvas?.contentSize = bounds.size
    }
}
