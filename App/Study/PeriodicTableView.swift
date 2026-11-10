import AgentNotesCore
import SwiftUI

extension ElementCategory {
    var title: LocalizedStringKey {
        switch self {
        case .alkaliMetal: return "Alkali metal"
        case .alkalineEarthMetal: return "Alkaline earth metal"
        case .transitionMetal: return "Transition metal"
        case .postTransitionMetal: return "Post-transition metal"
        case .metalloid: return "Metalloid"
        case .nonmetal: return "Nonmetal"
        case .halogen: return "Halogen"
        case .nobleGas: return "Noble gas"
        case .lanthanide: return "Lanthanide"
        case .actinide: return "Actinide"
        }
    }

    var color: Color {
        switch self {
        case .alkaliMetal: return Color(red: 0.96, green: 0.62, blue: 0.60)
        case .alkalineEarthMetal: return Color(red: 0.97, green: 0.78, blue: 0.56)
        case .transitionMetal: return Color(red: 0.66, green: 0.80, blue: 0.93)
        case .postTransitionMetal: return Color(red: 0.72, green: 0.86, blue: 0.80)
        case .metalloid: return Color(red: 0.80, green: 0.85, blue: 0.60)
        case .nonmetal: return Color(red: 0.98, green: 0.90, blue: 0.55)
        case .halogen: return Color(red: 0.62, green: 0.88, blue: 0.90)
        case .nobleGas: return Color(red: 0.82, green: 0.74, blue: 0.93)
        case .lanthanide: return Color(red: 0.95, green: 0.76, blue: 0.86)
        case .actinide: return Color(red: 0.88, green: 0.70, blue: 0.74)
        }
    }
}

extension ChemicalElement {
    /// The element name in the app's current interface language.
    var displayName: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true ? arabicName : name
    }
}

struct PeriodicTableView: View {
    @State private var search = ""
    @State private var selected: ChemicalElement?

    private static let cell: CGFloat = 64
    private static let spacing: CGFloat = 4

    var body: some View {
        let matches = Set(PeriodicTable.search(search).map(\.number))

        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                table(matches: matches)
                legend
                Text("Development data set. It has not yet been validated against IUPAC values and must not be used as a reference.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Theme.backdrop)
        .navigationTitle("Periodic Table")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: Text("Name, symbol or number"))
        .sheet(item: $selected) { element in
            ElementDetailView(element: element)
        }
    }

    private func table(matches: Set<Int>) -> some View {
        let pitch = Self.cell + Self.spacing
        return ZStack(alignment: .topLeading) {
            ForEach(PeriodicTable.elements) { element in
                let position = element.gridPosition
                // The two f-block rows sit below the main table with a small gap.
                let rowOffset = position.row >= 8 ? CGFloat(position.row - 1) + 0.4 : CGFloat(position.row - 1)
                Button {
                    selected = element
                } label: {
                    ElementCell(element: element)
                        .frame(width: Self.cell, height: Self.cell)
                }
                .buttonStyle(.plain)
                .opacity(matches.contains(element.number) ? 1 : 0.2)
                .offset(x: CGFloat(position.column - 1) * pitch, y: rowOffset * pitch)
                .accessibilityIdentifier("element.\(element.symbol)")
            }
        }
        .frame(width: 18 * pitch, height: 9.4 * pitch, alignment: .topLeading)
        // The table keeps its standard orientation in every interface language.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(ElementCategory.allCases, id: \.self) { category in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(category.color)
                        .frame(width: 18, height: 18)
                    Text(category.title)
                        .font(.footnote)
                }
            }
        }
        .frame(width: 18 * (Self.cell + Self.spacing), alignment: .leading)
    }
}

private struct ElementCell: View {
    let element: ChemicalElement

    var body: some View {
        VStack(spacing: 1) {
            Text(verbatim: "\(element.number)")
                .font(.system(size: 10))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: element.symbol)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(verbatim: element.displayName)
                .font(.system(size: 8))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(4)
        .foregroundStyle(Color(red: 0.07, green: 0.13, blue: 0.27))
        .background(element.category.color, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(element.number), \(element.displayName)"))
    }
}

private struct ElementDetailView: View {
    let element: ChemicalElement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ElementCell(element: element)
                            .frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: element.name).font(.title2.weight(.semibold))
                            Text(verbatim: element.arabicName).font(.title3)
                        }
                    }
                }
                Section {
                    LabeledContent("Atomic number", value: "\(element.number)")
                    LabeledContent("Symbol", value: element.symbol)
                    LabeledContent("Atomic mass", value: element.massText)
                    LabeledContent("Period", value: "\(element.period)")
                    LabeledContent("Group", value: element.group.map { "\($0)" } ?? "–")
                    LabeledContent("Category") { Text(element.category.title) }
                } footer: {
                    if element.atomicWeight == nil {
                        Text("Brackets show the mass number of a long-lived isotope; this element has no standard atomic weight.")
                    }
                }
            }
            .navigationTitle(Text(verbatim: element.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
