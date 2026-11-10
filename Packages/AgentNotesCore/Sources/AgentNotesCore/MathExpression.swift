import Foundation

public enum AngleMode: String, CaseIterable, Sendable {
    case radians
    case degrees
}

public enum MathError: Error, Equatable {
    case empty
    case unexpectedCharacter(String)
    case unexpectedEnd
    case unexpectedToken(String)
    case missingClosingParenthesis
    case unknownName(String)
    case wrongArgumentCount(function: String)
    case divisionByZero
    /// The function is not defined for this input (for example sqrt(-1) or ln(0)).
    case outsideDomain(function: String)
    case resultTooLarge
}

/// A safe arithmetic expression: parsed once into a tree and evaluated without `NSExpression`,
/// `eval`, or any dynamic code execution. Only the operators, functions and constants listed in
/// this file exist.
///
/// Precedence, lowest to highest: `+ -`, `* /` and implicit multiplication, unary minus,
/// `^` (right-associative), postfix `!` and `%`. So `-2^2` is `-4` and `2^3^2` is `512`.
public struct MathExpression: Sendable {
    indirect enum Node: Sendable {
        case number(Double)
        case name(String)
        case negate(Node)
        case binary(Character, Node, Node)
        case call(String, [Node])
        case factorial(Node)
        case percent(Node)
    }

    public let source: String
    let root: Node

    public init(_ source: String) throws {
        self.source = source
        var parser = Parser(tokens: try Tokenizer.tokenize(source))
        root = try parser.parse()
    }

    /// Names that are neither functions nor built-in constants (for example `x`).
    public var variables: Set<String> {
        var result = Set<String>()
        func visit(_ node: Node) {
            switch node {
            case .number: break
            case .name(let name):
                if Self.constants[name] == nil { result.insert(name) }
            case .negate(let inner), .factorial(let inner), .percent(let inner):
                visit(inner)
            case .binary(_, let left, let right):
                visit(left)
                visit(right)
            case .call(_, let arguments):
                arguments.forEach(visit)
            }
        }
        visit(root)
        return result
    }

    public func evaluate(variables: [String: Double] = [:], angleMode: AngleMode = .radians) throws -> Double {
        let value = try Self.evaluate(root, variables: variables, angleMode: angleMode)
        guard value.isFinite else { throw MathError.resultTooLarge }
        return value == 0 ? 0 : value // normalizes -0
    }

    // MARK: Vocabulary

    static let constants: [String: Double] = [
        "pi": Double.pi,
        "π": Double.pi,
        "tau": 2 * Double.pi,
        "e": exp(1.0)
    ]

    public static let functionNames: Set<String> = [
        "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
        "sqrt", "cbrt", "abs", "ln", "log", "log2", "exp", "floor", "ceil", "round", "sign",
        "min", "max", "mod", "root"
    ]

    // MARK: Evaluation

    private static func evaluate(_ node: Node, variables: [String: Double], angleMode: AngleMode) throws -> Double {
        switch node {
        case .number(let value):
            return value
        case .name(let name):
            if let value = variables[name] ?? constants[name] { return value }
            throw MathError.unknownName(name)
        case .negate(let inner):
            return -(try evaluate(inner, variables: variables, angleMode: angleMode))
        case .percent(let inner):
            return try evaluate(inner, variables: variables, angleMode: angleMode) / 100
        case .factorial(let inner):
            let value = try evaluate(inner, variables: variables, angleMode: angleMode)
            guard value >= 0, value == value.rounded(), value <= 170 else {
                throw MathError.outsideDomain(function: "!")
            }
            return value < 2 ? 1 : (2...Int(value)).reduce(1.0) { $0 * Double($1) }
        case .binary(let op, let leftNode, let rightNode):
            let left = try evaluate(leftNode, variables: variables, angleMode: angleMode)
            let right = try evaluate(rightNode, variables: variables, angleMode: angleMode)
            switch op {
            case "+": return left + right
            case "-": return left - right
            case "*": return left * right
            case "/":
                guard right != 0 else { throw MathError.divisionByZero }
                return left / right
            default:
                if left == 0, right < 0 { throw MathError.divisionByZero }
                let value = pow(left, right)
                guard !value.isNaN else { throw MathError.outsideDomain(function: "^") }
                return value
            }
        case .call(let name, let argumentNodes):
            let arguments = try argumentNodes.map { try evaluate($0, variables: variables, angleMode: angleMode) }
            return try call(name, arguments, angleMode: angleMode)
        }
    }

    private static func call(_ name: String, _ arguments: [Double], angleMode: AngleMode) throws -> Double {
        func one() throws -> Double {
            guard arguments.count == 1 else { throw MathError.wrongArgumentCount(function: name) }
            return arguments[0]
        }
        func two() throws -> (Double, Double) {
            guard arguments.count == 2 else { throw MathError.wrongArgumentCount(function: name) }
            return (arguments[0], arguments[1])
        }
        func inverse(_ radians: Double) -> Double {
            angleMode == .degrees ? radians * 180 / .pi : radians
        }

        switch name {
        case "sin": return try trig(sin, quarterTurns: [0, 1, 0, -1], angle: one(), angleMode: angleMode)
        case "cos": return try trig(cos, quarterTurns: [1, 0, -1, 0], angle: one(), angleMode: angleMode)
        case "tan":
            let angle = try one()
            let cosine = trig(cos, quarterTurns: [1, 0, -1, 0], angle: angle, angleMode: angleMode)
            guard abs(cosine) > 1e-15 else { throw MathError.outsideDomain(function: name) }
            return trig(sin, quarterTurns: [0, 1, 0, -1], angle: angle, angleMode: angleMode) / cosine
        case "asin", "acos":
            let value = try one()
            guard (-1...1).contains(value) else { throw MathError.outsideDomain(function: name) }
            return inverse(name == "asin" ? asin(value) : acos(value))
        case "atan": return inverse(atan(try one()))
        case "sinh": return sinh(try one())
        case "cosh": return cosh(try one())
        case "tanh": return tanh(try one())
        case "sqrt":
            let value = try one()
            guard value >= 0 else { throw MathError.outsideDomain(function: name) }
            return value.squareRoot()
        case "cbrt": return cbrt(try one())
        case "abs": return abs(try one())
        case "ln", "log", "log2":
            let value = try one()
            guard value > 0 else { throw MathError.outsideDomain(function: name) }
            if name == "ln" { return log(value) }
            return name == "log" ? log10(value) : log2(value)
        case "exp": return exp(try one())
        case "floor": return (try one()).rounded(.down)
        case "ceil": return (try one()).rounded(.up)
        case "round": return (try one()).rounded(.toNearestOrAwayFromZero)
        case "sign":
            let value = try one()
            return value > 0 ? 1 : (value < 0 ? -1 : 0)
        case "min":
            guard !arguments.isEmpty else { throw MathError.wrongArgumentCount(function: name) }
            return arguments.min() ?? 0
        case "max":
            guard !arguments.isEmpty else { throw MathError.wrongArgumentCount(function: name) }
            return arguments.max() ?? 0
        case "mod":
            let (value, divisor) = try two()
            guard divisor != 0 else { throw MathError.divisionByZero }
            return value - divisor * (value / divisor).rounded(.down)
        case "root":
            let (value, degree) = try two()
            guard degree != 0 else { throw MathError.divisionByZero }
            if value < 0 {
                // Odd integer roots of negative numbers are real.
                guard degree == degree.rounded(), Int(degree) % 2 != 0 else {
                    throw MathError.outsideDomain(function: name)
                }
                return -pow(-value, 1 / degree)
            }
            return pow(value, 1 / degree)
        default:
            throw MathError.unknownName(name)
        }
    }

    /// In degree mode, exact multiples of 90° return exact values (sin 180° is 0, not 1.2e-16).
    private static func trig(
        _ function: (Double) -> Double, quarterTurns: [Double], angle: Double, angleMode: AngleMode
    ) -> Double {
        guard angleMode == .degrees else { return function(angle) }
        let quarters = angle / 90
        if quarters == quarters.rounded(), abs(quarters) < 1e15 {
            let index = ((Int(quarters) % 4) + 4) % 4
            return quarterTurns[index]
        }
        return function(angle * .pi / 180)
    }
}

// MARK: - Tokenizer

enum Token: Equatable, Sendable {
    case number(Double)
    case name(String)
    case symbol(Character)

    var description: String {
        switch self {
        case .number(let value): return MathFormatter.format(value)
        case .name(let name): return name
        case .symbol(let character): return String(character)
        }
    }
}

enum Tokenizer {
    private static let symbolAliases: [Character: Character] = [
        "×": "*", "·": "*", "⋅": "*", "∗": "*",
        "÷": "/", "∕": "/",
        "−": "-", "–": "-",
        "،": ",", ";": ",", "؛": ",",
        "٪": "%"
    ]
    private static let symbols: Set<Character> = ["+", "-", "*", "/", "^", "(", ")", ",", "!", "%"]

    private static func digitValue(_ character: Character) -> Int? {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else { return nil }
        switch scalar.value {
        case 0x30...0x39: return Int(scalar.value - 0x30)
        case 0x0660...0x0669: return Int(scalar.value - 0x0660) // Arabic-Indic
        case 0x06F0...0x06F9: return Int(scalar.value - 0x06F0) // Extended Arabic-Indic
        default: return nil
        }
    }

    private static func isDecimalPoint(_ character: Character) -> Bool {
        character == "." || character == "٫"
    }

    static func tokenize(_ source: String) throws -> [Token] {
        let characters = Array(source)
        var tokens: [Token] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if digitValue(character) != nil || isDecimalPoint(character) {
                var text = ""
                while index < characters.count {
                    if let digit = digitValue(characters[index]) {
                        text.append(String(digit))
                    } else if isDecimalPoint(characters[index]), !text.contains(".") {
                        text.append(".")
                    } else {
                        break
                    }
                    index += 1
                }
                // Scientific notation only when an exponent really follows ("2e3", "2E-3");
                // otherwise "2e" means 2 × e.
                if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                    var lookahead = index + 1
                    var exponent = "e"
                    if lookahead < characters.count, characters[lookahead] == "+" || characters[lookahead] == "-" {
                        exponent.append(characters[lookahead])
                        lookahead += 1
                    }
                    var digits = ""
                    while lookahead < characters.count, let digit = digitValue(characters[lookahead]) {
                        digits.append(String(digit))
                        lookahead += 1
                    }
                    if !digits.isEmpty {
                        text += exponent + digits
                        index = lookahead
                    }
                }
                guard let value = Double(text) else { throw MathError.unexpectedCharacter(text) }
                tokens.append(.number(value))
            } else if character == "√" {
                tokens.append(.name("sqrt"))
                index += 1
            } else if character.isLetter {
                var name = ""
                while index < characters.count, characters[index].isLetter || digitValue(characters[index]) != nil {
                    name.append(characters[index])
                    index += 1
                }
                tokens.append(.name(name == "π" ? name : name.lowercased()))
            } else {
                let symbol = symbolAliases[character] ?? character
                guard symbols.contains(symbol) else { throw MathError.unexpectedCharacter(String(character)) }
                tokens.append(.symbol(symbol))
                index += 1
            }
        }
        return tokens
    }
}

// MARK: - Parser (recursive descent)

struct Parser {
    let tokens: [Token]
    var position = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    private var current: Token? {
        position < tokens.count ? tokens[position] : nil
    }

    private mutating func accept(_ symbol: Character) -> Bool {
        if current == .symbol(symbol) {
            position += 1
            return true
        }
        return false
    }

    mutating func parse() throws -> MathExpression.Node {
        guard !tokens.isEmpty else { throw MathError.empty }
        let node = try expression()
        if let leftover = current { throw MathError.unexpectedToken(leftover.description) }
        return node
    }

    private mutating func expression() throws -> MathExpression.Node {
        var node = try term()
        while true {
            if accept("+") {
                node = .binary("+", node, try term())
            } else if accept("-") {
                node = .binary("-", node, try term())
            } else {
                return node
            }
        }
    }

    private mutating func term() throws -> MathExpression.Node {
        var node = try unary()
        while true {
            if accept("*") {
                node = .binary("*", node, try unary())
            } else if accept("/") {
                node = .binary("/", node, try unary())
            } else if startsImplicitFactor {
                // "2x", "2(3+1)", "(a)(b)", "3 sin(x)"
                node = .binary("*", node, try power())
            } else {
                return node
            }
        }
    }

    private var startsImplicitFactor: Bool {
        switch current {
        case .number, .name: return true
        case .symbol(let symbol): return symbol == "("
        case nil: return false
        }
    }

    private mutating func unary() throws -> MathExpression.Node {
        if accept("-") { return .negate(try unary()) }
        if accept("+") { return try unary() }
        return try power()
    }

    private mutating func power() throws -> MathExpression.Node {
        let base = try postfix()
        if accept("^") {
            // Right-associative, and the exponent may carry its own sign: 2^-1, 2^3^2.
            return .binary("^", base, try unary())
        }
        return base
    }

    private mutating func postfix() throws -> MathExpression.Node {
        var node = try primary()
        while true {
            if accept("!") {
                node = .factorial(node)
            } else if accept("%") {
                node = .percent(node)
            } else {
                return node
            }
        }
    }

    private mutating func primary() throws -> MathExpression.Node {
        guard let token = current else { throw MathError.unexpectedEnd }
        position += 1
        switch token {
        case .number(let value):
            return .number(value)
        case .name(let name):
            guard MathExpression.functionNames.contains(name) else { return .name(name) }
            if accept("(") {
                var arguments: [MathExpression.Node] = []
                if !accept(")") {
                    repeat {
                        arguments.append(try expression())
                    } while accept(",")
                    guard accept(")") else { throw MathError.missingClosingParenthesis }
                }
                return .call(name, arguments)
            }
            // "sin 30", "√2": the function applies to the next factor.
            return .call(name, [try unary()])
        case .symbol("("):
            let inner = try expression()
            guard accept(")") else { throw MathError.missingClosingParenthesis }
            return inner
        case .symbol(let symbol):
            throw MathError.unexpectedToken(String(symbol))
        }
    }
}

// MARK: - Formatting

public enum MathFormatter {
    /// Up to 12 significant digits, which hides binary round-off (0.1 + 0.2 shows 0.3).
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return value.isNaN ? "NaN" : (value > 0 ? "∞" : "-∞") }
        if value == 0 { return "0" }
        var text = String(format: "%.12g", value)
        if let range = text.range(of: "e") {
            // "1.5e+20" -> "1.5×10^20"
            let mantissa = String(text[..<range.lowerBound])
            var exponent = String(text[range.upperBound...])
            let negative = exponent.hasPrefix("-")
            exponent = String(exponent.drop { $0 == "+" || $0 == "-" || $0 == "0" })
            text = mantissa + "×10^" + (negative ? "-" : "") + (exponent.isEmpty ? "0" : exponent)
        }
        return text
    }
}

// MARK: - Graph sampling

/// Turns `y = f(x)` into polyline segments in graph coordinates. A new segment starts wherever
/// the function is undefined or jumps (a pole such as 1/x at 0, or tan near 90°), so the plot
/// never draws a false vertical line through a discontinuity.
public enum GraphSampler {
    public static func segments(
        for expression: MathExpression,
        variable: String = "x",
        xRange: ClosedRange<Double>,
        yRange: ClosedRange<Double>,
        samples: Int,
        angleMode: AngleMode = .radians
    ) -> [[PagePoint]] {
        guard samples >= 2, xRange.upperBound > xRange.lowerBound else { return [] }
        let step = (xRange.upperBound - xRange.lowerBound) / Double(samples - 1)
        let span = yRange.upperBound - yRange.lowerBound
        // Allow drawing a little outside the visible window, then cut.
        let low = yRange.lowerBound - span
        let high = yRange.upperBound + span

        var segments: [[PagePoint]] = []
        var current: [PagePoint] = []
        func flush() {
            if current.count > 1 { segments.append(current) }
            current = []
        }

        func value(at x: Double) -> Double? {
            try? expression.evaluate(variables: [variable: x], angleMode: angleMode)
        }

        // Unclamped previous sample; nil after an undefined point.
        var previous: PagePoint?
        for index in 0..<samples {
            let x = xRange.lowerBound + Double(index) * step
            guard let y = value(at: x) else {
                flush()
                previous = nil
                continue
            }
            if let previous, isDiscontinuity(from: previous, to: PagePoint(x: x, y: y), span: span, value: value) {
                flush()
            }
            current.append(PagePoint(x: x, y: min(max(y, low), high)))
            previous = PagePoint(x: x, y: y)
        }
        flush()
        return segments
    }

    /// Two neighbouring samples that are far apart are joined only if the function really passes
    /// between them: the value at the midpoint must lie between the two. Across a pole the
    /// midpoint is undefined or far outside, so the curve is cut there. (A small step, such as
    /// floor(x), is still joined.)
    private static func isDiscontinuity(
        from a: PagePoint, to b: PagePoint, span: Double, value: (Double) -> Double?
    ) -> Bool {
        let jump = abs(b.y - a.y)
        guard jump > span / 2 else { return false }
        guard let middle = value((a.x + b.x) / 2) else { return true }
        // The tolerance is tied to the window, not to the jump: next to a pole one sample can be
        // astronomically large, and a jump-relative tolerance would then accept anything.
        let tolerance = span / 100
        return middle < min(a.y, b.y) - tolerance || middle > max(a.y, b.y) + tolerance
    }
}
