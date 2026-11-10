# Progress and remaining work

Last updated: 2026-11-10. Update this file at the end of every working session.

## Honest status

| Item | Status |
| --- | --- |
| Milestone A source code | Written |
| Swift compilation (core package or app) | **Never executed.** No Swift toolchain on the authoring machine |
| Core unit tests (`swift test`) | **Never executed** |
| iPad simulator / device run | **Never executed** |
| Apple Pencil test | **Never executed** |
| Static checks (`python tools/check_strings.py`) | Passed on 2026-11-10 (119 strings, 4 JSON files, 27 Swift files) |
| Git repository | Not initialized: `git` is not installed on the authoring machine |

Expect compile errors on first build. The code was written carefully against known APIs but nothing
has been checked by a compiler. The first Mac session should fix those before any new feature work.

## Authoring environment (2026-11-10)

Windows 10, PowerShell. Available: Node 24, Python 3.12, winget. Missing: git, Swift, Xcode, Docker,
WSL distro, Supabase CLI, Blender.

## What exists (Milestone A)

- Core package: document manifest model, versioned codec with migration chain, package layout,
  page operations, PDF crop/rotation geometry, template geometry, bilingual search normalizer, tests.
- App: library (SQLite/GRDB index, folders, favorites, trash, sort, title search, rename, duplicate,
  move), PDF and native-package import, blank notebooks with 5 templates, editor (lazy page stack,
  zoom, PencilKit ink per page, own toolbar, undo/redo, thumbnails, page add/duplicate/reorder/
  delete/bookmark/template change), debounced atomic autosave, flattened PDF export, native package
  export, settings, Arabic + English UI, honest placeholder screens for Study/Atlas/Community.

## First tasks on a Mac (in order)

1. `brew install xcodegen && xcodegen generate`
2. `swift test --package-path Packages/AgentNotesCore` and fix failures.
3. Build the app; fix compile errors. Likely spots: GRDB record conformances
   (`App/Storage/LibraryDatabase.swift`), SwiftUI overload resolution in `LibraryView.swift` and
   `EditorScreen.swift`, `@Observable` + `init` in `EditorModel.swift`.
4. Run the README demo path on a simulator, then on an iPad with Pencil.
5. Verify the device-only risks below and record results here.

## Unverified behaviour to check on device

| Risk | Where | What to check |
| --- | --- | --- |
| PDF rotation/crop drawing | `PageRenderer.drawBackground` | Assumes `PDFPage.draw(with:to:)` applies crop box and rotation and places the page at the origin. Test with 90/180/270-rotated and cropped PDFs; ink must stay aligned on screen and in export |
| Ink sharpness when zoomed | `EditorCanvasController` | Each page's `PKCanvasView` is scaled by an ancestor transform. Strokes may look soft at high zoom. If so, re-render at the zoom scale or switch to per-canvas zoom |
| Finger scroll vs Pencil draw | `PageView.load`, `applyDrawingPolicy` | With `.pencilOnly`, one finger must scroll the outer scroll view; with finger drawing on, two fingers scroll |
| Programmatic drawing assignment | `PageView.load` | `canvasViewDrawingDidChange` must not trigger a save when a page is merely loaded |
| Undo across pages | `EditorCanvasController.undoManager` | Canvases should register with the controller's undo manager; undo on a page scrolled far away |
| Sharing a package directory | `EditorScreen.export` | `UIActivityViewController` with a `.agentnote` directory: Save to Files and AirDrop; re-import through the picker |
| Tiled PDF drawing off-main | `PageBackgroundView.draw` | No crashes or blank tiles on long PDFs while scrolling fast |
| Force-quit recovery | `InkAutosaver` | Write, force-quit within 1 s, relaunch. Up to `autosaveDelay` (0.8 s) of strokes can be lost by design if the process is killed without backgrounding |
| Long documents | `EditorCanvasController.rebuild` | 500+ page PDF: memory stays flat while scrolling; open time acceptable |

## Known gaps inside Milestone A scope

- Image import, document tabs, covers, chapter outlines, internal links, tags: not started.
- Horizontal page-turn mode and expandable PDF margins: not started (vertical scrolling only).
- Page deletion is not undoable (confirmation dialog instead; undo history is cleared).
- Exported PDF does not carry over the source PDF's hyperlinks or outline.
- Library search covers titles only. Full-text search is Milestone B.
- No app icon artwork (empty AppIcon set: Xcode will warn).
- No recovery journal beyond per-file atomic writes and index rebuild from packages.
- Password-protected PDFs are rejected with a message.

## Decisions waiting for the owner

1. Exact annual Pro price (provisional USD 19.99/year) before creating App Store products.
2. Confirm the "2 one-time atlas sessions" interpretation before public release.
3. Bundle identifier / Apple developer team (currently placeholder `com.agentnotes.app`).
4. Whether to install the Swift toolchain on the Windows machine so the core package tests can run
   there, or to do all compilation on a Mac.

## Next milestones

See [FEATURE_MATRIX.md](FEATURE_MATRIX.md). Do not start Milestone B features before Milestone A
compiles and the demo path passes.

## Verification commands

```
python tools/check_strings.py                                  # anywhere
swift test --package-path Packages/AgentNotesCore              # Mac (or any Swift toolchain)
xcodegen generate                                              # Mac
xcodebuild -project AgentNotes.xcodeproj -scheme AgentNotes -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```
