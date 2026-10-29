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
    /// V22.2: laatst actief (s sinds 1970) — "nieuwste wint" tegen een grafsteen (heropende tab).
    var active: Double?

    init(id: UUID, url: URL?, title: String? = nil, pinned: Bool = false, time: Double? = nil, duration: Double? = nil,
         active: Double? = nil) {
        self.id = id; self.url = url.map(SyncTab.canonical); self.title = title; self.pinned = pinned; self.time = time
        self.duration = duration; self.active = active
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
    /// V22.2: recent gesloten tab-id's → sluitmoment (s sinds 1970), max. 7 dagen / 200 stuks.
    /// nil = oude app-versie (die kent geen grafstenen).
    var closed: [String: Double]?
    /// V22.2: klokwaarde (ms) waarop `playingID` op de afzender begon te spelen.
    var playStamp: UInt64?
    /// V22.2: uniek per overdracht (prepareDeviceSwitch); dubbel versturen telt als één overdracht.
    var handoffNonce: String?

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
    /// `elapsed`: seconden sinds `other` verstuurd werd. V22.2: voor de spelende tab wordt de vorige
    /// tijd doorgerekend — zo gaat er tijdens gewoon afspelen niet elke 5 s een volledige snapshot
    /// over de lijn (scheelt radio/energie op alle apparaten), wel bij spoelen en hooguit elke 60 s.
    func matches(_ other: SyncContent?, elapsed: Double = 0) -> Bool {
        guard let other, selectedID == other.selectedID, playingID == other.playingID, handoffID == other.handoffID,
              tabs.count == other.tabs.count else { return false }
        for (a, b) in zip(tabs, other.tabs) {
            guard a.id == b.id, a.url == b.url, a.pinned == b.pinned, a.title == b.title else { return false }
            // V22.2: de spelende tab pas vanaf 5 s (minder volledige snapshots; overdracht gebruikt
            // de exacte handoffTime / pauseAndReportTime en rekent de verstreken tijd zelf door), de rest vanaf 2 s.
            if a.id == playingID {
                if elapsed >= 60 { return false }
                if abs((a.time ?? 0) - ((b.time ?? 0) + max(0, elapsed))) >= 5 { return false }
            } else if abs((a.time ?? 0) - (b.time ?? 0)) >= 2 { return false }
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
        /// V22.2: "pauzeer hier en speel verder op `to`" (Watch › verplaats) — via continuePlayback(on:).
        case continueOn
        /// V22.2: "pauzeer wat hier speelt" (nooit starten — veiliger dan toggle bij verouderde info).
        case pause
    }
    var kind: Kind
    var target: String            // apparaat-id dat de opdracht moet uitvoeren
    var url: URL?
    var value: Double?
    /// V19.1: afzender (voor het antwoord op een overdracht). Oude berichten hebben hem niet.
    var from: String? = nil
    /// V22.2: bestemming bij `.continueOn` (oude berichten hebben hem niet).
    var to: String? = nil
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
                            closed: [String: Double]? = nil, playStamp: UInt64? = nil, handoffNonce: String? = nil,
                            force: Bool = false, now: Date = Date()) -> SyncSnapshot? {
        let content = SyncContent(tabs: tabs, selectedID: selectedID, playingID: playingID, handoffID: handoff?.id)
        if !force, content.matches(current?.content, elapsed: current.map { now.timeIntervalSince($0.sentAt) } ?? 0) { return nil }
        // Hybride klok: minstens "nu" in milliseconden, en altijd hoger dan alles wat we zagen.
        // Zo wint na een herstart de écht nieuwste wijziging, en blijft de volgorde kloppen.
        clock = max(clock + 1, UInt64(max(0, now.timeIntervalSince1970 * 1000)))
        let snapshot = SyncSnapshot(version: clock, origin: deviceID, originName: name, tabs: tabs,
                                    selectedID: selectedID, playingID: playingID, sentAt: now,
                                    handoffID: handoff?.id, handoffTime: handoff?.time,
                                    closed: closed, playStamp: playStamp, handoffNonce: handoff == nil ? nil : handoffNonce)
        current = snapshot
        return snapshot
    }

    /// V22.2: klokwaarde voor "nu begon hier iets te spelen" (altijd hoger dan alles wat we zagen).
    func stamp(now: Date = Date()) -> UInt64 { max(clock + 1, UInt64(max(0, now.timeIntervalSince1970 * 1000))) }

    /// Verwerkt een ontvangen snapshot. Geeft hem terug als hij toegepast moet worden.
    mutating func receive(_ snapshot: SyncSnapshot) -> SyncSnapshot? {
        clock = max(clock, snapshot.version)
        guard snapshot.origin != deviceID, snapshot.supersedes(current) else { return nil }
        current = snapshot
        return snapshot
    }
}

/// V22.2: pure sync-regels (grafstenen, afspeel-voorrang, overdrachtsleutel) — los testbaar.
enum SyncRules {
    /// Grafstenen voor in een snapshot: jonger dan `maxAge`, hooguit de `limit` nieuwste.
    static func recentTombstones(_ all: [String: Double], now: Date = Date(), maxAge: Double = 7 * 86_400,
                                 limit: Int = 200) -> [String: Double] {
        let cutoff = now.timeIntervalSince1970 - maxAge
        let fresh = all.filter { $0.value > cutoff }
        guard fresh.count > limit else { return fresh }
        return Dictionary(uniqueKeysWithValues: fresh.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) })
    }

    /// Mag deze tab van een ander apparaat hier NIET (terug)komen? Ja als hij hier of daar gesloten is
    /// en daarna niet meer actief was (heropend/gebruikt na de sluiting = nieuwer → wél toevoegen).
    static func blocks(_ tab: SyncTab, local: [String: Double], remote: [String: Double]?) -> Bool {
        let key = tab.id.uuidString
        guard let stone = [local[key], remote?[key]].compactMap({ $0 }).max() else { return false }
        return (tab.active ?? 0) <= stone
    }

    /// Moet een tab hier dicht omdat de afzender hem sloot? Alleen als hij hier daarna niet meer actief was.
    static func shouldClose(_ id: UUID, lastActive: Date, remote: [String: Double]?) -> Bool {
        guard let stone = remote?[id.uuidString] else { return false }
        return lastActive.timeIntervalSince1970 < stone
    }

    /// Wint het afspelen op het andere apparaat van wat hier speelt? Oude versies (zonder stempel): ja.
    static func remotePlayWins(remote: UInt64?, local: UInt64) -> Bool {
        guard let remote else { return true }
        return remote > local
    }

    /// Sleutel van één overdracht: origin:tab:nonce (oude versies zonder nonce: origin:tab).
    static func handoffKey(origin: String, tab: UUID, nonce: String?) -> String {
        nonce.map { "\(origin):\(tab):\($0)" } ?? "\(origin):\(tab)"
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
