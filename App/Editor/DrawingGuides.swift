import PencilKit
import SwiftUI
import UIKit

/// Drawing guides laid over the page. The straight ruler is PencilKit's own; the circle,
/// protractor and set square are this app's: move them with one finger, turn them with two,
/// pinch to resize, and draw along an edge with the pen — the stroke snaps onto that edge.
enum DrawingGuide: String, CaseIterable, Identifiable {
    case ruler
    case circle
    case protractor
    case setSquare

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .ruler: return "Ruler"
        case .circle: return "Circle"
        case .protractor: return "Protractor"
        case .setSquare: return "Set Square"
        }
    }

    var symbol: String {
        switch self {
        case .ruler: return "ruler"
        case .circle: return "circle.dashed"
        case .protractor: return "angle"
        case .setSquare: return "triangle"
        }
    }

    var tint: Color {
        switch self {
        case .ruler: return Vivid.green
        case .circle: return Vivid.blue
        case .protractor: return Vivid.orange
        case .setSquare: return Vivid.purple
        }
    }

    var uiTint: UIColor { UIColor(tint) }
}

/// A see-through template (circle, protractor or set square) floating over the pages.
/// It lives in screen space above the scrolling pages, so dragging it never scrolls the page.
final class GuideView: UIView, UIGestureRecognizerDelegate {
    let kind: DrawingGuide
    /// Rotation in radians (applied as the view's transform).
    private var angle: CGFloat = 0
    /// Distance (in screen points) within which a stroke is pulled onto an edge.
    private static let snapDistance: CGFloat = 24

    init(kind: DrawingGuide) {
        self.kind = kind
        let size: CGSize
        switch kind {
        case .circle: size = CGSize(width: 240, height: 240)
        case .protractor: size = CGSize(width: 340, height: 180)
        default: size = CGSize(width: 300, height: 300)
        }
        super.init(frame: CGRect(origin: .zero, size: size))
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        accessibilityIdentifier = "guide.\(kind.rawValue)"
        isAccessibilityElement = true
        accessibilityLabel = String(localized: "Drawing guide")

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        for recognizer in [pan, rotate, pinch] as [UIGestureRecognizer] {
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Shape

    /// The guide's outline in its own coordinates.
    private var shapePath: UIBezierPath {
        let rect = bounds
        switch kind {
        case .circle, .ruler:
            return UIBezierPath(ovalIn: rect)
        case .protractor:
            let path = UIBezierPath()
            let center = CGPoint(x: rect.midX, y: rect.maxY)
            path.addArc(withCenter: center, radius: rect.width / 2, startAngle: .pi, endAngle: 0, clockwise: true)
            path.close()
            return path
        case .setSquare:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.close()
            return path
        }
    }

    /// Only the template itself catches touches; around it they reach the page.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        shapePath.contains(point)
    }

    /// The nearest point on the guide's edge, in the guide's own coordinates.
    private func nearestEdgePoint(to point: CGPoint) -> CGPoint {
        let rect = bounds
        func onSegment(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            let dx = b.x - a.x, dy = b.y - a.y
            let length = dx * dx + dy * dy
            guard length > 0 else { return a }
            let t = min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / length, 0), 1)
            return CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        }
        func onCircle(center: CGPoint, radius: CGFloat) -> CGPoint {
            let dx = point.x - center.x, dy = point.y - center.y
            let distance = max(sqrt(dx * dx + dy * dy), 0.001)
            return CGPoint(x: center.x + dx / distance * radius, y: center.y + dy / distance * radius)
        }
        func nearest(_ candidates: [CGPoint]) -> CGPoint {
            candidates.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? point
        }
        switch kind {
        case .circle, .ruler:
            return onCircle(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2)
        case .protractor:
            let center = CGPoint(x: rect.midX, y: rect.maxY)
            var arc = onCircle(center: center, radius: rect.width / 2)
            if arc.y > center.y { arc = point.x < center.x ? CGPoint(x: rect.minX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.maxY) }
            return nearest([arc, onSegment(CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY))])
        case .setSquare:
            let a = CGPoint(x: rect.minX, y: rect.minY)
            let b = CGPoint(x: rect.minX, y: rect.maxY)
            let c = CGPoint(x: rect.maxX, y: rect.maxY)
            return nearest([onSegment(a, b), onSegment(b, c), onSegment(c, a)])
        }
    }

    /// If most of the stroke runs along an edge, the same stroke laid exactly onto that edge.
    /// Points are converted between the page canvas and this view, so zoom and rotation are handled.
    func snapped(_ stroke: PKStroke, in canvas: UIView) -> PKStroke? {
        let points = Array(stroke.path)
        guard points.count >= 2 else { return nil }
        let local = points.map { convert($0.location.applying(stroke.transform), from: canvas) }
        let projected = local.map { nearestEdgePoint(to: $0) }
        let close = zip(local, projected).filter { hypot($0.x - $1.x, $0.y - $1.y) < Self.snapDistance }.count
        guard Double(close) >= Double(points.count) * 0.75 else { return nil }
        let newPoints = zip(points, projected).map { original, edge in
            PKStrokePoint(
                location: convert(edge, to: canvas), timeOffset: original.timeOffset,
                size: original.size, opacity: original.opacity, force: original.force,
                azimuth: original.azimuth, altitude: original.altitude)
        }
        return PKStroke(
            ink: stroke.ink,
            path: PKStrokePath(controlPoints: newPoints, creationDate: stroke.path.creationDate),
            transform: .identity, mask: stroke.mask)
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        let tint = kind.uiTint
        let path = shapePath
        UIColor.white.withAlphaComponent(0.55).setFill()
        path.fill()
        tint.withAlphaComponent(0.16).setFill()
        path.fill()
        tint.setStroke()
        path.lineWidth = 2
        path.stroke()

        let ticks = UIBezierPath()
        ticks.lineWidth = 1
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: tint
        ]
        let b = bounds
        switch kind {
        case .circle, .ruler:
            let center = CGPoint(x: b.midX, y: b.midY)
            let radius = b.width / 2
            for step in 0..<72 {
                let a = CGFloat(step) * .pi / 36
                let length: CGFloat = step % 6 == 0 ? 14 : 7
                ticks.move(to: CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius))
                ticks.addLine(to: CGPoint(x: center.x + cos(a) * (radius - length), y: center.y + sin(a) * (radius - length)))
            }
            ticks.move(to: CGPoint(x: center.x - 8, y: center.y))
            ticks.addLine(to: CGPoint(x: center.x + 8, y: center.y))
            ticks.move(to: CGPoint(x: center.x, y: center.y - 8))
            ticks.addLine(to: CGPoint(x: center.x, y: center.y + 8))
            tint.setStroke()
            ticks.stroke()
            let centimetres = radius / 72 * 2.54
            let label = String(format: "r = %.1f cm", centimetres) as NSString
            label.draw(at: CGPoint(x: center.x + 6, y: center.y + 6), withAttributes: labelAttributes)
        case .protractor:
            let center = CGPoint(x: b.midX, y: b.maxY)
            let radius = b.width / 2
            for degree in stride(from: 0, through: 180, by: 5) {
                let a = CGFloat(degree) * .pi / 180
                let length: CGFloat = degree % 30 == 0 ? 18 : (degree % 10 == 0 ? 11 : 6)
                let outer = CGPoint(x: center.x - cos(a) * radius, y: center.y - sin(a) * radius)
                let inner = CGPoint(x: center.x - cos(a) * (radius - length), y: center.y - sin(a) * (radius - length))
                ticks.move(to: outer)
                ticks.addLine(to: inner)
                if degree % 30 == 0 {
                    let text = "\(degree)°" as NSString
                    let size = text.size(withAttributes: labelAttributes)
                    let at = CGPoint(
                        x: center.x - cos(a) * (radius - 30) - size.width / 2,
                        y: center.y - sin(a) * (radius - 30) - size.height / 2)
                    text.draw(at: at, withAttributes: labelAttributes)
                }
            }
            ticks.move(to: CGPoint(x: center.x, y: center.y))
            ticks.addLine(to: CGPoint(x: center.x, y: center.y - 14))
            tint.setStroke()
            ticks.stroke()
        case .setSquare:
            // Centimetre marks along the two straight sides (72 points per inch).
            let step: CGFloat = 72 / 2.54
            var y = b.maxY - step
            var mark = 1
            while y > b.minY + 4 {
                ticks.move(to: CGPoint(x: b.minX, y: y))
                ticks.addLine(to: CGPoint(x: b.minX + (mark % 5 == 0 ? 16 : 9), y: y))
                y -= step
                mark += 1
            }
            var x = b.minX + step
            mark = 1
            while x < b.maxX - 4 {
                ticks.move(to: CGPoint(x: x, y: b.maxY))
                ticks.addLine(to: CGPoint(x: x, y: b.maxY - (mark % 5 == 0 ? 16 : 9)))
                if mark % 5 == 0 {
                    ("\(mark)" as NSString).draw(at: CGPoint(x: x - 4, y: b.maxY - 30), withAttributes: labelAttributes)
                }
                x += step
                mark += 1
            }
            tint.setStroke()
            ticks.stroke()
            ("45°" as NSString).draw(at: CGPoint(x: b.minX + 8, y: b.minY + 34), withAttributes: labelAttributes)
            ("90°" as NSString).draw(at: CGPoint(x: b.minX + 8, y: b.maxY - 34), withAttributes: labelAttributes)
        }
    }

    // MARK: Gestures (fingers only; the pen draws)

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        recognizer.setTranslation(.zero, in: superview)
    }

    @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
        guard kind != .circle else { return }
        angle += recognizer.rotation
        recognizer.rotation = 0
        transform = CGAffineTransform(rotationAngle: angle)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        let scale = recognizer.scale
        recognizer.scale = 1
        let width = min(max(bounds.width * scale, 80), 900)
        let height = bounds.height * width / max(bounds.width, 1)
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        setNeedsDisplay()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer.view === self
    }
}
