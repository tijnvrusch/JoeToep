// V21 — Gedeeld tussen de app en de widgets (dit bestand staat twee keer in het project:
// JoeToep/Support/WidgetShared.swift en JoeToepWidgets/WidgetShared.swift — altijd gelijk houden;
// Scripts/validate_project.py controleert dat).
//
// De app schrijft een klein JSON-bestand in de gedeelde App Group-map (wat er speelt op elk
// apparaat, Spotify, favorieten, geschiedenis, tabs). De widgets lezen dat en tonen het.
// Knoppen in een widget zetten een opdracht in de gedeelde map en seinen de app met een
// systeemnotificatie; de app voert hem uit (ook voor je andere apparaten, via sync).
import Foundation
#if os(iOS) && canImport(ActivityKit)
import ActivityKit
#endif

enum WidgetShared {
    #if os(macOS)
    static let appGroup = "37WRZNSADT.nl.tijn.JoeToep.shared"
    #else
    static let appGroup = "group.nl.tijn.JoeToep"
    #endif
    static let snapshotFile = "widget-snapshot.json"
    static let commandsKey = "widgetCommandsV21"
    /// Darwin-notificatie: "er staat een widget-opdracht klaar".
    static let commandNotification = "nl.tijn.JoeToep.widgetCommand"
    static let urlScheme = "joetoep"

    static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) }
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot? {
        guard let url = container?.appendingPathComponent(snapshotFile),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = container?.appendingPathComponent(snapshotFile) else { return false }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    // MARK: Opdrachten van widgets naar de app

    static func enqueue(_ command: WidgetCommand) {
        guard let d = defaults else { return }
        var list = (d.data(forKey: commandsKey)).flatMap { try? JSONDecoder().decode([WidgetCommand].self, from: $0) } ?? []
        list.append(command)
        list = Array(list.suffix(20))
        if let data = try? JSONEncoder().encode(list) { d.set(data, forKey: commandsKey) }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(commandNotification as CFString), nil, nil, true)
    }
    static func drain() -> [WidgetCommand] {
        guard let d = defaults, let data = d.data(forKey: commandsKey),
              let list = try? JSONDecoder().decode([WidgetCommand].self, from: data) else { return [] }
        d.removeObject(forKey: commandsKey)
        // Oude opdrachten (> 2 min) negeren: die zijn niet meer bedoeld.
        return list.filter { Date().timeIntervalSince($0.created) < 120 }
    }

    // MARK: Deep links

    static func openURL(_ url: URL) -> URL { link("open", ["url": url.absoluteString]) }
    static func searchURL(platform: String? = nil) -> URL { link("search", platform.map { ["p": $0] } ?? [:]) }
    static func link(_ host: String, _ query: [String: String] = [:]) -> URL {
        var c = URLComponents(); c.scheme = urlScheme; c.host = host
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url ?? URL(string: "\(urlScheme)://\(host)")!
    }

    /// YouTube-miniatuur bij een video-URL (voor widgets zonder eigen hoesafbeelding).
    static func thumbnail(for url: URL?) -> URL? {
        guard let url, let host = url.host?.lowercased() else { return nil }
        var id: String?
        if host.contains("youtu.be") { id = url.pathComponents.dropFirst().first }
        else if host.contains("youtube") {
            id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
            if id == nil, url.pathComponents.count >= 3, ["shorts", "live", "embed"].contains(url.pathComponents[1]) { id = url.pathComponents[2] }
        }
        guard let id, !id.isEmpty else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
    }
}

/// Wat een widget laat zien.
struct WidgetSnapshot: Codable, Equatable {
    var updated = Date()
    var thisDeviceID = ""
    var thisDeviceName = ""
    var devices: [WidgetDevice] = []
    var spotify: WidgetSpotify?
    var favourites: [WidgetLink] = []
    var history: [WidgetLink] = []
    var continueWatching: [WidgetLink] = []
    var connectedPeers: [String] = []

    /// Wat er nu (of het laatst) speelt, met voorrang voor wat echt speelt.
    var nowPlaying: WidgetDevice? {
        devices.first { $0.playing } ?? devices.filter { $0.title != nil }.max { ($0.updated ?? .distantPast) < ($1.updated ?? .distantPast) }
    }
}

struct WidgetDevice: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var kind: String             // "mac", "iphone", "ipad"
    var isThisDevice: Bool
    var title: String?
    var url: URL?
    var playing = false
    var time: Double?
    var duration: Double?
    var updated: Date?
    var tabCount = 0
    var tabs: [WidgetLink] = []

    var symbol: String {
        switch kind {
        case "mac": "laptopcomputer"
        case "ipad": "ipad"
        default: "iphone"
        }
    }
    /// Geschatte positie nu (de video liep door sinds `updated`).
    func livePosition(at now: Date = Date()) -> Double? {
        guard let time else { return nil }
        guard playing, let updated else { return time }
        let t = time + now.timeIntervalSince(updated)
        if let duration, duration > 0 { return min(t, duration) }
        return t
    }
}

struct WidgetSpotify: Codable, Equatable {
    var deviceID: String
    var deviceName: String
    var playing: Bool
    var track: String
    var artist: String
    var artworkURL: URL?
    var position: Double
    var duration: Double
    var updated: Date
    var album: String? = nil
    var volume: Double? = nil
    var shuffling: Bool? = nil
    var repeating: Bool? = nil

    func livePosition(at now: Date = Date()) -> Double {
        guard playing else { return position }
        return min(duration > 0 ? duration : .infinity, position + now.timeIntervalSince(updated))
    }
}

struct WidgetLink: Codable, Equatable, Identifiable {
    var id: String { url.absoluteString }
    var title: String
    var url: URL
}

struct WidgetCommand: Codable, Equatable {
    enum Action: String, Codable { case playPause, play, pause, skipForward, skipBack, spotifyPlayPause, spotifyNext, spotifyPrevious, open, takeOver,
        // V22
        continueOn, spotifyVolumeUp, spotifyVolumeDown, skipForward30, skipBack30, pauseAll }
    var action: Action
    var deviceID: String?        // nil = dit apparaat
    var url: URL?
    var created = Date()
}

// MARK: - V22 Live Activity (iPhone/iPad: vergrendelscherm, Dynamic Island, Apple Watch Smart Stack)
#if os(iOS) && canImport(ActivityKit)
struct NowPlayingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var deviceName: String
        var deviceKind: String            // "mac", "iphone", "ipad"
        var deviceID: String
        var isThisDevice: Bool
        var playing: Bool
        var time: Double                  // positie op moment `updated`
        var duration: Double              // 0 = onbekend
        var updated: Date
        var thumbnail: URL?
        var spotifyTrack: String?
        var spotifyArtist: String?
        var spotifyPlaying: Bool?

        var symbol: String { deviceKind == "mac" ? "laptopcomputer" : (deviceKind == "ipad" ? "ipad" : "iphone") }
        /// Begin/eind van de video in klok-tijd → voortgang loopt vanzelf door zonder updates.
        var interval: ClosedRange<Date>? {
            guard playing, duration > 0, time < duration else { return nil }
            let start = updated.addingTimeInterval(-time)
            return start...start.addingTimeInterval(duration)
        }
    }
}
#endif
