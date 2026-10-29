import XCTest
import SwiftUI
@testable import JoeToep

@MainActor
final class V15FeatureTests: XCTestCase {
    private func freshDefaults() throws -> (UserDefaults, String) {
        let suite = "V15Tests." + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }

    // MARK: Tab titles

    func testCleanTitleRemovesYouTubeSuffixAndCounter() {
        let url = URL(string: "https://www.youtube.com/watch?v=abcdefghijk")
        XCTAssertEqual(TabTitleSummarizer.cleanPageTitle("(3) Great Video - YouTube", url: url), "Great Video")
        XCTAssertEqual(TabTitleSummarizer.cleanPageTitle("YouTube", url: URL(string: "https://www.youtube.com/")), "Home")
        XCTAssertEqual(TabTitleSummarizer.cleanPageTitle("", url: URL(string: "https://m.youtube.com/feed/subscriptions")), "Subscriptions")
        XCTAssertEqual(TabTitleSummarizer.cleanPageTitle(nil, url: URL(string: "https://www.youtube.com/results?search_query=lofi")), "Search: lofi")
        XCTAssertEqual(TabTitleSummarizer.cleanPageTitle(nil, url: URL(string: "https://www.apple.com/iphone/")), "apple.com")
        XCTAssertNotEqual(TabTitleSummarizer.cleanPageTitle("YouTube", url: url), "YouTube", "Tabs never just say YouTube")
    }

    func testHeuristicSummaryIsShortAndMeaningful() {
        let summary = TabTitleSummarizer.heuristicSummary("Rick Astley - Never Gonna Give You Up (Official Music Video) [4K Remaster] 🔥 #rickroll", maxWords: 4)
        let words = summary.split(separator: " ")
        XCTAssertLessThanOrEqual(words.count, 4)
        XCTAssertTrue(summary.contains("Rick"))
        XCTAssertFalse(summary.contains("Official"))
        XCTAssertFalse(summary.contains("#"))
        XCTAssertFalse(summary.contains("🔥"))
        XCTAssertEqual(TabTitleSummarizer.heuristicSummary("Short title", maxWords: 4), "Short title")
        XCTAssertLessThanOrEqual(TabTitleSummarizer.heuristicSummary("How I built a tiny house in the woods for one hundred dollars | Full Tour", maxWords: 2).split(separator: " ").count, 2)
    }

    func testSanitizeAIOutput() {
        XCTAssertEqual(TabTitleSummarizer.sanitize("\"Label: Tiny House Build.\"", maxWords: 4), "Tiny House Build")
        XCTAssertNil(TabTitleSummarizer.sanitize("   ", maxWords: 3))
        XCTAssertEqual(TabTitleSummarizer.sanitize("one two three four five", maxWords: 3), "one two three")
    }

    // MARK: Address bar

    func testAddressBarParsing() {
        XCTAssertEqual(WebSession.addressURL("apple.com")?.absoluteString, "https://apple.com")
        XCTAssertEqual(WebSession.addressURL("https://www.youtube.com/watch?v=1")?.host, "www.youtube.com")
        XCTAssertEqual(WebSession.addressURL("localhost:8080/test")?.absoluteString, "https://localhost:8080/test")
        XCTAssertNil(WebSession.addressURL("lofi hip hop"))
        XCTAssertNil(WebSession.addressURL("lofi"))
        XCTAssertEqual(SearchEngine.youtube.url(for: "lofi hip hop")?.absoluteString, "https://www.youtube.com/results?search_query=lofi%20hip%20hop")
        for engine in SearchEngine.allCases { XCTAssertNotNil(engine.url(for: "a&b=c"), engine.title) }
    }

    // MARK: Ad blocking

    func testAdBlockLevelsAreCumulativeAndMigrate() throws {
        XCTAssertEqual(AdBlockLevel.allCases.count, 6)
        XCTAssertFalse(AdBlockLevel.minimal.blocksAdServers)
        XCTAssertTrue(AdBlockLevel.light.blocksAdServers)
        XCTAssertTrue(AdBlockLevel.balanced.skipsAds && !AdBlockLevel.balanced.fastForwardsAds)
        XCTAssertTrue(AdBlockLevel.strict.blocksMeasurement && AdBlockLevel.strict.fastForwardsAds && !AdBlockLevel.strict.prunesPlayerAds)
        XCTAssertTrue(AdBlockLevel.aggressive.prunesPlayerAds && !AdBlockLevel.aggressive.prunesFeedAds)
        XCTAssertTrue(AdBlockLevel.maximum.prunesFeedAds && AdBlockLevel.maximum.dismissesWarnings)
        let (defaults, suite) = try freshDefaults(); defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AdBlockLevel.stored(defaults), .balanced)
        defaults.set("light", forKey: "adBlockLevelV5")
        XCTAssertEqual(AdBlockLevel.stored(defaults), .minimal, "V5 'light' was cosmetic-only")
        defaults.set("aggressive", forKey: AdBlockLevel.storageKey)
        XCTAssertEqual(AdBlockLevel.stored(defaults), .aggressive)
    }

    // MARK: SponsorBlock

    func testSponsorBlockSettingsPersistAndVideoIDs() throws {
        let (defaults, suite) = try freshDefaults(); defer { defaults.removePersistentDomain(forName: suite) }
        var value = SponsorBlockSettings.stored(defaults)
        XCTAssertTrue(value.enabled)
        XCTAssertEqual(value.mode(.sponsor), .skip)
        value.modes[SponsorBlockCategory.intro.rawValue] = .skip
        value.minimumDuration = 3
        value.save(defaults)
        XCTAssertEqual(SponsorBlockSettings.stored(defaults), value)
        XCTAssertEqual(SponsorBlockService.videoID(from: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=5")), "dQw4w9WgXcQ")
        XCTAssertEqual(SponsorBlockService.videoID(from: URL(string: "https://m.youtube.com/shorts/dQw4w9WgXcQ")), "dQw4w9WgXcQ")
        XCTAssertEqual(SponsorBlockService.videoID(from: URL(string: "https://youtu.be/dQw4w9WgXcQ")), "dQw4w9WgXcQ")
        XCTAssertNil(SponsorBlockService.videoID(from: URL(string: "https://www.youtube.com/watch?v=bad'id")))
        XCTAssertNil(SponsorBlockService.videoID(from: URL(string: "https://example.com/watch?v=dQw4w9WgXcQ")))
        let options = value.scriptOptions
        XCTAssertTrue(JSONSerialization.isValidJSONObject(options))
    }

    // MARK: Settings

    func testV15SettingsDefaultsPersistAndReset() throws {
        let (defaults, suite) = try freshDefaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.themeStyle, .youtube)
        XCTAssertEqual(settings.pipReturnTarget, .fullscreen)
        XCTAssertTrue(settings.pipReturnKeepsPlaying)
        XCTAssertTrue(settings.aiTabSummary)
        XCTAssertEqual(settings.tabSummaryLength, .short)
        XCTAssertEqual(settings.tabLifetime, .days2)
        settings.themeStyle = .midnight; settings.accentChoice = .custom; settings.customAccentHex = "#12AB34"
        settings.iconVariant = .circleFilled; settings.toolbarDensity = .roomy; settings.searchEngine = .duckDuckGo
        settings.sponsorBlock.enabled = false; settings.adBlockLevel = .maximum
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.themeStyle, .midnight)
        XCTAssertEqual(restored.accentChoice, .custom)
        XCTAssertEqual(restored.customAccentHex, "#12AB34")
        XCTAssertEqual(restored.iconVariant, .circleFilled)
        XCTAssertEqual(restored.toolbarDensity, .roomy)
        XCTAssertEqual(restored.searchEngine, .duckDuckGo)
        XCTAssertFalse(restored.sponsorBlock.enabled)
        XCTAssertEqual(restored.adBlockLevel, .maximum)
        restored.resetPreferences()
        XCTAssertEqual(restored.themeStyle, .youtube)
        XCTAssertTrue(restored.sponsorBlock.enabled)
        XCTAssertEqual(restored.adBlockLevel, .balanced)
    }

    func testToolbarSizesBetweenComfortableAndLarge() {
        let order = ToolbarDensity.allCases
        let comfortable = order.firstIndex(of: .comfortable)!, large = order.firstIndex(of: .large)!
        XCTAssertEqual(large - comfortable - 1, 3, "three sizes just below Large")
        for (a, b) in zip(order, order.dropFirst()) {
            XCTAssertLessThan(a.scale, b.scale); XCTAssertLessThan(a.height, b.height)
        }
    }

    func testColorHexRoundTrip() {
        XCTAssertNotNil(Color(hexString: "#FF3B30"))
        XCTAssertNil(Color(hexString: "nope"))
        XCTAssertEqual(Color(hex: 0x12AB34).hexString, "#12AB34")
    }

    // MARK: Library & tabs

    func testLibraryBookmarksAndHistory() throws {
        let (defaults, suite) = try freshDefaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let library = BrowserLibrary(defaults: defaults)
        let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s")!
        library.toggleBookmark(title: "Song", url: url)
        XCTAssertTrue(library.isBookmarked(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")))
        library.toggleBookmark(title: "Song", url: url)
        XCTAssertFalse(library.isBookmarked(url))
        library.recordVisit(title: "A", url: url)
        library.recordVisit(title: "A2", url: url)
        XCTAssertEqual(library.history.count, 1, "a repeated visit updates the entry")
        XCTAssertEqual(library.history.first?.title, "A2")
        library.recordVisit(title: "B", url: URL(string: "https://www.apple.com/")!)
        XCTAssertEqual(library.history.count, 2)
        library.clearHistory()
        XCTAssertTrue(library.history.isEmpty)
    }

    func testPinnedTabsNeverExpire() throws {
        let (defaults, suite) = try freshDefaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let pinned = SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=pinned12345"), lastActive: now.addingTimeInterval(-40 * 86400), pinned: true, title: "Pinned")
        let old = SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=old12345678"), lastActive: now.addingTimeInterval(-40 * 86400))
        let current = SavedBrowserTab(url: URL(string: "https://www.apple.com/"), lastActive: now)
        TabSessionStore(defaults: defaults).save(SavedTabSession(tabs: [pinned, old, current], selectedID: current.id), window: UUID())
        let restored = try XCTUnwrap(TabSessionStore(defaults: defaults).restore(lifetime: TabLifetime.days2.seconds, now: now))
        XCTAssertEqual(restored.tabs.map(\.id), [pinned.id, current.id])
        XCTAssertEqual(restored.tabs.first?.title, "Pinned")
        XCTAssertEqual(restored.tabs.first?.pinned, true)
        XCTAssertEqual(restored.tabs.last?.url?.host, "www.apple.com", "any website can be restored")
    }
}
