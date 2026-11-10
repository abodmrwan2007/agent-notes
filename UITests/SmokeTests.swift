import XCTest

/// End-to-end smoke test of the Milestone A vertical slice on an iPad simulator.
/// Screenshots are written to the host file system (simulator processes can do that) so CI can
/// upload them for a human to inspect: ink being visible is judged from the pictures.
final class SmokeTests: XCTestCase {
    private let shotsDirectory = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? "/tmp/agentnotes-shots",
        isDirectory: true)

    override func setUp() {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(at: shotsDirectory, withIntermediateDirectories: true)
    }

    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        // The simulator has no Apple Pencil, so finger drawing is switched on through the same
        // user default the Settings toggle writes.
        app.launchArguments = [
            "-allowsFingerDrawing", "YES",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language
        ]
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: shotsDirectory.appendingPathComponent(name + ".png"))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Taps the centre of an element by coordinate. Needed for SwiftUI rows and menus whose
    /// identifier lands on a child (an icon) that XCUITest does not consider hittable.
    private func tap(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 10) {
        let target = element(app, identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "missing element \(identifier)")
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func stroke(_ app: XCUIApplication, from: CGVector, to: CGVector) {
        let start = app.coordinate(withNormalizedOffset: from)
        let end = app.coordinate(withNormalizedOffset: to)
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func test1_createWriteCloseReopenAndRelaunch() {
        var app = launch(language: "en")
        shot("01-library-empty")

        // Create a notebook from the empty state; the editor opens on it.
        let create = element(app, "library.empty.newNotebook")
        XCTAssertTrue(create.waitForExistence(timeout: 15), "empty-state New Notebook button")
        create.tap()

        let back = element(app, "editor.back")
        XCTAssertTrue(back.waitForExistence(timeout: 15), "editor did not open")
        XCTAssertTrue(app.staticTexts["Page 1 of 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Undo"].isEnabled, "nothing to undo before writing")
        shot("02-editor-empty")

        // Write three strokes.
        stroke(app, from: CGVector(dx: 0.40, dy: 0.40), to: CGVector(dx: 0.75, dy: 0.45))
        stroke(app, from: CGVector(dx: 0.45, dy: 0.50), to: CGVector(dx: 0.70, dy: 0.65))
        stroke(app, from: CGVector(dx: 0.70, dy: 0.50), to: CGVector(dx: 0.45, dy: 0.65))
        XCTAssertTrue(app.buttons["Undo"].isEnabled, "strokes were not registered by the canvas")
        shot("03-editor-ink")

        // Undo one stroke, then redo it.
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Redo"].isEnabled)
        shot("04-editor-after-undo")
        app.buttons["Redo"].tap()

        // Add a second page.
        // SwiftUI Menu labels are not reliably "hittable" for XCUITest, so tap by coordinate.
        let addPage = app.buttons["Add Page"].firstMatch
        XCTAssertTrue(addPage.waitForExistence(timeout: 5))
        addPage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let grid = app.buttons["Grid"].firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "template menu did not open")
        shot("04b-add-page-menu")
        grid.tap()
        XCTAssertTrue(app.staticTexts["Page 2 of 2"].waitForExistence(timeout: 5), "second page was not added")
        shot("05-editor-two-pages")

        // Give the autosave debounce time to fire, then go back to the library.
        sleep(2)
        back.tap()
        let card = element(app, "library.card")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "notebook card missing in library")
        sleep(2)
        shot("06-library-with-notebook")

        // Force-close and relaunch: the notebook and its ink must still be there.
        app.terminate()
        app = launch(language: "en")
        let cardAfterRelaunch = element(app, "library.card")
        XCTAssertTrue(cardAfterRelaunch.waitForExistence(timeout: 15), "notebook lost after relaunch")
        cardAfterRelaunch.tap()
        XCTAssertTrue(element(app, "editor.back").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Page 1 of 2"].waitForExistence(timeout: 5), "page count lost after relaunch")
        sleep(2)
        shot("07-reopened-after-relaunch")

        // Flattened PDF export: the share sheet must appear (the file itself is checked by eye
        // on a device; the simulator test only proves the export pipeline completes).
        let export = app.buttons["Export"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let exportPDF = app.buttons["PDF with annotations (flattened)"].firstMatch
        XCTAssertTrue(exportPDF.waitForExistence(timeout: 5), "export menu did not open")
        exportPDF.tap()
        XCTAssertTrue(
            app.otherElements["ActivityListView"].waitForExistence(timeout: 20)
                || app.navigationBars["UIActivityContentView"].exists,
            "share sheet did not appear after PDF export")
        sleep(1)
        shot("07b-export-share-sheet")
    }

    func test2_writeThenKillWithoutLeavingEditor() {
        // Harsher recovery check: write, wait just over the autosave delay, kill the process
        // while the editor is still open (no orderly close), relaunch.
        var app = launch(language: "en")
        let card = element(app, "library.card")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        XCTAssertTrue(element(app, "editor.back").waitForExistence(timeout: 15))

        stroke(app, from: CGVector(dx: 0.40, dy: 0.75), to: CGVector(dx: 0.75, dy: 0.80))
        sleep(2)
        shot("08-before-kill")
        app.terminate()

        app = launch(language: "en")
        let cardAgain = element(app, "library.card")
        XCTAssertTrue(cardAgain.waitForExistence(timeout: 15))
        cardAgain.tap()
        XCTAssertTrue(element(app, "editor.back").waitForExistence(timeout: 15))
        sleep(2)
        shot("09-after-kill-relaunch")
    }

    func test3_arabicInterface() {
        let app = launch(language: "ar")
        XCTAssertTrue(element(app, "library.card").waitForExistence(timeout: 15))
        sleep(1)
        shot("10-library-arabic")

        tap(app, "sidebar.study")
        XCTAssertTrue(element(app, "study.tool.periodicTable").waitForExistence(timeout: 10))
        shot("18-study-arabic")
        tap(app, "study.tool.periodicTable")
        XCTAssertTrue(element(app, "element.Fe").waitForExistence(timeout: 10))
        sleep(1)
        shot("19-periodic-table-arabic")

        app.terminate()
        let relaunched = launch(language: "ar")
        XCTAssertTrue(element(relaunched, "library.card").waitForExistence(timeout: 15))
        element(relaunched, "library.card").tap()
        XCTAssertTrue(element(relaunched, "editor.back").waitForExistence(timeout: 15))
        sleep(2)
        shot("11-editor-arabic")
    }

    private func pressKeys(_ app: XCUIApplication, _ keys: [String]) {
        for key in keys {
            let button = element(app, "key.\(key)")
            XCTAssertTrue(button.waitForExistence(timeout: 5), "calculator key \(key)")
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func goBack(_ app: XCUIApplication, from title: String) {
        let back = app.navigationBars[title].buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "back button on \(title)")
        back.tap()
    }

    func test4_studyTools() {
        let app = launch(language: "en")
        tap(app, "sidebar.study", timeout: 15)
        XCTAssertTrue(element(app, "study.tool.calculator").waitForExistence(timeout: 10), "study tools list")
        shot("12-study-home")

        // Scientific calculator: precedence, degree-mode trigonometry, and an error state.
        tap(app, "study.tool.calculator")
        let input = element(app, "calculator.input")
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        pressKeys(app, ["2", "+", "3", "×", "4", "="])
        XCTAssertEqual(input.value as? String, "14")
        pressKeys(app, ["C", "sin", "3", "0", ")", "="])
        XCTAssertEqual(input.value as? String, "0.5")
        pressKeys(app, ["C", "2", "^", "1", "0", "="])
        XCTAssertEqual(input.value as? String, "1024")
        pressKeys(app, ["C", "1", "÷", "0", "="])
        XCTAssertEqual(element(app, "calculator.status").label, "Division by zero.")
        shot("13-calculator")
        goBack(app, from: "Scientific Calculator")

        // Graphing calculator: the default examples include a pole (1/x).
        tap(app, "study.tool.graph")
        XCTAssertTrue(element(app, "graph.plot").waitForExistence(timeout: 10))
        sleep(1)
        shot("14-graph")
        tap(app, "graph.zoomIn")
        tap(app, "graph.zoomIn")
        sleep(1)
        shot("15-graph-zoomed")
        goBack(app, from: "Graphing Calculator")

        // Periodic table: open an element.
        tap(app, "study.tool.periodicTable")
        let iron = element(app, "element.Fe")
        XCTAssertTrue(iron.waitForExistence(timeout: 10))
        shot("16-periodic-table")
        tap(app, "element.Fe")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "iron detail sheet did not open")
        XCTAssertTrue(app.staticTexts["Iron"].exists, "iron detail sheet content")
        shot("17-element-detail")
        app.buttons["Done"].tap()
        goBack(app, from: "Periodic Table")

        // Focus timer: it must actually count down.
        tap(app, "study.tool.focusTimer")
        let remaining = element(app, "timer.remaining")
        XCTAssertTrue(remaining.waitForExistence(timeout: 10))
        XCTAssertEqual(remaining.label, "25:00")
        tap(app, "timer.start")
        sleep(3)
        XCTAssertNotEqual(remaining.label, "25:00", "timer did not count down")
        shot("20-focus-timer")
        tap(app, "timer.pause")
    }
}
