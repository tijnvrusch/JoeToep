import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// V15: short, glanceable tab titles.
/// 1. Apple Intelligence (on-device Foundation Models) when the device supports it.
/// 2. Otherwise a deterministic shortener that strips channel names, brackets, emoji,
///    hashtags and filler words and keeps the most meaningful words.
/// When summaries are off the tab shows the full video title (never just "YouTube").
@MainActor
enum TabTitleSummarizer {
    struct Config: Equatable { var enabled = true; var maxWords = 4; var useAI = true }
    private(set) static var config = Config()
    private static var cache: [String: String] = [:]
    private static var pending: Set<String> = []
    static let didChange = Notification.Name("nl.tijn.JoeToep.tabSummaryChanged")

    static func configure(from settings: AppSettings) {
        let next = Config(enabled: settings.aiTabSummary, maxWords: settings.tabSummaryLength.maxWords,
                          useAI: settings.useAppleIntelligence)
        guard next != config else { return }
        config = next
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Clean full title of a page (no " - YouTube" suffix or notification counter).
    static func cleanPageTitle(_ raw: String?, url: URL?) -> String {
        var title = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = title.range(of: #"^\(\d+\+?\)\s*"#, options: .regularExpression) { title.removeSubrange(range) }
        for suffix in [" - YouTube Music", " - YouTube", " – YouTube", " | YouTube"] where title.hasSuffix(suffix) {
            title = String(title.dropLast(suffix.count))
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || title == "YouTube" || title == "youtube.com" { return fallbackTitle(for: url) }
        return title
    }

    /// Title for pages without a useful document title.
    static func fallbackTitle(for url: URL?) -> String {
        guard let url else { return "New tab" }
        let host = (url.host ?? "").lowercased()
        if NavigationPolicy.isYouTubeHost(host) {
            let path = url.path.lowercased()
            if path == "/" || path.isEmpty { return "Home" }
            if path.hasPrefix("/feed/subscriptions") { return "Subscriptions" }
            if path.hasPrefix("/feed/history") { return "History" }
            if path.hasPrefix("/feed/you") || path.hasPrefix("/feed/library") { return "Library" }
            if path.hasPrefix("/playlist") { return "Playlist" }
            if path.hasPrefix("/results"),
               let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "search_query" })?.value {
                return "Search: " + query
            }
            if path.hasPrefix("/shorts") { return "Shorts" }
            if path.hasPrefix("/watch") { return "Video" }
            if path.hasPrefix("/@") { return String(url.path.dropFirst()) }
            return "YouTube page"
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : (host.isEmpty ? "Page" : host)
    }

    /// Title shown in the tab right now (synchronously), plus an optional async upgrade.
    static func displayTitle(pageTitle: String?, url: URL?, update: @escaping @MainActor (String) -> Void) -> String {
        let clean = cleanPageTitle(pageTitle, url: url)
        guard config.enabled, NavigationPolicy.isPlaybackPage(url), clean != "Video" else { return clean }
        let key = "\(config.maxWords)|\(config.useAI)|" + clean
        if let cached = cache[key] { return cached }
        let quick = heuristicSummary(clean, maxWords: config.maxWords)
        if config.useAI && !pending.contains(key) {
            pending.insert(key)
            Task { @MainActor in
                defer { pending.remove(key) }
                if let smart = await appleSummary(clean, maxWords: config.maxWords) {
                    cache[key] = smart
                    update(smart)
                } else { cache[key] = quick }
            }
        } else { cache[key] = quick }
        return quick
    }

    static var appleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    private static func appleSummary(_ title: String, maxWords: Int) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let session = LanguageModelSession(instructions: """
                You write very short browser-tab labels for YouTube videos. Reply with only the label: \
                at most \(maxWords) words, no quotes, no emoji, no channel names, no punctuation at the end. \
                Keep the language of the title. Keep names of people, games, products and places.
                """)
            do {
                let response = try await session.respond(to: "Video title: " + title)
                return sanitize(response.content, maxWords: maxWords)
            } catch { return nil }
        }
        #endif
        return nil
    }

    static func sanitize(_ text: String, maxWords: Int) -> String? {
        var value = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'“”‘’.:;!-"))
        if value.lowercased().hasPrefix("label:") { value = String(value.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        let words = value.split(whereSeparator: { $0 == " " })
        guard !words.isEmpty else { return nil }
        value = words.prefix(maxWords).joined(separator: " ")
        return value.isEmpty ? nil : value
    }

    private static let fillerWords: Set<String> = [
        "official", "video", "music", "lyrics", "lyric", "audio", "visualizer", "visualiser", "hd", "4k", "8k", "hq",
        "full", "version", "remastered", "remaster", "the", "a", "an", "of", "in", "on", "for", "with", "and", "to",
        "at", "by", "from", "is", "are", "my", "your", "our", "this", "that", "how", "why", "what", "we", "i", "you",
        "de", "het", "een", "van", "en", "met", "voor", "op", "te", "ik", "je", "wij", "dit", "dat", "is", "zijn",
        "new", "latest", "episode", "ep", "part", "pt", "vs", "feat", "ft", "prod", "live", "trailer", "teaser",
        "clip", "extended", "edition", "explained", "review", "reaction", "shorts", "vlog"
    ]
    private static let keepWhenShort: Set<String> = ["vs", "live", "trailer", "review", "reaction", "explained", "episode", "part"]

    /// Deterministic shortener (also used when Apple Intelligence is unavailable).
    static func heuristicSummary(_ title: String, maxWords: Int) -> String {
        var text = title
        // Drop bracketed decorations like (Official Video), [4K], 【MV】.
        text = text.replacingOccurrences(of: #"[\x{28}\x{5B}【\x{7B}][^\x{29}\x{5D}】\x{7D}]{0,60}[\x{29}\x{5D}】\x{7D}]"#, with: " ", options: .regularExpression)
        // Keep the main clause before separators such as " | ", " // ", " • ".
        for separator in [" | ", " || ", " // ", " • ", " ~ ", " — ", " – "] {
            if let range = text.range(of: separator), text.distance(from: text.startIndex, to: range.lowerBound) >= 8 {
                text = String(text[..<range.lowerBound])
            }
        }
        text = text.replacingOccurrences(of: #"#\S+"#, with: " ", options: .regularExpression)
        // Emoji and pictographs.
        text = String(text.unicodeScalars.filter { !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C)) }
            .map(Character.init))
        // "Artist - Song" keeps both, a leading "Channel: Title" keeps the title.
        if let colon = text.range(of: ": "), text.distance(from: text.startIndex, to: colon.lowerBound) <= 24 {
            let tail = String(text[colon.upperBound...])
            if tail.split(separator: " ").count >= 2 { text = tail }
        }
        let rawWords = text.replacingOccurrences(of: #"[\"“”‘’!?¿¡,.;…*]+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init).filter { !$0.isEmpty && $0 != "-" && $0 != "&" }
        guard !rawWords.isEmpty else { return title }
        if rawWords.count <= maxWords { return rawWords.joined(separator: " ") }
        var kept: [String] = []
        for word in rawWords {
            let lower = word.lowercased()
            if fillerWords.contains(lower) && !(keepWhenShort.contains(lower) && maxWords >= 4) { continue }
            kept.append(word)
            if kept.count == maxWords { break }
        }
        if kept.isEmpty { kept = Array(rawWords.prefix(maxWords)) }
        return kept.joined(separator: " ")
    }
}
