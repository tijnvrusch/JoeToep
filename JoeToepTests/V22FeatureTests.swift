import XCTest
@testable import JoeToep

/// V22: overdracht na achtergrond, live positie, dashboard-indeling, tab-icoon, Watch-toestand.
@MainActor
final class V22FeatureTests: XCTestCase {

    func testPausedHandoffDoesNotRunTheClock() {
        let r = BrowserWorkspace.RemotePlayback(device: "phone", tabID: UUID(), url: URL(string: "https://www.youtube.com/watch?v=a")!,
                                                time: 120, receivedAt: Date(timeIntervalSinceNow: -30), paused: true)
        XCTAssertEqual(r.estimatedTime(), 120, accuracy: 0.001, "a video paused by the other device stays at its exact second")
    }

    func testHandoffMarkerIsPartOfTheContent() {
        let id = UUID()
        let tabs = [SyncTab(id: id, url: URL(string: "https://www.youtube.com/watch?v=a"), time: 10)]
        let a = SyncContent(tabs: tabs, selectedID: id, playingID: nil, handoffID: nil)
        let b = SyncContent(tabs: tabs, selectedID: id, playingID: nil, handoffID: id)
        XCTAssertFalse(b.matches(a), "a new hand-off must always be sent")
    }

    func testPlayingTabSharesPositionFromOneSecond() {
        let id = UUID()
        let a = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 10)], selectedID: id, playingID: id)
        let b = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 11.2)], selectedID: id, playingID: id)
        XCTAssertFalse(b.matches(a))
        let c = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 11.2)], selectedID: id, playingID: nil)
        let d = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 10)], selectedID: id, playingID: nil)
        XCTAssertTrue(c.matches(d), "paused tabs still use the 2 s threshold")
    }

    func testOldSnapshotsStillDecode() throws {
        let json = #"{"version":1,"origin":"a","originName":"Mac","tabs":[],"selectedID":"\#(UUID().uuidString)","sentAt":0}"#
        let snap = try JSONDecoder().decode(SyncSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snap.handoffID)
    }

    func testOverlayLayoutAlwaysContainsEverySectionOnce() {
        var layout = OverlayLayout()
        layout.order = [.spotify, .spotify]
        XCTAssertEqual(layout.normalizedOrder.count, OverlaySection.allCases.count)
        XCTAssertEqual(layout.normalizedOrder.first, .spotify)
    }

    func testFullscreenDefaults() {
        for key in ["fullscreenOnPlayV22", "exitFullscreenOnPauseV22"] { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertTrue(SettingsSnapshot.standard.fullscreenOnPlay)
        XCTAssertFalse(SettingsSnapshot.standard.exitFullscreenOnPause)
    }

    func testTabIconDefaults() {
        for key in ["tabIconActionV22", "tabIconSwitchV22"] { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertEqual(TabAudioIconPrefs.action, "playPause")
        XCTAssertTrue(TabAudioIconPrefs.switchOnPlay)
    }

    func testWatchStateRoundTripAndLivePosition() throws {
        var s = WatchState()
        s.devices = [WatchDeviceState(id: "m", name: "Mac", kind: "mac", isPhone: false, connected: true, title: "T",
                                      url: "https://www.youtube.com/watch?v=abc", playing: true, time: 10, duration: 100,
                                      updated: Date(timeIntervalSinceNow: -5))]
        let back = try XCTUnwrap(WatchState.decode(try XCTUnwrap(s.encoded())))
        XCTAssertEqual(back.devices.first?.videoID, "abc")
        XCTAssertEqual(back.devices.first?.livePosition() ?? 0, 15, accuracy: 0.5)
        XCTAssertEqual(watchClock(3725), "1:02:05")
    }
}
