// V26 — Alle instellingen van de Arc/Dia-functies op één plek: sleutels, standaardwaarden en grenzen.
// De instellingenpagina (Views/V26Settings.swift) gebruikt dezelfde sleutels via @AppStorage; de rest van
// de app leest ze hier. Alleen Foundation: testbaar op Linux.
import Foundation

enum V26Prefs {
    enum Key {
        // Spaces
        static let spacesEnabled = "spacesEnabledV26"
        static let spaceSwitcher = "spaceSwitcherV26"
        static let spaceTint = "spaceTintV26"
        static let spaceTintStrength = "spaceTintStrengthV26"
        static let pinnedEverywhere = "pinnedEverywhereV26"
        static let spaceShortcuts = "spaceShortcutsV26"
        static let spaceNameInTabBar = "spaceNameInTabBarV26"
        // Split View
        static let splitEnabled = "splitEnabledV26"
        static let splitFraction = "splitFractionV26"
        static let splitVertical = "splitVerticalV26"
        static let splitHeaders = "splitHeadersV26"
        static let splitGap = "splitGapV26"
        static let splitFocusRing = "splitFocusRingV26"
        static let splitDimUnfocused = "splitDimUnfocusedV26"
        // Peek
        static let peekEnabled = "peekEnabledV26"
        static let peekShiftClick = "peekShiftClickV26"
        static let peekSize = "peekSizeV26"
        static let peekDim = "peekDimV26"
        static let peekCloseOutside = "peekCloseOutsideV26"
        // Boosts
        static let boostsEnabled = "boostsEnabledV26"
        static let zapHighlight = "zapHighlightV26"
        // Pagina-assistent
        static let assistantEnabled = "assistantEnabledV26"
        static let assistantAppleIntelligence = "assistantAppleIntelligenceV26"
        static let assistantSentences = "assistantSentencesV26"
        static let assistantWidth = "assistantWidthV26"
        static let assistantAutoSummary = "assistantAutoSummaryV26"
        static let assistantShowKeywords = "assistantShowKeywordsV26"
    }

    private static func flag(_ key: String, _ fallback: Bool, _ d: UserDefaults) -> Bool { (d.object(forKey: key) as? Bool) ?? fallback }
    private static func number(_ key: String, _ fallback: Double, _ d: UserDefaults) -> Double {
        guard let value = d.object(forKey: key) as? Double, value.isFinite else { return fallback }
        return value
    }
    private static func whole(_ key: String, _ fallback: Int, _ d: UserDefaults) -> Int { (d.object(forKey: key) as? Int) ?? fallback }

    // MARK: Spaces
    static func spacesEnabled(_ d: UserDefaults = .standard) -> Bool { flag(Key.spacesEnabled, true, d) }
    static func spaceSwitcher(_ d: UserDefaults = .standard) -> Bool { flag(Key.spaceSwitcher, true, d) }
    static func spaceTint(_ d: UserDefaults = .standard) -> Bool { flag(Key.spaceTint, true, d) }
    static func spaceTintStrength(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.spaceTintStrength, 0.14, d), 0), 0.5) }
    /// Vastgezette tabs = "favorieten" die in elke Space zichtbaar blijven (zoals in Arc).
    static func pinnedEverywhere(_ d: UserDefaults = .standard) -> Bool { flag(Key.pinnedEverywhere, true, d) }
    static func spaceShortcuts(_ d: UserDefaults = .standard) -> Bool { flag(Key.spaceShortcuts, true, d) }
    static func spaceNameInTabBar(_ d: UserDefaults = .standard) -> Bool { flag(Key.spaceNameInTabBar, true, d) }

    // MARK: Split View
    static func splitEnabled(_ d: UserDefaults = .standard) -> Bool { flag(Key.splitEnabled, true, d) }
    static func splitFraction(_ d: UserDefaults = .standard) -> Double { SplitLayout.clamp(number(Key.splitFraction, 0.5, d)) }
    static func splitVertical(_ d: UserDefaults = .standard) -> Bool { flag(Key.splitVertical, false, d) }
    static func splitHeaders(_ d: UserDefaults = .standard) -> Bool { flag(Key.splitHeaders, true, d) }
    static func splitGap(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.splitGap, 6, d), 0), 24) }
    static func splitFocusRing(_ d: UserDefaults = .standard) -> Bool { flag(Key.splitFocusRing, true, d) }
    static func splitDimUnfocused(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.splitDimUnfocused, 0, d), 0), 0.5) }

    // MARK: Peek
    static func peekEnabled(_ d: UserDefaults = .standard) -> Bool { flag(Key.peekEnabled, true, d) }
    /// Mac: ⇧-klik op een link opent hem in Peek.
    static func peekShiftClick(_ d: UserDefaults = .standard) -> Bool { flag(Key.peekShiftClick, true, d) }
    /// Grootte van het Peek-venster als deel van de werkruimte (0,5…0,95).
    static func peekSize(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.peekSize, 0.84, d), 0.5), 0.95) }
    static func peekDim(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.peekDim, 0.28, d), 0), 0.8) }
    static func peekCloseOutside(_ d: UserDefaults = .standard) -> Bool { flag(Key.peekCloseOutside, true, d) }

    // MARK: Boosts
    static func boostsEnabled(_ d: UserDefaults = .standard) -> Bool { flag(Key.boostsEnabled, true, d) }
    static func zapHighlight(_ d: UserDefaults = .standard) -> Bool { flag(Key.zapHighlight, true, d) }

    // MARK: Pagina-assistent
    static func assistantEnabled(_ d: UserDefaults = .standard) -> Bool { flag(Key.assistantEnabled, true, d) }
    static func assistantAppleIntelligence(_ d: UserDefaults = .standard) -> Bool { flag(Key.assistantAppleIntelligence, true, d) }
    static func assistantSentences(_ d: UserDefaults = .standard) -> Int { min(max(whole(Key.assistantSentences, 5, d), 2), 12) }
    static func assistantWidth(_ d: UserDefaults = .standard) -> Double { min(max(number(Key.assistantWidth, 340, d), 280), 560) }
    static func assistantAutoSummary(_ d: UserDefaults = .standard) -> Bool { flag(Key.assistantAutoSummary, true, d) }
    static func assistantShowKeywords(_ d: UserDefaults = .standard) -> Bool { flag(Key.assistantShowKeywords, true, d) }

    /// Alles terug naar de standaard (knop onderaan de instellingenpagina).
    static func reset(_ d: UserDefaults = .standard) {
        let keys = [Key.spacesEnabled, Key.spaceSwitcher, Key.spaceTint, Key.spaceTintStrength, Key.pinnedEverywhere, Key.spaceShortcuts,
                    Key.spaceNameInTabBar, Key.splitEnabled, Key.splitFraction, Key.splitVertical, Key.splitHeaders,
                    Key.splitGap, Key.splitFocusRing, Key.splitDimUnfocused, Key.peekEnabled, Key.peekShiftClick, Key.peekSize,
                    Key.peekDim, Key.peekCloseOutside, Key.boostsEnabled, Key.zapHighlight,
                    Key.assistantEnabled, Key.assistantAppleIntelligence, Key.assistantSentences, Key.assistantWidth,
                    Key.assistantAutoSummary, Key.assistantShowKeywords]
        keys.forEach(d.removeObject(forKey:))
    }
}
