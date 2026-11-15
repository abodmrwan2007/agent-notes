import SwiftUI

/// A panel beside the page while writing: study tools and stickers stay open next to the
/// notebook instead of covering it. Opening or closing it keeps the page position.
struct EditorSidePanel: View {
    let model: EditorModel

    enum Tab: Hashable {
        case tools
        case stickers
        case audio
    }

    @State private var tab = Tab.tools

    var body: some View {
        VStack(spacing: 0) {
            Picker("Panel", selection: $tab) {
                Text("Tools").tag(Tab.tools)
                Text("Stickers").tag(Tab.stickers)
                Text("Audio").tag(Tab.audio)
            }
            .pickerStyle(.segmented)
            .padding(10)
            .accessibilityIdentifier("panel.tabs")
            Divider()

            switch tab {
            case .tools:
                NavigationStack {
                    List(StudyTool.allCases) { tool in
                        NavigationLink(value: tool) {
                            Label(tool.title, systemImage: tool.symbol)
                        }
                        .accessibilityIdentifier("panel.tool.\(tool.rawValue)")
                    }
                    .navigationTitle("Tools")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: StudyTool.self) { tool in
                        switch tool {
                        case .calculator:
                            CalculatorView(compact: true) { text in
                                model.insertTextObject(text)
                            }
                        case .graph:
                            GraphView(compact: true)
                        case .periodicTable:
                            PeriodicTableView()
                        case .focusTimer:
                            FocusTimerView()
                        }
                    }
                }
            case .audio:
                RecordingsList(model: model)
            case .stickers:
                ScrollView {
                    StickerGrid(onPick: { data, size in
                        model.insertSticker(pngData: data, size: size)
                    }, minimumCell: 72)
                    .padding(12)
                }
            }
        }
        .background(Theme.backdrop)
    }
}
