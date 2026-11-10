# Agent Notes (working title)

Native iPad note-taking and scientific learning app. Swift, SwiftUI + UIKit, PencilKit, PDFKit.
The display name is configurable (`APP_DISPLAY_NAME` in `project.yml`).

**Current state: Milestone A builds and its smoke tests pass on an iPad simulator in CI
(GitHub Actions, Xcode 16.4). It has never run on a physical iPad or with Apple Pencil.**
Read [PROGRESS.md](PROGRESS.md) for exactly what was and was not verified. Per-feature status is in
[FEATURE_MATRIX.md](FEATURE_MATRIX.md).

It is authored on a Windows machine without Xcode; every build and test runs in
`.github/workflows/ci.yml`, which uploads simulator screenshots as an artifact.

## Layout

| Path | Contents |
| --- | --- |
| `project.yml` | XcodeGen spec that generates `AgentNotes.xcodeproj` |
| `App/` | iPad app target (SwiftUI/UIKit, PencilKit, PDFKit, GRDB) |
| `Packages/AgentNotesCore/` | Platform-neutral core (Foundation only) + unit tests |
| `tools/` | Python scripts: string catalog generator and static checks |
| `docs/` | Design decisions, data format |

## Requirements

- macOS with Xcode 16 or later (GRDB 7 needs Swift 6 tooling; the app compiles in Swift 5 language mode)
- iPadOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- For real handwriting tests: an iPad with Apple Pencil (the simulator has no Pencil pressure/tilt)

## Build and run (on a Mac)

Install XcodeGen once:

```bash
brew install xcodegen
```

Generate the project (re-run whenever files are added or `project.yml` changes):

```bash
xcodegen generate
```

Run the core unit tests (no simulator needed):

```bash
swift test --package-path Packages/AgentNotesCore
```

Build the app for an iPad simulator (pick a simulator name from `xcrun simctl list devices`):

```bash
xcodebuild -project AgentNotes.xcodeproj -scheme AgentNotes -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

Run the UI smoke tests (writes screenshots to `/tmp/agentnotes-shots`):

```bash
xcodebuild -project AgentNotes.xcodeproj -scheme AgentNotes -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' test
```

Or open `AgentNotes.xcodeproj` in Xcode and press Run. To run on a physical iPad set your team ID in
`project.yml` (`DEVELOPMENT_TEAM`) and regenerate.

## Checks that run anywhere (Python 3)

```bash
python tools/check_strings.py
```

Verifies that every UI string has an Arabic translation, JSON resources parse, and Swift files have
balanced delimiters. This is not a compiler and does not prove the app builds.

Regenerate the Arabic string catalog after editing `tools/build_strings.py`:

```bash
python tools/build_strings.py
```

## Demo path for Milestone A (to be executed on a Mac/iPad)

1. Launch. The library is empty: use **New Notebook** (choose a template) or **Import PDF**.
2. Write with Apple Pencil (or enable **Draw with finger** in the toolbar). Try pen, pencil,
   highlighter, both eraser modes, lasso, colors, thickness, undo/redo.
3. Pinch to zoom; toggle the thumbnail sidebar and rotate the iPad: the same content stays at the top.
4. Add, duplicate, reorder (drag in the sidebar), bookmark and delete pages. Change a page template:
   ink does not move.
5. Force-quit the app from the app switcher, relaunch, reopen the notebook: ink is still there.
6. **Export → PDF with annotations** and open the result in Files/Preview. **Export → Editable
   notebook package**, then **Import** that `.agentnote` back.
7. Library: folders and subfolders, favorites, rename, duplicate, move, trash, restore, permanent
   delete, sort, title search (Arabic/English insensitive to diacritics and alef/ya variants).
8. Switch the iPad language to Arabic: UI is right-to-left and translated.

## External credentials and assets

None are needed for Milestone A. `.env.example` lists the placeholders later milestones will need.
