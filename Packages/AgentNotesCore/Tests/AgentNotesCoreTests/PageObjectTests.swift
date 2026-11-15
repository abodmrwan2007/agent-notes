import XCTest
@testable import AgentNotesCore

final class PageObjectTests: XCTestCase {
    private func note(x: Double = 100, y: Double = 100, width: Double = 200, height: Double = 120) -> PageObject {
        PageObject(kind: .stickyNote, frame: PageRect(x: x, y: y, width: width, height: height), text: "ملاحظة note")
    }

    func testStackingOrderAndHitTesting() {
        var layer = PageObjectLayer()
        let bottom = note()
        let top = note(x: 150, y: 150)
        layer.add(bottom)
        layer.add(top)

        // In the overlap the object added last is on top.
        XCTAssertEqual(layer.topmostObject(at: PagePoint(x: 200, y: 200))?.id, top.id)
        XCTAssertEqual(layer.topmostObject(at: PagePoint(x: 110, y: 110))?.id, bottom.id)
        XCTAssertNil(layer.topmostObject(at: PagePoint(x: 10, y: 10)))

        layer.bringToFront(bottom.id)
        XCTAssertEqual(layer.topmostObject(at: PagePoint(x: 200, y: 200))?.id, bottom.id)
        layer.sendToBack(bottom.id)
        XCTAssertEqual(layer.topmostObject(at: PagePoint(x: 200, y: 200))?.id, top.id)
        XCTAssertEqual(layer.objects.map(\.id), [bottom.id, top.id])
    }

    func testRotatedHitTesting() {
        // A wide, flat box rotated a quarter turn becomes tall and narrow.
        var object = PageObject(kind: .shape, frame: PageRect(x: 100, y: 190, width: 200, height: 20), shape: .rectangle)
        XCTAssertTrue(object.contains(PagePoint(x: 110, y: 200)))
        XCTAssertFalse(object.contains(PagePoint(x: 200, y: 120)))
        object.rotation = 90
        XCTAssertFalse(object.contains(PagePoint(x: 110, y: 200)))
        XCTAssertTrue(object.contains(PagePoint(x: 200, y: 120)))
        XCTAssertTrue(object.contains(PagePoint(x: 200, y: 200)))
    }

    func testLockedObjectsCannotBeChangedOrRemoved() {
        var layer = PageObjectLayer()
        let object = note()
        layer.add(object)
        layer.setLocked(true, id: object.id)

        XCTAssertFalse(layer.update(object.id) { $0.text = "changed" })
        XCTAssertFalse(layer.move(object.id, toOrigin: PagePoint(x: 0, y: 0), pageSize: .a4))
        XCTAssertFalse(layer.resize(object.id, toWidth: 50, height: 50, keepAspectRatio: false))
        XCTAssertFalse(layer.remove(object.id))
        XCTAssertEqual(layer.object(id: object.id)?.text, "ملاحظة note")
        XCTAssertEqual(layer.object(id: object.id)?.frame, object.frame)

        layer.setLocked(false, id: object.id)
        XCTAssertTrue(layer.remove(object.id))
        XCTAssertTrue(layer.isEmpty)
    }

    func testMoveKeepsPartOfTheObjectOnThePage() {
        var layer = PageObjectLayer()
        let object = note()
        layer.add(object)
        let page = PageSize.a4
        let keep = PageObjectLayer.keepVisible

        layer.move(object.id, toOrigin: PagePoint(x: -5000, y: -5000), pageSize: page)
        XCTAssertEqual(layer.object(id: object.id)?.frame.maxX, keep)
        XCTAssertEqual(layer.object(id: object.id)?.frame.maxY, keep)

        layer.move(object.id, toOrigin: PagePoint(x: 5000, y: 5000), pageSize: page)
        XCTAssertEqual(layer.object(id: object.id)?.frame.x, page.width - keep)
        XCTAssertEqual(layer.object(id: object.id)?.frame.y, page.height - keep)

        layer.move(object.id, toOrigin: PagePoint(x: 40, y: 60), pageSize: page)
        XCTAssertEqual(layer.object(id: object.id)?.frame.x, 40)
        XCTAssertEqual(layer.object(id: object.id)?.frame.y, 60)
        // Moving never changes the size.
        XCTAssertEqual(layer.object(id: object.id)?.frame.width, 200)
    }

    func testResizeRespectsMinimumAndAspectRatio() {
        var layer = PageObjectLayer()
        let object = note(width: 200, height: 100)
        layer.add(object)

        layer.resize(object.id, toWidth: 1, height: 1, keepAspectRatio: false)
        XCTAssertEqual(layer.object(id: object.id)?.frame.width, PageObjectLayer.minimumSide)
        XCTAssertEqual(layer.object(id: object.id)?.frame.height, PageObjectLayer.minimumSide)

        layer.resize(object.id, toWidth: 200, height: 100, keepAspectRatio: false)
        layer.resize(object.id, toWidth: 400, height: 110, keepAspectRatio: true)
        let frame = layer.object(id: object.id)?.frame
        XCTAssertEqual(frame?.width ?? 0, 400, accuracy: 1e-9)
        XCTAssertEqual(frame?.height ?? 0, 200, accuracy: 1e-9)
        // The top-left corner stays put.
        XCTAssertEqual(frame?.x, 100)
        XCTAssertEqual(frame?.y, 100)
    }

    func testDuplicateIsANewUnlockedObjectOnTop() {
        var layer = PageObjectLayer()
        let object = note()
        layer.add(object)
        layer.setLocked(true, id: object.id)
        let copy = layer.duplicate(object.id)
        XCTAssertNotNil(copy)
        XCTAssertNotEqual(copy?.id, object.id)
        XCTAssertEqual(copy?.isLocked, false)
        XCTAssertEqual(copy?.text, object.text)
        XCTAssertEqual(layer.objects.last?.id, copy?.id)
        XCTAssertNotEqual(copy?.frame.x, object.frame.x)
        XCTAssertNil(layer.duplicate(UUID()))
    }

    func testObjectsRoundTripThroughThePackage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("objects-test-\(UUID().uuidString).agentnote", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = DocumentPackageLayout(root: root)
        try layout.createDirectories()
        let pageID = UUID()

        XCTAssertTrue(try layout.readObjects(pageID: pageID).isEmpty)

        var layer = PageObjectLayer()
        layer.add(note())
        layer.add(PageObject(
            kind: .shape, frame: PageRect(x: 10, y: 20, width: 30, height: 40), rotation: 90,
            colorHex: "CC2229", shape: .arrow, lineWidth: 3))
        layer.add(PageObject(
            kind: .image, frame: PageRect(x: 0, y: 0, width: 300, height: 200), assetFileName: "a.jpg"))
        layer.add(PageObject(
            kind: .stickyNote, frame: PageRect(x: 5, y: 5, width: 150, height: 150), text: "مهم", noteStyle: .taped))
        try layout.writeObjects(layer, pageID: pageID)
        XCTAssertEqual(try layout.readObjects(pageID: pageID), layer)

        // Writing an empty layer removes the file instead of leaving an empty one behind.
        try layout.writeObjects(PageObjectLayer(), pageID: pageID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: layout.objectsURL(pageID: pageID).path))
        XCTAssertTrue(try layout.readObjects(pageID: pageID).isEmpty)
    }

    func testWritingObjectsIntoAVersion1PackageCreatesTheDirectory() throws {
        // A package made before objects existed has no objects/ directory.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-test-\(UUID().uuidString).agentnote", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let layout = DocumentPackageLayout(root: root)
        let pageID = UUID()
        var layer = PageObjectLayer()
        layer.add(note())
        try layout.writeObjects(layer, pageID: pageID)
        XCTAssertEqual(try layout.readObjects(pageID: pageID), layer)
    }
}
