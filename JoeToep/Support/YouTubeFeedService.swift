import Foundation
import WebKit

/// V18 — Haalt de home-feed en zoekresultaten op met de YouTube-cookies van JoeToep
/// (dus jouw eigen, ingelogde aanbevelingen) — voor de Apple Watch.
@MainActor
enum YouTubeFeedService {
    private static var cache: [String: (date: Date, videos: [FeedVideo])] = [:]

    static func home() async -> [FeedVideo] {
        await load(URL(string: "https://www.youtube.com/")!, cacheKey: "home", maxAge: 120)
    }

    static func search(_ query: String) async -> [FeedVideo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var parts = URLComponents(string: "https://www.youtube.com/results")!
        // sp=EgIQAQ%3D%3D = alleen video's (geen kanalen/playlists).
        parts.queryItems = [URLQueryItem(name: "search_query", value: trimmed), URLQueryItem(name: "sp", value: "EgIQAQ==")]
        return await load(parts.url!, cacheKey: "q:" + trimmed.lowercased(), maxAge: 300)
    }

    private static func load(_ url: URL, cacheKey: String, maxAge: TimeInterval) async -> [FeedVideo] {
        if let hit = cache[cacheKey], Date().timeIntervalSince(hit.date) < maxAge, !hit.videos.isEmpty { return hit.videos }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.joeToepCookies()
            .filter { $0.domain.hasSuffix("youtube.com") || $0.domain.hasSuffix("google.com") }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9,nl;q=0.8", forHTTPHeaderField: "Accept-Language")
        HTTPCookie.requestHeaderFields(with: cookies).forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpShouldHandleCookies = false
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { return cache[cacheKey]?.videos ?? [] }
        // Parsen buiten de hoofdthread (de pagina is ±1 MB).
        let videos = await Task.detached(priority: .userInitiated) { YouTubeFeedParser.videos(fromHTML: html) }.value
        if !videos.isEmpty { cache[cacheKey] = (Date(), videos) }
        return videos
    }
}

private extension WKHTTPCookieStore {
    func joeToepCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in getAllCookies { continuation.resume(returning: $0) } }
    }
}
