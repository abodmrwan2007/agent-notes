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

    init(page: PageRecord, pdfPage: PDFPage?) {
        self.page = page
        self.pdfPage = pdfPage
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

    func configure(page: PageRecord, pdfPage: PDFPage?) {
        lock.lock()
        self.page = page
        self.pdfPage = pdfPage
        lock.unlock()
        layer.contents = nil
        layer.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        lock.lock()
        let page = self.page
        let pdfPage = self.pdfPage
        lock.unlock()
        PageRenderer.drawBackground(page: page, pdfPage: pdfPage, in: context)
    }
}

/// One notebook page in the editor. Its bounds ARE the canonical page coordinate space:
/// the ink canvas covers it 1:1, and zooming is applied by an ancestor view's transform,
/// so stored stroke coordinates never depend on zoom or device.
///
/// Until `load` is called this is a lightweight white placeholder, which is what keeps
/// very long documents cheap.
final class PageView: UIView {
    let pageID: UUID
    private(set) var page: PageRecord
    private var pdfPage: PDFPage?
    private var background: PageBackgroundView?
    private(set) var canvas: PKCanvasView?

    /// Pages edited in this session keep their canvas alive so undo keeps working on them.
    var hasSessionEdits = false
    /// True while a drawing is being assigned programmatically (not a user edit).
    private(set) var isApplyingDrawing = false

    var isLoaded: Bool { canvas != nil }

    init(page: PageRecord, pdfPage: PDFPage?) {
        self.pageID = page.id
        self.page = page
        self.pdfPage = pdfPage
        super.init(frame: .zero)
        backgroundColor = .white
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(page: PageRecord, pdfPage: PDFPage?) {
        let backgroundChanged = page.template != self.page.template || page.pdf != self.page.pdf
        self.page = page
        self.pdfPage = pdfPage
        if backgroundChanged {
            background?.configure(page: page, pdfPage: pdfPage)
        }
    }

    func load(
        drawing: PKDrawing,
        isEditable: Bool,
        tool: PKTool,
        policy: PKCanvasViewDrawingPolicy,
        delegate: PKCanvasViewDelegate
    ) {
        guard canvas == nil else { return }

        let background = PageBackgroundView(page: page, pdfPage: pdfPage)
        background.frame = bounds
        addSubview(background)
        self.background = background

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
        canvas.delegate = delegate
        addSubview(canvas)
        self.canvas = canvas
        // PencilKit may report the programmatic assignment on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingDrawing = false
        }
    }

    func unload() {
        canvas?.delegate = nil
        canvas?.removeFromSuperview()
        canvas = nil
        background?.removeFromSuperview()
        background = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        background?.frame = bounds
        canvas?.frame = bounds
        canvas?.contentSize = bounds.size
    }
}
