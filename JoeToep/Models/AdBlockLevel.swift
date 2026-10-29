import Foundation

/// V15: six strictness levels, so blocking can be tuned if YouTube changes.
/// Each level includes everything from the levels below it.
// AdBlockLevel bepaalt hoe streng de ingebouwde advertentieblokkering is.
// "Comparable" is nieuw hier: dit betekent dat je twee waarden van dit type
// kunt vergelijken met <, >, <= en >=, zodra je zelf (hieronder) de "<"-
// operator hebt gedefinieerd. Zo kun je bijv. checken of het huidige niveau
// "minstens zo streng" is als .strict.
enum AdBlockLevel: String, CaseIterable, Identifiable, Sendable, Comparable {
    // Cases zonder eigen tekst: de rawValue is gelijk aan de naam zelf. De
    // VOLGORDE hier is belangrijk (zie "rank" hieronder): van mildst naar strengst.
    case minimal, light, balanced, strict, aggressive, maximum
    var id: String { rawValue }
    // Zoekt de positie (index) van deze case binnen "allCases" (van
    // CaseIterable) op, in de volgorde waarin ze hierboven gedeclareerd zijn.
    // "?? 0" is een terugvalwaarde voor het (in de praktijk onmogelijke) geval
    // dat de case niet gevonden wordt.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    // Definieert zelf hoe "<" werkt voor dit type: eentje is "kleiner" (milder)
    // als zijn rank lager is. Dit maakt het mogelijk om hieronder ".strict" of
    // hoger te checken met ">=".
    static func < (lhs: AdBlockLevel, rhs: AdBlockLevel) -> Bool { lhs.rank < rhs.rank }
    // Titel met volgnummer, zoals getoond in de instellingen.
    var title: String {
        switch self {
        case .minimal: "1 · Minimal"
        case .light: "2 · Light"
        case .balanced: "3 · Balanced"
        case .strict: "4 · Strict"
        case .aggressive: "5 · Aggressive"
        case .maximum: "6 · Maximum"
        }
    }
    // Uitgebreide uitleg per niveau, getoond in de instellingen zodat de
    // gebruiker weet wat elk niveau precies doet.
    var explanation: String {
        switch self {
        case .minimal: "Only hides ad cards and promoted tiles. Blocks no network requests. Lowest risk of breakage."
        case .light: "Also blocks requests to known ad servers (DoubleClick, Google ad services)."
        case .balanced: "Also presses YouTube's own “Skip” button the moment it appears. Recommended."
        case .strict: "Also blocks ad-measurement endpoints and promotional shelves, hides overlay banners and fast-forwards unskippable ads (muted)."
        case .aggressive: "Also removes ad placements from YouTube's player data before the player sees them, so most video ads never start."
        case .maximum: "Also removes ad slots from feeds and search results and closes YouTube's ad-blocker warnings. Use if ads return; switch back if something breaks."
        }
    }
    /// Blocks network requests to ad servers.
    // Dit zijn allemaal computed properties die vertalen "is dit niveau
    // minstens zo streng als X?" naar een simpele true/false-vlag, die de rest
    // van de app kan gebruiken zonder zelf steeds met rangen te vergelijken.
    var blocksAdServers: Bool { self >= .light }
    var skipsAds: Bool { self >= .balanced }
    var blocksMeasurement: Bool { self >= .strict }
    var fastForwardsAds: Bool { self >= .strict }
    var prunesPlayerAds: Bool { self >= .aggressive }
    // Deze twee gelden alleen bij het allerstrengste niveau, dus wordt hier
    // met "==" vergeleken in plaats van ">=".
    var prunesFeedAds: Bool { self == .maximum }
    var dismissesWarnings: Bool { self == .maximum }

    // De sleutel waaronder het gekozen niveau wordt opgeslagen in
    // UserDefaults (Apple's simpele opslag voor instellingen).
    static let storageKey = "adBlockLevelV15"
    /// V5–V13 stored light (cosmetic only), balanced or strict.
    // Leest het opgeslagen niveau uit, met migratie-logica voor gebruikers die
    // de app al hadden vóór dit systeem met 6 niveaus bestond.
    static func stored(_ defaults: UserDefaults) -> AdBlockLevel {
        // Als er al een waarde is opgeslagen onder de NIEUWE sleutel, en die
        // waarde komt overeen met een bestaande case, gebruik die direct.
        if let value = defaults.string(forKey: storageKey), let level = AdBlockLevel(rawValue: value) { return level }
        // Anders kijken we naar de OUDE (V5) opslagsleutel, en zetten we die
        // oude drie niveaus om naar het dichtstbijzijnde nieuwe niveau.
        switch defaults.string(forKey: "adBlockLevelV5") {
        case "light": return .minimal
        case "strict": return .strict
        default: return .balanced
        }
    }
}
