import AgentNotesCore
import SwiftUI
import UIKit

/// Default palette: white / light gray surfaces, dark navy text, restrained cyan accent.
enum Theme {
    /// The interface colour chosen in Settings (restrained cyan by default). The root view is
    /// rebuilt when it changes, so every use picks up the new value.
    static var accent: Color { AccentChoice.current.color }

    static let text = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.93, alpha: 1)
            : UIColor(red: 0.07, green: 0.13, blue: 0.27, alpha: 1)
    })

    /// Area behind the pages in the editor and behind cards in the library.
    static let backdropUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.10, alpha: 1)
            : UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    }
    static let backdrop = Color(uiColor: backdropUIColor)

    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 12
}

extension PageTemplate {
    var title: LocalizedStringKey {
        switch self {
        case .blank: return "Blank"
        case .ruled: return "Ruled"
        case .grid: return "Grid"
        case .dotGrid: return "Dot Grid"
        case .cornell: return "Cornell"
        case .planner: return "Planner"
        }
    }

    var symbol: String {
        switch self {
        case .blank: return "doc"
        case .ruled: return "text.justify"
        case .grid: return "squareshape.split.3x3"
        case .dotGrid: return "circle.grid.3x3"
        case .cornell: return "rectangle.split.2x1"
        case .planner: return "calendar"
        }
    }
}

/// Interface colours offered in Settings. Each has a light and a dark variant.
enum AccentChoice: String, CaseIterable, Identifiable {
    case cyan
    case blue
    case teal
    case purple
    case coral
    case green

    static let storageKey = "interfaceColor"

    static var current: AccentChoice {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AccentChoice.init(rawValue:)) ?? .cyan
    }

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .cyan: return "Cyan"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .purple: return "Purple"
        case .coral: return "Coral"
        case .green: return "Green"
        }
    }

    private var components: (light: (Double, Double, Double), dark: (Double, Double, Double)) {
        switch self {
        case .cyan: return ((0.00, 0.60, 0.78), (0.25, 0.78, 0.92))
        case .blue: return ((0.10, 0.42, 0.90), (0.40, 0.62, 1.00))
        case .teal: return ((0.00, 0.55, 0.52), (0.25, 0.80, 0.75))
        case .purple: return ((0.45, 0.30, 0.80), (0.68, 0.55, 0.98))
        case .coral: return ((0.88, 0.36, 0.32), (1.00, 0.55, 0.50))
        case .green: return ((0.15, 0.58, 0.32), (0.35, 0.80, 0.50))
        }
    }

    var color: Color {
        let values = components
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? values.dark : values.light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

/// A text-entry alert used for naming and renaming notebooks and folders.
struct NamePrompt: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let initialText: String
    let action: (String) -> Void
}

private struct NamePromptModifier: ViewModifier {
    @Binding var prompt: NamePrompt?
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: prompt?.id) { _, _ in
                text = prompt?.initialText ?? ""
            }
            .alert(
                prompt?.title ?? "",
                isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
                presenting: prompt
            ) { current in
                TextField("Name", text: $text)
                Button("Save") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { current.action(trimmed) }
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

extension View {
    func namePrompt(_ prompt: Binding<NamePrompt?>) -> some View {
        modifier(NamePromptModifier(prompt: prompt))
    }
}
