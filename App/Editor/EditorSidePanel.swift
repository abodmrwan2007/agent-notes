import SwiftUI

/// A panel beside the page while writing: study tools and stickers stay open next to the
/// notebook instead of covering it. Opening or closing it keeps the page position.
struct EditorSidePanel: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                tab("Tools", symbol: "square.grid.2x2.fill", tint: Vivid.blue, value: .tools)
                tab("Stickers", symbol: "face.smiling.inverse", tint: Vivid.orange, value: .stickers)
                tab("Audio", symbol: "waveform", tint: Vivid.red, value: .audio)
                tab("AI", symbol: "sparkles", tint: Vivid.purple, value: .assistant)
            }
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
                            Label {
                                Text(tool.title)
                                    .font(.body.weight(.medium))
                            } icon: {
                                IconBadge(symbol: tool.symbol, color: tool.color, size: 30)
                            }
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

    private func tab(_ title: LocalizedStringKey, symbol: String, tint: Color, value: EditorPanelTab) -> some View {
        let isSelected = model.panelTab == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { model.panelTab = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.12))))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
