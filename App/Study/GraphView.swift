import AgentNotesCore
import SwiftUI

/// Plots y = f(x) for up to three functions. Angles are in radians, as is conventional for graphs.
struct GraphView: View {
    /// Narrow layout for the editor's side panel: function list above the plot.
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    // Two starting examples: a smooth curve and one with a pole at x = 0.
    @State private var formulas = ["sin(x)", "1/x", ""]
    // The visible window: centre and width in graph units. Height follows the view's aspect ratio.
    @State private var centerX = 0.0
    @State private var centerY = 0.0
    @State private var xSpan = 20.0
    @State private var dragOrigin: (x: Double, y: Double)?
    @State private var zoomOrigin: Double?

    private static let colors: [Color] = [Theme.accent, .red, .green]
    private static let defaultSpan = 20.0

    var body: some View {
        Group {
            if compact {
                VStack(spacing: 0) {
                    controls
                        .frame(height: 330)
                    Divider()
                    plot
                }
            } else {
                HStack(spacing: 0) {
                    controls
                        .frame(width: 300)
                    Divider()
                    plot
                }
            }
        }
        .navigationTitle("Graphing Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Controls

    private var controls: some View {
        Form {
            Section {
                ForEach(formulas.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(Self.colors[index]).frame(width: 10, height: 10)
                            Text(verbatim: "y =")
                            TextField("Function of x", text: $formulas[index])
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("graph.formula.\(index)")
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        if let message = errorMessage(for: formulas[index]) {
                            Text(verbatim: message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Functions")
            } footer: {
                Text("Use x as the variable, for example x^2, 1/x or 2sin(x). Angles are in radians.")
            }

            Section("View") {
                HStack {
                    Button {
                        xSpan = max(xSpan / 2, 1e-6)
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    .accessibilityIdentifier("graph.zoomIn")
                    Spacer()
                    Button {
                        xSpan = min(xSpan * 2, 1e9)
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    .accessibilityIdentifier("graph.zoomOut")
                }
                .buttonStyle(.borderless)
                Button("Reset View") {
                    centerX = 0
                    centerY = 0
                    xSpan = Self.defaultSpan
                }
            }
        }
    }

    private func errorMessage(for formula: String) -> String? {
        guard !formula.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            let expression = try MathExpression(formula)
            let unknown = expression.variables.subtracting(["x"])
            if let name = unknown.sorted().first { throw MathError.unknownName(name) }
            return nil
        } catch let error as MathError {
            return mathErrorMessage(error)
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: Plot

    private var plot: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .background(.white)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let origin = dragOrigin ?? (x: centerX, y: centerY)
                        dragOrigin = origin
                        let unitsPerPoint = xSpan / Double(max(size.width, 1))
                        centerX = origin.x - Double(value.translation.width) * unitsPerPoint
                        centerY = origin.y + Double(value.translation.height) * unitsPerPoint
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let origin = zoomOrigin ?? xSpan
                        zoomOrigin = origin
                        xSpan = min(max(origin / Double(max(scale, 0.01)), 1e-6), 1e9)
                    }
                    .onEnded { _ in zoomOrigin = nil }
            )
            .accessibilityLabel("Graph")
            .accessibilityIdentifier("graph.plot")
        }
        // The x axis always grows to the right.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let width = Double(size.width)
        let height = Double(size.height)
        let unitsPerPoint = xSpan / width
        let ySpan = unitsPerPoint * height
        let xRange: ClosedRange<Double> = (centerX - xSpan / 2)...(centerX + xSpan / 2)
        let yRange: ClosedRange<Double> = (centerY - ySpan / 2)...(centerY + ySpan / 2)

        func point(_ x: Double, _ y: Double) -> CGPoint {
            let px: Double = (x - xRange.lowerBound) / unitsPerPoint
            let py: Double = height - (y - yRange.lowerBound) / unitsPerPoint
            return CGPoint(x: px, y: py)
        }

        // Grid and tick labels.
        let step = Self.niceStep(xSpan / 10)
        var grid = Path()
        var x = (xRange.lowerBound / step).rounded(.up) * step
        while x <= xRange.upperBound {
            grid.move(to: point(x, yRange.lowerBound))
            grid.addLine(to: point(x, yRange.upperBound))
            // No label on the axis itself or where it would be cut off by the edge.
            if abs(x) > step / 2, point(x, 0).x > 16, point(x, 0).x < size.width - 16 {
                let labelY = min(max(point(0, 0).y + 10, 10), size.height - 10)
                context.draw(
                    Text(verbatim: MathFormatter.format(x)).font(.caption2).foregroundColor(.gray),
                    at: CGPoint(x: point(x, 0).x, y: labelY))
            }
            x += step
        }
        var y = (yRange.lowerBound / step).rounded(.up) * step
        while y <= yRange.upperBound {
            grid.move(to: point(xRange.lowerBound, y))
            grid.addLine(to: point(xRange.upperBound, y))
            if abs(y) > step / 2, point(0, y).y > 12, point(0, y).y < size.height - 12 {
                let labelX = min(max(point(0, 0).x + 14, 16), size.width - 16)
                context.draw(
                    Text(verbatim: MathFormatter.format(y)).font(.caption2).foregroundColor(.gray),
                    at: CGPoint(x: labelX, y: point(0, y).y))
            }
            y += step
        }
        context.stroke(grid, with: .color(Color.gray.opacity(0.22)), lineWidth: 0.5)

        // Axes.
        var axes = Path()
        axes.move(to: point(xRange.lowerBound, 0))
        axes.addLine(to: point(xRange.upperBound, 0))
        axes.move(to: point(0, yRange.lowerBound))
        axes.addLine(to: point(0, yRange.upperBound))
        context.stroke(axes, with: .color(Color.gray), lineWidth: 1)

        // Curves: one sample per horizontal point; discontinuities start a new segment.
        for (index, formula) in formulas.enumerated() {
            guard let expression = try? MathExpression(formula),
                  expression.variables.subtracting(["x"]).isEmpty else { continue }
            let segments = GraphSampler.segments(
                for: expression, xRange: xRange, yRange: yRange, samples: max(Int(size.width), 2))
            var curve = Path()
            for segment in segments {
                guard let first = segment.first else { continue }
                curve.move(to: point(first.x, first.y))
                for sample in segment.dropFirst() {
                    curve.addLine(to: point(sample.x, sample.y))
                }
            }
            context.stroke(curve, with: .color(Self.colors[index % Self.colors.count]), lineWidth: 2)
        }
    }

    /// Rounds a raw spacing to 1, 2 or 5 times a power of ten.
    static func niceStep(_ raw: Double) -> Double {
        guard raw > 0, raw.isFinite else { return 1 }
        let magnitude = pow(10, floor(log10(raw)))
        let fraction = raw / magnitude
        return (fraction < 1.5 ? 1 : (fraction < 3.5 ? 2 : (fraction < 7.5 ? 5 : 10))) * magnitude
    }
}
