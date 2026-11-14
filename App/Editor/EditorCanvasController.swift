import AgentNotesCore
import PencilKit
import UIKit

/// The scrolling, zooming stack of pages.
///
/// Layout: `scrollView` zooms `contentView`; `contentView` holds one `PageView` per page,
/// laid out vertically in unscaled points. Only pages near the viewport carry a PencilKit
/// canvas and a rendered background; the rest are placeholders.
final class EditorCanvasController: UIViewController, UIScrollViewDelegate, PKCanvasViewDelegate {
    private let model: EditorModel
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageViews: [PageView] = []

    private var appliedLayoutVersion = -1
    private var lastBoundsSize = CGSize.zero
    private var isRebuilding = false
    /// While true, the page width tracks the view width (e.g. when a side panel opens or the iPad rotates).
    private var followsFitZoom = true
    private var currentTool: PKTool = PKInkingTool(.pen, color: .black, width: 3)
    private var interaction: PageInteraction = .ink
    private var hasAppliedOpenTarget = false

    private static let margin: CGFloat = 24
    private static let pageSpacing: CGFloat = 20

    // One undo history for the whole document rather than the window's shared one.
    private let editorUndoManager = UndoManager()
    override var undoManager: UndoManager? { editorUndoManager }

    var allowsFingerDrawing = false {
        didSet {
            guard oldValue != allowsFingerDrawing else { return }
            applyDrawingPolicy()
        }
    }

    init(model: EditorModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.backdropUIColor

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        applyDrawingPolicy()

        let center = NotificationCenter.default
        for name in [Notification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange,
                     .NSUndoManagerDidCloseUndoGroup] {
            center.addObserver(self, selector: #selector(undoStateChanged), name: name, object: editorUndoManager)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = scrollView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        if appliedLayoutVersion != model.layoutVersion {
            rebuild()
        } else if size != lastBoundsSize {
            // A panel opened/closed or the device rotated: keep the same content at the top.
            let anchor = captureAnchor()
            lastBoundsSize = size
            applyZoomLimits()
            if followsFitZoom {
                scrollView.zoomScale = fitZoom
            }
            centerContent()
            restore(anchor)
            updateVisiblePages()
        }
    }

    // MARK: Public API (used by EditorModel and the SwiftUI wrapper)

    func reloadIfNeeded() {
        guard isViewLoaded, scrollView.bounds.width > 0, appliedLayoutVersion != model.layoutVersion else { return }
        rebuild()
    }

    func apply(tool: PKTool) {
        currentTool = tool
        for pageView in pageViews {
            pageView.canvas?.tool = tool
        }
    }

    func scrollToPage(id: UUID, animated: Bool) {
        guard let pageView = pageViews.first(where: { $0.pageID == id }) else { return }
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let y = min(max(0, (pageView.frame.minY - Self.margin / 2) * scrollView.zoomScale), maxY)
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: animated)
    }

    // MARK: Page objects

    /// Ink, object or text-selection mode for every page.
    func setInteraction(_ mode: PageInteraction) {
        guard interaction != mode else { return }
        interaction = mode
        for pageView in pageViews {
            pageView.setInteraction(mode)
        }
    }

    /// Opening from a search result: jump to that page once, and highlight the query on it.
    private func applyOpenTargetIfNeeded() {
        guard !hasAppliedOpenTarget, let target = model.openTarget else { return }
        hasAppliedOpenTarget = true
        scrollToPage(id: target.pageID, animated: false)
        updateVisiblePages()
        pageViews.first { $0.pageID == target.pageID }?.textLayer?.highlight(target.highlightQuery)
    }

    func refreshObjects(pageID: UUID) {
        pageViews.first { $0.pageID == pageID }?.objectsView?.setLayer(model.objects(for: pageID))
        refreshObjectSelection()
    }

    func refreshObjectSelection() {
        let selection = model.selection
        for pageView in pageViews {
            pageView.objectsView?.selectedID = selection?.pageID == pageView.pageID ? selection?.objectID : nil
        }
    }

    func registerUndo(_ action: @escaping () -> Void) {
        editorUndoManager.registerUndo(withTarget: self) { _ in action() }
        undoStateChanged()
    }

    /// Centre of the part of a page that is currently on screen, in page coordinates.
    func visibleCenter(ofPage pageID: UUID) -> PagePoint? {
        let zoom = scrollView.zoomScale
        guard zoom > 0, let pageView = pageViews.first(where: { $0.pageID == pageID }) else { return nil }
        let visible = CGRect(
            x: scrollView.contentOffset.x / zoom,
            y: scrollView.contentOffset.y / zoom,
            width: scrollView.bounds.width / zoom,
            height: scrollView.bounds.height / zoom)
        let onPage = visible.intersection(pageView.frame)
        guard !onPage.isNull, !onPage.isEmpty else { return nil }
        return PagePoint(
            x: Double(onPage.midX - pageView.frame.minX),
            y: Double(onPage.midY - pageView.frame.minY))
    }

    /// Objects are drawn by an ordinary view that an ancestor transform scales, so its backing
    /// store is re-rendered at the zoomed resolution to keep text sharp.
    private var objectRenderScale: CGFloat {
        let screenScale = view.window?.screen.scale ?? traitCollection.displayScale
        return max(screenScale, 1) * min(max(scrollView.zoomScale, 1), 4)
    }

    func undo() {
        if editorUndoManager.canUndo { editorUndoManager.undo() }
        undoStateChanged()
    }

    func redo() {
        if editorUndoManager.canRedo { editorUndoManager.redo() }
        undoStateChanged()
    }

    func clearUndoHistory() {
        editorUndoManager.removeAllActions()
        undoStateChanged()
    }

    // MARK: Layout

    private var unscaledContentSize: CGSize {
        scrollView.zoomScale > 0
            ? CGSize(
                width: scrollView.contentSize.width / scrollView.zoomScale,
                height: scrollView.contentSize.height / scrollView.zoomScale)
            : scrollView.contentSize
    }

    private var fitZoom: CGFloat {
        let width = unscaledContentSize.width
        guard width > 0, scrollView.bounds.width > 0 else { return 1 }
        return scrollView.bounds.width / width
    }

    private func applyZoomLimits() {
        let fit = fitZoom
        scrollView.minimumZoomScale = fit * 0.5
        scrollView.maximumZoomScale = max(fit * 6, 4)
    }

    /// Reconciles the page views with the manifest. Existing pages keep their view (and ink).
    private func rebuild() {
        isRebuilding = true
        defer { isRebuilding = false }

        let anchor = captureAnchor()
        let previousZoom = scrollView.zoomScale
        // Frames below are in unscaled points, so lay out at zoom 1.
        scrollView.minimumZoomScale = min(scrollView.minimumZoomScale, 1)
        scrollView.maximumZoomScale = max(scrollView.maximumZoomScale, 1)
        scrollView.zoomScale = 1

        let pages = model.manifest.pages
        var reusable = Dictionary(uniqueKeysWithValues: pageViews.map { ($0.pageID, $0) })
        let widest = CGFloat(pages.map(\.size.width).max() ?? AppConfig.defaultPageSize.width)
        let totalWidth = widest + Self.margin * 2

        var newViews: [PageView] = []
        newViews.reserveCapacity(pages.count)
        var y = Self.margin
        for page in pages {
            let pdfPage = model.pdfPage(for: page)
            let pageView: PageView
            if let existing = reusable.removeValue(forKey: page.id) {
                pageView = existing
                pageView.update(page: page, pdfPage: pdfPage)
            } else {
                pageView = PageView(page: page, pdfPage: pdfPage)
                contentView.addSubview(pageView)
            }
            let size = page.size.cgSize
            pageView.frame = CGRect(x: (totalWidth - size.width) / 2, y: y, width: size.width, height: size.height)
            newViews.append(pageView)
            y += size.height + Self.pageSpacing
        }
        for removed in reusable.values {
            removed.unload()
            removed.removeFromSuperview()
        }
        pageViews = newViews

        let contentSize = CGSize(width: totalWidth, height: y - Self.pageSpacing + Self.margin)
        contentView.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.contentSize = contentSize

        appliedLayoutVersion = model.layoutVersion
        lastBoundsSize = scrollView.bounds.size
        applyZoomLimits()
        scrollView.zoomScale = followsFitZoom
            ? fitZoom
            : min(max(previousZoom, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
        centerContent()
        restore(anchor)
        updateVisiblePages()
        // The first build can come from either layout or a SwiftUI update, so this lives here.
        applyOpenTargetIfNeeded()
    }

    /// Centers the pages horizontally when they are narrower than the viewport.
    private func centerContent() {
        let inset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
    }

    /// The page at the top of the viewport and how far into it we are (unscaled points).
    private func captureAnchor() -> (pageID: UUID, offset: CGFloat)? {
        guard scrollView.zoomScale > 0 else { return nil }
        let y = max(0, scrollView.contentOffset.y) / scrollView.zoomScale
        guard let pageView = pageViews.first(where: { $0.frame.maxY > y }) else { return nil }
        return (pageView.pageID, y - pageView.frame.minY)
    }

    private func restore(_ anchor: (pageID: UUID, offset: CGFloat)?) {
        guard let anchor, let pageView = pageViews.first(where: { $0.pageID == anchor.pageID }) else {
            // Nothing to return to (first layout): start at the top. Setting the zoom scale keeps
            // the viewport centre fixed, which would otherwise leave a long document scrolled down.
            scrollView.contentOffset = CGPoint(x: -scrollView.contentInset.left, y: 0)
            return
        }
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let y = min(max(0, (pageView.frame.minY + anchor.offset) * scrollView.zoomScale), maxY)
        // Narrower than the viewport: centered by the inset. Wider (zoomed in): keep the horizontal position.
        let inset = scrollView.contentInset.left
        let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let x = inset > 0 ? -inset : min(max(0, scrollView.contentOffset.x), maxX)
        scrollView.contentOffset = CGPoint(x: x, y: y)
    }

    // MARK: Lazy page loading

    private func updateVisiblePages() {
        let zoom = scrollView.zoomScale
        guard zoom > 0, !pageViews.isEmpty else { return }
        let visible = CGRect(
            x: scrollView.contentOffset.x / zoom,
            y: scrollView.contentOffset.y / zoom,
            width: scrollView.bounds.width / zoom,
            height: scrollView.bounds.height / zoom)
        let loadRect = visible.insetBy(dx: -visible.width, dy: -visible.height)
        let keepRect = visible.insetBy(dx: -visible.width, dy: -visible.height * 3)

        for pageView in pageViews {
            if pageView.frame.intersects(loadRect) {
                if !pageView.isLoaded { load(pageView) }
            } else if pageView.isLoaded, !pageView.hasSessionEdits, !pageView.frame.intersects(keepRect) {
                pageView.unload()
            }
        }

        let centerY = visible.midY
        let index = pageViews.firstIndex { $0.frame.maxY + Self.pageSpacing / 2 > centerY } ?? pageViews.count - 1
        if model.currentPageIndex != index {
            model.currentPageIndex = index
        }
    }

    private func load(_ pageView: PageView) {
        let drawing: PKDrawing
        let isEditable: Bool
        switch model.loadInk(for: pageView.pageID) {
        case .drawing(let loaded):
            drawing = loaded
            isEditable = true
        case .unreadable:
            drawing = PKDrawing()
            isEditable = false
        }
        let pageID = pageView.pageID
        let objectsView = PageObjectsView(
            layer: model.objects(for: pageID),
            pageSize: pageView.page.size,
            assetProvider: { [weak model = self.model] name in model?.asset(named: name) })
        objectsView.onSelect = { [weak self] id in
            self?.model.select(id.map { ObjectSelection(pageID: pageID, objectID: $0) })
        }
        objectsView.onCommit = { [weak self] layer in
            self?.model.commitObjects(layer, pageID: pageID)
        }
        objectsView.onEditText = { [weak self] id in
            self?.model.beginEditingText(ObjectSelection(pageID: pageID, objectID: id))
        }
        let selection = model.selection
        objectsView.selectedID = selection?.pageID == pageID ? selection?.objectID : nil
        objectsView.setRenderScale(objectRenderScale)

        pageView.load(
            drawing: drawing, isEditable: isEditable, objectsView: objectsView, interaction: interaction,
            tool: currentTool, policy: drawingPolicy, delegate: self)

        if let textLayer = pageView.textLayer {
            textLayer.onSelectionChange = { [weak self] text in
                self?.model.setTextSelection(text.map { TextSelection(pageID: pageID, text: $0) })
            }
            if let target = model.openTarget, target.pageID == pageID, hasAppliedOpenTarget {
                textLayer.highlight(target.highlightQuery)
            }
        }
    }

    private var drawingPolicy: PKCanvasViewDrawingPolicy {
        allowsFingerDrawing ? .anyInput : .pencilOnly
    }

    private func applyDrawingPolicy() {
        // Finger drawing on: one finger draws, so scrolling needs two.
        scrollView.panGestureRecognizer.minimumNumberOfTouches = allowsFingerDrawing ? 2 : 1
        for pageView in pageViews {
            pageView.canvas?.drawingPolicy = drawingPolicy
        }
    }

    @objc private func undoStateChanged() {
        if model.canUndo != editorUndoManager.canUndo { model.canUndo = editorUndoManager.canUndo }
        if model.canRedo != editorUndoManager.canRedo { model.canRedo = editorUndoManager.canRedo }
    }

    // MARK: UIScrollViewDelegate

    // PKCanvasViewDelegate inherits UIScrollViewDelegate, so each page canvas (itself a scroll view)
    // also calls these. Only the outer scroll view is handled.

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === self.scrollView ? contentView : nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView, !isRebuilding else { return }
        centerContent()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard scrollView === self.scrollView else { return }
        followsFitZoom = abs(scale - fitZoom) < 0.02
        updateVisiblePages()
        let renderScale = objectRenderScale
        for pageView in pageViews {
            pageView.objectsView?.setRenderScale(renderScale)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView, !isRebuilding else { return }
        updateVisiblePages()
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let pageView = canvasView.superview as? PageView, !pageView.isApplyingDrawing else { return }
        pageView.hasSessionEdits = true
        model.inkChanged(pageID: pageView.pageID, drawing: canvasView.drawing)
        undoStateChanged()
    }
}
