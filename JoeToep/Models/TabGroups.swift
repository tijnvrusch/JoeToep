// V21 — Tabgroepen (Arc/Dia-stijl), voorkeuren voor de zwevende zoekbalk, en "Tab om te zoeken".
import Foundation
import SwiftUI

struct TabGroup: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var color: String          // naam uit `palette`
    var collapsed = false

    static let palette = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "gray"]
    var swiftUIColor: Color { Self.color(named: color) }
    static func color(named name: String) -> Color {
        switch name {
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "teal": .teal
        case "gray": .gray
        default: .blue
        }
    }
}

enum TabGroupStore {
    static let key = "tabGroupsV21"
    static func load() -> [TabGroup] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let groups = try? JSONDecoder().decode([TabGroup].self, from: data) else { return [] }
        return groups
    }
    static func save(_ groups: [TabGroup]) {
        if let data = try? JSONEncoder().encode(groups) { UserDefaults.standard.set(data, forKey: key) }
    }
}

enum CommandBarPrefs {
    private static var d: UserDefaults { .standard }
    /// ⌘T / "+" opent de zwevende zoekbalk boven de huidige pagina (Arc) i.p.v. een lege tab.
    static var overlayForNewTab: Bool { d.object(forKey: "commandBarNewTabV21") as? Bool ?? true }
    /// Klik op de actieve tab / ⌘L opent dezelfde balk om het adres te wijzigen.
    static var overlayForAddress: Bool { d.object(forKey: "commandBarAddressV21") as? Bool ?? true }
    /// Hoe sterk de pagina achter de balk getint wordt (0…0.5).
    static var tint: Double { d.object(forKey: "commandBarTintV21") as? Double ?? 0.12 }
    static var maxSuggestions: Int { d.object(forKey: "commandBarSuggestionsV21") as? Int ?? 8 }
    static var showTabs: Bool { d.object(forKey: "commandBarShowTabsV21") as? Bool ?? true }
    static var showHistory: Bool { d.object(forKey: "commandBarShowHistoryV21") as? Bool ?? true }
    static var tabToSearch: Bool { d.object(forKey: "commandBarTabToSearchV21") as? Bool ?? true }
}

/// "YouTube" typen en dan Tab → zoeken op YouTube. Werkt voor elk platform (en afkortingen).
enum SearchToken {
    static let aliases: [(MediaPlatform, [String])] = [
        (.youtube, ["youtube", "yt", "you tube"]),
        (.youtubeMusic, ["youtube music", "yt music", "ytmusic", "music"]),
        (.spotify, ["spotify", "sp"]),
        (.twitch, ["twitch", "tw"]),
        (.vimeo, ["vimeo"]),
        (.soundcloud, ["soundcloud", "sc"]),
        (.dailymotion, ["dailymotion", "dm"]),
        (.web, ["web", "google", "search", "zoek"]),
    ]
    /// Welk platform bedoelt deze invoer (volledige naam, afkorting of begin van de naam, ≥ 2 letters)?
    static func platform(for text: String) -> MediaPlatform? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.count >= 2 else { return nil }
        for (p, names) in aliases where names.contains(t) { return p }
        for (p, names) in aliases where names.contains(where: { $0.hasPrefix(t) && t.count >= 3 }) { return p }
        return nil
    }
}
