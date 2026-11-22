import LocalAuthentication
import SwiftUI

/// Face ID / Touch ID / device passcode gate for locked notebooks.
///
/// Honest scope: this stops a locked notebook from being opened, previewed, or searched inside
/// the app. It is not separate encryption: the files are protected on disk by iPadOS Data
/// Protection like all app data, and anyone who can unlock the iPad itself can authenticate.
enum NotebookLock {
    /// nil on success. An empty string when the person cancelled (show nothing); otherwise a
    /// message to show.
    static func authenticate(reason: String) async -> String? {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return String(localized: "Set a passcode on this iPad to lock notebooks.")
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? nil : String(localized: "The notebook could not be unlocked.")
        } catch let error as LAError where [.userCancel, .appCancel, .systemCancel].contains(error.code) {
            return ""
        } catch {
            return error.localizedDescription
        }
    }
}

/// A cover colour shown on the library card instead of the first page.
enum NotebookCover: String, CaseIterable, Identifiable {
    case navy
    case ocean
    case coral
    case forest
    case sand
    case plum
    case mint
    case sky
    case peach
    case lavender
    case sunset
    case midnight

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .navy: return "Navy"
        case .ocean: return "Ocean"
        case .coral: return "Coral"
        case .forest: return "Forest"
        case .sand: return "Sand"
        case .plum: return "Plum"
        case .mint: return "Mint"
        case .sky: return "Sky"
        case .peach: return "Peach"
        case .lavender: return "Lavender"
        case .sunset: return "Sunset"
        case .midnight: return "Midnight"
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    var colors: [Color] {
        switch self {
        case .navy: return [Self.rgb(0.16, 0.25, 0.50), Self.rgb(0.05, 0.09, 0.24)]
        case .ocean: return [Self.rgb(0.20, 0.78, 0.90), Self.rgb(0.05, 0.42, 0.70)]
        case .coral: return [Self.rgb(1.00, 0.60, 0.50), Self.rgb(0.90, 0.30, 0.40)]
        case .forest: return [Self.rgb(0.35, 0.75, 0.50), Self.rgb(0.10, 0.40, 0.30)]
        case .sand: return [Self.rgb(0.99, 0.90, 0.70), Self.rgb(0.90, 0.72, 0.48)]
        case .plum: return [Self.rgb(0.68, 0.45, 0.90), Self.rgb(0.38, 0.20, 0.60)]
        case .mint: return [Self.rgb(0.70, 0.96, 0.86), Self.rgb(0.35, 0.82, 0.72)]
        case .sky: return [Self.rgb(0.72, 0.86, 1.00), Self.rgb(0.45, 0.62, 0.98)]
        case .peach: return [Self.rgb(1.00, 0.85, 0.72), Self.rgb(1.00, 0.62, 0.55)]
        case .lavender: return [Self.rgb(0.90, 0.84, 1.00), Self.rgb(0.70, 0.62, 0.98)]
        case .sunset: return [Self.rgb(1.00, 0.78, 0.35), Self.rgb(0.98, 0.38, 0.52)]
        case .midnight: return [Self.rgb(0.22, 0.20, 0.38), Self.rgb(0.06, 0.06, 0.14)]
        }
    }

    var textColor: Color {
        switch self {
        case .sand, .mint, .sky, .peach, .lavender: return Self.rgb(0.16, 0.16, 0.26)
        default: return .white
        }
    }

    enum Pattern { case dots, lines, waves, grid, plain }

    var pattern: Pattern {
        switch self {
        case .navy, .lavender, .midnight: return .dots
        case .ocean, .sky: return .waves
        case .coral, .peach: return .lines
        case .forest, .mint: return .grid
        case .sand, .plum, .sunset: return .plain
        }
    }
}

/// A notebook's outline: tight corners at the binding, rounder at the open edge.
struct NotebookShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 6, bottomLeadingRadius: 6,
            bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
            .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> NotebookShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// Front of a notebook with a chosen cover: gradient, a light pattern, binding, elastic band and
/// a title label.
struct NotebookCoverView: View {
    let cover: NotebookCover
    let title: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: cover.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                CoverPatternView(pattern: cover.pattern, color: cover.textColor.opacity(0.14))
                // Gloss.
                LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                // Binding.
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.28), .black.opacity(0.08)],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(width: width * 0.09)
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
                    Spacer(minLength: 0)
                    // Elastic band.
                    Rectangle()
                        .fill(.black.opacity(0.22))
                        .frame(width: max(5, width * 0.035))
                        .padding(.trailing, width * 0.10)
                }
                // Title label.
                VStack {
                    Spacer().frame(height: proxy.size.height * 0.22)
                    Text(verbatim: title)
                        .font(.system(size: max(11, width * 0.085), weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.16, blue: 0.26))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: width * 0.62)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 1))
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, width * 0.06)
            }
        }
        .clipShape(NotebookShape())
    }
}

/// Subtle repeating decoration drawn on a cover.
struct CoverPatternView: View {
    let pattern: NotebookCover.Pattern
    let color: Color

    var body: some View {
        Canvas { context, size in
            switch pattern {
            case .dots:
                let step: CGFloat = 14
                var y: CGFloat = 6
                while y < size.height {
                    var x: CGFloat = 6
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(color))
                        x += step
                    }
                    y += step
                }
            case .lines:
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 16
                }
                context.stroke(path, with: .color(color), lineWidth: 5)
            case .waves:
                var path = Path()
                var y: CGFloat = 12
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x < size.width {
                        path.addQuadCurve(to: CGPoint(x: x + 20, y: y), control: CGPoint(x: x + 10, y: y - 7))
                        x += 20
                    }
                    y += 18
                }
                context.stroke(path, with: .color(color), lineWidth: 2)
            case .grid:
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 16 }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 16 }
                context.stroke(path, with: .color(color), lineWidth: 1)
            case .plain:
                break
            }
        }
        .allowsHitTesting(false)
    }
}

/// What a locked notebook shows in the library: never its pages.
struct LockedCoverView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.24, green: 0.26, blue: 0.36), Color(red: 0.10, green: 0.11, blue: 0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            CoverPatternView(pattern: .dots, color: .white.opacity(0.10))
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(0.16)))
                Text("Locked")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .clipShape(NotebookShape())
    }
}
