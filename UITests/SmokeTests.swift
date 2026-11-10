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
        app.buttons["Add Page"].tap()
        app.buttons["Grid"].firstMatch.tap()
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
        element(app, "library.card").tap()
        XCTAssertTrue(element(app, "editor.back").waitForExistence(timeout: 15))
        sleep(2)
        shot("11-editor-arabic")
    }
}
