# Progress and remaining work

Last updated: 2026-11-10. Update this file at the end of every working session.

## Honest status

| Item | Status |
| --- | --- |
| Milestone A source code | Written and compiling |
| App build (Xcode 16.4, iPad simulator, Debug) | **Passes in CI**, 0 errors (GitHub Actions run 42816099862, 2026-11-10) |
| Core unit tests | **20 tests pass** in CI on Linux (Swift 6.0) |
| UI smoke tests on an iPad Pro simulator | **3 tests pass** in CI; 13 screenshots inspected by eye |
| Static checks (`python tools/check_strings.py`) | Pass |
| Physical iPad run | **Never executed** |
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
- Published as release `playground-1` (asset `AgentNotes.swiftpm.zip`) in the private repository.
- **Never opened in Swift Playgrounds on an iPad yet.** Unknowns: whether the Arabic strings are
  picked up from the package resources, and whether `.agentnote` import works without a declared type.
- Regenerate and publish a new release after every app change the owner should test.

## Next steps, in order

1. Owner opens the playground on the iPad and reports what works with Apple Pencil; fix what fails.
2. Fixture PDFs (rotated, cropped, long) + a UI test for import, annotation alignment and export.
3. UI tests for library actions, dark mode and landscape.
4. Then Milestone B. See [FEATURE_MATRIX.md](FEATURE_MATRIX.md).
