import AgentNotesCore
import SwiftUI

/// Insert ▸ Link…: a link to another page of this notebook or to a web page.
struct LinkSheet: View {
    enum Choice {
        case page(Int)
        case web(URL)
    }

    let pageCount: Int
    let currentPage: Int
    let onAdd: (String, Choice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var toWeb = false
    @State private var label = ""
    @State private var pageIndex = 0
    @State private var address = ""

    private var webURL: URL? { PageLink.webURL(from: address) }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Link to", selection: $toWeb) {
                    Text("A page in this notebook").tag(false)
                    Text("A website").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("link.kind")

                Section {
                    TextField("Text shown on the page", text: $label)
                        .accessibilityIdentifier("link.label")
                }
                if toWeb {
                    Section {
                        TextField("example.com", text: $address)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("link.address")
                    } footer: {
                        if !address.isEmpty && webURL == nil {
                            Text("Enter a web address such as en.wikipedia.org/wiki/Heart.")
                        }
                    }
                } else {
                    Picker("Page", selection: $pageIndex) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Text("Page \(index + 1)").tag(index)
                        }
                    }
                    .accessibilityIdentifier("link.page")
                }
                Section {
                    Text("Tap the link in reading mode (Read at the top), or select it and tap Open Link.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if toWeb, let url = webURL {
                            onAdd(label, .web(url))
                        } else if !toWeb {
                            let fallback = String(localized: "Page \(pageIndex + 1)")
                            onAdd(label.isEmpty ? fallback : label, .page(pageIndex))
                        }
                        dismiss()
                    }
                    .disabled(toWeb && webURL == nil)
                    .accessibilityIdentifier("link.add")
                }
            }
            .onAppear { pageIndex = min(currentPage + 1, max(pageCount - 1, 0)) }
        }
    }
}
