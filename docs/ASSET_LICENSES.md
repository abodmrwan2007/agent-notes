# Asset and dependency license inventory

Last updated: 2026-11-15. Every bundled or generated asset and every third-party dependency must
be listed here before release, with its source and the obligations it carries.

## Artwork shipped with the app

| Asset | Where | Source | Ownership / license | Obligations |
| --- | --- | --- | --- | --- |
| Built-in sticker pack (18 stickers: star, heart, check, warning, question, idea, capsule, DNA, flask, heartbeat, bone, arrow, and Important / Exam / Review banners in English and Arabic) | `App/Stickers/StickerArt.swift` | Original vector drawings written as code for this project (paths and fills); banner lettering uses the iOS system font at render time | Project-owned original work | None. No third-party icon sets, clip art or SF Symbols are used, so stickers may be embedded in exported user documents |
| Page templates (ruled, grid, dot grid, Cornell, planner) | `Packages/AgentNotesCore/.../TemplateGeometry.swift` | Original geometry | Project-owned | None |
| App icon | — | Not created yet | — | — |

SF Symbols are used only as interface icons inside the app's own UI, as Apple's license permits.
They are never rendered into user documents or exports.

## Data sets

| Data | Where | Source | Status |
| --- | --- | --- | --- |
| Periodic table (118 elements, English and Arabic names, masses) | `Packages/AgentNotesCore/.../PeriodicTable.swift` | Typed by hand for development | **Unreviewed.** Must be validated against IUPAC / PubChem (public domain) and the Arabic names reviewed before release |
| Medical terminology | — | Not started | Needs a licensed or original reviewed set |
| Anatomy models | — | Not started | Needs original or commercially licensed segmented assets |

## Code dependencies

| Package | Use | License | Obligations |
| --- | --- | --- | --- |
| GRDB.swift 7.x | SQLite library index (Xcode app only; the Swift Playgrounds variant uses a JSON index instead) | MIT | Keep the copyright and license notice in the app's acknowledgements |

## Development-only content (never shipped)

| Content | Where | Notes |
| --- | --- | --- |
| UI test fixture PDF and images | `App/Search/UITestFixtures.swift` | Generated at test time in Debug builds only (`-uiTestSeedPDF`); text written for the tests |
