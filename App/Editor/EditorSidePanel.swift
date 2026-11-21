import SwiftUI

/// A panel beside the page while writing: study tools and stickers stay open next to the
/// notebook instead of covering it. Opening or closing it keeps the page position.
struct EditorSidePanel: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("Panel", selection: $model.panelTab) {
                Text("Tools").tag(EditorPanelTab.tools)
                Text("Stickers").tag(EditorPanelTab.stickers)
                Text("Audio").tag(EditorPanelTab.audio)
                Text("AI").tag(EditorPanelTab.assistant)
            }
            .pickerStyle(.segmented)
            .padding(10)
            .accessibilityIdentifier("panel.tabs")
            Divider()

            switch model.panelTab {
            case .assistant:
                AssistantPanel(model: model)
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
                        tool.destination(compact: true) { text in
                            model.insertTextBlock(text)
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
