import Foundation

/// One point of a pen stroke: position in page coordinates and seconds since the stroke began.
public struct InkSample: Hashable, Sendable {
    public var location: PagePoint
    public var time: Double

    public init(x: Double, y: Double, time: Double) {
        self.location = PagePoint(x: x, y: y)
        self.time = time
    }
}

/// An ideal shape that replaces a hand-drawn stroke.
public enum RecognizedShape: Equatable, Sendable {
    case line(from: PagePoint, to: PagePoint)
    /// Axis-aligned. A circle is an ellipse with equal radii.
    case ellipse(center: PagePoint, radiusX: Double, radiusY: Double)
    /// Axis-aligned.
    case rectangle(PageRect)

    /// Points along the shape, in drawing order, for building a new stroke. Corners of a
    /// rectangle are repeated so a smoothing stroke renderer keeps them sharp.
    public func outline(pointsPerSide: Int = 12) -> [PagePoint] {
        switch self {
        case .line(let from, let to):
            return (0...pointsPerSide).map { step in
                let t = Double(step) / Double(pointsPerSide)
                return PagePoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
            }
        case .ellipse(let center, let rx, let ry):
            let count = pointsPerSide * 4
            return (0...count).map { step in
                let angle = Double(step) / Double(count) * 2 * .pi - .pi / 2
                return PagePoint(x: center.x + rx * cos(angle), y: center.y + ry * sin(angle))
            }
        case .rectangle(let rect):
            let corners = [
                PagePoint(x: rect.x, y: rect.y), PagePoint(x: rect.maxX, y: rect.y),
                PagePoint(x: rect.maxX, y: rect.maxY), PagePoint(x: rect.x, y: rect.maxY),
                PagePoint(x: rect.x, y: rect.y)
            ]
            var points: [PagePoint] = []
            for (a, b) in zip(corners, corners.dropFirst()) {
                points += [a, a]
                for step in 1..<pointsPerSide {
                    let t = Double(step) / Double(pointsPerSide)
                    points.append(PagePoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                }
            }
            points += [corners[4], corners[4], corners[4]]
            return points
        }
    }
}

public enum InkGeometry {
    // MARK: Hold detection

    /// Seconds the pen must stay still at the end of a stroke to count as "hold to snap".
    public static let holdDuration = 0.45
    /// How far (points) the pen may drift while holding.
    public static let holdRadius = 4.0

    /// If the stroke ends with the pen held still, returns the stroke without the held part.
    /// Returns nil when there was no hold.
    public static func strokeEndingInHold(_ samples: [InkSample]) -> [InkSample]? {
        guard samples.count >= 3, let last = samples.last else { return nil }
        var index = samples.count - 1
        while index > 0, distance(samples[index - 1].location, last.location) <= holdRadius {
            index -= 1
        }
        guard last.time - samples[index].time >= holdDuration else { return nil }
        let kept = Array(samples[...index])
        return kept.count >= 2 ? kept : nil
    }

    // MARK: Shape recognition

    /// Recognizes a straight line, an ellipse/circle, or a rectangle. Returns nil when the stroke
    /// is none of these (handwriting must never be turned into a shape by accident).
    public static func recognizeShape(_ points: [PagePoint]) -> RecognizedShape? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        let length = pathLength(points)
        guard length >= 12 else { return nil }

        // Line: every point lies close to the segment between the ends.
        let chord = distance(first, last)
        if chord >= 12, chord / length > 0.92 {
            let deviation = points.map { distanceFromSegment($0, first, last) }.max() ?? 0
            if deviation <= max(4, chord * 0.06) {
                return .line(from: first, to: last)
            }
        }

        // Closed shapes: the ends meet and the stroke goes around once.
        guard points.count >= 8, chord <= max(16, length * 0.18) else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let width = maxX - minX
        let height = maxY - minY
        guard width >= 12, height >= 12 else { return nil }
        // One loop only: an ellipse's perimeter is between 2(w+h)·0.78 and 2(w+h).
        guard length <= 2 * (width + height) * 1.35 else { return nil }

        let small = min(width, height)
        let edgeError = points.map { point in
            min(abs(point.x - minX), abs(point.x - maxX), abs(point.y - minY), abs(point.y - maxY))
        }.reduce(0, +) / Double(points.count) / small

        let center = PagePoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let rx = width / 2
        let ry = height / 2
        let ellipseError = points.map { point in
            abs(((point.x - center.x) / rx * (point.x - center.x) / rx
                + (point.y - center.y) / ry * (point.y - center.y) / ry).squareRoot() - 1)
        }.reduce(0, +) / Double(points.count)

        // A rectangle needs points near all four corners; an ellipse never reaches its corners.
        let cornerReach = [
            PagePoint(x: minX, y: minY), PagePoint(x: maxX, y: minY),
            PagePoint(x: maxX, y: maxY), PagePoint(x: minX, y: maxY)
        ].map { corner in points.map { distance($0, corner) }.min() ?? .infinity }
        // (A circle's points stay 0.41·r from its box corners, so 0.15 of the short side is safe.)
        let reachesCorners = cornerReach.allSatisfy { $0 <= small * 0.15 }

        if reachesCorners, edgeError < 0.07, edgeError < ellipseError {
            return .rectangle(PageRect(x: minX, y: minY, width: width, height: height))
        }
        if ellipseError < 0.13 {
            // Nearly round: make it a true circle.
            let ratio = rx / ry
            if ratio > 0.85, ratio < 1 / 0.85 {
                let radius = (rx + ry) / 2
                return .ellipse(center: center, radiusX: radius, radiusY: radius)
            }
            return .ellipse(center: center, radiusX: rx, radiusY: ry)
        }
        return nil
    }

    // MARK: Scribble to erase

    /// True for a fast back-and-forth zigzag (the "scribble out" gesture). Ordinary writing moves
    /// forward with only small backward loops, so it does not qualify: a reversal only counts
    /// when the pen travels back at least `backtrack` of the scribble's width.
    public static func isScribble(_ points: [PagePoint], minimumReversals: Int = 4, backtrack: Double = 0.35) -> Bool {
        guard points.count >= 8 else { return false }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return false }
        let width = maxX - minX
        let height = maxY - minY
        // Measure along the longer side of the scribble.
        let horizontal = width >= height
        let span = max(width, height)
        guard span >= 20 else { return false }
        let along = horizontal ? xs : ys

        // Count changes of direction along that side, ignoring wiggles smaller than the threshold.
        let threshold = span * backtrack
        var reversals = 0
        var direction = 0 // 0 unknown, 1 increasing, -1 decreasing
        var high = along[0]
        var low = along[0]
        for value in along.dropFirst() {
            switch direction {
            case 0:
                high = max(high, value)
                low = min(low, value)
                if value - low >= threshold {
                    direction = 1
                    high = value
                } else if high - value >= threshold {
                    direction = -1
                    low = value
                }
            case 1:
                if value > high {
                    high = value
                } else if high - value >= threshold {
                    reversals += 1
                    direction = -1
                    low = value
                }
            default:
                if value < low {
                    low = value
                } else if value - low >= threshold {
                    reversals += 1
                    direction = 1
                    high = value
                }
            }
        }
        return reversals >= minimumReversals && pathLength(points) >= span * 2.5
    }

    // MARK: Smoothing

    /// Smooths a stroke's path. `strength` is 0 (unchanged) to 1 (strong). The ends stay where
    /// they are and the number of points does not change, so per-point pressure and timing can
    /// be kept by the caller.
    public static func smooth(_ points: [PagePoint], strength: Double) -> [PagePoint] {
        let strength = min(max(strength, 0), 1)
        guard strength > 0, points.count > 2 else { return points }
        let radius = 1 + Int((strength * 3).rounded())
        let passes = 1 + Int((strength * 2).rounded())
        var current = points
        for _ in 0..<passes {
            var next = current
            for index in 1..<(current.count - 1) {
                // Shrink the window near the ends so they are not pulled inward.
                let reach = min(radius, index, current.count - 1 - index)
                var sumX = 0.0
                var sumY = 0.0
                var weightSum = 0.0
                for offset in -reach...reach {
                    let weight = Double(reach + 1 - abs(offset))
                    sumX += current[index + offset].x * weight
                    sumY += current[index + offset].y * weight
                    weightSum += weight
                }
                next[index] = PagePoint(x: sumX / weightSum, y: sumY / weightSum)
            }
            current = next
        }
        return current
    }

    // MARK: Helpers

    public static func distance(_ a: PagePoint, _ b: PagePoint) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    public static func pathLength(_ points: [PagePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func distanceFromSegment(_ p: PagePoint, _ a: PagePoint, _ b: PagePoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(p, a) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared, 0), 1)
        return distance(p, PagePoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}
