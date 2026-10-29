import XCTest
@testable import JoeToep

/// V23: fullscreen-bewaker, handmatig wisselen, Live Activity-houdbaarheid, outbox.
@MainActor
final class V23FeatureTests: XCTestCase {

    func testAutomaticSwitchingSettingDefaultsOnAndCanBeTurnedOff() {
        let key = "handoffAutoResumeV21"
        let old = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(old, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(HandoffPrefs.autoResume, "automatic switching stays on by default")
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(HandoffPrefs.autoResume, "off = only Continue here / Play here")
    }

    func testUnknownDeviceIsNotReachableAndCommandIsQueued() {
        let sync = TabSyncService.shared
        let ghost = "v23-test-" + UUID().uuidString
        XCTAssertFalse(sync.isReachable(ghost))
        sync.send(SyncCommand(kind: .pause, target: ghost, url: nil, value: nil))
        XCTAssertTrue(sync.hasQueuedCommand(for: ghost), "a command for a device that is reconnecting waits in the outbox")
    }

    #if os(macOS)
    func testFullscreenFitScriptIsSelfContained() {
        XCTAssertTrue(MacFullscreenFitGuard.fitScript.contains("joetoep-fs-fit"))
        XCTAssertTrue(MacFullscreenFitGuard.fitScript.contains("object-fit:contain"), "forced fit keeps the aspect ratio")
        XCTAssertTrue(MacFullscreenFitGuard.cleanupScript.contains("joetoep-fs-fit"))
    }
    #endif

    #if os(iOS) && canImport(ActivityKit)
    func testLiveActivityStaysFreshUntilTheVideoEnds() {
        let now = Date()
        var state = NowPlayingActivityAttributes.ContentState(title: "a", deviceName: "Mac", deviceKind: "mac", deviceID: "m",
                                                             isThisDevice: false, playing: true, time: 60, duration: 3600, updated: now)
        let stale = LiveActivityManager.staleDate(for: state, anyPlaying: true, now: now)
        XCTAssertEqual(stale.timeIntervalSince(now), 3540 + 120, accuracy: 1, "fresh until the end of the video (+2 min)")
        state.playing = false
        XCTAssertEqual(LiveActivityManager.staleDate(for: state, anyPlaying: false, now: now).timeIntervalSince(now), 600, accuracy: 1)
        state.playing = true; state.duration = 0
        XCTAssertEqual(LiveActivityManager.staleDate(for: state, anyPlaying: true, now: now).timeIntervalSince(now), 3600, accuracy: 1)
    }
    #endif
}
