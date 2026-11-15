import AgentNotesCore
import SwiftUI

/// User-facing text for a calculation error.
func mathErrorMessage(_ error: MathError) -> String {
    switch error {
    case .empty:
        return String(localized: "Enter an expression.")
    case .unexpectedCharacter(let text):
        return String(localized: "This character is not understood: \(text)")
    case .unexpectedEnd:
        return String(localized: "The expression is incomplete.")
    case .unexpectedToken(let text):
        return String(localized: "Unexpected symbol: \(text)")
    case .missingClosingParenthesis:
        return String(localized: "A closing parenthesis is missing.")
    case .unknownName(let name):
        return String(localized: "Unknown name: \(name)")
    case .wrongArgumentCount(let function):
        return String(localized: "Wrong number of values for \(function).")
    case .divisionByZero:
        return String(localized: "Division by zero.")
    case .outsideDomain(let function):
        return String(localized: "Not defined for this value: \(function)")
    case .resultTooLarge:
        return String(localized: "The result is too large.")
    }
}

private struct CalculatorKey: Identifiable {
    enum Action {
        case insert(String)
        case backspace
        case clear
        case evaluate
    }

    let label: String
    let action: Action
    var isOperator = false

    var id: String { label }

    static let rows: [[CalculatorKey]] = [
        [key("sin", "sin("), key("cos", "cos("), key("tan", "tan("), key("(", "("), key(")", ")")],
        [key("asin", "asin("), key("acos", "acos("), key("atan", "atan("), key("^", "^", true), key("√", "sqrt(")],
        [key("ln", "ln("), key("log", "log("), key("π", "π"), key("e", "e"), key("!", "!", true)],
        [key("7", "7"), key("8", "8"), key("9", "9"), key("÷", "÷", true),
         CalculatorKey(label: "⌫", action: .backspace)],
        [key("4", "4"), key("5", "5"), key("6", "6"), key("×", "×", true),
         CalculatorKey(label: "C", action: .clear)],
        [key("1", "1"), key("2", "2"), key("3", "3"), key("−", "−", true), key("Ans", "ans")],
        [key("0", "0"), key(".", "."), key("%", "%", true), key("+", "+", true),
         CalculatorKey(label: "=", action: .evaluate)]
    ]

    private static func key(_ label: String, _ text: String, _ isOperator: Bool = false) -> CalculatorKey {
        CalculatorKey(label: label, action: .insert(text), isOperator: isOperator)
    }
}

private struct CalculationRecord: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
}

struct CalculatorView: View {
    /// Narrow layout for the editor's side panel: no history column, smaller keys.
    let compact: Bool
    /// When set, a button puts the last calculation on the page as text.
    let onInsert: ((String) -> Void)?

    init(compact: Bool = false, onInsert: ((String) -> Void)? = nil) {
        self.compact = compact
        self.onInsert = onInsert
    }

    @AppStorage("calculator.angleMode") private var angleModeRaw = AngleMode.degrees.rawValue
    @State private var input = ""
    @State private var errorMessage: String?
    @State private var history: [CalculationRecord] = []
    @State private var lastAnswer = 0.0
    /// After "=", the display shows the result: a digit starts a new expression, an operator continues it.
    @State private var showsResult = false

    private var angleMode: AngleMode { AngleMode(rawValue: angleModeRaw) ?? .degrees }

    /// Live result while typing, when the expression is already valid.
    private var preview: String? {
        guard !showsResult, !input.isEmpty,
              let value = try? MathExpression(input).evaluate(variables: ["ans": lastAnswer], angleMode: angleMode)
        else { return nil }
        return MathFormatter.format(value)
    }

    var body: some View {
        Group {
            if compact {
                ScrollView {
                    calculatorColumn
                        .padding(12)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    calculatorColumn
                        .padding(20)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)

                    Divider()
                    historyList
                        .frame(width: 280)
                }
            }
        }
        .background(Theme.backdrop)
        .navigationTitle("Scientific Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calculatorColumn: some View {
        VStack(spacing: compact ? 12 : 16) {
            display
            Picker("Angle unit", selection: $angleModeRaw) {
                Text("Degrees").tag(AngleMode.degrees.rawValue)
                Text("Radians").tag(AngleMode.radians.rawValue)
            }
            .pickerStyle(.segmented)
            keypad
            if let onInsert, let last = history.first {
                Button {
                    onInsert(last.expression + " = " + last.result)
                } label: {
                    Label("Insert into Page", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("calculator.insert")
            }
        }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("Expression", text: $input)
                .font(.system(size: compact ? 26 : 34, weight: .medium, design: .rounded))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .onSubmit(evaluate)
                .onChange(of: input) { _, _ in errorMessage = nil }
                .accessibilityIdentifier("calculator.input")

            Group {
                if let errorMessage {
                    Text(verbatim: errorMessage).foregroundStyle(.red)
                } else if let preview {
                    Text(verbatim: "= " + preview).foregroundStyle(.secondary)
                } else {
                    Text(verbatim: " ")
                }
            }
            .font(.title3)
            .accessibilityIdentifier("calculator.status")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        // Mathematics reads left to right in every interface language.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Array(CalculatorKey.rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { key in
                        Button {
                            press(key)
                        } label: {
                            Text(verbatim: key.label)
                                .font(compact ? .body.weight(.medium) : .title3.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: compact ? 38 : 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(tint(for: key))
                        .accessibilityIdentifier("key.\(key.label)")
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func tint(for key: CalculatorKey) -> Color {
        switch key.action {
        case .evaluate: return Theme.accent
        case .clear, .backspace: return .red
        case .insert: return key.isOperator ? Theme.accent : Theme.text
        }
    }

    private var historyList: some View {
        List {
            Section("History") {
                if history.isEmpty {
                    Text("Results you calculate appear here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(history) { record in
                    Button {
                        input = record.result
                        showsResult = true
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(verbatim: record.expression)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(verbatim: "= " + record.result)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }

    private func press(_ key: CalculatorKey) {
        switch key.action {
        case .insert(let text):
            if showsResult, !key.isOperator { input = "" }
            showsResult = false
            input += text
        case .backspace:
            showsResult = false
            if !input.isEmpty { input.removeLast() }
        case .clear:
            showsResult = false
            input = ""
            errorMessage = nil
        case .evaluate:
            evaluate()
        }
    }

    private func evaluate() {
        do {
            let value = try MathExpression(input).evaluate(variables: ["ans": lastAnswer], angleMode: angleMode)
            let result = MathFormatter.format(value)
            history.insert(CalculationRecord(expression: input, result: result), at: 0)
            lastAnswer = value
            input = result
            showsResult = true
            errorMessage = nil
        } catch let error as MathError {
            errorMessage = mathErrorMessage(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
