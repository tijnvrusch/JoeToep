import Foundation
import Combine

/// V15: bookmarks, history and recently closed tabs (stored locally in UserDefaults).
struct LibraryItem: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
    var date = Date()
}

@MainActor
final class BrowserLibrary: ObservableObject {
    static let shared = BrowserLibrary()
    @Published private(set) var bookmarks: [LibraryItem] = []
    @Published private(set) var history: [LibraryItem] = []
    private let defaults: UserDefaults
    private static let bookmarksKey = "bookmarksV15"
    private static let historyKey = "historyV15"
    private static let historyLimit = 3000
    private var saveTask: Task<Void, Never>?

    /// V22.2: recent bekeken video's, elke video maar één keer (de geschiedenis bevat dezelfde video
    /// vaak meerdere keren met een andere &t=/&pp=) — stopt zodra er genoeg zijn (geen volle scan).
    func recentVideos(_ limit: Int) -> [LibraryItem] {
        var seen = Set<String>(), result: [LibraryItem] = []
        for item in history where NavigationPolicy.isPlaybackPage(item.url) {
            let key = SponsorBlockService.videoID(from: item.url) ?? item.url.absoluteString
            guard seen.insert(key).inserted else { continue }
            result.append(item)
            if result.count >= limit { break }
        }
        return result
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = Self.load(Self.bookmarksKey, defaults)
        history = Self.load(Self.historyKey, defaults)
    }
    private static func load(_ key: String, _ defaults: UserDefaults) -> [LibraryItem] {
        guard let data = defaults.data(forKey: key), let items = try? JSONDecoder().decode([LibraryItem].self, from: data) else { return [] }
        return items
    }
    private func persist() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(self.bookmarks) { self.defaults.set(data, forKey: Self.bookmarksKey) }
            if let data = try? JSONEncoder().encode(self.history) { self.defaults.set(data, forKey: Self.historyKey) }
        }
    }

    func isBookmarked(_ url: URL?) -> Bool {
        guard let url else { return false }
        return bookmarks.contains { Self.same($0.url, url) }
    }
    func toggleBookmark(title: String, url: URL?) {
        guard let url, ["http", "https"].contains(url.scheme ?? "") else { return }
        if let index = bookmarks.firstIndex(where: { Self.same($0.url, url) }) { bookmarks.remove(at: index) }
        else { bookmarks.insert(LibraryItem(title: title, url: Self.withoutTimestamp(url)), at: 0) }
        persist()
    }
    func removeBookmarks(at offsets: IndexSet) { bookmarks.remove(atOffsets: offsets); persist() }
    func removeBookmark(_ item: LibraryItem) { bookmarks.removeAll { $0.id == item.id }; persist() }

    /// Records a visit (a repeated URL within 30 minutes only updates its title and time).
    func recordVisit(title: String, url: URL?) {
        guard let url, ["http", "https"].contains(url.scheme ?? "") else { return }
        let clean = Self.withoutTimestamp(url)
        if let first = history.first, Self.same(first.url, clean), Date().timeIntervalSince(first.date) < 1800 {
            if first.title != title || Date().timeIntervalSince(first.date) > 60 {
                history[0].title = title; history[0].date = Date(); persist()
            }
            return
        }
        history.insert(LibraryItem(title: title, url: clean), at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        persist()
    }
    func updateTitle(_ title: String, for url: URL?) {
        guard let url, let index = history.prefix(5).firstIndex(where: { Self.same($0.url, url) }),
              history[index].title != title else { return }
        history[index].title = title; persist()
    }
    func removeHistory(_ item: LibraryItem) { history.removeAll { $0.id == item.id }; persist() }
    func clearHistory(since date: Date? = nil) {
        if let date { history.removeAll { $0.date >= date } } else { history.removeAll() }
        persist()
    }

    static func same(_ a: URL, _ b: URL) -> Bool { withoutTimestamp(a).absoluteString == withoutTimestamp(b).absoluteString }
    static func withoutTimestamp(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = parts.queryItems else { return url }
        let filtered = items.filter { !["t", "start", "pp", "si", "feature"].contains($0.name) }
        parts.queryItems = filtered.isEmpty ? nil : filtered
        return parts.url ?? url
    }
}
