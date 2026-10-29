import XCTest
@testable import JoeToep

/// V20: Spotify-sync, mediacentrum, nieuwe-tab-layout, icoonstijlen en instellingen-zoeken.
@MainActor
final class V20FeatureTests: XCTestCase {

    func testSpotifySyncMessagesRoundTrip() throws {
        var state = SpotifyState(running: true, playing: true, track: "Song", artist: "Artist", album: "Album",
                                 artworkURL: URL(string: "https://i.scdn.co/image/x"), duration: 200, position: 42,
                                 volume: 64, shuffling: true, repeating: false, trackURI: "spotify:track:abc", device: "Mac", deviceID: "m")
        state.updated = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let a = SyncMessage.spotify(deviceID: "m", state: state)
        XCTAssertEqual(SyncMessage.decode(try XCTUnwrap(a.encoded())), a)
        let b = SyncMessage.spotifyCommand(target: "m", action: .setVolume, value: 30, uri: nil)
        XCTAssertEqual(SyncMessage.decode(try XCTUnwrap(b.encoded())), b)
        // Oude berichten blijven gewoon werken.
        let ack = SyncMessage.ack(deviceID: "x", name: "iPhone", version: 1, tabs: 2)
        XCTAssertEqual(SyncMessage.decode(try XCTUnwrap(ack.encoded())), ack)
    }

    func testSpotifyLivePositionAndLinks() {
        var s = SpotifyState(running: true, playing: true, track: "T", duration: 100, position: 10, trackURI: "spotify:track:123")
        s.updated = Date(timeIntervalSinceNow: -5)
        XCTAssertEqual(s.livePosition(), 15, accuracy: 0.5)
        s.playing = false
        XCTAssertEqual(s.livePosition(), 10)
        s.playing = true; s.updated = Date(timeIntervalSinceNow: -500)
        XCTAssertEqual(s.livePosition(), 100, "never past the end of the track")
        XCTAssertEqual(s.webURL?.absoluteString, "https://open.spotify.com/track/123")
        XCTAssertTrue(s.hasTrack)
    }

    func testRemoteSpotifyStateIsTrackedAndForgotten() {
        let spotify = SpotifyController.shared
        spotify.receive(SpotifyState(running: true, playing: true, track: "Remote"), from: "dev-remote-test")
        XCTAssertEqual(spotify.remote["dev-remote-test"]?.track, "Remote")
        spotify.forget(deviceID: "dev-remote-test")
        XCTAssertNil(spotify.remote["dev-remote-test"])
        spotify.receive(SpotifyState(running: false), from: "dev-remote-test")
        XCTAssertNil(spotify.remote["dev-remote-test"], "a closed Spotify is not listed")
    }

    func testNewTabLayoutDefaultsNormalizeAndRoundTrip() throws {
        var layout = NewTabLayout()
        XCTAssertEqual(Set(layout.items.map(\.section)), Set(NewTabSection.allCases))
        XCTAssertTrue(layout.items.first { $0.section == .spotify }!.enabled)
        XCTAssertFalse(layout.items.first { $0.section == .history }!.enabled)
        // Een oudere opgeslagen layout zonder nieuwe onderdelen krijgt ze er vanzelf bij.
        layout.items = [.init(section: .search, enabled: true), .init(section: .search, enabled: false)]
        layout.itemsPerSection = 99; layout.tileColumns = 1; layout.contentWidth = 10; layout.visiblePlatforms = []
        layout.normalize()
        XCTAssertEqual(layout.items.count, NewTabSection.allCases.count, "no duplicates, nothing missing")
        XCTAssertEqual(layout.items.first?.section, .search)
        XCTAssertEqual(layout.itemsPerSection, 20)
        XCTAssertEqual(layout.tileColumns, 2)
        XCTAssertEqual(layout.contentWidth, 420)
        XCTAssertEqual(layout.visiblePlatforms, [.youtube])
        let data = try JSONEncoder().encode(layout)
        XCTAssertEqual(try JSONDecoder().decode(NewTabLayout.self, from: data), layout)
    }

    func testNewTabStoreMoveAndToggle() {
        let store = NewTabStore.shared
        let saved = store.layout
        defer { store.layout = saved }
        store.reset()
        store.move(.spotify, before: .greeting)
        XCTAssertEqual(store.layout.items.first?.section, .spotify)
        let before = store.layout.items.first { $0.section == .favourites }!.enabled
        store.toggle(.favourites)
        XCTAssertNotEqual(store.layout.items.first { $0.section == .favourites }!.enabled, before)
    }

    func testIconVariantsAreGroupedAndStyled() {
        let groups = Set(IconVariant.allCases.map(\.group))
        XCTAssertEqual(groups, ["Classic", "Outline", "Clean & minimal"])
        XCTAssertGreaterThanOrEqual(IconVariant.allCases.filter { $0.group == "Outline" }.count, 7)
        XCTAssertGreaterThanOrEqual(IconVariant.allCases.filter { $0.group == "Clean & minimal" }.count, 6)
        XCTAssertEqual(IconVariant(rawValue: "outline"), .outline, "saved values from older versions still load")
        for v in IconVariant.allCases { XCTAssertGreaterThan(v.sizeFactor, 0.5); XCTAssertFalse(v.title.isEmpty) }
    }

    func testNewAppIconSeriesAreRegistered() {
        let titles = AppIconController.series.map(\.title)
        XCTAssertTrue(titles.contains("Outline")); XCTAssertTrue(titles.contains("Minimal"))
        let names = AppIconController.names
        XCTAssertEqual(Set(names).count, names.count, "icon names are unique")
        XCTAssertEqual(names.filter { $0.hasPrefix("Outline") }.count, 20)
        XCTAssertEqual(names.filter { $0.hasPrefix("Minimal") }.count, 20)
        XCTAssertEqual(AppIconController.title("OutlineRedCircle"), "RedCircle")
    }

    func testV20SettingsAreSearchable() {
        for key in SettingHelp.v20Texts.keys { XCTAssertNotNil(SettingHelp.v20Pages[key], key) }
        XCTAssertTrue(SettingHelp.search("spotify").contains { $0.page == "Music & Spotify" })
        XCTAssertTrue(SettingHelp.search("hide").contains { $0.page == "Top bar auto-hide" })
    }

    func testMediaHubSiteNames() {
        XCTAssertEqual(MediaHub.siteName("twitch.tv"), "Twitch")
        XCTAssertEqual(MediaHub.siteName("open.spotify.com"), "Spotify Web")
        XCTAssertEqual(MediaHub.siteName("example.org"), "example.org")
    }

    func testAutoHideDefaultsOff() {
        UserDefaults.standard.removeObject(forKey: "autoHideModeV20")
        let chrome = ChromeAutoHide.shared
        chrome.schedule()
        XCTAssertEqual(chrome.mode, .off)
        XCTAssertFalse(chrome.hidden)
        XCTAssertFalse(chrome.tabsHidden || chrome.buttonsHidden)
    }
}
