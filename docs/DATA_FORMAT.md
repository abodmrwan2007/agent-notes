# Native document format (version 1)

A document is a directory with the extension `.agentnote`
(uniform type `com.agentnotes.document`, conforms to `com.apple.package`).

```
<document-id>.agentnote/
  manifest.json            document metadata and page list
  sources/<uuid>.pdf       original imported PDFs, byte-for-byte, never modified
  ink/<page-id>.ink        handwriting for one page (absent when the page has no ink)
```

## manifest.json

UTF-8 JSON, keys sorted, dates in ISO 8601 (UTC, second precision).

| Field | Type | Notes |
| --- | --- | --- |
| `formatVersion` | int | `1`. Readers must refuse larger values |
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

## Versioning and migration

`ManifestCodec.decode` reads `formatVersion`, refuses newer versions, and applies migration steps
one version at a time (`ManifestCodec.migrations`, keyed by the version being upgraded from) before
decoding. Version 1 is the first format, so there are no steps yet. When the schema changes:
bump `DocumentFormat.currentVersion`, add the step, add a test with a fixture of the old version.

## Library index (not part of the document format)

`Application Support/AgentNotes/library.sqlite` holds folders and per-document organization
(folder, favorite, trash date, last opened) plus cached title, dates and page count.
It is derived data for everything the manifest also stores and can be rebuilt from the packages;
folder placement, favorites and trash state are stored only there.
