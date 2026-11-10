# Feature matrix

Last updated: 2026-11-10.

**Status legend**

- **Written**: source code exists; never compiled, run, or tested (no Swift toolchain where it was authored).
- **Partial**: some of the requirement is Written; the rest is not started (see note).
- **Not started**: no code.
- **Blocked**: needs an external asset, credential, account or owner decision first.
- **Verified**: built and tested, with the date and how. *Nothing is Verified yet.*

"Verified" may only be set after the acceptance check was actually executed.

**Reference-app inventory:** the feature inventory from public documentation of CollaNote, Freenotes,
Goodnotes, Complete Anatomy and Visible Body has **not been researched yet**. The rows below are the
explicit scope from the build brief only. Add researched features as new rows with their source.

## 3. UI and navigation

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Primary areas: Library, Editor, Settings | A | Written | |
| Primary areas: Study, Atlas, Community | B–E | Not started | Honest "not available" screens are Written |
| Adaptive sidebar | A | Written | `NavigationSplitView` |
| Palette (white/gray, navy, cyan), dark mode | A | Written | Paper stays white in dark mode |
| Arabic RTL + English LTR UI | A | Written | 119 strings translated; layout mirroring untested |
| Dynamic Type, VoiceOver labels | A | Partial | System text styles and labels used; no audit done |
| Keyboard shortcuts | A | Partial | Undo/redo only |
| Compact toolbar | A | Written | Not yet customizable |
| Page thumbnails | A | Written | |
| Document tabs | B | Not started | |
| Assistant / inspector side panel | C | Not started | |
| PDF beside lecture or atlas | C–D | Not started | |
| Position preserved when panels toggle | A | Written | Anchor restore in `EditorCanvasController` |
| Empty / loading / error states | A | Written | Library and editor |
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
| Blank and multi-page notebooks | A | Written | |
| Page duplicate / reorder / delete | A | Written | Delete is confirmed, not undoable |
| Bookmarks | A | Partial | Per-page flag and badge; no bookmark list |
| Covers, chapter outlines, internal links | B | Not started | |
| Templates: blank, ruled, grid, dot, Cornell | A | Written | |
| Templates: planner, custom imported background | B | Not started | |
| Change background without moving ink | A | Written | |
| Vertical scrolling | A | Written | |
| Horizontal page turning | B | Not started | |
| Expandable margins around PDF pages | B | Not started | |
| Typed text, images, shapes, sticky notes, links, tables, formulas | B | Not started | |
| Stickers (original pack, custom import) | B | Not started | Needs original artwork |
| Audio attachments | C | Not started | |
| Atlas scene cards | D | Not started | |
| Object resize / rotate / layer / group / lock | B | Not started | |
| PDF hyperlinks + return-to-position | B | Not started | |
| Export PDF with annotations | A | Written | Flattened; ink rasterized at 3x. Not opened in an external viewer yet |
| Export / import native package | A | Written | Directory sharing untested |

## 5. Handwriting and gestures

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Pen, pencil, highlighter | A | Written | Native PencilKit inks |
| Eraser (stroke / partial) | A | Written | |
| Colors, thickness | A | Written | |
| Opacity, tool favorites | B | Not started | |
| Extra brushes | B | Not started | Only with a real implementation |
| Finger drawing mode | A | Written | |
| Lasso selection | A | Written | Native PencilKit lasso |
| Rectangular selection, resize selection | B | Not started | |
| Undo / redo | A | Written | Ink only |
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
| Focus timer, activity dashboard, reminders, goals | B–C | Not started | |

## 10. Scientific utilities

| Feature | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Insert / Study Tools panel with favorites and reorder | B | Not started | |
| Scientific calculator, graphing calculator | B | Not started | |
| Handwriting calculator | B | Not started | Depends on recognition |
| Step-by-step math solver | B–C | Not started | |
| Translation tool | C | Not started | |
| Periodic table | B | Blocked | Needs a licensed, cited dataset |
| Study game | B | Not started | |

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
| Arabic/English normalization | A | Written | `SearchNormalizer` + tests |
| Title search | A | Written | |
| PDF text, handwriting, tags, headings, transcripts | B–C | Not started | SQLite FTS5 planned |
| "Where have I studied this?", highlight compilation, image occlusion | B–C | Not started | |

## 14–15. Engineering and deliverables

| Item | Milestone | Status | Notes |
| --- | --- | --- | --- |
| Versioned file format + migrations | A | Written | Tests written, not run |
| Atomic saves, autosave, index rebuild | A | Written | |
| Lazy page loading for long documents | A | Written | |
| Core unit tests | A | Written | Never executed |
| Runnable Xcode project | A | Partial | `project.yml` for XcodeGen; project not generated or built |
| Backend schema, migrations, functions | C–E | Not started | |
| `.env.example` | A | Written | Placeholders only |
| Asset license inventory | D | Not started | No third-party assets yet. Code dependency: GRDB.swift (MIT) |
| App Store metadata, screenshots, privacy policy, TestFlight notes | E | Not started | |

## Acceptance checks

None of the acceptance checks in the brief has been executed. Each needs a Mac and, for Pencil,
a physical iPad. Record results in PROGRESS.md when run.
