import Foundation

/// A rectangle in canonical page coordinates (points, origin top-left, y down).
public struct PageRect: Codable, Hashable, Sendable {
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

    public var center: PagePoint { PagePoint(x: x + width / 2, y: y + height / 2) }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    public func contains(_ point: PagePoint) -> Bool {
        point.x >= x && point.x <= maxX && point.y >= y && point.y <= maxY
    }
}

public enum PageObjectKind: String, Codable, Sendable {
    case text
    case stickyNote
    case image
    case shape
}

/// Paper of a sticky note.
public enum NoteStyle: String, Codable, CaseIterable, Sendable {
    case plain
    case lined
    case grid
    /// A strip of tape across the top.
    case taped
    /// A pin at the top.
    case pinned
}

public enum ShapeKind: String, Codable, CaseIterable, Sendable {
    case rectangle
    case ellipse
    /// Drawn from the top-left to the bottom-right corner of the frame.
    case line
    case arrow
}

/// Something placed on a page other than handwriting: typed text, a sticky note, an image or a shape.
/// Geometry is in canonical page coordinates, like ink, so objects never move when the view is zoomed.
public struct PageObject: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: PageObjectKind
    public var frame: PageRect
    /// Clockwise rotation in degrees around the centre of `frame`.
    public var rotation: Double
    public var isLocked: Bool

    /// Text content (text boxes and sticky notes).
    public var text: String?
    public var fontSize: Double?
    /// "RRGGBB". Text colour, shape stroke colour, or sticky-note paper colour.
    public var colorHex: String?
    public var shape: ShapeKind?
    public var lineWidth: Double?
    /// File name inside the package `assets/` directory (images).
    public var assetFileName: String?
    /// Sticky notes only; nil means plain.
    public var noteStyle: NoteStyle?
    /// Text boxes that are links: "page:<page id>" or a web address. See `PageLink`.
    public var link: String?

    public init(
        id: UUID = UUID(),
        kind: PageObjectKind,
        frame: PageRect,
        rotation: Double = 0,
        isLocked: Bool = false,
        text: String? = nil,
        fontSize: Double? = nil,
        colorHex: String? = nil,
        shape: ShapeKind? = nil,
        lineWidth: Double? = nil,
        assetFileName: String? = nil,
        noteStyle: NoteStyle? = nil,
        link: String? = nil
    ) {
        self.link = link
        self.id = id
        self.kind = kind
        self.frame = frame
        self.rotation = rotation
        self.isLocked = isLocked
        self.text = text
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.shape = shape
        self.lineWidth = lineWidth
        self.assetFileName = assetFileName
        self.noteStyle = noteStyle
    }

    public var hasText: Bool { kind == .text || kind == .stickyNote }

    public var pageLink: PageLink? { link.flatMap(PageLink.init(rawValue:)) }

    /// Whether `point` (page coordinates) falls inside the object, taking its rotation into account.
    public func contains(_ point: PagePoint) -> Bool {
        guard rotation != 0 else { return frame.contains(point) }
        // Rotate the point back into the object's unrotated space.
        let centre = frame.center
        let radians = -rotation * .pi / 180
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let local = PagePoint(
            x: centre.x + dx * cos(radians) - dy * sin(radians),
            y: centre.y + dx * sin(radians) + dy * cos(radians))
        return frame.contains(local)
    }
}

/// All objects of one page. Array order is the stacking order: the last object is on top.
public struct PageObjectLayer: Codable, Equatable, Sendable {
    public static let minimumSide = 24.0
    /// How much of an object must stay on the page so it can always be grabbed again.
    public static let keepVisible = 24.0

    public var objects: [PageObject]

    public init(objects: [PageObject] = []) {
        self.objects = objects
    }

    public var isEmpty: Bool { objects.isEmpty }

    public func object(id: UUID) -> PageObject? {
        objects.first { $0.id == id }
    }

    /// The object on top at `point`, if any.
    public func topmostObject(at point: PagePoint) -> PageObject? {
        objects.last { $0.contains(point) }
    }

    public mutating func add(_ object: PageObject) {
        objects.append(object)
    }

    /// Applies `change` to an unlocked object. Returns false when the object is missing or locked.
    @discardableResult
    public mutating func update(_ id: UUID, _ change: (inout PageObject) -> Void) -> Bool {
        guard let index = objects.firstIndex(where: { $0.id == id }), !objects[index].isLocked else {
            return false
        }
        change(&objects[index])
        return true
    }

    /// Locking is the one change allowed on a locked object.
    public mutating func setLocked(_ isLocked: Bool, id: UUID) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        objects[index].isLocked = isLocked
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> Bool {
        guard let index = objects.firstIndex(where: { $0.id == id }), !objects[index].isLocked else {
            return false
        }
        objects.remove(at: index)
        return true
    }

    public mutating func bringToFront(_ id: UUID) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let object = objects.remove(at: index)
        objects.append(object)
    }

    public mutating func sendToBack(_ id: UUID) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let object = objects.remove(at: index)
        objects.insert(object, at: 0)
    }

    /// Adds a copy on top, shifted so it is visibly a second object. The copy is never locked.
    @discardableResult
    public mutating func duplicate(_ id: UUID, offset: Double = 18) -> PageObject? {
        guard var copy = object(id: id) else { return nil }
        copy.id = UUID()
        copy.isLocked = false
        copy.frame.x += offset
        copy.frame.y += offset
        objects.append(copy)
        return copy
    }

    /// Moves an object, keeping part of it on the page.
    @discardableResult
    public mutating func move(_ id: UUID, toOrigin origin: PagePoint, pageSize: PageSize) -> Bool {
        update(id) { object in
            let keep = Self.keepVisible
            object.frame.x = min(max(origin.x, keep - object.frame.width), pageSize.width - keep)
            object.frame.y = min(max(origin.y, keep - object.frame.height), pageSize.height - keep)
        }
    }

    /// Resizes from the bottom-right corner; the top-left corner stays where it is.
    @discardableResult
    public mutating func resize(_ id: UUID, toWidth width: Double, height: Double, keepAspectRatio: Bool) -> Bool {
        update(id) { object in
            var newWidth = max(width, Self.minimumSide)
            var newHeight = max(height, Self.minimumSide)
            if keepAspectRatio, object.frame.width > 0, object.frame.height > 0 {
                let ratio = object.frame.width / object.frame.height
                // Follow whichever side the user dragged further, relative to the original.
                if newWidth / object.frame.width > newHeight / object.frame.height {
                    newHeight = max(newWidth / ratio, Self.minimumSide)
                    newWidth = newHeight * ratio
                } else {
                    newWidth = max(newHeight * ratio, Self.minimumSide)
                    newHeight = newWidth / ratio
                }
            }
            object.frame.width = newWidth
            object.frame.height = newHeight
        }
    }
}

public enum PageObjectCodec {
    public static func encode(_ layer: PageObjectLayer) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(layer)
    }

    public static func decode(_ data: Data) throws -> PageObjectLayer {
        try JSONDecoder().decode(PageObjectLayer.self, from: data)
    }
}
