import Foundation

/// Produces a matching key for bilingual search. The original text is never modified or stored
/// in normalized form; this is only used to compare a query against content.
///
/// Rules: case and Latin diacritics are ignored; Arabic harakat and tatweel are ignored; alef,
/// ya, waw and ta-marbuta variants are unified; Arabic presentation forms (common in text
/// extracted from PDFs) become ordinary letters; Arabic-Indic digits become ASCII digits; any run
/// of whitespace, including line breaks, counts as one space.
public enum SearchNormalizer {
    public static func normalize(_ text: String) -> String {
        String(mapped(text).characters)
    }

    public static func matches(_ text: String, query: String) -> Bool {
        let key = normalize(query)
        return key.isEmpty || normalize(text).contains(key)
    }

    /// The normalized text together with, for every normalized character, the index of the
    /// original character it came from. This lets a match found in normalized text be shown and
    /// highlighted in the original text.
    public static func mapped(_ text: String) -> (characters: [Character], origins: [String.Index]) {
        var characters: [Character] = []
        var origins: [String.Index] = []
        characters.reserveCapacity(text.utf8.count)
        origins.reserveCapacity(text.utf8.count)
        var lastWasSpace = true // drops leading whitespace

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                if !lastWasSpace {
                    characters.append(" ")
                    origins.append(index)
                    lastWasSpace = true
                }
            } else {
                let folded = fold(character)
                for result in folded {
                    characters.append(result)
                    origins.append(index)
                }
                if !folded.isEmpty { lastWasSpace = false }
            }
            index = text.index(after: index)
        }
        if characters.last == " " {
            characters.removeLast()
            origins.removeLast()
        }
        return (characters, origins)
    }

    /// Normalizes one grapheme cluster. Returns "" for characters that are ignored (tatweel, or a
    /// cluster made only of harakat).
    static func fold(_ character: Character) -> String {
        // Fast path for plain ASCII, which is most of any English or numeric text.
        if character.isASCII, let ascii = character.asciiValue {
            if ascii >= 65, ascii <= 90 { return String(Character(Unicode.Scalar(ascii + 32))) }
            return String(character)
        }

        var source = String(character)
        // Presentation forms (FB50–FDFF, FE70–FEFF) -> ordinary Arabic letters.
        if source.unicodeScalars.contains(where: { (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }) {
            source = source.precomposedStringWithCompatibilityMapping
        }

        var scalars = String.UnicodeScalarView()
        for scalar in source.unicodeScalars {
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
        guard !scalars.isEmpty else { return "" }
        return String(scalars).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// A short piece of text around a match, for search results.
public struct TextExcerpt: Equatable, Sendable {
    public var before: String
    public var match: String
    public var after: String

    public init(before: String, match: String, after: String) {
        self.before = before
        self.match = match
        self.after = after
    }
}

/// Finds a query in text using `SearchNormalizer` rules and reports ranges in the ORIGINAL text.
public enum TextMatcher {
    /// Ranges of the original text whose normalized form equals the normalized query.
    public static func ranges(of query: String, in text: String, limit: Int = .max) -> [Range<String.Index>] {
        let needle = SearchNormalizer.mapped(query).characters
        guard !needle.isEmpty, limit > 0 else { return [] }
        let (haystack, origins) = SearchNormalizer.mapped(text)
        guard haystack.count >= needle.count else { return [] }

        var results: [Range<String.Index>] = []
        var start = 0
        let last = haystack.count - needle.count
        while start <= last {
            var offset = 0
            while offset < needle.count, haystack[start + offset] == needle[offset] {
                offset += 1
            }
            if offset == needle.count {
                let lower = origins[start]
                let upper = text.index(after: origins[start + needle.count - 1])
                results.append(lower..<upper)
                if results.count >= limit { break }
                start += needle.count
            } else {
                start += 1
            }
        }
        return results
    }

    /// Up to `context` characters on each side of `range`, cut at word boundaries, with all
    /// whitespace (including line breaks) shown as single spaces.
    public static func excerpt(of range: Range<String.Index>, in text: String, context: Int = 60) -> TextExcerpt {
        func collapse(_ part: Substring) -> String {
            part.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }

        var lower = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        var upper = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        // Do not start or end in the middle of a word.
        if lower > text.startIndex, let space = text[lower..<range.lowerBound].firstIndex(where: \.isWhitespace) {
            lower = space
        }
        if upper < text.endIndex, let space = text[range.upperBound..<upper].lastIndex(where: \.isWhitespace) {
            upper = space
        }

        var before = collapse(text[lower..<range.lowerBound])
        var after = collapse(text[range.upperBound..<upper])
        if text[lower..<range.lowerBound].last?.isWhitespace == true, !before.isEmpty { before += " " }
        if text[range.upperBound..<upper].first?.isWhitespace == true, !after.isEmpty { after = " " + after }
        if lower > text.startIndex { before = "…" + before }
        if upper < text.endIndex { after += "…" }
        return TextExcerpt(before: before, match: collapse(text[range]), after: after)
    }
}
