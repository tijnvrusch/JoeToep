import Foundation

struct SavedBrowserTab: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var url: URL?
    /// V11: playback position to continue after relaunch (optional: V10 data stays readable).
    var time: Double? = nil
    var playing: Bool? = nil
    /// V13: last time the tab was opened or played (inactive tabs expire).
    var lastActive: Date? = nil
    /// V15: pinned tabs never expire; the title shows before the tab loads.
    var pinned: Bool? = nil
    var title: String? = nil
    /// V21: tabgroep (zijbalk/tabbalk), optioneel zodat oudere data leesbaar blijft.
    var groupID: UUID? = nil
}
struct SavedTabSession: Codable, Equatable {
    var tabs: [SavedBrowserTab]
    var selectedID: UUID
}

/// One atomic snapshot across open windows. After relaunch all saved tabs appear
/// in the first window, including tabs whose web views have not loaded yet.
@MainActor
final class TabSessionStore {
    static let shared = TabSessionStore(defaults: .standard)
    private let defaults: UserDefaults
    private let key = "browserTabsV10"
    private var claimed = false
    private var windows: [UUID: SavedTabSession] = [:]
    private var windowOrder: [UUID] = []
    init(defaults: UserDefaults) { self.defaults = defaults }
    static func restorable(_ url: URL?) -> URL? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(), !host.isEmpty, url.user == nil, url.password == nil,
              // Sign-in pages carry one-time tokens; never reopen them.
              !["accounts.google.com", "accounts.youtube.com"].contains(host) else { return nil }
        return url
    }
    func restore(lifetime: TimeInterval? = nil, now: Date = Date()) -> SavedTabSession? {
        guard !claimed else { return nil }
        claimed = true
        guard let data = defaults.data(forKey: key),
              var saved = try? JSONDecoder().decode(SavedTabSession.self, from: data), !saved.tabs.isEmpty else { return nil }
        var seen = Set<UUID>()
        saved.tabs = saved.tabs.filter { seen.insert($0.id).inserted }.map {
            SavedBrowserTab(id: $0.id, url: Self.restorable($0.url), time: $0.time, playing: $0.playing, lastActive: $0.lastActive,
                            pinned: $0.pinned, title: $0.title)
        }
        if let lifetime {
            let selected = saved.selectedID
            saved.tabs = saved.tabs.filter { $0.id == selected || $0.pinned == true || now.timeIntervalSince($0.lastActive ?? now) <= lifetime }
            if saved.tabs.isEmpty { return nil }
        }
        if !saved.tabs.contains(where: { $0.id == saved.selectedID }) { saved.selectedID = saved.tabs[0].id }
        return saved
    }
    func save(_ session: SavedTabSession, window: UUID) {
        if windows[window] == nil { windowOrder.append(window) }
        windows[window] = session
        let all = windowOrder.flatMap { windows[$0]?.tabs ?? [] }.map {
            SavedBrowserTab(id: $0.id, url: Self.restorable($0.url), time: $0.time, playing: $0.playing, lastActive: $0.lastActive,
                            pinned: $0.pinned, title: $0.title)
        }
        // V22.3: de selectie van het EERSTE (hoofd)venster bewaren, niet van het venster dat toevallig als
        // laatste opsloeg (een extra venster zette anders na een herstart zijn eigen "Home"-tab voorop).
        let selection = windowOrder.first.flatMap { windows[$0]?.selectedID } ?? session.selectedID
        guard !all.isEmpty, let data = try? JSONEncoder().encode(SavedTabSession(tabs: all, selectedID: selection)) else { return }
        defaults.set(data, forKey: key)
    }
    /// V22.3: een (extra) venster is gesloten → zijn tabs niet meer bewaren (ze kwamen anders bij elke
    /// herstart terug als stapel "Home"-tabs). Het laatste venster wordt nooit vergeten: sluit je dat,
    /// dan blijven je tabs gewoon voor de volgende start bewaard.
    func forget(window: UUID) {
        guard windows[window] != nil, windows.count > 1 else { return }
        windows[window] = nil; windowOrder.removeAll { $0 == window }
        guard let first = windowOrder.first, let main = windows[first] else { return }
        save(main, window: first)
    }
    /// V22.3: alle vensters dicht (app blijft open op de Mac): bewaarde tabs blijven staan, en een nieuw
    /// venster mag ze weer ophalen (anders begon dat met één lege tab — en deelde dat via de sync).
    func releaseWindows() { windows = [:]; windowOrder = []; claimed = false }
    func clear() { defaults.removeObject(forKey: key); claimed = false; windows = [:]; windowOrder = [] }
}
