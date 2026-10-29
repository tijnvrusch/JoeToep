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

    func testPlayingTabSharesPositionFromFiveSeconds() {
        let id = UUID()
        let a = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 10)], selectedID: id, playingID: id)
        let b = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 15.2)], selectedID: id, playingID: id)
        XCTAssertFalse(b.matches(a))
        let e = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 13)], selectedID: id, playingID: id)
        XCTAssertTrue(e.matches(a), "V22.2: live position is shared from 5 s (fewer full snapshots)")
        let c = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 11.2)], selectedID: id, playingID: nil)
        let d = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 10)], selectedID: id, playingID: nil)
        XCTAssertTrue(c.matches(d), "paused tabs still use the 2 s threshold")
    }

    func testSteadyPlaybackIsExtrapolatedNotResent() {
        let id = UUID()
        let a = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 100)], selectedID: id, playingID: id)
        let later = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 130)], selectedID: id, playingID: id)
        XCTAssertTrue(later.matches(a, elapsed: 30), "30 s of normal playback needs no new snapshot")
        let seek = SyncContent(tabs: [SyncTab(id: id, url: nil, time: 200)], selectedID: id, playingID: id)
        XCTAssertFalse(seek.matches(a, elapsed: 30), "a seek is always shared")
        XCTAssertFalse(SyncContent(tabs: [SyncTab(id: id, url: nil, time: 161)], selectedID: id, playingID: id).matches(a, elapsed: 61),
                       "at most once a minute a refresh while playing")
    }

    func testOldSnapshotsStillDecode() throws {
        let json = #"{"version":1,"origin":"a","originName":"Mac","tabs":[],"selectedID":"\#(UUID().uuidString)","sentAt":0}"#
        let snap = try JSONDecoder().decode(SyncSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snap.handoffID)
        XCTAssertNil(snap.closed); XCTAssertNil(snap.playStamp); XCTAssertNil(snap.handoffNonce)
    }

    // MARK: V22.2 — sync-reparaties

    func testOldTabsAndCommandsStillDecode() throws {
        let id = UUID()
        let json = #"{"version":1,"origin":"a","originName":"Mac","tabs":[{"id":"\#(id.uuidString)","pinned":false,"time":12}],"selectedID":"\#(id.uuidString)","sentAt":0,"handoffID":"\#(id.uuidString)","handoffTime":3}"#
        let snap = try JSONDecoder().decode(SyncSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snap.tabs.first?.active)
        XCTAssertEqual(snap.handoffTime, 3)
        let cmd = try JSONDecoder().decode(SyncCommand.self, from: Data(#"{"kind":"toggle","target":"x"}"#.utf8))
        XCTAssertNil(cmd.to)
    }

    func testNewFieldsRoundTrip() throws {
        let id = UUID()
        var ledger = SyncLedger(deviceID: "mac")
        let snap = try XCTUnwrap(ledger.makeLocal(name: "Mac", tabs: [SyncTab(id: id, url: nil, active: 5)], selectedID: id, playingID: id,
                                                  handoff: (id, 4), closed: ["x": 1], playStamp: 9, handoffNonce: "n"))
        let back = try JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(snap))
        XCTAssertEqual(back.tabs, snap.tabs)
        XCTAssertEqual(back.closed, ["x": 1]); XCTAssertEqual(back.playStamp, 9); XCTAssertEqual(back.handoffNonce, "n")
        XCTAssertEqual(back.tabs.first?.active, 5)
        XCTAssertGreaterThan(ledger.stamp(), snap.version, "a new local play always beats what we already saw")
    }

    func testTombstonesBlockStaleTabsButNotReopenedOnes() {
        let id = UUID()
        let stale = SyncTab(id: id, url: nil, active: 100)
        XCTAssertTrue(SyncRules.blocks(stale, local: [id.uuidString: 200], remote: nil), "closed here after its last use → stays closed")
        XCTAssertTrue(SyncRules.blocks(stale, local: [:], remote: [id.uuidString: 200]), "the sender's own tombstone counts too")
        XCTAssertTrue(SyncRules.blocks(SyncTab(id: id, url: nil), local: [id.uuidString: 200], remote: nil), "old versions send no activity")
        let reopened = SyncTab(id: id, url: nil, active: 300)
        XCTAssertFalse(SyncRules.blocks(reopened, local: [id.uuidString: 200], remote: nil), "reopened after the close → newer wins")
        XCTAssertFalse(SyncRules.blocks(stale, local: [:], remote: nil))
    }

    func testRemoteTombstoneClosesOnlyTabsNotUsedSince() {
        let id = UUID()
        XCTAssertTrue(SyncRules.shouldClose(id, lastActive: Date(timeIntervalSince1970: 100), remote: [id.uuidString: 200]))
        XCTAssertFalse(SyncRules.shouldClose(id, lastActive: Date(timeIntervalSince1970: 300), remote: [id.uuidString: 200]))
        XCTAssertFalse(SyncRules.shouldClose(id, lastActive: Date(timeIntervalSince1970: 100), remote: nil))
    }

    func testRecentTombstonesAreBoundedByAgeAndCount() {
        let now = Date(timeIntervalSince1970: 10 * 86_400)
        var all: [String: Double] = ["old": now.timeIntervalSince1970 - 8 * 86_400]
        for i in 0..<250 { all["k\(i)"] = now.timeIntervalSince1970 - Double(i) }
        let recent = SyncRules.recentTombstones(all, now: now)
        XCTAssertEqual(recent.count, 200)
        XCTAssertNil(recent["old"]); XCTAssertNotNil(recent["k0"]); XCTAssertNil(recent["k249"], "only the newest 200")
    }

    func testPlayPriorityAndHandoffKeys() {
        XCTAssertTrue(SyncRules.remotePlayWins(remote: nil, local: 50), "old versions keep the old behaviour")
        XCTAssertTrue(SyncRules.remotePlayWins(remote: 60, local: 50))
        XCTAssertFalse(SyncRules.remotePlayWins(remote: 40, local: 50), "an older play elsewhere does not pause the newest choice")
        let tab = UUID()
        XCTAssertEqual(SyncRules.handoffKey(origin: "p", tab: tab, nonce: nil), "p:\(tab)")
        XCTAssertNotEqual(SyncRules.handoffKey(origin: "p", tab: tab, nonce: "1"), SyncRules.handoffKey(origin: "p", tab: tab, nonce: "2"))
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

    func testEscapeClosesTopmostPanelOnly() {
        EscapeStack.handlers.removeAll()
        var closed: [String] = []
        let a = UUID(), b = UUID()
        EscapeStack.push(a) { closed.append("settings") }
        EscapeStack.push(b) { closed.append("commandBar") }
        XCTAssertTrue(EscapeStack.handle())
        XCTAssertEqual(closed, ["commandBar"], "Esc closes only the panel on top")
        EscapeStack.pop(b)
        XCTAssertTrue(EscapeStack.handle())
        XCTAssertEqual(closed, ["commandBar", "settings"])
        EscapeStack.pop(a)
        XCTAssertFalse(EscapeStack.handle(), "nothing open: Esc goes to the page (e.g. leave fullscreen)")
        EscapeStack.push(a, windowNumber: 1) { closed.append("w1") }
        XCTAssertFalse(EscapeStack.handle(in: 2), "Esc in another window leaves window 1's panel alone")
        XCTAssertTrue(EscapeStack.handle(in: 1))
        EscapeStack.pop(a)
    }

    func testClosedTabsAreRememberedForSyncMergeAndForgottenOnReopen() {
        let id = UUID()
        BrowserWorkspace.markClosed(id)
        XCTAssertTrue(BrowserWorkspace.closedSyncIDs.contains(id.uuidString), "a closed tab must not come back at the next merge")
        BrowserWorkspace.unmarkClosed(id)
        XCTAssertFalse(BrowserWorkspace.closedSyncIDs.contains(id.uuidString), "reopening a tab lifts the tombstone")
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
