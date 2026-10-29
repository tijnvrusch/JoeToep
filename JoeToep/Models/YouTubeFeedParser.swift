import Foundation

/// V18 — Haalt video's uit een YouTube-pagina (home-feed of zoekresultaten) voor de Apple Watch.
///
/// YouTube stopt alle gegevens van een pagina in een groot JSON-object `ytInitialData`.
/// We zoeken daarin recursief naar video-blokken. YouTube gebruikt (afhankelijk van versie en
/// A/B-test) twee vormen, we ondersteunen beide:
///  • `videoRenderer` / `compactVideoRenderer` / `gridVideoRenderer` (klassiek)
///  • `lockupViewModel` met `contentType == LOCKUP_CONTENT_TYPE_VIDEO` (nieuw, 2024+)
struct FeedVideo: Codable, Equatable, Identifiable, Sendable {
    var id: String            // YouTube video-id (11 tekens)
    var title: String
    var channel: String
    var duration: String?     // "12:34", nil bij livestreams

    var url: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
    /// Klein plaatje (120×90, ±4 kB): snel genoeg voor de Watch.
    var thumbnail: URL { URL(string: "https://i.ytimg.com/vi/\(id)/default.jpg")! }

    /// Compacte vorm voor WatchConnectivity (alleen property-list-typen toegestaan).
    var plist: [String: String] {
        var d = ["id": id, "t": title, "c": channel]
        if let duration { d["d"] = duration }
        return d
    }
    init(id: String, title: String, channel: String, duration: String? = nil) {
        self.id = id; self.title = title; self.channel = channel; self.duration = duration
    }
    init?(plist: [String: String]) {
        guard let id = plist["id"], let title = plist["t"] else { return nil }
        self.init(id: id, title: title, channel: plist["c"] ?? "", duration: plist["d"])
    }
}

enum YouTubeFeedParser {
    /// Maximaal aantal video's voor de Watch (meer is traag op het kleine scherm en in de overdracht).
    static let limit = 30

    static func videos(fromHTML html: String, limit: Int = limit) -> [FeedVideo] {
        guard let json = initialData(in: html) else { return [] }
        return videos(fromJSON: json, limit: limit)
    }

    static func videos(fromJSON root: Any, limit: Int = limit) -> [FeedVideo] {
        var result: [FeedVideo] = []
        var seen = Set<String>()
        walk(root, depth: 0) { video in
            guard result.count < limit, seen.insert(video.id).inserted else { return result.count >= limit }
            result.append(video)
            return result.count >= limit
        }
        return result
    }

    /// Zoekt `ytInitialData = {...};` en parseert het JSON-object (haakjes tellen, met strings).
    static func initialData(in html: String) -> Any? {
        let markers = ["var ytInitialData = ", "window[\"ytInitialData\"] = ", "ytInitialData = "]
        guard let marker = markers.lazy.compactMap({ html.range(of: $0) }).first else { return nil }
        let bytes = Array(html.utf8[marker.upperBound...])
        guard bytes.first == 0x7B /* open brace */ else { return nil }
        var depth = 0, inString = false, escaped = false, end = -1
        for (i, b) in bytes.enumerated() {
            if inString {
                if escaped { escaped = false } else if b == UInt8(ascii: "\\") { escaped = true } else if b == UInt8(ascii: "\"") { inString = false }
                continue
            }
            if b == UInt8(ascii: "\"") { inString = true }
            else if b == 0x7B /* open brace */ { depth += 1 }
            else if b == 0x7D /* close brace */ { depth -= 1; if depth == 0 { end = i; break } }
        }
        guard end > 0 else { return nil }
        return try? JSONSerialization.jsonObject(with: Data(bytes[0...end]))
    }

    /// Diepte-eerst door het JSON; `found` geeft true terug om te stoppen.
    @discardableResult
    private static func walk(_ node: Any, depth: Int, _ found: (FeedVideo) -> Bool) -> Bool {
        guard depth < 60 else { return false }
        if let dict = node as? [String: Any] {
            // Shorts en advertenties overslaan (ze horen niet in een simpele Watch-lijst).
            if dict["reelShelfRenderer"] != nil || dict["adSlotRenderer"] != nil || dict["shortsLockupViewModel"] != nil { return false }
            for key in ["videoRenderer", "compactVideoRenderer", "gridVideoRenderer"] {
                if let r = dict[key] as? [String: Any], let v = classic(r) { if found(v) { return true } }
            }
            if let l = dict["lockupViewModel"] as? [String: Any], let v = lockup(l) { if found(v) { return true } }
            for (key, value) in dict where !["videoRenderer", "compactVideoRenderer", "gridVideoRenderer", "lockupViewModel"].contains(key) {
                if walk(value, depth: depth + 1, found) { return true }
            }
        } else if let array = node as? [Any] {
            for value in array { if walk(value, depth: depth + 1, found) { return true } }
        }
        return false
    }

    private static func text(_ node: Any?) -> String? {
        guard let dict = node as? [String: Any] else { return node as? String }
        if let simple = dict["simpleText"] as? String { return simple }
        if let content = dict["content"] as? String { return content }
        if let runs = dict["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func validID(_ id: String?) -> String? {
        guard let id, id.count == 11, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        return id
    }

    private static func classic(_ r: [String: Any]) -> FeedVideo? {
        guard let id = validID(r["videoId"] as? String), let title = text(r["title"]) ?? text(r["headline"]) else { return nil }
        let channel = text(r["ownerText"]) ?? text(r["longBylineText"]) ?? text(r["shortBylineText"]) ?? ""
        return FeedVideo(id: id, title: title, channel: channel, duration: text(r["lengthText"]))
    }

    private static func lockup(_ l: [String: Any]) -> FeedVideo? {
        if let type = l["contentType"] as? String, type != "LOCKUP_CONTENT_TYPE_VIDEO" { return nil }
        guard let id = validID(l["contentId"] as? String),
              let meta = (l["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any],
              let title = text(meta["title"]) else { return nil }
        // Kanaalnaam: eerste tekst in de eerste metadata-rij.
        var channel = ""
        if let rows = (((meta["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any])?["metadataRows"] as? [[String: Any]]),
           let parts = rows.first?["metadataParts"] as? [[String: Any]], let first = parts.first {
            channel = text(first["text"]) ?? ""
        }
        // Duur: badge op het plaatje ("12:34").
        var duration: String?
        if let overlays = (((l["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any])?["overlays"] as? [[String: Any]]) {
            for overlay in overlays {
                let badges = ((overlay["thumbnailOverlayBadgeViewModel"] as? [String: Any])?["thumbnailBadges"] as? [[String: Any]]) ?? []
                if let t = badges.compactMap({ ($0["thumbnailBadgeViewModel"] as? [String: Any])?["text"] as? String }).first { duration = t; break }
            }
        }
        return FeedVideo(id: id, title: title, channel: channel, duration: duration)
    }
}
