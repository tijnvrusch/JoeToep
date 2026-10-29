import Foundation
import CryptoKit

/// V15: SponsorBlock client. Uses the privacy-preserving hash-prefix API: only the first four
/// hex characters of SHA-256(videoID) leave the device; matching happens locally.
@MainActor
final class SponsorBlockService {
    static let shared = SponsorBlockService()
    struct Segment: Equatable, Sendable {
        var start: Double; var end: Double; var category: String; var action: String; var uuid: String
        var dictionary: [String: Any] { ["start": start, "end": end, "category": category, "action": action, "uuid": uuid] }
    }
    private var cache: [String: (date: Date, segments: [Segment])] = [:]
    private var inFlight: [String: Task<[Segment], Never>] = [:]
    private(set) var lastStatus = "Idle"

    static let statsSkippedKey = "sponsorBlockSkippedV15"
    static let statsSavedKey = "sponsorBlockSavedSecondsV15"
    static func recordSkip(seconds: Double) {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: statsSkippedKey) + 1, forKey: statsSkippedKey)
        defaults.set(defaults.double(forKey: statsSavedKey) + max(0, seconds), forKey: statsSavedKey)
    }

    static func videoID(from url: URL?) -> String? {
        guard let url, NavigationPolicy.isYouTubeHost((url.host ?? "").lowercased()) else { return nil }
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if url.path == "/watch", let id = parts?.queryItems?.first(where: { $0.name == "v" })?.value, Self.isValid(id) { return id }
        for prefix in ["/shorts/", "/live/", "/embed/"] where url.path.hasPrefix(prefix) {
            let id = String(url.path.dropFirst(prefix.count)).split(separator: "/").first.map(String.init) ?? ""
            if Self.isValid(id) { return id }
        }
        if (url.host ?? "").lowercased() == "youtu.be" {
            let id = String(url.path.dropFirst())
            if Self.isValid(id) { return id }
        }
        return nil
    }
    static func isValid(_ id: String) -> Bool {
        id.count >= 10 && id.count <= 16 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    func segments(for videoID: String, settings: SponsorBlockSettings) async -> [Segment] {
        let categories = settings.activeCategories.map(\.rawValue).sorted()
        let key = videoID + "|" + categories.joined(separator: ",")
        if let hit = cache[key], Date().timeIntervalSince(hit.date) < 1800 { return hit.segments }
        if let task = inFlight[key] { return await task.value }
        guard !categories.isEmpty else { return [] }
        let server = settings.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = Task<[Segment], Never> { @MainActor in
            let result = await Self.fetch(videoID: videoID, categories: categories, server: server)
            self.lastStatus = result.status
            return result.segments
        }
        inFlight[key] = task
        let value = await task.value
        inFlight[key] = nil
        cache[key] = (Date(), value)
        if cache.count > 200 { cache.removeAll() }
        return value
    }

    nonisolated private static func fetch(videoID: String, categories: [String], server: String) async -> (segments: [Segment], status: String) {
        let digest = SHA256.hash(data: Data(videoID.utf8)).map { String(format: "%02x", $0) }.joined()
        let prefix = String(digest.prefix(4))
        guard var parts = URLComponents(string: (server.isEmpty ? "https://sponsor.ajay.app" : server) + "/api/skipSegments/" + prefix) else {
            return ([], "Invalid server URL")
        }
        let categoriesJSON = "[" + categories.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        parts.queryItems = [URLQueryItem(name: "categories", value: categoriesJSON),
                            URLQueryItem(name: "actionTypes", value: "[\"skip\",\"mute\"]")]
        guard let url = parts.url else { return ([], "Invalid request") }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("JoeToep/15 (personal SponsorBlock client)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 { return ([], "No segments for this video") }
            guard code == 200, let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return ([], "Server returned \(code)")
            }
            let entry = list.first { ($0["videoID"] as? String) == videoID }
            let raw = (entry?["segments"] as? [[String: Any]]) ?? []
            let segments: [Segment] = raw.compactMap { item in
                guard let range = item["segment"] as? [Double], range.count == 2, range[1] > range[0],
                      let category = item["category"] as? String else { return nil }
                return Segment(start: range[0], end: range[1], category: category,
                               action: (item["actionType"] as? String) ?? "skip", uuid: (item["UUID"] as? String) ?? UUID().uuidString)
            }.sorted { $0.start < $1.start }
            return (segments, segments.isEmpty ? "No segments for this video" : "\(segments.count) segment(s)")
        } catch {
            return ([], "Offline: " + error.localizedDescription)
        }
    }
}
