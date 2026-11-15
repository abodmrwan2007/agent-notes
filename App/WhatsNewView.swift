import SwiftUI

/// Shows what the app can do and exactly where to find each feature. Opens once after an update
/// that adds features (when `contentVersion` is raised) and from Settings at any time.
struct WhatsNewView: View {
    /// Raise when this list gains entries the person should be told about.
    static let contentVersion = 1
    static let seenKey = "whatsNewSeen"

    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let entries: [Entry] = [
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
            List(entries) { entry in
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
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("You can open this again from Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("whatsNew.done")
                }
            }
        }
    }
}
