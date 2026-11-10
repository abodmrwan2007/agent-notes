# Feature matrix

Last updated: 2026-11-10.

**Status legend**

- **Written**: source code exists and compiles in CI (Xcode 16.4), but no test or screenshot exercises it yet.
- **Partial**: some of the requirement is Written; the rest is not started (see note).
- **Not started**: no code.
- **Blocked**: needs an external asset, credential, account or owner decision first.
- **Sim-verified**: exercised by the UI smoke tests on an iPad simulator in CI on 2026-11-10 and
  confirmed in the screenshots. Not tested on a physical iPad or with Apple Pencil.
- **Verified**: fully covered by automated tests that pass in CI, with the date and how.

"Verified" may only be set after the acceptance check was actually executed.

**Reference-app inventory:** the feature inventory from public documentation of CollaNote, Freenotes,
Goodnotes, Complete Anatomy and Visible Body has **not been researched yet**. The rows below are the
explicit scope from the build brief only. Add researched features as new rows with their source.

**Device report:** on 2026-11-10 the owner ran the Swift Playgrounds build (`playground-1`,
Milestone A) on their own iPad and reported it builds and runs without errors. No per-feature
detail was reported, so rows stay at Sim-verified until specific device results are recorded.

## 3. UI and navigation

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Primary areas: Library, Editor, Settings | A | Sim-verified | Library and editor seen in screenshots; Settings screen not captured |
| Primary areas: Study, Atlas, Community | B–E | Partial | Study is built (4 tools, Sim-verified). Atlas and Community show honest "not available" screens |
| Adaptive sidebar | A | Sim-verified | `NavigationSplitView`, portrait only |
| Palette (white/gray, navy, cyan), dark mode | A | Partial | Light palette Sim-verified; dark mode not captured |
| Arabic RTL + English LTR UI | A | Sim-verified | 204 strings; library, editor, study panel and periodic table captured in both languages |
| Dynamic Type, VoiceOver labels | A | Partial | System text styles and labels used; no audit done |
| Keyboard shortcuts | A | Partial | Undo/redo only |
| Compact toolbar | A | Sim-verified | Not yet customizable |
| Page thumbnails | A | Sim-verified |  |
| Document tabs | B | Not started | |
| Assistant / inspector side panel | C | Not started | |
| PDF beside lecture or atlas | C–D | Not started | |
| Position preserved when panels toggle | A | Written | Anchor restore in `EditorCanvasController` |
| Empty / loading / error states | A | Partial | Empty library state Sim-verified; error states not exercised |
| Offline, quota, purchase, expiry states | E | Not started | |

## 4. Library, documents, inserts

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Folders, nested folders | A | Written | |
| Favorites, trash with recovery, recents | A | Written | |
| Sorting, title search | A | Written | |
| Duplicate, move, rename | A | Written | |
| Tags | B | Not started | |
| Import PDF (system picker) | A | Written | Password-protected PDFs rejected |
| Import images | B | Not started | |
| Blank and multi-page notebooks | A | Sim-verified |  |
| Page duplicate / reorder / delete | A | Written | Delete is confirmed, not undoable |
| Bookmarks | A | Partial | Per-page flag and badge; no bookmark list |
| Covers, chapter outlines, internal links | B | Not started | |
| Templates: blank, ruled, grid, dot, Cornell | A | Partial | Ruled and grid Sim-verified; blank, dot, Cornell compile but were not captured |
| Templates: planner, custom imported background | B | Not started | |
| Change background without moving ink | A | Written | |
| Vertical scrolling | A | Sim-verified |  |
| Horizontal page turning | B | Not started | |
| Expandable margins around PDF pages | B | Not started | |
| Typed text, images, shapes, sticky notes, links, tables, formulas | B | Partial | Text boxes, sticky notes, 4 shapes Sim-verified (insert, move, edit text, undo, persistence). Image insertion Written, untested. Links, tables, formulas not started |
| Stickers (original pack, custom import) | B | Not started | Needs original artwork |
| Audio attachments | C | Not started | |
| Atlas scene cards | D | Not started | |
| Object resize / rotate / layer / group / lock | B | Partial | Move, rotate 90°, duplicate + undo Sim-verified. Resize handle, front/back, lock, delete Written and unit-tested in the core model but not driven by a UI test. No free rotation, no grouping |
| PDF hyperlinks + return-to-position | B | Not started | |
| Export PDF with annotations | A | Partial | Export completes and the share sheet shows the PDF (Sim-verified). Content not opened in an external viewer; ink rasterized at 3x |
| Export / import native package | A | Written | Directory sharing untested |

## 5. Handwriting and gestures

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Pen, pencil, highlighter | A | Partial | Pen Sim-verified with finger input; pencil, highlighter and real Apple Pencil untested |
| Eraser (stroke / partial) | A | Written | |
| Colors, thickness | A | Written | |
| Opacity, tool favorites | B | Not started | |
| Extra brushes | B | Not started | Only with a real implementation |
| Finger drawing mode | A | Sim-verified |  |
| Lasso selection | A | Written | Native PencilKit lasso |
| Rectangular selection, resize selection | B | Not started | |
| Undo / redo | A | Sim-verified | Ink and page objects |
| Pencil double-tap, Pencil Pro squeeze, hover | B | Not started | |
| (1) Stroke smoothing with adjustable strength | B | Not started | |
| (2) Mixed Arabic–English recognition | B | Not started | Requires vendor evaluation on a real sample set |
| (3) Handwriting beautification with preview | B | Not started | Experimental until proven; never a font swap |
| Recognition vendor evaluation (native / ML Kit / MyScript) | B | Not started | |
| Hold-to-snap shapes | B | Not started | |
| Scribble-to-erase with undo | B | Not started | |
| Configurable gesture preferences | B | Not started | |
| Mind-map connectors | C | Not started | |

## 6. Selection, translation, terminology

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Unified selection action menu | B | Not started | |
| PDF text extraction, OCR, ink recognition | B | Not started | |
| Uncertain-word review | B | Not started | |
| Arabic–English translation | C | Not started | |
| Medical terminology entries | C | Blocked | Needs a licensed or original reviewed term set |
| Personal vocabulary, corrections, reporting | C | Not started | |

## 7. Anatomy atlas

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| RealityKit viewer (rotate, zoom, isolate, hide, transparency, labels) | D | Not started | |
| Heart module with per-structure meshes and IDs | D | Blocked | Needs original/licensed segmented 3D assets and anatomy review |
| Bilingual structure metadata | D | Blocked | Needs reviewer-approved metadata |
| Notebook term to structure linking | D | Not started | |
| Scene cards, snapshots, snapshot ink | D | Not started | |
| Asset packs, offline cache, validation | D | Not started | |
| Quiz mode | D | Not started | |
| Asset pipeline + acceptance checklist document | D | Not started | |
| Additional regions, animations | F | Blocked | After scientific review |

## 8. Scientific assistant

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Assistant modes with preview/confirm | C | Not started | |
| Retrieval with page citations that open and highlight | C | Not started | |
| Summaries, flashcards (spaced review, CSV/TSV), quizzes, mind maps | C | Not started | |
| Provider abstraction (OpenAI, Gemini, xAI, Anthropic) | C | Blocked | Needs API keys; model IDs and prices must come from current docs. No provider tested |
| BYOK | E | Not started | Needs App Store rule check |

## 9. Lectures, audio, study tools

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| YouTube embed / local video beside notes | C | Not started | IFrame API policy check pending |
| Timestamp bookmarks | C | Not started | |
| Transcript import, lecture summaries | C | Not started | |
| Audio recording synced to ink, dictation | C | Not started | |
| Focus timer, activity dashboard, reminders, goals | B–C | Partial | Focus timer Sim-verified (counts down; date-based logic unit-tested for backgrounding). Phase-end notification Written, untested. Dashboard, reminders, goals not started |

## 10. Scientific utilities

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Insert / Study Tools panel with favorites and reorder | B | Partial | Study panel with favorites, reorder, remove/restore is Written (list Sim-verified; the gestures themselves are not exercised by a test). No Insert panel inside the editor yet |
| Scientific calculator, graphing calculator | B | Sim-verified | Safe parser with 44 passing core tests (precedence, functions, errors, poles). UI test checks 2+3×4, sin 30°, 2^10, 1÷0. Graph pan/pinch untested; no units |
| Handwriting calculator | B | Not started | Depends on recognition; listed as unavailable |
| Step-by-step math solver | B–C | Not started | Listed as unavailable in the Study panel |
| Translation tool | C | Not started | Listed as unavailable |
| Periodic table | B | Partial | 118 elements, layout, search, detail sheet Sim-verified. DATA IS UNREVIEWED: typed by hand, must be validated against IUPAC/PubChem; the screen says so |
| Study game | B | Not started | Listed as unavailable |

## 11. Plans, quotas, ads

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| One annual Pro subscription (StoreKit 2, local config) | E | Blocked | Owner must confirm price (provisional USD 19.99/yr) |
| Free limits (3 notebooks, 5 translations/day, 3 AI tasks/day, 2 atlas sessions) | E | Not started | Not enforced anywhere yet |
| Backend usage ledger, idempotency, reservations | E | Not started | |
| Entitlement cache, restore, expiry, refunds | E | Not started | |
| Ads for Free in library | E | Blocked | Needs an ad account; none integrated |

## 12. Community, privacy

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Opt-in sharing, challenges, reactions | E | Not started | Gated until moderation exists |
| Reporting, blocking, moderation, copyright handling | E | Not started | |
| Privacy settings, data export, account deletion | E | Not started | No accounts exist yet |
| Privacy manifest, App Privacy disclosures | E | Not started | Milestone A collects no data and has no network code |

## 13. Search

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Arabic/English normalization | A | Verified | `SearchNormalizer` unit tests pass in CI |
| Title search | A | Written | |
| PDF text, handwriting, tags, headings, transcripts | B–C | Not started | SQLite FTS5 planned |
| "Where have I studied this?", highlight compilation, image occlusion | B–C | Not started | |

## 14–15. Engineering and deliverables

| Item | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Versioned file format + migrations | A | Verified | Format v2 with a real 1→2 migration; version-1 fixture test passes in CI |
| Atomic saves, autosave, index rebuild | A | Sim-verified | Kill-and-relaunch test keeps ink; index refresh after kill seen. Lost-database rebuild untested |
| Lazy page loading for long documents | A | Written | |
| Core unit tests | A | Verified | All core tests pass in CI (Linux, Swift 6.0), 2026-11-10 |
| Runnable Xcode project | A | Verified | XcodeGen + Xcode 16.4 build passes in CI, 2026-11-10 |
| Backend schema, migrations, functions | C–E | Not started | |
| `.env.example` | A | Written | Placeholders only |
| Asset license inventory | D | Not started | No third-party assets yet. Code dependency: GRDB.swift (MIT) |
| App Store metadata, screenshots, privacy policy, TestFlight notes | E | Not started | |

## Acceptance checks

Only one check from the brief has been partly executed: "write, force-close, reopen, verify
content recovery" passes on the simulator with finger input (not with Apple Pencil, not on a device).
Every other acceptance check is still open. Record results in PROGRESS.md when run.
