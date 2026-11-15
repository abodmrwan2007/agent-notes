import AgentNotesCore
import SwiftUI
import UIKit

/// Default palette: white / light gray surfaces, dark navy text, restrained cyan accent.
enum Theme {
    /// Restrained cyan. Defined in code (same values as the AccentColor asset) so it does not
    /// depend on an asset catalog being present.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.78, blue: 0.92, alpha: 1)
            : UIColor(red: 0.00, green: 0.60, blue: 0.78, alpha: 1)
    })

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
