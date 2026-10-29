import Foundation

/// V15: built-in SponsorBlock (community segment database, sponsor.ajay.app).
enum SponsorBlockCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case sponsor, selfpromo, interaction, intro, outro, preview, hook, filler, music_offtopic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sponsor: "Sponsor"
        case .selfpromo: "Unpaid / self promotion"
        case .interaction: "Interaction reminder (subscribe)"
        case .intro: "Intermission / intro animation"
        case .outro: "Endcards / credits"
        case .preview: "Preview / recap"
        case .hook: "Hook / greetings"
        case .filler: "Filler tangent / jokes"
        case .music_offtopic: "Music: non-music section"
        }
    }
    /// SponsorBlock's standard colours (used for progress-bar markers).
    var colorHex: String {
        switch self {
        case .sponsor: "#00D400"
        case .selfpromo: "#FFFF00"
        case .interaction: "#CC00FF"
        case .intro: "#00FFFF"
        case .outro: "#0202ED"
        case .preview: "#008FD6"
        case .hook: "#395699"
        case .filler: "#7300FF"
        case .music_offtopic: "#FF9900"
        }
    }
    var defaultMode: SponsorBlockMode {
        switch self {
        case .sponsor, .music_offtopic: .skip
        case .selfpromo, .interaction, .intro, .outro: .ask
        case .preview, .hook, .filler: .show
        }
    }
}

enum SponsorBlockMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case skip, mute, ask, show, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .skip: "Skip automatically"
        case .mute: "Mute"
        case .ask: "Show skip button"
        case .show: "Only show in progress bar"
        case .off: "Ignore"
        }
    }
}

struct SponsorBlockSettings: Codable, Equatable, Sendable {
    var enabled = true
    var modes: [String: SponsorBlockMode] = Dictionary(uniqueKeysWithValues:
        SponsorBlockCategory.allCases.map { ($0.rawValue, $0.defaultMode) })
    var showNotice = true
    var noticeSeconds: Double = 4
    var showMarkers = true
    var minimumDuration: Double = 1
    var skipOnlyOnce = true
    var serverURL = "https://sponsor.ajay.app"

    func mode(_ category: SponsorBlockCategory) -> SponsorBlockMode { modes[category.rawValue] ?? category.defaultMode }
    var activeCategories: [SponsorBlockCategory] { SponsorBlockCategory.allCases.filter { mode($0) != .off } }

    static let storageKey = "sponsorBlockV15"
    static func stored(_ defaults: UserDefaults) -> SponsorBlockSettings {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(SponsorBlockSettings.self, from: data) else { return SponsorBlockSettings() }
        return value
    }
    func save(_ defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
    }
    /// Options object handed to sponsorBlock.js.
    var scriptOptions: [String: Any] {
        var modeMap: [String: String] = [:]
        for category in SponsorBlockCategory.allCases { modeMap[category.rawValue] = mode(category).rawValue }
        var colors: [String: String] = [:]
        for category in SponsorBlockCategory.allCases { colors[category.rawValue] = category.colorHex }
        var titles: [String: String] = [:]
        for category in SponsorBlockCategory.allCases { titles[category.rawValue] = category.title }
        return ["modes": modeMap, "colors": colors, "titles": titles, "notice": showNotice,
                "noticeMs": Int(noticeSeconds * 1000), "markers": showMarkers,
                "minimum": minimumDuration, "once": skipOnlyOnce]
    }
}
