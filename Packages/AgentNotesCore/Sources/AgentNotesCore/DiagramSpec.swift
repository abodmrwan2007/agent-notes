import Foundation

/// A labelled study diagram: artwork (an SVG in the app's asset catalog, named
/// `diagram-<id>`) plus the labels drawn around it. The data lives in
/// `Diagrams.xcassets/diagram-labels.dataset/labels.json`.
public struct DiagramSpec: Codable, Hashable, Identifiable, Sendable {
    public enum Side: String, Codable, Sendable {
        case left
        case right
    }

    public struct Label: Codable, Hashable, Sendable {
        public var en: String
        public var ar: String
        /// The point the leader line touches, in artwork coordinates.
        public var at: [Double]
        public var side: Side

        public var anchorX: Double { at.first ?? 0 }
        public var anchorY: Double { at.count > 1 ? at[1] : 0 }
    }

    public var id: String
    public var en: String
    public var ar: String
    /// Artwork width and height.
    public var size: [Double]
    public var labels: [Label]

    public var width: Double { size.first ?? 0 }
    public var height: Double { size.count > 1 ? size[1] : 0 }
    public var assetName: String { "diagram-" + id }

    public struct File: Codable, Sendable {
        public var diagrams: [DiagramSpec]
    }

    public static func decode(_ data: Data) throws -> [DiagramSpec] {
        try JSONDecoder().decode(File.self, from: data).diagrams
    }
}

/// Where the labels of a diagram go: a column on each side of the artwork, each label as close
/// to the height of its anchor as the spacing allows.
public enum DiagramLayout {
    /// Width of each label column, in artwork units.
    public static let margin: Double = 150
    /// Minimum vertical distance between two labels in one column (room for two lines).
    public static let spacing: Double = 30

    /// The label centre heights for anchors at `anchorYs`, in the same order. Labels keep their
    /// top-to-bottom order, are at least `spacing` apart and stay inside `0...height`.
    public static func labelYs(anchorYs: [Double], height: Double, spacing: Double = spacing) -> [Double] {
        let order = anchorYs.indices.sorted { anchorYs[$0] < anchorYs[$1] }
        var ys: [Double] = []
        for index in order {
            var y = max(anchorYs[index], spacing / 2)
            if let last = ys.last, y < last + spacing { y = last + spacing }
            ys.append(y)
        }
        // Labels pushed past the bottom move back up, pushing their neighbours above them.
        if !ys.isEmpty {
            ys[ys.count - 1] = min(ys[ys.count - 1], height - spacing / 2)
            for i in stride(from: ys.count - 2, through: 0, by: -1) {
                ys[i] = min(ys[i], ys[i + 1] - spacing)
            }
        }
        var result = Array(repeating: 0.0, count: anchorYs.count)
        for (position, index) in order.enumerated() { result[index] = ys[position] }
        return result
    }

    /// Label heights for every label of `spec`, in the order of `spec.labels`.
    public static func labelYs(for spec: DiagramSpec) -> [Double] {
        var result = Array(repeating: 0.0, count: spec.labels.count)
        for side in [DiagramSpec.Side.left, .right] {
            let indices = spec.labels.indices.filter { spec.labels[$0].side == side }
            let ys = labelYs(anchorYs: indices.map { spec.labels[$0].anchorY }, height: spec.height)
            for (index, y) in zip(indices, ys) { result[index] = y }
        }
        return result
    }
}
