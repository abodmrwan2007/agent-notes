import Foundation

/// Turns text read from a handwritten sum into something `MathExpression` understands.
public enum HandwrittenMath {
    /// - Replaces ×, x, X between numbers with *, ÷ and : with /, typographic minus signs with -.
    /// - Reads O/o as 0 and l, I, | as 1 when they sit next to a digit.
    /// - Drops spaces, a trailing "=" and anything written after it.
    public static func normalize(_ recognized: String) -> String {
        var text = recognized.replacingOccurrences(of: "\n", with: "")
        if let equals = text.firstIndex(of: "=") {
            text = String(text[..<equals])
        }
        text = text.replacingOccurrences(of: " ", with: "")
        let simple: [String: String] = ["÷": "/", ":": "/", "−": "-", "–": "-", "—": "-", "·": "*", "×": "*", "^": "^", "²": "^2", "³": "^3"]
        for (from, to) in simple {
            text = text.replacingOccurrences(of: from, with: to)
        }

        let characters = Array(text)
        var result = ""
        for (index, character) in characters.enumerated() {
            let previous = index > 0 ? characters[index - 1] : nil
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let nearDigit = (previous?.isNumber ?? false) || (next?.isNumber ?? false)
            switch character {
            case "x", "X":
                // Multiplication only between two numbers or brackets; otherwise it is a variable.
                let leftIsValue = previous.map { $0.isNumber || $0 == ")" } ?? false
                let rightIsValue = next.map { $0.isNumber || $0 == "(" } ?? false
                result.append(leftIsValue && rightIsValue ? "*" : character)
            case "O", "o":
                result.append(nearDigit ? "0" : character)
            case "l", "I", "|":
                result.append(nearDigit ? "1" : character)
            default:
                result.append(character)
            }
        }
        return result
    }
}
