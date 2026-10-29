// V26 — Spaces (zoals in Arc): aparte sets tabs per onderwerp ("Thuis", "Muziek", "Werk" …), elk met
// een eigen naam, icoon en kleur. Vastgezette tabs zijn standaard "favorieten" en blijven in elke Space
// zichtbaar. Alleen Foundation: deze logica is ook op Linux te compileren en te testen
// (Scripts/linux_swift_tests.sh → JoeToepTests/LinuxV26Tests.swift).
import Foundation

struct BrowserSpace: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
    /// SF Symbol-naam (bijv. "house.fill") of één emoji.
    var symbol: String
    /// Kleurnaam uit `SpaceLogic.palette` (dezelfde namen als tabgroepen).
    var color: String

    /// Is het icoon een emoji (geen SF Symbol)? SF Symbols bestaan uit ASCII-letters, cijfers en punten.
    var symbolIsEmoji: Bool { !symbol.isEmpty && !symbol.allSatisfy { $0.isASCII } }
}

/// Eén tab zoals de Space-logica hem ziet (los van BrowserTab, zodat alles testbaar blijft).
struct SpaceMember: Equatable, Sendable {
    var id: UUID
    var spaceID: UUID?
    var pinned: Bool
}

enum SpaceLogic {
    static let palette = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "gray"]
    static let suggestedSymbols = ["house.fill", "music.note", "briefcase.fill", "graduationcap.fill", "gamecontroller.fill",
                                   "film.fill", "sparkles", "heart.fill", "star.fill", "leaf.fill", "airplane", "cart.fill",
                                   "book.fill", "paintpalette.fill", "dumbbell.fill", "moon.stars.fill"]
    /// Maximaal aantal Spaces (⌃1…⌃9 + één reserve; meer is in een zijbalk niet meer overzichtelijk).
    static let maximumCount = 10

    /// De eerste Space bestaat altijd en is waar tabs zonder Space (oude data, sync, widgets) landen.
    static func defaultSpace() -> BrowserSpace { BrowserSpace(name: "Home", symbol: "house.fill", color: "blue") }

    /// Lijst opschonen: minstens één Space, unieke id's, geldige kleuren/namen, hooguit `maximumCount`.
    static func normalized(_ spaces: [BrowserSpace]) -> [BrowserSpace] {
        var seen = Set<UUID>()
        var result: [BrowserSpace] = []
        for var space in spaces where seen.insert(space.id).inserted {
            space.name = cleanName(space.name)
            if !palette.contains(space.color) { space.color = palette[result.count % palette.count] }
            if space.symbol.trimmingCharacters(in: .whitespaces).isEmpty { space.symbol = "circle.fill" }
            result.append(space)
            if result.count == maximumCount { break }
        }
        return result.isEmpty ? [defaultSpace()] : result
    }

    static func cleanName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Space" : String(trimmed.prefix(40))
    }

    /// In welke Space hoort een tab echt? Onbekend of leeg → de eerste Space.
    static func resolve(_ spaceID: UUID?, in spaces: [BrowserSpace]) -> UUID {
        if let spaceID, spaces.contains(where: { $0.id == spaceID }) { return spaceID }
        return spaces.first?.id ?? defaultSpace().id
    }

    /// Hoort deze tab in de getoonde Space? Vastgezette tabs zijn (met `pinnedEverywhere`) overal zichtbaar.
    static func isVisible(_ member: SpaceMember, active: UUID, spaces: [BrowserSpace], pinnedEverywhere: Bool) -> Bool {
        if member.pinned && pinnedEverywhere { return true }
        return resolve(member.spaceID, in: spaces) == active
    }

    /// Alle zichtbare tabs, in de oorspronkelijke volgorde.
    static func visibleIDs(_ members: [SpaceMember], active: UUID, spaces: [BrowserSpace], pinnedEverywhere: Bool) -> [UUID] {
        members.filter { isVisible($0, active: active, spaces: spaces, pinnedEverywhere: pinnedEverywhere) }.map(\.id)
    }

    /// Welke tab tonen na het wisselen naar `space`? Eerst de laatst gebruikte tab daar, anders de eerste
    /// gewone tab, anders een vastgezette tab. nil = de Space is leeg (dan opent de app een nieuwe tab).
    static func selectionAfterSwitch(to space: UUID, lastSelected: [UUID: UUID], members: [SpaceMember],
                                     spaces: [BrowserSpace], pinnedEverywhere: Bool) -> UUID? {
        let visible = members.filter { isVisible($0, active: space, spaces: spaces, pinnedEverywhere: pinnedEverywhere) }
        if let last = lastSelected[space], visible.contains(where: { $0.id == last }) { return last }
        return visible.first(where: { !$0.pinned })?.id ?? visible.first?.id
    }

    /// Volgende/vorige Space (rondgaand).
    static func neighbour(of active: UUID, in spaces: [BrowserSpace], offset: Int) -> UUID? {
        guard !spaces.isEmpty else { return nil }
        let index = spaces.firstIndex { $0.id == active } ?? 0
        let count = spaces.count
        return spaces[((index + offset) % count + count) % count].id
    }

    /// Space verwijderen: de laatste Space blijft altijd bestaan. Geeft de nieuwe lijst en de Space
    /// waar de tabs van de verwijderde Space naartoe gaan.
    static func removing(_ id: UUID, from spaces: [BrowserSpace]) -> (spaces: [BrowserSpace], fallback: UUID)? {
        guard spaces.count > 1, let index = spaces.firstIndex(where: { $0.id == id }) else { return nil }
        var rest = spaces
        rest.remove(at: index)
        return (rest, rest[max(0, index - 1)].id)
    }

    /// Space verplaatsen in de lijst (slepen / "Move left/right").
    static func moving(_ id: UUID, by offset: Int, in spaces: [BrowserSpace]) -> [BrowserSpace] {
        guard let index = spaces.firstIndex(where: { $0.id == id }) else { return spaces }
        let target = min(max(index + offset, 0), spaces.count - 1)
        guard target != index else { return spaces }
        var copy = spaces
        let space = copy.remove(at: index)
        copy.insert(space, at: target)
        return copy
    }

    /// Nieuwe Space met een kleur en icoon die nog niet gebruikt worden.
    static func makeSpace(named name: String, existing: [BrowserSpace]) -> BrowserSpace {
        let usedColors = Set(existing.map(\.color)), usedSymbols = Set(existing.map(\.symbol))
        let color = palette.first { !usedColors.contains($0) } ?? palette[existing.count % palette.count]
        let symbol = suggestedSymbols.first { !usedSymbols.contains($0) } ?? "circle.fill"
        return BrowserSpace(name: cleanName(name), symbol: symbol, color: color)
    }
}

enum SpaceStore {
    static let key = "browserSpacesV26"
    static let activeKey = "activeSpaceV26"
    /// Object = de werkruimte (het venster) die de lijst wijzigde; andere vensters laden hem opnieuw.
    static let didChange = Notification.Name("nl.tijn.JoeToep.spacesChanged")
    static func load(_ defaults: UserDefaults = .standard) -> [BrowserSpace] {
        guard let data = defaults.data(forKey: key),
              let spaces = try? JSONDecoder().decode([BrowserSpace].self, from: data) else { return [SpaceLogic.defaultSpace()] }
        return SpaceLogic.normalized(spaces)
    }
    static func save(_ spaces: [BrowserSpace], _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(SpaceLogic.normalized(spaces)) { defaults.set(data, forKey: key) }
    }
    static func loadActive(_ defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
    }
    static func saveActive(_ id: UUID, _ defaults: UserDefaults = .standard) { defaults.set(id.uuidString, forKey: activeKey) }
}
