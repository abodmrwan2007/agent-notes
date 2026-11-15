import XCTest
@testable import AgentNotesCore

final class ManifestCodecTests: XCTestCase {
    private func sampleManifest() -> DocumentManifest {
        let source = SourceRecord(kind: .pdf, fileName: "a.pdf", originalFileName: "Anatomy.pdf")
        return DocumentManifest(
            title: "قلب Heart",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sources: [source],
            pages: [
                PageRecord(size: .a4, template: .ruled),
                PageRecord(size: PageSize(width: 842, height: 595), pdf: PDFPageReference(sourceID: source.id, pageIndex: 3))
            ]
        )
    }

    func testRoundTripPreservesEverything() throws {
        let manifest = sampleManifest()
        let decoded = try ManifestCodec.decode(ManifestCodec.encode(manifest))
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.formatVersion, DocumentFormat.currentVersion)
    }

    func testRejectsNewerFormat() throws {
        var manifest = sampleManifest()
        manifest.formatVersion = DocumentFormat.currentVersion + 1
        let data = try ManifestCodec.encode(manifest)
        XCTAssertThrowsError(try ManifestCodec.decode(data)) { error in
            XCTAssertEqual(
                error as? ManifestCodecError,
                .newerFormat(found: DocumentFormat.currentVersion + 1, supported: DocumentFormat.currentVersion))
        }
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try ManifestCodec.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? ManifestCodecError, .malformed)
        }
    }

    /// A manifest exactly as version 1 of the app wrote it (before page objects existed).
    private let version1Fixture = """
    {
      "createdAt" : "2023-11-14T22:13:20Z",
      "formatVersion" : 1,
      "id" : "11111111-2222-3333-4444-555555555555",
      "inkEncoding" : "apple.pencilkit.drawing",
      "modifiedAt" : "2023-11-14T22:13:20Z",
      "pages" : [
        {
          "id" : "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
          "isBookmarked" : true,
          "size" : { "height" : 842, "width" : 595 },
          "template" : "ruled"
        }
      ],
      "sources" : [],
      "title" : "قلب Heart"
    }
    """

    func testVersion1DocumentsStillOpenAndAreUpgraded() throws {
        let decoded = try ManifestCodec.decode(Data(version1Fixture.utf8))
        XCTAssertEqual(decoded.formatVersion, DocumentFormat.currentVersion)
        XCTAssertEqual(decoded.title, "قلب Heart")
        XCTAssertEqual(decoded.id, UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        XCTAssertEqual(decoded.pages.count, 1)
        XCTAssertEqual(decoded.pages[0].template, .ruled)
        XCTAssertTrue(decoded.pages[0].isBookmarked)
        XCTAssertEqual(decoded.createdAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testMigrationStepsRunInOrder() throws {
        // A made-up future chain on top of the fixture: 1 -> 2 -> 3, each step leaving a mark.
        let migrations: [Int: ManifestCodec.Migration] = [
            1: { object in object["title"] = "one" },
            2: { object in object["title"] = (object["title"] as? String ?? "") + "+two" }
        ]
        let decoded = try ManifestCodec.decode(Data(version1Fixture.utf8), migrations: migrations, currentVersion: 3)
        XCTAssertEqual(decoded.title, "one+two")
        XCTAssertEqual(decoded.formatVersion, 3)
    }

    func testMissingMigrationIsAnError() throws {
        XCTAssertThrowsError(
            try ManifestCodec.decode(Data(version1Fixture.utf8), migrations: [:], currentVersion: 2)
        ) { error in
            XCTAssertEqual(error as? ManifestCodecError, .missingMigration(from: 1))
        }
    }

    func testPackageWriteAndReadOnDisk() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("core-test-\(UUID().uuidString).agentnote", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = DocumentPackageLayout(root: root)
        try layout.createDirectories()
        let manifest = sampleManifest()
        try layout.writeManifest(manifest)
        XCTAssertEqual(try layout.readManifest(), manifest)
        XCTAssertEqual(layout.inkURL(pageID: manifest.pages[0].id).pathExtension, "ink")
    }
}

final class ManifestEditingTests: XCTestCase {
    private func manifest(pageCount: Int) -> DocumentManifest {
        DocumentManifest(title: "t", pages: (0..<pageCount).map { _ in PageRecord(size: .a4) })
    }

    func testDuplicateInsertsAfterOriginalWithNewID() throws {
        var m = manifest(pageCount: 3)
        let original = m.pages[1]
        let copy = try m.duplicatePage(original.id)
        XCTAssertEqual(m.pages.count, 4)
        XCTAssertEqual(m.pages[2].id, copy.id)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.size, original.size)
    }

    func testCannotRemoveLastPage() throws {
        var m = manifest(pageCount: 1)
        XCTAssertThrowsError(try m.removePage(m.pages[0].id)) { error in
            XCTAssertEqual(error as? ManifestEditError, .cannotRemoveLastPage)
        }
        XCTAssertThrowsError(try m.removePage(UUID())) { error in
            XCTAssertEqual(error as? ManifestEditError, .pageNotFound)
        }
    }

    func testMoveMatchesSwiftUISemantics() {
        var m = manifest(pageCount: 5)
        let ids = m.pages.map(\.id)
        // Move index 0 to "before index 3" -> [1, 2, 0, 3, 4].
        m.movePages(fromOffsets: [0], toOffset: 3)
        XCTAssertEqual(m.pages.map(\.id), [ids[1], ids[2], ids[0], ids[3], ids[4]])

        var n = manifest(pageCount: 5)
        let nids = n.pages.map(\.id)
        // Move index 4 to the front.
        n.movePages(fromOffsets: [4], toOffset: 0)
        XCTAssertEqual(n.pages.map(\.id), [nids[4], nids[0], nids[1], nids[2], nids[3]])

        var k = manifest(pageCount: 5)
        let kids = k.pages.map(\.id)
        // Multi-select 1 and 3 to the end, out-of-range offsets ignored.
        k.movePages(fromOffsets: [3, 1, 99], toOffset: 5)
        XCTAssertEqual(k.pages.map(\.id), [kids[0], kids[2], kids[4], kids[1], kids[3]])
    }

    func testTemplateChangeKeepsPageIdentityAndSize() throws {
        var m = manifest(pageCount: 1)
        let before = m.pages[0]
        try m.setTemplate(.cornell, forPage: before.id)
        XCTAssertEqual(m.pages[0].id, before.id)
        XCTAssertEqual(m.pages[0].size, before.size)
        XCTAssertEqual(m.pages[0].template, .cornell)
    }
}

final class PDFPageGeometryTests: XCTestCase {
    // A cropped page: crop box offset inside the media box.
    private let box = PDFBox(x: 20, y: 30, width: 400, height: 600)

    func testCanonicalSizeSwapsOnQuarterTurns() {
        XCTAssertEqual(PDFPageGeometry(cropBox: box, rotationDegrees: 0).canonicalSize, PageSize(width: 400, height: 600))
        XCTAssertEqual(PDFPageGeometry(cropBox: box, rotationDegrees: 90).canonicalSize, PageSize(width: 600, height: 400))
        XCTAssertEqual(PDFPageGeometry(cropBox: box, rotationDegrees: 180).canonicalSize, PageSize(width: 400, height: 600))
        XCTAssertEqual(PDFPageGeometry(cropBox: box, rotationDegrees: -90).rotation, 270)
        XCTAssertEqual(PDFPageGeometry(cropBox: box, rotationDegrees: 450).rotation, 90)
    }

    func testCornersMapToDisplayedCorners() {
        // PDF top-left corner of the crop box.
        let pdfTopLeft = PagePoint(x: 20, y: 630)
        let pdfBottomLeft = PagePoint(x: 20, y: 30)

        let r0 = PDFPageGeometry(cropBox: box, rotationDegrees: 0)
        XCTAssertEqual(r0.canonicalPoint(fromPDF: pdfTopLeft), PagePoint(x: 0, y: 0))
        XCTAssertEqual(r0.canonicalPoint(fromPDF: pdfBottomLeft), PagePoint(x: 0, y: 600))

        // Rotated 90 clockwise: the original top-left ends up top-right, bottom-left ends up top-left.
        let r90 = PDFPageGeometry(cropBox: box, rotationDegrees: 90)
        XCTAssertEqual(r90.canonicalPoint(fromPDF: pdfTopLeft), PagePoint(x: 600, y: 0))
        XCTAssertEqual(r90.canonicalPoint(fromPDF: pdfBottomLeft), PagePoint(x: 0, y: 0))

        let r180 = PDFPageGeometry(cropBox: box, rotationDegrees: 180)
        XCTAssertEqual(r180.canonicalPoint(fromPDF: pdfTopLeft), PagePoint(x: 400, y: 600))

        // Rotated 270 clockwise: the original top-left ends up bottom-left.
        let r270 = PDFPageGeometry(cropBox: box, rotationDegrees: 270)
        XCTAssertEqual(r270.canonicalPoint(fromPDF: pdfTopLeft), PagePoint(x: 0, y: 400))
    }

    func testRoundTripForEveryRotation() {
        let samples = [PagePoint(x: 20, y: 30), PagePoint(x: 123.5, y: 456.25), PagePoint(x: 420, y: 630)]
        for rotation in [0, 90, 180, 270] {
            let geometry = PDFPageGeometry(cropBox: box, rotationDegrees: rotation)
            for point in samples {
                let back = geometry.pdfPoint(fromCanonical: geometry.canonicalPoint(fromPDF: point))
                XCTAssertEqual(back.x, point.x, accuracy: 1e-9, "rotation \(rotation)")
                XCTAssertEqual(back.y, point.y, accuracy: 1e-9, "rotation \(rotation)")
            }
        }
    }
}

final class TemplateGeometryTests: XCTestCase {
    func testBlankHasNoMarks() {
        let layout = TemplateGeometry.layout(for: .blank, size: .a4)
        XCTAssertTrue(layout.lines.isEmpty)
        XCTAssertTrue(layout.dots.isEmpty)
    }

    func testAllMarksStayInsideThePage() {
        let size = PageSize.a4
        for template in PageTemplate.allCases {
            let layout = TemplateGeometry.layout(for: template, size: size)
            for point in layout.lines.flatMap({ [$0.start, $0.end] }) + layout.dots {
                XCTAssertTrue((0...size.width).contains(point.x), "\(template)")
                XCTAssertTrue((0...size.height).contains(point.y), "\(template)")
            }
        }
    }

    func testCornellHasTwoDividersAndRulingOnlyInNotesArea() {
        let size = PageSize.a4
        let layout = TemplateGeometry.layout(for: .cornell, size: size)
        XCTAssertEqual(layout.lines.filter(\.isEmphasized).count, 2)
        let cueX = (size.width * TemplateGeometry.cornellCueFraction).rounded()
        for line in layout.lines where !line.isEmphasized {
            XCTAssertEqual(line.start.x, cueX)
        }
    }

    func testPlannerHasSevenDayRows() {
        let size = PageSize.a4
        let layout = TemplateGeometry.layout(for: .planner, size: size)
        let horizontalDividers = layout.lines.filter { $0.isEmphasized && $0.start.y == $0.end.y }
        XCTAssertEqual(horizontalDividers.count, 8, "header line, six day dividers and a bottom line")
        XCTAssertEqual(layout.lines.filter { $0.isEmphasized && $0.start.x == $0.end.x }.count, 1)
        XCTAssertEqual(horizontalDividers.first?.start.y, TemplateGeometry.plannerHeaderHeight)
    }

    func testVersion2DocumentsOpenWithoutBackgrounds() throws {
        var manifest = DocumentManifest(title: "v2", pages: [PageRecord(size: .a4, template: .grid)])
        manifest.formatVersion = 2
        let decoded = try ManifestCodec.decode(ManifestCodec.encode(manifest))
        XCTAssertEqual(decoded.formatVersion, DocumentFormat.currentVersion)
        XCTAssertNil(decoded.pages[0].backgroundAsset)
    }

    func testGridAndDotsAreNonEmpty() {
        XCTAssertFalse(TemplateGeometry.layout(for: .grid, size: .a4).lines.isEmpty)
        XCTAssertFalse(TemplateGeometry.layout(for: .dotGrid, size: .a4).dots.isEmpty)
    }
}

final class SearchNormalizerTests: XCTestCase {
    func testArabicVariantsAndDiacritics() {
        XCTAssertEqual(SearchNormalizer.normalize("أُذَيْن"), SearchNormalizer.normalize("اذين"))
        XCTAssertEqual(SearchNormalizer.normalize("الرئة"), SearchNormalizer.normalize("الريه"))
        XCTAssertEqual(SearchNormalizer.normalize("مستشفى"), SearchNormalizer.normalize("مستشفي"))
        XCTAssertEqual(SearchNormalizer.normalize("قـــلب"), "قلب")
    }

    func testDigitsAndLatinFolding() {
        XCTAssertEqual(SearchNormalizer.normalize("الفصل ٣"), "الفصل 3")
        XCTAssertEqual(SearchNormalizer.normalize("  Mitral VALVE "), "mitral valve")
        XCTAssertEqual(SearchNormalizer.normalize("Café"), "cafe")
    }

    func testWhitespaceAndLineBreaksCollapse() {
        XCTAssertEqual(SearchNormalizer.normalize("mitral\n\n  valve"), "mitral valve")
        XCTAssertTrue(SearchNormalizer.matches("the mitral\nvalve closes", query: "Mitral valve"))
    }

    func testArabicPresentationFormsFromPDFs() {
        // "قلب" written with presentation forms, as some PDF text layers produce it.
        let presentation = "\u{FED7}\u{FEE0}\u{FE8F}"
        XCTAssertEqual(SearchNormalizer.normalize(presentation), SearchNormalizer.normalize("قلب"))
    }

    func testMixedScriptMatching() {
        XCTAssertTrue(SearchNormalizer.matches("الصمام التاجي Mitral valve", query: "mitral"))
        XCTAssertTrue(SearchNormalizer.matches("الصِّمام التاجي Mitral valve", query: "الصمام"))
        XCTAssertFalse(SearchNormalizer.matches("Aorta", query: "قلب"))
        XCTAssertTrue(SearchNormalizer.matches("anything", query: "   "))
    }
}
