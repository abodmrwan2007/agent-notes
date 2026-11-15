import UIKit

/// Stickers from Twemoji (https://github.com/jdecked/twemoji), CC BY 4.0, used unmodified.
/// Copyright Twitter, Inc and other contributors. Attribution is shown wherever stickers are
/// offered and in Settings ▸ Acknowledgements; see third_party/twemoji/NOTICE.md.
///
/// The files are SVGs in `Twemoji.xcassets` with vector data preserved, so a sticker is rendered
/// sharp at any size when it is placed on a page.
struct TwemojiSticker: Identifiable, Hashable {
    enum Group: CaseIterable {
        case medical
        case study
    }

    /// Unicode code points, as in the Twemoji file name (for example "1fac0").
    let code: String
    let englishName: String
    let arabicName: String
    let group: Group

    var id: String { code }
    var assetName: String { "tw-" + code }

    var accessibilityName: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true ? arabicName : englishName
    }

    static let attribution = "Twemoji © Twitter, Inc and other contributors, CC BY 4.0"

    static let all: [TwemojiSticker] = [
        // Medical
        TwemojiSticker(code: "1fac0", englishName: "Anatomical heart", arabicName: "قلب تشريحي", group: .medical),
        TwemojiSticker(code: "1fac1", englishName: "Lungs", arabicName: "رئتان", group: .medical),
        TwemojiSticker(code: "1f9e0", englishName: "Brain", arabicName: "دماغ", group: .medical),
        TwemojiSticker(code: "1f9b7", englishName: "Tooth", arabicName: "سن", group: .medical),
        TwemojiSticker(code: "1f9b4", englishName: "Bone", arabicName: "عظمة", group: .medical),
        TwemojiSticker(code: "1f441", englishName: "Eye", arabicName: "عين", group: .medical),
        TwemojiSticker(code: "1f442", englishName: "Ear", arabicName: "أذن", group: .medical),
        TwemojiSticker(code: "1f443", englishName: "Nose", arabicName: "أنف", group: .medical),
        TwemojiSticker(code: "1f9b5", englishName: "Leg", arabicName: "ساق", group: .medical),
        TwemojiSticker(code: "1f4aa", englishName: "Muscle", arabicName: "عضلة", group: .medical),
        TwemojiSticker(code: "1fa78", englishName: "Drop of blood", arabicName: "قطرة دم", group: .medical),
        TwemojiSticker(code: "1fa7a", englishName: "Stethoscope", arabicName: "سماعة طبيب", group: .medical),
        TwemojiSticker(code: "1f489", englishName: "Syringe", arabicName: "حقنة", group: .medical),
        TwemojiSticker(code: "1f48a", englishName: "Pill", arabicName: "دواء", group: .medical),
        TwemojiSticker(code: "1fa79", englishName: "Bandage", arabicName: "ضمادة", group: .medical),
        TwemojiSticker(code: "1fa7b", englishName: "X-ray", arabicName: "أشعة سينية", group: .medical),
        TwemojiSticker(code: "1fa7c", englishName: "Crutch", arabicName: "عكاز", group: .medical),
        TwemojiSticker(code: "1f9ec", englishName: "DNA", arabicName: "حمض نووي", group: .medical),
        TwemojiSticker(code: "1f9a0", englishName: "Microbe", arabicName: "ميكروب", group: .medical),
        TwemojiSticker(code: "1f9ea", englishName: "Test tube", arabicName: "أنبوب اختبار", group: .medical),
        TwemojiSticker(code: "1f9eb", englishName: "Petri dish", arabicName: "طبق بتري", group: .medical),
        TwemojiSticker(code: "1f52c", englishName: "Microscope", arabicName: "مجهر", group: .medical),
        TwemojiSticker(code: "1f321", englishName: "Thermometer", arabicName: "ميزان حرارة", group: .medical),
        TwemojiSticker(code: "1f3e5", englishName: "Hospital", arabicName: "مستشفى", group: .medical),
        TwemojiSticker(code: "1f691", englishName: "Ambulance", arabicName: "إسعاف", group: .medical),
        TwemojiSticker(code: "1f9d1-200d-2695-fe0f", englishName: "Health worker", arabicName: "عامل صحي", group: .medical),
        // Study
        TwemojiSticker(code: "2764", englishName: "Red heart", arabicName: "قلب أحمر", group: .study),
        TwemojiSticker(code: "2b50", englishName: "Star", arabicName: "نجمة", group: .study),
        TwemojiSticker(code: "2705", englishName: "Check mark", arabicName: "علامة صح", group: .study),
        TwemojiSticker(code: "274c", englishName: "Cross mark", arabicName: "علامة خطأ", group: .study),
        TwemojiSticker(code: "26a0", englishName: "Warning", arabicName: "تنبيه", group: .study),
        TwemojiSticker(code: "2753", englishName: "Question", arabicName: "سؤال", group: .study),
        TwemojiSticker(code: "2757", englishName: "Exclamation", arabicName: "تعجّب", group: .study),
        TwemojiSticker(code: "1f4a1", englishName: "Idea", arabicName: "فكرة", group: .study),
        TwemojiSticker(code: "1f4cc", englishName: "Pushpin", arabicName: "دبوس", group: .study),
        TwemojiSticker(code: "1f4ce", englishName: "Paperclip", arabicName: "مشبك ورق", group: .study),
        TwemojiSticker(code: "1f4dd", englishName: "Memo", arabicName: "مذكرة", group: .study),
        TwemojiSticker(code: "1f4da", englishName: "Books", arabicName: "كتب", group: .study),
        TwemojiSticker(code: "1f3af", englishName: "Target", arabicName: "هدف", group: .study),
        TwemojiSticker(code: "23f0", englishName: "Alarm clock", arabicName: "منبّه", group: .study),
        TwemojiSticker(code: "1f525", englishName: "Fire", arabicName: "نار", group: .study),
        TwemojiSticker(code: "1f3c6", englishName: "Trophy", arabicName: "كأس", group: .study),
        TwemojiSticker(code: "1f389", englishName: "Celebration", arabicName: "احتفال", group: .study),
        TwemojiSticker(code: "1f44d", englishName: "Thumbs up", arabicName: "إعجاب", group: .study),
        TwemojiSticker(code: "1f9e9", englishName: "Puzzle piece", arabicName: "قطعة أحجية", group: .study),
        TwemojiSticker(code: "1f4c8", englishName: "Chart", arabicName: "رسم بياني", group: .study)
    ]

    static func stickers(in group: Group) -> [TwemojiSticker] {
        all.filter { $0.group == group }
    }

    /// The vector image from the asset catalog (app bundle, or the package bundle in the
    /// Swift Playgrounds build).
    var vectorImage: UIImage? {
        if let image = UIImage(named: assetName, in: .main, with: nil) { return image }
        #if SWIFT_PACKAGE
        return UIImage(named: assetName, in: .module, with: nil)
        #else
        return nil
        #endif
    }

    /// Rendered for the page at 3x of `pageSide` points, transparency kept.
    func pngData(pageSide: CGFloat = 96) -> Data? {
        guard let vector = vectorImage else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let size = CGSize(width: pageSide, height: pageSide)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            vector.draw(in: CGRect(origin: .zero, size: size))
        }.pngData()
    }
}
