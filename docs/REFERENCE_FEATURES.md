# Reference app feature inventory

Purpose: list what comparable apps offer, so the product plan covers it. We build our own
implementation, layout, artwork and wording; nothing here is copied.

**Source honesty.** Only the CollaNote rows marked "screenshot" come from material checked in this
project (the owner's screenshots of CollaNote's Premium screen, 2026-11-15). All other rows are from
general product knowledge and have **not** been checked against each vendor's current
documentation; verify before relying on any detail (names, limits, platforms change often).

Status values match FEATURE_MATRIX.md. "Planned" means not started but in scope.

## Writing and ink

| Feature | Seen in | Our status |
| --- | --- | --- |
| Many pens and brushes (CollaNote advertises 25) | CollaNote (screenshot), Goodnotes, Notability, Freenotes | Partial: pen, pencil, highlighter + fountain pen, monoline, watercolor, crayon (native PencilKit inks) |
| Writing stabilizer / smoothing | CollaNote (screenshot), Goodnotes | Partial: on lift, not live |
| Shape recognition (hold to snap) | Goodnotes, Notability, CollaNote | Partial: line, circle, ellipse, rectangle |
| Ruler | CollaNote (screenshot), Goodnotes, Notability | Written: PencilKit ruler on the current page |
| Lasso select / move / recolour / resize | All | Partial: native lasso (move); recolour/resize planned |
| Scribble to erase | Goodnotes | Partial |
| Zoom window / magnified writing | Goodnotes, Notability | Planned |
| Laser pointer / presentation mode | Goodnotes, Notability | Planned |
| Tape / hide-reveal for active recall | Goodnotes (study sets), CollaNote | Planned (image-occlusion cards cover part of it) |
| ASMR writing sound | CollaNote (screenshot) | Planned (needs original sound assets) |

## Documents and pages

| Feature | Seen in | Our status |
| --- | --- | --- |
| Write beside PDFs and slides (expandable margins) | CollaNote (screenshot), Goodnotes, Notability | Planned: margins around PDF pages |
| Unlimited notebooks and pages | CollaNote (screenshot, paid) | Our Free plan: 3 notebooks (provisional), Pro unlimited |
| Folder and notebook covers | CollaNote (screenshot), Goodnotes | Planned |
| Templates incl. planners | Goodnotes, Freenotes, CollaNote | Partial: blank, ruled, grid, dot, Cornell, planner, custom background image |
| Infinite canvas / whiteboard | CollaNote, Freenotes, Goodnotes (whiteboards) | Planned |
| Horizontal page turning | Goodnotes, Notability | Planned |
| Reading mode | CollaNote (screenshot), Goodnotes | Written: hides tools, page not editable |
| Password / Face ID protected notes | CollaNote (screenshot), Notability | Planned |
| Tabs (several documents open) | Goodnotes, Notability | Planned |
| Split view: two documents side by side | Notability, Goodnotes | Planned |
| Outline / table of contents, links between pages | Goodnotes, Notion | Planned |
| Import PDF, images; export PDF | All | Partial: PDF, images, flattened PDF, native package |

## Inserts and study tools

| Feature | Seen in | Our status |
| --- | --- | --- |
| Stickers, custom stickers | CollaNote (screenshot), Freenotes, Goodnotes | Written: 18 original stickers, custom stickers from Photos, side panel |
| Text boxes, sticky notes, shapes, images | All | Sim-verified |
| Tools beside the notebook while writing | Owner request (CollaNote/Freenotes style) | Written: side panel with calculator, graphing, periodic table, timer, stickers |
| Translation tool | CollaNote (screenshot), Freenotes | Planned (Milestone C) |
| Scientific / graphing calculator, periodic table | Owner's reference screenshot (Freenotes-style insert menu) | Sim-verified (study tools) |
| Flashcards, quizzes from notes | Goodnotes (AI), Notability (Learn), Freenotes (AI) | Planned (Milestone C) |
| AI summaries / chat over notes | Goodnotes, Notability, Freenotes, Notion | Planned (Milestone C) |
| Voice recording synced to notes | CollaNote (screenshot), Notability (signature feature), Goodnotes | Planned (Milestone C) |
| Handwriting search, convert to text | Goodnotes, Notability | Planned (needs recognizer evaluation) |
| Math conversion / handwriting calculator | Goodnotes, Notability (Apple Math Notes) | Planned |

## Look and organisation

| Feature | Seen in | Our status |
| --- | --- | --- |
| Custom background and interface colour | CollaNote (screenshot) | Planned |
| Folders, tags, favourites, search | All; Notion (databases, tags) | Sim-verified (folders, tags, favourites, full-text search) |
| Databases / linked pages / templates gallery | Notion | Out of scope for a handwriting app; tags and internal links cover the student need |
| Collaboration / sharing | Goodnotes, CollaNote, Notion | Milestone E (community, gated by moderation) |
| Sync across devices | All | Milestone E (optional sync) |

## Pricing models seen (for context, not a decision)

CollaNote's screenshot shows a one-time "lifetime" Premium purchase. Our plan is different by
owner decision: one annual Pro subscription (provisional USD 19.99/year), no lifetime SKU.
