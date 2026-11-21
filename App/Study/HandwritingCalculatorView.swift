import AgentNotesCore
import PencilKit
import SwiftUI

/// Study ▸ Handwriting Calculator: write a sum, the iPad reads it and works it out.
struct HandwritingCalculatorView: View {
    var onInsert: ((String) -> Void)?

    @State private var drawing = PKDrawing()
    @State private var expression = ""
    @State private var result: String?
    @State private var errorText: String?
    @State private var isReading = false
    @State private var degrees = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Write a calculation with Apple Pencil or your finger, for example 12 × 3 + 4, then tap Solve. Check what was read before trusting the answer.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HandwritingPad(drawing: $drawing)
                .frame(minHeight: 220)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gray.opacity(0.3)))
                .accessibilityIdentifier("handwriting.pad")

            HStack {
                Button {
                    solve()
                } label: {
                    Label("Solve", systemImage: "equal.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(drawing.strokes.isEmpty || isReading)
                .accessibilityIdentifier("handwriting.solve")
                Button("Clear") {
                    drawing = PKDrawing()
                    expression = ""
                    result = nil
                    errorText = nil
                }
                .buttonStyle(.bordered)
                Spacer()
                Picker("Angles", selection: $degrees) {
                    Text(verbatim: "DEG").tag(true)
                    Text(verbatim: "RAD").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                if isReading { ProgressView() }
            }

            if !expression.isEmpty || result != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Read as (you can correct it):")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Expression", text: $expression)
                        .font(.title3.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(calculate)
                        .accessibilityIdentifier("handwriting.expression")
                    if let result {
                        Text(verbatim: "= " + result)
                            .font(.largeTitle.weight(.semibold).monospacedDigit())
                            .accessibilityIdentifier("handwriting.result")
                        if let onInsert {
                            Button {
                                onInsert(expression + " = " + result)
                            } label: {
                                Label("Insert into Page", systemImage: "text.badge.plus")
                            }
                        }
                    }
                }
            }
            if let errorText {
                Text(verbatim: errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Spacer()
        }
        .padding(20)
        .navigationTitle("Handwriting Calculator")
    }

    private func solve() {
        isReading = true
        errorText = nil
        let bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        let image = drawing.image(from: bounds, scale: 3)
        // Black ink on white, so recognition does not depend on the light or dark appearance.
        let flattened = UIGraphicsImageRenderer(size: image.size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
        Task {
            defer { isReading = false }
            do {
                let text = try await TextRecognizer.recognize(flattened)
                expression = HandwrittenMath.normalize(text)
                calculate()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func calculate() {
        do {
            let value = try MathExpression(expression).evaluate(angleMode: degrees ? .degrees : .radians)
            result = MathFormatter.format(value)
            errorText = nil
        } catch {
            result = nil
            errorText = String(localized: "This could not be worked out. Correct the expression above and press Return.")
        }
    }
}

/// A plain PencilKit canvas: pen only, finger drawing allowed.
private struct HandwritingPad: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}
