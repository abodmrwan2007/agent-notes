import SwiftUI

/// Shows what the app can do and exactly where to find each feature. Opens once after an update
/// that adds features (when `contentVersion` is raised) and from Settings at any time.
struct WhatsNewView: View {
    /// Raise when this list gains entries the person should be told about.
    static let contentVersion = 6
    static let seenKey = "whatsNewSeen"

    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let entries: [Entry] = [
        Entry(symbol: "rectangle.on.rectangle.angled", title: "Flashcards, links, transcripts, versions",
              detail: "Study ▸ Flashcards: decks with spaced review (Hard, Remembered, Easy); save AI cards as a deck. Insert ▸ Link… to another page or a website. Touch and hold a recording to transcribe it. In the library, touch and hold a notebook ▸ Version History…."),
        Entry(symbol: "text.viewfinder", title: "Handwriting to text, translate, scan",
              detail: "Page actions (•••) ▸ Recognize Handwriting turns your writing into text you can translate, look up, hear or put on the page. Insert ▸ Scan Document, Export ▸ Pages as Images or Print, five new papers, audio speed in Tools ▸ Audio, and Remove Background for pictures."),
        Entry(symbol: "heart.text.square", title: "3D heart atlas",
              detail: "Atlas in the sidebar: turn and zoom a 3D heart, tap a part to see its name in Arabic and English, hide parts or make the walls see-through to look at the valves."),
        Entry(symbol: "sparkles", title: "AI study assistant",
              detail: "Tools ▸ AI: summarize a page or the notebook, make flashcards and a quiz, ask questions, or select PDF text and tap Explain. Add your Claude API key in Settings ▸ AI Assistant first."),
        Entry(symbol: "heart.circle", title: "Labelled medical diagrams",
              detail: "Tools ▸ Stickers ▸ Labelled Diagrams: heart, lungs, brain, neuron, eye and cell, with English, Arabic or blank labels to test yourself."),
        Entry(symbol: "mic", title: "Record lectures",
              detail: "Tap Record at the top while you write. In Tools ▸ Audio, turn on Tap writing to hear it, then tap your notes to hear that moment."),
        Entry(symbol: "sidebar.trailing", title: "Tools beside your page",
              detail: "Open a notebook and tap Tools at the top. The calculator, graphing, periodic table, timer and stickers stay open next to the page."),
        Entry(symbol: "heart.text.square", title: "Medical stickers",
              detail: "Insert ▸ Sticker…, or the Stickers tab in Tools: heart, lungs, brain, stethoscope, DNA and more."),
        Entry(symbol: "note.text", title: "Sticky notes in five styles",
              detail: "Insert ▸ Sticky Note: plain, lined, grid, taped or pinned, in seven colours."),
        Entry(symbol: "text.magnifyingglass", title: "Search everything",
              detail: "Search in the sidebar finds words in titles, PDFs and typed text, in Arabic and English."),
        Entry(symbol: "character.textbox", title: "Select and copy PDF text",
              detail: "Choose the Select Text tool and drag across a PDF, then Copy or Where Else?"),
        Entry(symbol: "paintbrush.pointed", title: "Brushes and ruler",
              detail: "The brush button holds fountain pen, monoline, watercolor and crayon. The ruler button shows a ruler on the page."),
        Entry(symbol: "circle.dashed", title: "Perfect shapes",
              detail: "Draw a line, circle or rectangle and keep the pen still for half a second before lifting it."),
        Entry(symbol: "scribble", title: "Scribble to erase",
              detail: "Scribble back and forth over ink to erase it. Undo brings it back."),
        Entry(symbol: "book", title: "Reading mode",
              detail: "Tap Read at the top to hide the tools while you study."),
        Entry(symbol: "lock", title: "Lock, covers and tags",
              detail: "Touch and hold a notebook in the library for Lock…, Cover and Tags…"),
        Entry(symbol: "graduationcap", title: "Study tools",
              detail: "Study in the sidebar: scientific calculator, graphing, periodic table and focus timer.")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: entry.symbol)
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                        Text(entry.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                    }
                } footer: {
                    Text("You can open this again from Settings.")
                }
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("whatsNew.done")
                }
            }
        }
    }
}
