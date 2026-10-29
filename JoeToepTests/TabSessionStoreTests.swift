import XCTest
@testable import JoeToep

final class TabSessionStoreTests: XCTestCase {
    @MainActor func testRestoresOrderSelectionAndUnloadedTabsAcrossLaunches() throws {
        let suite = "TabsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tabs = [SavedBrowserTab(url: URL(string: "https://m.youtube.com/watch?v=first")), SavedBrowserTab(url: URL(string: "https://www.youtube.com/playlist?list=WL")), SavedBrowserTab()]
        let saved = SavedTabSession(tabs: tabs, selectedID: tabs[1].id)
        TabSessionStore(defaults: defaults).save(saved, window: UUID())
        let relaunched = TabSessionStore(defaults: defaults)
        XCTAssertEqual(relaunched.restore(), saved)
        XCTAssertNil(relaunched.restore(), "Opening another window must not duplicate restored tabs")
    }
    @MainActor func testClosingTabsDoesNotResurrectThemAndWindowsAreMerged() throws {
        let suite = "TabsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TabSessionStore(defaults: defaults), window = UUID()
        let first = SavedBrowserTab(), second = SavedBrowserTab(), third = SavedBrowserTab()
        store.save(SavedTabSession(tabs: [first, second], selectedID: second.id), window: window)
        store.save(SavedTabSession(tabs: [third], selectedID: third.id), window: UUID())
        store.save(SavedTabSession(tabs: [first], selectedID: first.id), window: window)
        XCTAssertEqual(TabSessionStore(defaults: defaults).restore()?.tabs, [first, third])
    }
    @MainActor func testCorruptionAndAuthenticationURLsNeverLoadOnRestore() throws {
        let suite = "TabsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid json".utf8), forKey: "browserTabsV10")
        XCTAssertNil(TabSessionStore(defaults: defaults).restore())
        for url in ["javascript:alert(1)", "https://accounts.google.com/login?token=secret", "https://accounts.youtube.com/accounts/SetSID?x=1", "https://user:password@youtube.com/watch?v=1"] {
            XCTAssertNil(TabSessionStore.restorable(URL(string: url)))
        }
    }
    @MainActor func testRepeatedSaveAndRestoreKeepsExactlyOneCopyPerTab() throws {
        let suite = "TabsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tabs = (0..<50).map { SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=\($0)")) }
        let saved = SavedTabSession(tabs: tabs, selectedID: tabs[20].id)
        for _ in 0..<200 {
            let store = TabSessionStore(defaults: defaults)
            store.save(saved, window: UUID())
            XCTAssertEqual(store.restore(), saved)
        }
    }
    @MainActor func testV13ExpiredInactiveTabsAreDroppedButSelectedTabAndPositionsSurvive() throws {
        let suite = "TabsTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let old = SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=old"), lastActive: now.addingTimeInterval(-3 * 86400))
        let recent = SavedBrowserTab(url: URL(string: "https://www.youtube.com/watch?v=recent"), time: 123, playing: true, lastActive: now.addingTimeInterval(-3600))
        let selectedOld = SavedBrowserTab(url: URL(string: "https://www.youtube.com/"), lastActive: now.addingTimeInterval(-9 * 86400))
        TabSessionStore(defaults: defaults).save(SavedTabSession(tabs: [old, recent, selectedOld], selectedID: selectedOld.id), window: UUID())
        let restored = try XCTUnwrap(TabSessionStore(defaults: defaults).restore(lifetime: TabLifetime.days2.seconds, now: now))
        XCTAssertEqual(restored.tabs.map(\.id), [recent.id, selectedOld.id])
        XCTAssertEqual(restored.tabs.first?.time, 123)
        XCTAssertEqual(TabLifetime.stored(defaults), .days2, "Default lifetime is two days")
    }
    @MainActor func testV13LifetimeChoices() {
        XCTAssertEqual(TabLifetime.allCases.map(\.rawValue), [1, 6, 12, 24, 48, 72, 96, 120, 144, 168, 720])
        XCTAssertEqual(ToolbarDensity.allCases.count, 8)
        XCTAssertTrue(ToolbarDensity.maximum.height > ToolbarDensity.extraLarge.height)
    }
}
