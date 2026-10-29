import XCTest
@testable import JoeToep

/// V21: overdracht tussen apparaten, zoekbalk (Tab om te zoeken, opdrachten), groepen, widgets.
@MainActor
final class V21FeatureTests: XCTestCase {

    func testRemotePlaybackEstimatesTheLivePosition() {
        let r = BrowserWorkspace.RemotePlayback(device: "mac", tabID: UUID(), url: URL(string: "https://www.youtube.com/watch?v=a")!,
                                                time: 100, receivedAt: Date(timeIntervalSinceNow: -2.5))
        XCTAssertEqual(r.estimatedTime(), 102.5, accuracy: 0.2, "the video kept playing while the message travelled")
        let future = BrowserWorkspace.RemotePlayback(device: "mac", tabID: UUID(), url: r.url, time: 10, receivedAt: Date(timeIntervalSinceNow: 5))
        XCTAssertEqual(future.estimatedTime(), 10, accuracy: 0.01, "clock skew never moves the time backwards")
    }

    func testHandoffPreferencesHaveSafeDefaults() {
        for key in ["handoffAutoResumeV21", "handoffIdleV21", "handoffLatencyV21", "handoffMaxAgeV21"] { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertTrue(HandoffPrefs.autoResume)
        XCTAssertEqual(HandoffPrefs.idleBeforeTakeover, 4)
        XCTAssertEqual(HandoffPrefs.latencyCompensation, 0.08, accuracy: 0.001)
        XCTAssertGreaterThan(HandoffPrefs.maxAge, 60)
    }

    func testLaunchDoesNotAutoplayByDefault() {
        UserDefaults.standard.removeObject(forKey: "resumeOnLaunchV21")
        XCTAssertFalse(LaunchPrefs.resumeOnLaunch)
    }

    func testTabToSearchRecognisesPlatformsAndAbbreviations() {
        XCTAssertEqual(SearchToken.platform(for: "youtube"), .youtube)
        XCTAssertEqual(SearchToken.platform(for: "YT"), .youtube)
        XCTAssertEqual(SearchToken.platform(for: "spotify"), .spotify)
        XCTAssertEqual(SearchToken.platform(for: "spo"), .spotify, "the start of a name works from 3 letters")
        XCTAssertEqual(SearchToken.platform(for: "twitch"), .twitch)
        XCTAssertEqual(SearchToken.platform(for: "sc"), .soundcloud)
        XCTAssertEqual(SearchToken.platform(for: "youtube music"), .youtubeMusic)
        XCTAssertNil(SearchToken.platform(for: "y"))
        XCTAssertNil(SearchToken.platform(for: "banana bread"))
    }

    func testPaletteCommandsAreUniqueAndFindable() {
        let titles = PaletteCommand.all.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertTrue(PaletteCommand.all.contains { $0.keywords.contains("pin") })
        XCTAssertTrue(PaletteCommand.all.contains { $0.keywords.contains("audio") })
        XCTAssertGreaterThanOrEqual(PaletteCommand.all.count, 20)
    }

    func testTabGroupsRoundTripAndColours() throws {
        let groups = [TabGroup(name: "Music", color: "green"), TabGroup(name: "Later", color: "nope", collapsed: true)]
        let data = try JSONEncoder().encode(groups)
        XCTAssertEqual(try JSONDecoder().decode([TabGroup].self, from: data), groups)
        XCTAssertEqual(TabGroup.color(named: "nope"), .blue, "unknown colours fall back to blue")
        XCTAssertEqual(TabGroup.palette.count, Set(TabGroup.palette).count)
    }

    func testSavedTabsKeepTheirGroupAndOldDataStillLoads() throws {
        let id = UUID()
        let saved = SavedBrowserTab(url: URL(string: "https://www.youtube.com")!, groupID: id)
        let decoded = try JSONDecoder().decode(SavedBrowserTab.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.groupID, id)
        let old = #"{"id":"\#(UUID().uuidString)","url":"https:\/\/www.youtube.com"}"#
        XCTAssertNil(try JSONDecoder().decode(SavedBrowserTab.self, from: Data(old.utf8)).groupID)
    }

    func testWidgetLinksAndThumbnails() {
        let open = WidgetShared.openURL(URL(string: "https://www.youtube.com/watch?v=abc")!)
        XCTAssertEqual(open.scheme, "joetoep"); XCTAssertEqual(open.host, "open")
        XCTAssertEqual(WidgetShared.searchURL(platform: "spotify").absoluteString, "joetoep://search?p=spotify")
        XCTAssertEqual(WidgetShared.thumbnail(for: URL(string: "https://www.youtube.com/watch?v=abc123")!)?.absoluteString,
                       "https://i.ytimg.com/vi/abc123/mqdefault.jpg")
        XCTAssertEqual(WidgetShared.thumbnail(for: URL(string: "https://youtu.be/xyz")!)?.absoluteString, "https://i.ytimg.com/vi/xyz/mqdefault.jpg")
        XCTAssertNil(WidgetShared.thumbnail(for: URL(string: "https://vimeo.com/1")!))
        XCTAssertNil(DefaultBrowser.webURL(fromCustom: URL(string: "joetoep://open")!), "widget links never become a web page")
    }

    func testWidgetSnapshotRoundTripAndNowPlayingChoice() throws {
        var s = WidgetSnapshot()
        s.devices = [
            WidgetDevice(id: "a", name: "iPhone", kind: "iphone", isThisDevice: true, title: "Old", playing: false, updated: Date(timeIntervalSinceNow: -60)),
            WidgetDevice(id: "b", name: "MacBook", kind: "mac", isThisDevice: false, title: "Now", playing: true, time: 50, duration: 100, updated: Date(timeIntervalSinceNow: -10)),
        ]
        XCTAssertEqual(s.nowPlaying?.id, "b", "what really plays wins")
        XCTAssertEqual(s.devices[1].livePosition() ?? 0, 60, accuracy: 0.5)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let back = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(s))
        XCTAssertEqual(back.devices.map(\.id), ["a", "b"])
        XCTAssertEqual(WidgetBridge.kind(forName: "Tijn's MacBook Pro"), "mac")
        XCTAssertEqual(WidgetBridge.kind(forName: "Tijn's iPad"), "ipad")
        XCTAssertEqual(WidgetBridge.kind(forName: "eiFoon"), "iphone")
    }

    func testCommandBarDefaults() {
        for key in ["commandBarNewTabV21", "commandBarTabToSearchV21", "commandBarTintV21"] { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertTrue(CommandBarPrefs.overlayForNewTab)
        XCTAssertTrue(CommandBarPrefs.tabToSearch)
        XCTAssertEqual(CommandBarPrefs.tint, 0.12, accuracy: 0.001)
    }

    func testMediaExtrasClampBoost() {
        XCTAssertEqual(5.0.clamped(1, 3), 3)
        XCTAssertEqual(0.2.clamped(1, 3), 1)
    }
}
