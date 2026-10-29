import Foundation

/// V15: six strictness levels, so blocking can be tuned if YouTube changes.
/// Each level includes everything from the levels below it.
enum AdBlockLevel: String, CaseIterable, Identifiable, Sendable, Comparable {
    case minimal, light, balanced, strict, aggressive, maximum
    var id: String { rawValue }
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: AdBlockLevel, rhs: AdBlockLevel) -> Bool { lhs.rank < rhs.rank }
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
    var blocksAdServers: Bool { self >= .light }
    var skipsAds: Bool { self >= .balanced }
    var blocksMeasurement: Bool { self >= .strict }
    var fastForwardsAds: Bool { self >= .strict }
    var prunesPlayerAds: Bool { self >= .aggressive }
    var prunesFeedAds: Bool { self == .maximum }
    var dismissesWarnings: Bool { self == .maximum }

    static let storageKey = "adBlockLevelV15"
    /// V5–V13 stored light (cosmetic only), balanced or strict.
    static func stored(_ defaults: UserDefaults) -> AdBlockLevel {
        if let value = defaults.string(forKey: storageKey), let level = AdBlockLevel(rawValue: value) { return level }
        switch defaults.string(forKey: "adBlockLevelV5") {
        case "light": return .minimal
        case "strict": return .strict
        default: return .balanced
        }
    }
}
