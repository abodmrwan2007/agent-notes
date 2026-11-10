# Progress and remaining work

Last updated: 2026-11-10. Update this file at the end of every working session.

## Honest status

| Item | Status |
| --- | --- |
| Milestone A source code | Written and compiling |
| App build (Xcode 16.4, iPad simulator, Debug) | **Passes in CI**, 0 errors (latest run 42833212539, 2026-11-10) |
| Core unit tests | **44 tests pass** in CI on Linux (Swift 6.0) |
| UI smoke tests on an iPad Pro simulator | **4 tests pass** in CI; 22 screenshots, the new ones inspected by eye |
| Static checks (`python tools/check_strings.py`) | Pass |
| Physical iPad run | Owner ran the Swift Playgrounds build `playground-1` (Milestone A) on their iPad on 2026-11-10 and reported no errors. No detailed per-feature report yet |
| Apple Pencil test | **Never executed** (the simulator has no Pencil; tests draw with a finger) |
| PDF import with a real PDF | **Never executed** (no test drives the file picker yet) |

Repository: private, `github.com/abodmrwan2007/agent-notes`. CI: `.github/workflows/ci.yml`
(core tests and static checks on Linux, then build + UI tests on macOS). Documentation-only pushes
skip CI.

## What the simulator run proved (inspected screenshots, 2026-11-10)

- Launch into an empty library; create a ruled notebook; editor opens.
- Finger strokes render; undo and redo work; thumbnails update after autosave.
- Add a second page (grid template); page indicator follows.
- Close to library: cover shows the ink and page count.
- Terminate and relaunch: notebook, both pages and ink are intact.
- Write, wait 2 s, kill the process with the editor open, relaunch: the stroke survived, and the
  library cover is up to date.
- Flattened PDF export completes and the share sheet shows a 127 KB PDF.
- Arabic launch: right-to-left layout, translated labels, localized date.

## Milestone B, part 1: study tools (2026-11-10)

The Study area now has four working tools and a panel with favorites, reorder and remove/restore:

- **Scientific calculator**: `MathExpression` in the core package is a hand-written recursive-descent
  parser and evaluator (no `NSExpression`, no dynamic code). Degrees/radians, exact values at
  multiples of 90 degrees, Arabic-Indic digits, implicit multiplication, typed errors.
- **Graphing calculator**: `GraphSampler` cuts curves at poles (midpoint test) and extends each
  branch by bisection to the window edge or the domain edge.
- **Periodic table**: 118 elements, computed group/period/layout, bilingual names, search, detail.
  **The data set is unreviewed** (typed by hand); the screen states this. Validate against
  IUPAC/PubChem and review the Arabic names before release.
- **Focus timer**: `FocusTimer` is defined by absolute dates, so it stays correct across
  backgrounding and relaunch. Optional phase-end notification, requested only when switched on.

Simulator run proved: calculator results for 2+3×4, sin(30) in degrees, 2^10 and the 1÷0 error;
graph renders sin(x) and 1/x with both branches reaching the window edges and no line through the
pole; periodic table layout in English and Arabic, element detail sheet; timer counts down.

Not exercised by any test: graph pan/pinch, typing a custom formula, panel swipe/reorder gestures,
timer notification, timer behaviour across a real background/relaunch (unit-tested logic only).

Found in screenshots and fixed: 1/x branches stopping short of the window edge; a possible false
line through a pole at some window sizes; a large blank area above the periodic table; the table
opening on its right end in Arabic; axis labels clipped at the plot edge.

## Milestone B, part 2: page objects — IN PROGRESS, PAUSED 2026-11-10

**Resume here.** Work stopped at the owner's request (weekly usage limit). State when paused:

- Code is written and pushed (commit "Milestone B (part 2): page objects…"): text boxes, sticky
  notes, shapes (rectangle, ellipse, line, arrow), images from Photos; Objects tool (select, move,
  resize, double-tap to edit text); object actions (colour, duplicate, front/back, rotate 90°,
  lock, delete); undo/redo; objects in thumbnails, covers and PDF export.
- Document format bumped to **version 2** (`objects/<page-id>.json`, `assets/`), with a 1→2
  migration and a version-1 fixture test. `docs/DATA_FORMAT.md` is **not yet updated** for v2.
- **Not verified.** The first CI run for this commit had not finished when work paused. Check the
  latest run (`gh run list --limit 1`): fix compile errors first, then look at screenshots 21–28
  from `test5_pageObjects`.
- Likely trouble spots: `App/Editor/PageObjectsView.swift` (gesture priority against the scroll
  view), `EditorModel` object methods, the `photosPicker` wiring in `EditorScreen.swift`, and the
  UI test's drag coordinates and `typeText` into the text sheet.
- Known limits by design: rotation in 90° steps only and the resize handle ignores rotation;
  line/arrow always run top-left to bottom-right; no grouping, stickers, tables or formulas;
  orphaned image assets are not garbage-collected when their object or page is deleted;
  image import decodes and downscales on the main thread.
- No `playground-3` release yet. Publish one from the CI artifact only after the run is green and
  the screenshots look right. FEATURE_MATRIX.md has not been updated for page objects.

## Bugs found by the simulator run and fixed

1. Library cover and page count were stale after a kill (modification date was only written on an
   orderly close). Now written with every autosave, and stale index rows are refreshed at launch.
2. Empty strip at the bottom of the editor (safe area). Pages now extend under the home indicator.
3. Multi-page documents opened scrolled into the middle of page 1 (setting the zoom scale keeps
   the viewport centre). Now opens at the top.

## Working environment

Authoring machine: Windows 10, no Xcode. Portable Git and GitHub CLI live in
`C:\Users\lenovo\tools` (not installed system-wide; prepend `mingit\cmd` and `gh\bin` to PATH).
All compilation and testing happens in GitHub Actions. An attempt to install Visual Studio Build
Tools + Swift locally was cancelled at the UAC prompt and is no longer needed.

Private-repository macOS minutes are limited and billed at a multiple; a full run takes about
4–5 minutes. Batch changes rather than pushing one-line fixes.

## Loop for every change

```
python tools/check_strings.py
git add -A && git commit -m "..." && git push
gh run watch <id> --exit-status
gh run download <id> --dir <scratch>      # screenshots/ and build-log/
```

Then look at the screenshots. A green run is not enough: two of the three bugs above passed the
assertions and were only visible in the pictures.

## Still unverified (needs a device, or a test that does not exist yet)

| Risk | Where | What to check |
| --- | --- | --- |
| PDF import, rotation/crop drawing | `DocumentStore.importPDF`, `PageRenderer.drawBackground` | Import real PDFs including 90/180/270-rotated and cropped pages; ink alignment on screen and in export. Next step: bundle fixture PDFs and import them through a test launch argument |
| Exported PDF content | `PDFExporter` | Only "share sheet appears with a PDF" is tested. Open the file in an external viewer and compare |
| Ink sharpness when zoomed | `EditorCanvasController` | Canvas is scaled by an ancestor transform; strokes may look soft at high zoom |
| Pencil vs finger | `PageView.load`, `applyDrawingPolicy` | With Pencil-only mode, one finger must scroll; pressure/tilt rendering |
| Undo across far-apart pages | `EditorCanvasController.undoManager` | |
| Native package export/import | `EditorScreen.export`, `DocumentStore.importPackage` | Sharing a directory through the share sheet; re-import |
| Long documents | `EditorCanvasController.rebuild` | 500+ page PDF: memory while scrolling, open time |
| Library actions | `LibraryView` | Folders, move, trash/restore, duplicate, rename, sort and search have no UI test yet |
| Dark mode, rotation, split view | whole app | Not captured yet |

## Known gaps inside Milestone A scope

- Image import, document tabs, covers, chapter outlines, internal links, tags: not started.
- Horizontal page-turn mode and expandable PDF margins: not started (vertical scrolling only).
- Page deletion is not undoable (confirmation dialog instead; undo history is cleared).
- Exported PDF does not carry over the source PDF's hyperlinks or outline.
- Library search covers titles only. Full-text search is Milestone B.
- No app icon artwork (empty AppIcon set).
- Password-protected PDFs are rejected with a message.
- One compiler warning: non-Sendable `NSString` capture in `ThumbnailService.pageThumbnail`.

## Decisions waiting for the owner

1. Exact annual Pro price (provisional USD 19.99/year) before creating App Store products.
2. Confirm the "2 one-time atlas sessions" interpretation before public release.
3. Bundle identifier / Apple developer team (currently placeholder `com.agentnotes.app`).

## Swift Playgrounds variant (for the owner's iPad; no Mac or paid account needed)

- Generated by `python tools/build_playground.py` into `build/playground/` (git-ignored). One module,
  JSON library index instead of GRDB (`playground/LibraryDatabase.swift`), `.lproj` strings.
- CI (run 42819693304): the generated sources compile as one module; Xcode parses the generated
  `Package.swift`. Building through the package manifest itself is attempted as an informational step.
- Releases in the private repository (asset `AgentNotes.swiftpm.zip`): `playground-1` (Milestone A),
  `playground-2` (adds the study tools).
- The owner opened `playground-1` on their iPad and reported no errors. Still unknown: whether the
  Arabic strings are picked up from the package resources, and whether `.agentnote` import works
  without a declared type. `playground-2` has not been reported on yet.
- Regenerate and publish a new release after every app change the owner should test.

## Next steps, in order

1. Owner tries `playground-2` on the iPad (Pencil writing, PDF import, study tools) and reports
   specifics; fix what fails.
2. Rest of Milestone B, in this order: editor objects (text boxes, sticky notes, shapes, images),
   image import, PDF text selection and full-text search, hold-to-snap shapes, then the
   handwriting-recognition vendor evaluation (needs a real bilingual sample set).
2. Fixture PDFs (rotated, cropped, long) + a UI test for import, annotation alignment and export.
3. UI tests for library actions, dark mode and landscape.
4. Then Milestone B. See [FEATURE_MATRIX.md](FEATURE_MATRIX.md).
