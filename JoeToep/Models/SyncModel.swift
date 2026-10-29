import Foundation

// V18 — Het "wat" van de tab-synchronisatie, los van het netwerk (zodat het testbaar is).
//
// Idee: elk apparaat stuurt bij élke wijziging een complete momentopname (snapshot) van zijn
// tabs. Een snapshot heeft een versienummer (Lamport-klok: altijd hoger dan alles wat dit
// apparaat ooit zag). Het hoogste nummer wint; bij gelijk nummer beslist de apparaat-id.
// Zo komen alle apparaten altijd op precies dezelfde toestand uit, hoe berichten ook kruisen.

struct SyncTab: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var url: URL?
    var title: String?
    var pinned: Bool = false
    /// Afspeelpositie van de video in deze tab (seconden), als bekend.
    var time: Double?
    /// V22: lengte van de video (voor voortgang in widgets / Watch).
    var duration: Double?

    init(id: UUID, url: URL?, title: String? = nil, pinned: Bool = false, time: Double? = nil, duration: Double? = nil) {
        self.id = id; self.url = url.map(SyncTab.canonical); self.title = title; self.pinned = pinned; self.time = time
        self.duration = duration
    }

    /// Mac gebruikt www.youtube.com, iPhone m.youtube.com: in de sync altijd dezelfde vorm,
    /// anders zou elk apparaat de "andere" URL als wijziging zien.
    static func canonical(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if parts.host?.lowercased() == "m.youtube.com" || parts.host?.lowercased() == "youtube.com" { parts.host = "www.youtube.com" }
        if let items = parts.queryItems {
            let kept = items.filter { !["pp", "si", "app", "feature"].contains($0.name) }
            parts.queryItems = kept.isEmpty ? nil : kept
        }
        return parts.url ?? url
    }
}

struct SyncSnapshot: Codable, Equatable, Sendable {
    var version: UInt64
    var origin: String            // apparaat-id van de afzender
    var originName: String        // leesbare naam ("Tijn's MacBook")
    var tabs: [SyncTab]
    var selectedID: UUID
    /// Tab waarvan de video NU speelt op het apparaat `origin` (nil = niets speelt daar).
    var playingID: UUID?
    var sentAt: Date = Date()
    /// V22: deze tab speelde tot dit apparaat naar de achtergrond ging (iPhone pauzeert dan).
    /// Het volgende apparaat dat je pakt, speelt hem verder op precies `handoffTime`.
    var handoffID: UUID?
    var handoffTime: Double?

    /// Inhoud zonder versie/afzender/tijd: om te zien of er echt iets veranderde.
    var content: SyncContent { SyncContent(tabs: tabs, selectedID: selectedID, playingID: playingID, handoffID: handoffID) }

    /// true als `self` nieuwer is dan `other` (totale ordening → iedereen kiest hetzelfde).
    func supersedes(_ other: SyncSnapshot?) -> Bool {
        guard let other else { return true }
        if version != other.version { return version > other.version }
        return origin > other.origin
    }
}

struct SyncContent: Equatable, Sendable {
    var tabs: [SyncTab]
    var selectedID: UUID
    var playingID: UUID?
    var handoffID: UUID? = nil

    /// Gelijk genoeg om niets te versturen: afspeeltijden die < 2 s verschillen tellen niet
    /// (die lopen tijdens het afspelen vanzelf; elke seconde versturen is zinloos).
    func matches(_ other: SyncContent?) -> Bool {
        guard let other, selectedID == other.selectedID, playingID == other.playingID, handoffID == other.handoffID,
              tabs.count == other.tabs.count else { return false }
        for (a, b) in zip(tabs, other.tabs) {
            guard a.id == b.id, a.url == b.url, a.pinned == b.pinned, a.title == b.title else { return false }
            // V22: de spelende tab telt al vanaf 1 s verschil (live positie), de rest vanaf 2 s.
            let limit = a.id == playingID ? 1.0 : 2.0
            if abs((a.time ?? 0) - (b.time ?? 0)) >= limit { return false }
        }
        return true
    }
}

/// Opdrachten die niet in een snapshot passen (Apple Watch-afstandsbediening via de iPhone).
struct SyncCommand: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case play, toggle, seek, rate, open
        /// V19.1 overdracht: "ik ga deze video spelen — pauzeer jij, en vertel me je exacte tijd".
        case handoffRequest
        /// Antwoord: de exacte tijd (value) waarop de video bij de afzender stopte.
        case handoffTime
        /// V21: "speel dit verder bij jou" — url + exacte tijd (value); de afzender pauzeert.
        case continueThere
    }
    var kind: Kind
    var target: String            // apparaat-id dat de opdracht moet uitvoeren
    var url: URL?
    var value: Double?
    /// V19.1: afzender (voor het antwoord op een overdracht). Oude berichten hebben hem niet.
    var from: String? = nil
}

/// Wat er over de lijn gaat: één envelop, JSON.
enum SyncMessage: Codable, Equatable, Sendable {
    case snapshot(SyncSnapshot)
    case command(SyncCommand)
    case hello(deviceID: String, name: String)
    /// V18: lijst met downloads van dat apparaat (alleen de lijst, geen bestanden).
    case downloads(DownloadListing)
    /// Bevestiging: "ik zit op versie X met N tabs" (voor de ✓ in Instellingen).
    case ack(deviceID: String, name: String, version: UInt64, tabs: Int)
    /// V20: wat er in Spotify speelt op het apparaat van de afzender.
    case spotify(deviceID: String, state: SpotifyState)
    /// V20: bedien Spotify op apparaat `target` (actie + optionele waarde / Spotify-URI).
    case spotifyCommand(target: String, action: SpotifyAction, value: Double?, uri: String?)

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decode(_ data: Data) -> SyncMessage? { try? JSONDecoder().decode(SyncMessage.self, from: data) }
}

/// Lamport-klok + "laatste wint"-beslissing. Puur: geen netwerk, geen UI.
struct SyncLedger: Sendable {
    let deviceID: String
    private(set) var clock: UInt64 = 0
    private(set) var current: SyncSnapshot?

    init(deviceID: String) { self.deviceID = deviceID }

    /// Maakt een nieuwe lokale snapshot, of nil als de inhoud gelijk is aan wat al gedeeld is.
    mutating func makeLocal(name: String, tabs: [SyncTab], selectedID: UUID, playingID: UUID?, handoff: (id: UUID, time: Double)? = nil,
                            force: Bool = false, now: Date = Date()) -> SyncSnapshot? {
        let content = SyncContent(tabs: tabs, selectedID: selectedID, playingID: playingID, handoffID: handoff?.id)
        if !force, content.matches(current?.content) { return nil }
        // Hybride klok: minstens "nu" in milliseconden, en altijd hoger dan alles wat we zagen.
        // Zo wint na een herstart de écht nieuwste wijziging, en blijft de volgorde kloppen.
        clock = max(clock + 1, UInt64(max(0, now.timeIntervalSince1970 * 1000)))
        let snapshot = SyncSnapshot(version: clock, origin: deviceID, originName: name, tabs: tabs,
                                    selectedID: selectedID, playingID: playingID, sentAt: now,
                                    handoffID: handoff?.id, handoffTime: handoff?.time)
        current = snapshot
        return snapshot
    }

    /// Verwerkt een ontvangen snapshot. Geeft hem terug als hij toegepast moet worden.
    mutating func receive(_ snapshot: SyncSnapshot) -> SyncSnapshot? {
        clock = max(clock, snapshot.version)
        guard snapshot.origin != deviceID, snapshot.supersedes(current) else { return nil }
        current = snapshot
        return snapshot
    }
}

/// Plan om een lokale tab-lijst gelijk te trekken met een ontvangen snapshot.
struct SyncDiff: Equatable {
    var remove: [UUID]
    var add: [SyncTab]
    var navigate: [(id: UUID, url: URL)]
    var order: [UUID]

    static func == (a: SyncDiff, b: SyncDiff) -> Bool {
        a.remove == b.remove && a.add == b.add && a.order == b.order &&
            a.navigate.map(\.id) == b.navigate.map(\.id) && a.navigate.map(\.url) == b.navigate.map(\.url)
    }

    /// `local`: huidige tabs (id + url). Private tabs worden nooit gesynchroniseerd en blijven staan.
    static func plan(local: [(id: UUID, url: URL?)], remote: [SyncTab]) -> SyncDiff {
        let remoteIDs = Set(remote.map(\.id))
        let localByID = Dictionary(local.map { ($0.id, $0.url) }, uniquingKeysWith: { a, _ in a })
        let remove = local.map(\.id).filter { !remoteIDs.contains($0) }
        let add = remote.filter { localByID[$0.id] == nil }
        var navigate: [(UUID, URL)] = []
        for tab in remote {
            guard let existing = localByID[tab.id], let url = tab.url else { continue }
            if !SyncDiff.sameDestination(existing, url) { navigate.append((tab.id, url)) }
        }
        return SyncDiff(remove: remove, add: add, navigate: navigate, order: remote.map(\.id))
    }

    /// Zelfde pagina? Voor video's telt alleen de video-id (tijd-parameters negeren we).
    static func sameDestination(_ a: URL?, _ b: URL?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        func key(_ u: URL) -> String {
            let parts = URLComponents(url: u, resolvingAgainstBaseURL: false)
            if let v = parts?.queryItems?.first(where: { $0.name == "v" })?.value { return "v:" + v }
            let host = (u.host ?? "").replacingOccurrences(of: "m.youtube.com", with: "www.youtube.com")
            var path = u.path; if path.hasSuffix("/") && path.count > 1 { path.removeLast() }
            return host + path + "?" + (parts?.queryItems?.filter { !["t", "pp", "si", "app"].contains($0.name) }
                .map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&") ?? "")
        }
        return key(a) == key(b)
    }
}
