# Progress and remaining work

Last updated: 2026-11-10. Update this file at the end of every working session.

## Honest status

| Item | Status |
| --- | --- |
| Milestone A source code | Written and compiling |
| App build (Xcode 16.4, iPad simulator, Debug) | **Passes in CI**, 0 errors (latest run 43706433953, 2026-11-15) |
| Core unit tests | **All core tests pass** in CI on Linux (Swift 6.0) |
| UI smoke tests on an iPad Pro simulator | **10 tests pass** in CI; 52 screenshots, the new ones inspected by eye |
| Static checks (`python tools/check_strings.py`) | Pass |
| Physical iPad run | Owner ran the Swift Playgrounds build `playground-1` (Milestone A) on their iPad on 2026-11-10 and reported no errors. No detailed per-feature report yet |
| Apple Pencil test | **Never executed** (the simulator has no Pencil; tests draw with a finger) |
| PDF import with a real PDF | Sim-verified with a generated fixture PDF (import path, text layer, rotated page). The file picker itself and real lecture PDFs are untested |

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

## Side panel, brushes, ruler, reading mode, stickers, lock, covers, colour (2026-11-15) — done

The repository was made **public** on 2026-11-15 at the owner's request, after a scan found no
secrets or personal data in any file or commit; this restored free GitHub Actions minutes (the
private quota had run out). CI run 43706433953: build, 10 UI tests, core tests all pass.

Sim-verified with screenshots 45–52: side panel beside the page (Tools and Stickers tabs; the
compact calculator; "Insert into Page" put "12×3 = 36" on the page as text); stickers inserted
from the panel; watercolor brush; PencilKit ruler on the current page; reading mode hides the
toolbars; coral notebook cover; locking asks the system for the iPad passcode and does not lock when
left unauthenticated; purple interface colour. Layout fixes found in screenshots: the toolbar now
scrolls sideways instead of clipping its first button when the panel is open; calculator keys stay
on one line in the panel.

Lock scope (also stated in code): stops opening, previewing (library cover) and searching a locked
notebook inside the app; not separate encryption.

Reference inventory: docs/REFERENCE_FEATURES.md (CollaNote rows from the owner's screenshots;
Goodnotes / Notability / Freenotes / Notion rows from general knowledge, unverified).

## Milestone B, part 5: scribble erase, Apple Pencil, planner, backgrounds (2026-11-15) — done

CI run 43695433516: build, 8 UI tests, core tests all pass. Planner screenshot (42) inspected.

- **Scribble to erase** (`InkGeometry.isScribble`, `InkRefiner.scribbleErase`): five or more
  back-and-forth passes across ink erase the strokes whose centre lies under the scribble; a notice
  "Erased N strokes" offers Undo. A scribble over empty paper stays ink. The detector counts a
  reversal only when the pen travels back ≥ 35% of the scribble's width, so cursive loops, W/M,
  N/Z shapes and small jitter are not scribbles (unit-tested, and simulated before CI).
  Setting: on by default.
- **Apple Pencil**: double-tap follows the system preference (switch to eraser / previous tool;
  "show palette" does nothing because there is no floating palette yet); squeeze (Pencil Pro,
  iPadOS 17.5+) returns to the previous tool; hover shows a ring at the tip with the pen's width
  and colour.
- **Planner template**: header band, seven day rows, day-name column.
- **Page background image**: page menu "Background Image…" uses a photo as the paper (aspect fill),
  replacing the template; ink and objects do not move. Shown in thumbnails and PDF export.
- Document format **version 3** (`backgroundAsset` page field, `planner` value), empty 2→3 migration.

Verified: Undo after a snapped shape removes the corrected stroke entirely (screenshot from run
43622982759), which is the behaviour scribble-erase relies on.

Not verified (simulator cannot do it): scribble-to-erase in the app (XCUITest can only drag in
straight lines), all Apple Pencil gestures, background images (no test drives the Photos picker).

## Milestone B, part 4: shapes, smoothing, tags, image import (2026-11-14) — done

CI run 43622982759: build, 7 UI tests, core tests all pass. Screenshots 35–41 inspected.

- **Hold to snap** (`InkGeometry`, `InkRefiner`): keep the pen still ≥ 0.45 s at the end of a stroke
  and a recognized line, circle, ellipse or rectangle replaces it, keeping the pen's ink, width
  and pressure. Unit tests cover recognition of wobbly lines, circles, flat ellipses and
  rectangles, and that cursive scribbles, a "U", a dot and a double loop are NOT turned into shapes.
  Rectangles and ellipses are axis-aligned only; no triangles or arrows.
- **Stroke smoothing** with strength 0–1 in Settings (default off). Unit-tested: jitter reduced,
  ends and point count kept, straight lines unchanged.
- Both apply **when the pen is lifted**, not live while writing (PencilKit does not expose the
  stroke in progress). That makes requirement 5.1 ("low-latency smoothing while writing") only
  partially met; live stabilization needs a custom ink engine.
- **Tags** on notebooks: context menu "Tags…", shown on cards, a Tags sidebar section that filters,
  included in library title search. Stored in the SQLite index (migration `v2_tags`; old rows
  decode with no tags). Sim-verified across a relaunch.
- **Images as a notebook**: selecting images in Import creates one notebook, one page per image
  sized to its proportions, image stored in the package as a locked full-page object.
  Sim-verified with a generated two-image fixture (landscape + portrait). The system file picker
  itself is still not driven by a test.

Not verified: the snap/smooth result with a real Apple Pencil and real handwriting; what Undo does
after a snap (PencilKit's own undo registration for the replaced stroke is not inspected; screenshot
38 exists but nothing asserts it); smoothing at all in the simulator.

## Milestone B, part 3: search and PDF text (2026-11-14) — done, Sim-verified

CI run 43618173671: build, 6 UI tests, core tests all pass. Screenshots 29–34 inspected.

- **Search screen** (sidebar): titles, the text layer of imported PDFs, and typed text (text boxes,
  sticky notes). Arabic/English normalization from `SearchNormalizer`; `TextMatcher` maps matches
  back to the original text for excerpts and highlights. PDF text is extracted once per source PDF
  and cached in Caches (`TextIndexService`); search runs off the main thread and is cancelled when
  the query changes.
- **Open a result** at its page with every match highlighted on the PDF text.
- **Select Text tool** in the editor: drag across PDF text, then Copy or "Where Else?" (searches all
  notes for the selection).
- PDF import, search, highlight and selection are now exercised with a real PDF: a Debug-only
  fixture (`UITestFixtures`, launch argument `-uiTestSeedPDF`) with English, Arabic and a page
  rotated 90°.

Simulator run proved: English and Arabic search inside the PDF; highlight sits exactly on the words
on the normal page **and on the 90°-rotated page** (closes the long-standing rotation/crop
alignment risk for search/selection overlays; ink alignment on rotated pages is still unverified);
text selection follows the drag and is copied; "Where Else?" returns results.

Findings worth knowing:
- Arabic search depends on the PDF's own text layer. A PDF generated with the iOS system font
  extracted garbled Arabic (dotless letters, stray symbols); with Geeza Pro the letters were
  correct but the lam-alef ligatures (لأ) and one other ligature still came out as symbols. Real
  lecture PDFs will vary; badly encoded ones need OCR, which does not exist yet.
- Jumping to a result from inside the layout pass kept the app from ever going idle; it now runs
  right after layout.

Not covered: handwriting search (no recognizer), search inside scanned PDFs (no OCR), a persistent
full-text index (search scans cached text; fine for a student library, revisit with SQLite FTS5 for
very large libraries), chapter/heading information in results, highlights for typed-text matches.

## Milestone B, part 2: page objects (2026-11-10) — done, Sim-verified

CI run 42861778463 passed on the first attempt: build, 5 UI tests, core tests. Screenshots 21–28
were inspected.

- Insert menu: text box, sticky note, shapes (rectangle, ellipse, line, arrow), image from Photos.
- Objects tool: tap to select, drag to move, corner handle to resize, double-tap to edit text.
- Object actions: colour, duplicate, bring to front / send to back, rotate 90°, lock, delete.
- Undo/redo covers every object change. Objects appear in thumbnails, library covers and PDF export.
- Document format is **version 2** (`objects/<page-id>.json`, `assets/`); version-1 documents open
  and are upgraded (fixture test).

Simulator run proved: insert a rectangle and drag it; insert a sticky note, type mixed
English/Arabic text into the sheet, rotate it, duplicate it and undo the duplication; objects
survive kill-and-relaunch and show on the library cover.

Not exercised by any test: resize handle, double-tap to edit, lock, front/back, colour change,
delete, image insertion (Photos picker), objects in an exported PDF, behaviour with Apple Pencil.

Known limits by design: rotation in 90° steps only, and the resize handle ignores rotation;
line/arrow always run top-left to bottom-right; no grouping, stickers, tables or formulas;
orphaned image assets are not garbage-collected; image import decodes and downscales on the main
thread.

**Work paused here on 2026-11-10 at the owner's request (weekly usage limit).** Nothing is half
done. Next session starts with the "Next steps" list at the end of this file.

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
  `playground-2` (adds the study tools), `playground-3` (adds page objects), `playground-4` (adds search and PDF text selection), `playground-5` (adds hold-to-snap, smoothing,
  tags, image import), `playground-6` (adds scribble-to-erase, Pencil gestures, planner, backgrounds),
  `playground-7`/`playground-8` (side panel, stickers, brushes, ruler, reading mode, lock, covers, colour).
- The owner opened `playground-1` on their iPad and reported no errors. Still unknown: whether the
  Arabic strings are picked up from the package resources, and whether `.agentnote` import works
  without a declared type. `playground-2` to `-8` have not been reported on yet.
- Regenerate and publish a new release after every app change the owner should test.

## Next steps, in order

1. Owner tries `playground-4` on the iPad with real lecture PDFs (Pencil writing, import, search,
   text selection) and reports specifics; fix what fails.
2. Rest of Milestone B: stickers (needs original artwork or the owner's go-ahead for simple
   original ones), horizontal page turning, Insert/Study Tools panel inside the editor, then the
   handwriting-recognition vendor evaluation (needs a real bilingual sample set from the owner)
   and OCR for scanned pages (Apple Vision supports Arabic text recognition on recent iPadOS;
   verify before relying on it).
2. Fixture PDFs (rotated, cropped, long) + a UI test for import, annotation alignment and export.
3. UI tests for library actions, dark mode and landscape.
4. Then Milestone B. See [FEATURE_MATRIX.md](FEATURE_MATRIX.md).
