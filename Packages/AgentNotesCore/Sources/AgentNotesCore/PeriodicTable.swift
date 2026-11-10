import Foundation

// DATA PROVENANCE AND REVIEW STATUS
// Element numbers, symbols and English names follow IUPAC. Atomic masses are abridged standard
// atomic weights; for elements without a standard weight, `massNumber` is the mass number of a
// long-lived isotope (these differ between references for the heaviest elements).
// The table and the Arabic names were typed in by hand for development and have NOT yet been
// checked line by line against an authoritative source. Before release: validate every row
// against the IUPAC periodic table / PubChem (public domain) and have the Arabic names reviewed.
// Unit tests cover structure (118 rows, unique symbols, layout) and a few spot values only.

public enum ElementCategory: String, CaseIterable, Sendable {
    case alkaliMetal
    case alkalineEarthMetal
    case transitionMetal
    case postTransitionMetal
    case metalloid
    case nonmetal
    case halogen
    case nobleGas
    case lanthanide
    case actinide
}

public struct ChemicalElement: Identifiable, Hashable, Sendable {
    public let number: Int
    public let symbol: String
    public let name: String
    public let arabicName: String
    /// Abridged standard atomic weight, when one is defined.
    public let atomicWeight: Double?
    /// Mass number of a long-lived isotope, for elements without a standard atomic weight.
    public let massNumber: Int?

    public var id: Int { number }

    public var period: Int {
        switch number {
        case ...2: return 1
        case ...10: return 2
        case ...18: return 3
        case ...36: return 4
        case ...54: return 5
        case ...86: return 6
        default: return 7
        }
    }

    /// IUPAC group 1...18, or nil for the f-block (lanthanides and actinides).
    public var group: Int? {
        switch number {
        case 1: return 1
        case 2: return 18
        case 3...4: return number - 2
        case 5...10: return number + 8
        case 11...12: return number - 10
        case 13...18: return number
        case 19...36: return number - 18
        case 37...54: return number - 36
        case 55...56: return number - 54
        case 57...71: return nil
        case 72...86: return number - 68
        case 87...88: return number - 86
        case 89...103: return nil
        default: return number - 100
        }
    }

    /// Position in the conventional 18-column layout with the f-block in two extra rows (8 and 9).
    public var gridPosition: (row: Int, column: Int) {
        if let group { return (period, group) }
        return number <= 71 ? (8, number - 57 + 3) : (9, number - 89 + 3)
    }

    /// Conventional colour-coding category. Classification of a few elements (for example
    /// polonium, astatine and the heaviest elements) varies between references.
    public var category: ElementCategory {
        switch number {
        case 3, 11, 19, 37, 55, 87: return .alkaliMetal
        case 4, 12, 20, 38, 56, 88: return .alkalineEarthMetal
        case 57...71: return .lanthanide
        case 89...103: return .actinide
        case 9, 17, 35, 53, 85, 117: return .halogen
        case 2, 10, 18, 36, 54, 86, 118: return .nobleGas
        case 5, 14, 32, 33, 51, 52: return .metalloid
        case 1, 6, 7, 8, 15, 16, 34: return .nonmetal
        case 13, 31, 49, 50, 81, 82, 83, 84, 113, 114, 115, 116: return .postTransitionMetal
        default: return .transitionMetal
        }
    }

    /// "55.845", or "[98]" style for elements without a standard atomic weight.
    public var massText: String {
        if let atomicWeight { return MathFormatter.format(atomicWeight) }
        if let massNumber { return "[\(massNumber)]" }
        return "-"
    }
}

public enum PeriodicTable {
    public static let elements: [ChemicalElement] = rows.enumerated().map { index, row in
        ChemicalElement(
            number: index + 1,
            symbol: row.0,
            name: row.1,
            arabicName: row.2,
            atomicWeight: row.3 > 0 ? row.3 : nil,
            massNumber: row.3 < 0 ? Int(-row.3) : nil)
    }

    public static func element(number: Int) -> ChemicalElement? {
        elements.indices.contains(number - 1) ? elements[number - 1] : nil
    }

    public static func search(_ query: String) -> [ChemicalElement] {
        let key = SearchNormalizer.normalize(query)
        guard !key.isEmpty else { return elements }
        return elements.filter { element in
            SearchNormalizer.normalize(element.symbol) == key
                || SearchNormalizer.normalize(element.name).contains(key)
                || SearchNormalizer.normalize(element.arabicName).contains(key)
                || String(element.number) == key
        }
    }

    // (symbol, English name, Arabic name, mass). A positive mass is the abridged standard atomic
    // weight; a negative value is minus the mass number of a long-lived isotope.
    private static let rows: [(String, String, String, Double)] = [
        ("H", "Hydrogen", "هيدروجين", 1.008),
        ("He", "Helium", "هيليوم", 4.0026),
        ("Li", "Lithium", "ليثيوم", 6.94),
        ("Be", "Beryllium", "بيريليوم", 9.0122),
        ("B", "Boron", "بورون", 10.81),
        ("C", "Carbon", "كربون", 12.011),
        ("N", "Nitrogen", "نيتروجين", 14.007),
        ("O", "Oxygen", "أكسجين", 15.999),
        ("F", "Fluorine", "فلور", 18.998),
        ("Ne", "Neon", "نيون", 20.180),
        ("Na", "Sodium", "صوديوم", 22.990),
        ("Mg", "Magnesium", "مغنيسيوم", 24.305),
        ("Al", "Aluminium", "ألومنيوم", 26.982),
        ("Si", "Silicon", "سيليكون", 28.085),
        ("P", "Phosphorus", "فوسفور", 30.974),
        ("S", "Sulfur", "كبريت", 32.06),
        ("Cl", "Chlorine", "كلور", 35.45),
        ("Ar", "Argon", "أرغون", 39.95),
        ("K", "Potassium", "بوتاسيوم", 39.098),
        ("Ca", "Calcium", "كالسيوم", 40.078),
        ("Sc", "Scandium", "سكانديوم", 44.956),
        ("Ti", "Titanium", "تيتانيوم", 47.867),
        ("V", "Vanadium", "فاناديوم", 50.942),
        ("Cr", "Chromium", "كروم", 51.996),
        ("Mn", "Manganese", "منغنيز", 54.938),
        ("Fe", "Iron", "حديد", 55.845),
        ("Co", "Cobalt", "كوبالت", 58.933),
        ("Ni", "Nickel", "نيكل", 58.693),
        ("Cu", "Copper", "نحاس", 63.546),
        ("Zn", "Zinc", "زنك", 65.38),
        ("Ga", "Gallium", "غاليوم", 69.723),
        ("Ge", "Germanium", "جرمانيوم", 72.630),
        ("As", "Arsenic", "زرنيخ", 74.922),
        ("Se", "Selenium", "سيلينيوم", 78.971),
        ("Br", "Bromine", "بروم", 79.904),
        ("Kr", "Krypton", "كريبتون", 83.798),
        ("Rb", "Rubidium", "روبيديوم", 85.468),
        ("Sr", "Strontium", "سترونشيوم", 87.62),
        ("Y", "Yttrium", "إتريوم", 88.906),
        ("Zr", "Zirconium", "زركونيوم", 91.224),
        ("Nb", "Niobium", "نيوبيوم", 92.906),
        ("Mo", "Molybdenum", "موليبدنوم", 95.95),
        ("Tc", "Technetium", "تكنيشيوم", -97),
        ("Ru", "Ruthenium", "روثينيوم", 101.07),
        ("Rh", "Rhodium", "روديوم", 102.91),
        ("Pd", "Palladium", "بالاديوم", 106.42),
        ("Ag", "Silver", "فضة", 107.87),
        ("Cd", "Cadmium", "كادميوم", 112.41),
        ("In", "Indium", "إنديوم", 114.82),
        ("Sn", "Tin", "قصدير", 118.71),
        ("Sb", "Antimony", "أنتيمون", 121.76),
        ("Te", "Tellurium", "تيلوريوم", 127.60),
        ("I", "Iodine", "يود", 126.90),
        ("Xe", "Xenon", "زينون", 131.29),
        ("Cs", "Caesium", "سيزيوم", 132.91),
        ("Ba", "Barium", "باريوم", 137.33),
        ("La", "Lanthanum", "لانثانوم", 138.91),
        ("Ce", "Cerium", "سيريوم", 140.12),
        ("Pr", "Praseodymium", "براسيوديميوم", 140.91),
        ("Nd", "Neodymium", "نيوديميوم", 144.24),
        ("Pm", "Promethium", "بروميثيوم", -145),
        ("Sm", "Samarium", "ساماريوم", 150.36),
        ("Eu", "Europium", "يوروبيوم", 151.96),
        ("Gd", "Gadolinium", "غادولينيوم", 157.25),
        ("Tb", "Terbium", "تربيوم", 158.93),
        ("Dy", "Dysprosium", "ديسبروسيوم", 162.50),
        ("Ho", "Holmium", "هولميوم", 164.93),
        ("Er", "Erbium", "إربيوم", 167.26),
        ("Tm", "Thulium", "ثوليوم", 168.93),
        ("Yb", "Ytterbium", "إتربيوم", 173.05),
        ("Lu", "Lutetium", "لوتيشيوم", 174.97),
        ("Hf", "Hafnium", "هافنيوم", 178.49),
        ("Ta", "Tantalum", "تانتالوم", 180.95),
        ("W", "Tungsten", "تنغستن", 183.84),
        ("Re", "Rhenium", "رينيوم", 186.21),
        ("Os", "Osmium", "أوزميوم", 190.23),
        ("Ir", "Iridium", "إيريديوم", 192.22),
        ("Pt", "Platinum", "بلاتين", 195.08),
        ("Au", "Gold", "ذهب", 196.97),
        ("Hg", "Mercury", "زئبق", 200.59),
        ("Tl", "Thallium", "ثاليوم", 204.38),
        ("Pb", "Lead", "رصاص", 207.2),
        ("Bi", "Bismuth", "بزموت", 208.98),
        ("Po", "Polonium", "بولونيوم", -209),
        ("At", "Astatine", "أستاتين", -210),
        ("Rn", "Radon", "رادون", -222),
        ("Fr", "Francium", "فرانسيوم", -223),
        ("Ra", "Radium", "راديوم", -226),
        ("Ac", "Actinium", "أكتينيوم", -227),
        ("Th", "Thorium", "ثوريوم", 232.04),
        ("Pa", "Protactinium", "بروتكتينيوم", 231.04),
        ("U", "Uranium", "يورانيوم", 238.03),
        ("Np", "Neptunium", "نبتونيوم", -237),
        ("Pu", "Plutonium", "بلوتونيوم", -244),
        ("Am", "Americium", "أمريسيوم", -243),
        ("Cm", "Curium", "كوريوم", -247),
        ("Bk", "Berkelium", "بركيليوم", -247),
        ("Cf", "Californium", "كاليفورنيوم", -251),
        ("Es", "Einsteinium", "أينشتاينيوم", -252),
        ("Fm", "Fermium", "فرميوم", -257),
        ("Md", "Mendelevium", "مندليفيوم", -258),
        ("No", "Nobelium", "نوبليوم", -259),
        ("Lr", "Lawrencium", "لورنسيوم", -266),
        ("Rf", "Rutherfordium", "رذرفورديوم", -267),
        ("Db", "Dubnium", "دوبنيوم", -268),
        ("Sg", "Seaborgium", "سيبورغيوم", -269),
        ("Bh", "Bohrium", "بوريوم", -270),
        ("Hs", "Hassium", "هاسيوم", -277),
        ("Mt", "Meitnerium", "مايتنريوم", -278),
        ("Ds", "Darmstadtium", "دارمشتاتيوم", -281),
        ("Rg", "Roentgenium", "رونتجينيوم", -282),
        ("Cn", "Copernicium", "كوبرنيسيوم", -285),
        ("Nh", "Nihonium", "نيهونيوم", -286),
        ("Fl", "Flerovium", "فليروفيوم", -289),
        ("Mc", "Moscovium", "موسكوفيوم", -290),
        ("Lv", "Livermorium", "ليفرموريوم", -293),
        ("Ts", "Tennessine", "تينيسين", -294),
        ("Og", "Oganesson", "أوغانيسون", -294)
    ]
}
