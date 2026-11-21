import SwiftUI
#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// A red laser trail that follows the finger or Pencil and fades away. Nothing is written on the
/// page. Used in reading mode to present notes (for example on a projector with screen mirroring).
struct LaserPointerOverlay: View {
    private struct Dot {
        let point: CGPoint
        let time: Date
    }

    @State private var dots: [Dot] = []
    private let lifetime: TimeInterval = 0.8

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                let now = timeline.date
                let alive = dots.filter { now.timeIntervalSince($0.time) < lifetime }
                guard alive.count > 1 else {
                    if let dot = alive.first { drawDot(dot.point, alpha: 1, in: &context) }
                    return
                }
                for (previous, current) in zip(alive, alive.dropFirst()) {
                    let age = now.timeIntervalSince(current.time) / lifetime
                    var path = Path()
                    path.move(to: previous.point)
                    path.addLine(to: current.point)
                    context.stroke(path, with: .color(.red.opacity(0.35 * (1 - age))),
                                   style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    context.stroke(path, with: .color(.red.opacity(1 - age)),
                                   style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
                if let last = alive.last { drawDot(last.point, alpha: 1, in: &context) }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let now = Date()
                    dots.append(Dot(point: value.location, time: now))
                    dots.removeAll { now.timeIntervalSince($0.time) > lifetime }
                }
        )
        .accessibilityIdentifier("editor.laserArea")
    }

    private func drawDot(_ point: CGPoint, alpha: Double, in context: inout GraphicsContext) {
        let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)), with: .color(.red.opacity(0.25 * alpha)))
        context.fill(Path(ellipseIn: rect), with: .color(.red.opacity(alpha)))
    }
}

/// Insert ▸ Generate Image…: Apple's Image Playground, on iPads with Apple Intelligence
/// (iPadOS 18.1 or later). Elsewhere the menu item is not shown.
struct ImageGenerationSheet: ViewModifier {
    @Binding var isPresented: Bool
    let onImage: (Data) -> Void

    func body(content: Content) -> some View {
        #if canImport(ImagePlayground)
        if #available(iOS 18.1, *) {
            content.imagePlaygroundSheet(isPresented: $isPresented, concept: "", onCompletion: { url in
                if let data = try? Data(contentsOf: url) { onImage(data) }
            })
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Whether Image Playground can run here. Read inside a view, because it is an environment value.
struct ImageGenerationAvailability<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        #if canImport(ImagePlayground)
        if #available(iOS 18.1, *) {
            SupportedReader(content: content)
        } else {
            content(false)
        }
        #else
        content(false)
        #endif
    }
}

#if canImport(ImagePlayground)
@available(iOS 18.1, *)
private struct SupportedReader<Content: View>: View {
    @Environment(\.supportsImagePlayground) private var supported
    let content: (Bool) -> Content

    var body: some View { content(supported) }
}
#endif
