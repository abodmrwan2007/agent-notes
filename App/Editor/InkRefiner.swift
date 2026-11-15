import AgentNotesCore
import PencilKit
import UIKit

/// Post-processes the stroke the user just finished:
/// - "hold to snap": if the pen rested at the end of the stroke, a recognized line, circle,
///   ellipse or rectangle replaces it;
/// - otherwise optional smoothing with the strength chosen in Settings.
///
/// Honest limits: both happen when the pen is lifted, not live while writing (PencilKit does not
/// expose the stroke while it is being drawn), and the original stroke is not kept: Undo removes
/// the refined stroke as a whole.
enum InkRefiner {
    static var snapsShapes: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.snapShapesOnHold) as? Bool ?? true
    }

    static var scribbleErases: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.scribbleToErase) as? Bool ?? true
    }

    /// If the last stroke is a scribble drawn over other strokes, returns the drawing without the
    /// scribble and without the strokes it covers, and how many were erased. Strokes count as
    /// covered when their centre lies inside the scribble's area. A scribble over empty paper is
    /// left alone (it is ordinary ink).
    static func scribbleErase(in drawing: PKDrawing) -> (drawing: PKDrawing, erased: Int)? {
        guard scribbleErases, drawing.strokes.count >= 2, let scribble = drawing.strokes.last else { return nil }
        let locations = scribble.path.map { $0.location.applying(scribble.transform) }
        guard InkGeometry.isScribble(locations.map { PagePoint(x: Double($0.x), y: Double($0.y)) }) else { return nil }

        let area = scribble.renderBounds.insetBy(dx: -4, dy: -4)
        let others = drawing.strokes.dropLast()
        let kept = others.filter { stroke in
            let bounds = stroke.renderBounds
            return !area.contains(CGPoint(x: bounds.midX, y: bounds.midY))
        }
        let erased = others.count - kept.count
        guard erased > 0 else { return nil }
        var result = drawing
        result.strokes = Array(kept)
        return (result, erased)
    }

    static var smoothingStrength: Double {
        UserDefaults.standard.object(forKey: SettingsKey.smoothingStrength) as? Double ?? 0
    }

    /// The refined drawing, or nil when the last stroke should stay as drawn.
    static func refineLastStroke(of drawing: PKDrawing) -> PKDrawing? {
        guard let stroke = drawing.strokes.last else { return nil }
        let points = Array(stroke.path)
        guard points.count >= 2 else { return nil }

        let samples = points.map {
            InkSample(x: Double($0.location.x), y: Double($0.location.y), time: $0.timeOffset)
        }

        var refined: PKStroke?
        if snapsShapes, let held = InkGeometry.strokeEndingInHold(samples),
           let shape = InkGeometry.recognizeShape(held.map(\.location)) {
            refined = makeStroke(like: stroke, points: points, outline: shape.outline())
        } else if smoothingStrength > 0.01, points.count > 4 {
            let smoothed = InkGeometry.smooth(samples.map(\.location), strength: smoothingStrength)
            let newPoints = zip(points, smoothed).map { original, location in
                PKStrokePoint(
                    location: CGPoint(x: location.x, y: location.y), timeOffset: original.timeOffset,
                    size: original.size, opacity: original.opacity, force: original.force,
                    azimuth: original.azimuth, altitude: original.altitude)
            }
            refined = PKStroke(
                ink: stroke.ink,
                path: PKStrokePath(controlPoints: newPoints, creationDate: stroke.path.creationDate),
                transform: stroke.transform, mask: stroke.mask)
        }

        guard let refined else { return nil }
        var result = drawing
        result.strokes[result.strokes.count - 1] = refined
        return result
    }

    /// A new stroke along `outline`, with the original's ink and a typical point of its pressure,
    /// width and tilt, so the shape looks like the user's own pen.
    private static func makeStroke(like stroke: PKStroke, points: [PKStrokePoint], outline: [PagePoint]) -> PKStroke {
        let typical = points[points.count / 2]
        let duration = max(points.last?.timeOffset ?? 0.3, 0.3)
        let newPoints = outline.enumerated().map { index, point in
            PKStrokePoint(
                location: CGPoint(x: point.x, y: point.y),
                timeOffset: duration * Double(index) / Double(max(outline.count - 1, 1)),
                size: typical.size, opacity: typical.opacity, force: typical.force,
                azimuth: typical.azimuth, altitude: typical.altitude)
        }
        return PKStroke(
            ink: stroke.ink,
            path: PKStrokePath(controlPoints: newPoints, creationDate: stroke.path.creationDate),
            transform: stroke.transform, mask: stroke.mask)
    }
}
