import Foundation

/// Produces a matching key for bilingual search. The original text is never modified or stored
/// in normalized form; this is only used to compare a query against content.
public enum SearchNormalizer {
    public static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            // Arabic harakat, Quranic marks, superscript alef, tatweel: ignored for matching.
            case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640:
                continue
            // Alef variants (madda, hamza above/below, wasla) -> bare alef.
            case 0x0622, 0x0623, 0x0625, 0x0671:
                scalars.append("\u{0627}")
            // Alef maqsura and hamza-on-ya -> ya.
            case 0x0649, 0x0626:
                scalars.append("\u{064A}")
            // Hamza-on-waw -> waw.
            case 0x0624:
                scalars.append("\u{0648}")
            // Ta marbuta -> ha.
            case 0x0629:
                scalars.append("\u{0647}")
            // Arabic-Indic and Extended Arabic-Indic digits -> ASCII digits.
            case 0x0660...0x0669:
                scalars.append(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9:
                scalars.append(Unicode.Scalar(scalar.value - 0x06F0 + 0x30)!)
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(_ text: String, query: String) -> Bool {
        let key = normalize(query)
        return key.isEmpty || normalize(text).contains(key)
    }
}
