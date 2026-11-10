# Native document format (version 2)

A document is a directory with the extension `.agentnote`
(uniform type `com.agentnotes.document`, conforms to `com.apple.package`).

```
<document-id>.agentnote/
  manifest.json            document metadata and page list
  sources/<uuid>.pdf       original imported PDFs, byte-for-byte, never modified
  ink/<page-id>.ink        handwriting for one page (absent when the page has no ink)
  objects/<page-id>.json   typed text, sticky notes, shapes, image placements (absent when none)
  assets/<uuid>.jpg        binary assets referenced by objects (inserted images)
```

## manifest.json

UTF-8 JSON, keys sorted, dates in ISO 8601 (UTC, second precision).

| Field | Type | Notes |
| --- | --- | --- |
| `formatVersion` | int | `2`. Readers must refuse larger values |
| `id` | UUID string | Stable document identifier |
| `title` | string | |
| `createdAt`, `modifiedAt` | date | |
| `inkEncoding` | string | `apple.pencilkit.drawing` |
| `sources[]` | object | `id` (UUID), `kind` (`pdf`), `fileName` (inside `sources/`), `originalFileName` |
| `pages[]` | object | In display order, see below |

Page object:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID string | Stable page identifier; names the ink file |
| `size` | `{width, height}` | Canonical size in points |
| `template` | string | `blank`, `ruled`, `grid`, `dotGrid`, `cornell`. Ignored when `pdf` is set |
| `pdf` | object or absent | `sourceID` (UUID of a source), `pageIndex` (zero-based) |
| `isBookmarked` | bool | |

## Coordinates

Canonical page coordinates: points, origin at the top-left corner of the page as displayed, x right,
y down. For PDF pages "as displayed" means the crop box after the page's rotation, so
`size` is the rotated crop-box size. Conversions to PDF user space are implemented and tested in
`PDFPageGeometry`.

All ink is stored in these coordinates. Zoom, device size and template changes never alter stored
geometry.

## Ink payload

`ink/<page-id>.ink` is the output of `PKDrawing.dataRepresentation()`. It is an Apple-defined opaque
format and is only readable with PencilKit. A portable stroke representation is planned before any
non-Apple client (see DECISIONS D6).

## Page objects (added in version 2)

`objects/<page-id>.json` is `{ "objects": [ ... ] }`. Array order is the stacking order: the last
object is on top. On a page, objects are drawn above the background and below the ink.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID string | Stable object identifier |
| `kind` | string | `text`, `stickyNote`, `image`, `shape` |
| `frame` | `{x, y, width, height}` | Canonical page coordinates |
| `rotation` | number | Clockwise degrees around the frame centre |
| `isLocked` | bool | Locked objects cannot be moved, resized, edited or deleted |
| `text`, `fontSize` | string, number | Text boxes and sticky notes |
| `colorHex` | `RRGGBB` | Text colour, shape stroke colour, or sticky-note paper colour |
| `shape`, `lineWidth` | string, number | `rectangle`, `ellipse`, `line`, `arrow` (line and arrow run from the top-left to the bottom-right corner of the frame) |
| `assetFileName` | string | File inside `assets/` (images) |

Optional fields are omitted when unused.

## Versioning and migration

`ManifestCodec.decode` reads `formatVersion`, refuses newer versions, and applies migration steps
one version at a time (`ManifestCodec.migrations`, keyed by the version being upgraded from) before
decoding. The 1→2 step is empty: version 2 only added new optional files, and the bump exists
so that older app versions refuse (rather than silently ignore the objects of) newer documents.
When the schema changes:
bump `DocumentFormat.currentVersion`, add the step, add a test with a fixture of the old version.

## Library index (not part of the document format)

`Application Support/AgentNotes/library.sqlite` holds folders and per-document organization
(folder, favorite, trash date, last opened) plus cached title, dates and page count.
It is derived data for everything the manifest also stores and can be rebuilt from the packages;
folder placement, favorites and trash state are stored only there.
