// V22 — Gedeeld tussen iPhone-app, Watch-app en Watch-complicaties. Dit bestand staat DRIE keer in
// het project (JoeToep/Support, JoeToepWatch, JoeToepWatchWidgets) — altijd gelijk houden;
// Scripts/validate_project.py controleert dat.
//
// De iPhone stuurt bij elke wijziging (wat speelt waar, positie, Spotify) een compacte toestand
// naar de Watch (WatchConnectivity application context). De Watch-app bewaart die in zijn App
// Group, zodat de complicaties en de Smart Stack-widgets hetzelfde laten zien.
import Foundation

struct WatchDeviceState: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: String                 // "mac", "iphone", "ipad"
    var isPhone: Bool                // de iPhone waarmee de Watch gekoppeld is
    var connected: Bool
    var title: String?
    var url: String?
    var playing = false
    var time: Double?
    var duration: Double?
    var rate: Double?
    var updated: Date = Date()

    var symbol: String { kind == "mac" ? "laptopcomputer" : (kind == "ipad" ? "ipad" : "iphone") }
    func livePosition(at now: Date = Date()) -> Double? {
        guard let time else { return nil }
        guard playing else { return time }
        let t = time + now.timeIntervalSince(updated) * (rate ?? 1)
        if let duration, duration > 0 { return min(t, duration) }
        return t
    }
    var videoID: String? {
        guard let url, let c = URLComponents(string: url) else { return nil }
        if let v = c.queryItems?.first(where: { $0.name == "v" })?.value { return v }
        if c.host?.contains("youtu.be") == true { return c.path.split(separator: "/").first.map(String.init) }
        return nil
    }
    var thumbnail: URL? { videoID.flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/mqdefault.jpg") } }
}

struct WatchSpotifyState: Codable, Equatable, Hashable {
    var device: String
    var playing: Bool
    var track: String
    var artist: String
    var artwork: String?
    var position: Double
    var duration: Double
    var volume: Double
    var shuffling: Bool
    var repeating: Bool
    var updated: Date

    func livePosition(at now: Date = Date()) -> Double {
        guard playing else { return position }
        return min(duration > 0 ? duration : .infinity, position + now.timeIntervalSince(updated))
    }
}

struct WatchState: Codable, Equatable {
    var devices: [WatchDeviceState] = []
    var spotify: WatchSpotifyState?
    var phoneID = ""
    var updated = Date()

    /// Wat nu speelt (of het laatst speelde).
    var nowPlaying: WatchDeviceState? {
        devices.first { $0.playing } ?? devices.filter { $0.title != nil }.max { $0.updated < $1.updated }
    }

    static let contextKey = "stateV22"
    static let appGroup = "group.nl.tijn.JoeToep"
    static let file = "watch-state.json"

    func encoded() -> Data? {
        let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970
        return try? e.encode(self)
    }
    static func decode(_ data: Data) -> WatchState? {
        let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970
        return try? d.decode(WatchState.self, from: data)
    }
    /// Watch: in de App Group bewaren (voor de complicaties).
    func saveToGroup() {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appendingPathComponent(Self.file), let data = encoded() else { return }
        try? data.write(to: url, options: .atomic)
    }
    static func loadFromGroup() -> WatchState? {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(file), let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }
}

/// Deep links naar de Watch-app (vanuit complicaties).
enum WatchLink {
    static func url(_ page: String, device: String? = nil) -> URL {
        var c = URLComponents(); c.scheme = "joetoepwatch"; c.host = page
        if let device { c.queryItems = [URLQueryItem(name: "device", value: device)] }
        return c.url ?? URL(string: "joetoepwatch://\(page)")!
    }
}

func watchClock(_ t: Double?) -> String {
    guard let t, t.isFinite else { return "" }
    let s = Int(max(0, t))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}
