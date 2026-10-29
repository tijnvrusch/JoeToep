import XCTest
@testable import JoeToep

/// V18: multi-monitor-PiP-regel, live tab-sync (klok, conflicten, diff) en de Watch-feedparser.
@MainActor
final class V18FeatureTests: XCTestCase {
    // MARK: Multi-monitor PiP

    func testSingleDisplayAlwaysStartsPiP() {
        XCTAssertTrue(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 1, joeToepScreen: "1", targetScreen: "1"))
        XCTAssertTrue(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 1, joeToepScreen: "1", targetScreen: nil))
    }
    func testMultipleDisplaysOnlySameScreenStartsPiP() {
        XCTAssertTrue(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 2, joeToepScreen: "1", targetScreen: "1"))
        XCTAssertFalse(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 2, joeToepScreen: "1", targetScreen: "5"))
        XCTAssertFalse(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 4, joeToepScreen: "3", targetScreen: "2"))
    }
    func testUnknownScreenOrDisabledFallsBackToClassicBehaviour() {
        XCTAssertTrue(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 3, joeToepScreen: nil, targetScreen: "2"))
        XCTAssertTrue(MultiMonitorPiPPolicy.shouldStartPiP(screenCount: 3, joeToepScreen: "1", targetScreen: "2", enabled: false))
    }

    // MARK: Sync — klok en conflicten

    private let a = UUID(), b = UUID(), c = UUID()
    private func tab(_ id: UUID, _ v: String, time: Double? = nil) -> SyncTab {
        SyncTab(id: id, url: URL(string: "https://www.youtube.com/watch?v=\(v)"), title: v, time: time)
    }

    func testLocalChangeProducesSnapshotOnlyWhenContentChanges() {
        var ledger = SyncLedger(deviceID: "mac")
        let first = ledger.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: nil)
        XCTAssertNotNil(first)
        XCTAssertNil(ledger.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: nil), "no duplicate sends")
        XCTAssertNil(ledger.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa", time: 1.5)], selectedID: a, playingID: nil), "tiny time drift is not a change")
        let moved = ledger.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa", time: 30)], selectedID: a, playingID: nil)
        XCTAssertNotNil(moved, "a real position change is shared")
        XCTAssertGreaterThan(moved!.version, first!.version)
    }

    func testNewestSnapshotWinsAndAllDevicesConverge() {
        var mac = SyncLedger(deviceID: "mac"), phone = SyncLedger(deviceID: "phone"), pad = SyncLedger(deviceID: "pad")
        let now = Date()
        let m = mac.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: nil, now: now)!
        let p = phone.makeLocal(name: "iPhone", tabs: [tab(b, "bbbbbbbbbbb")], selectedID: b, playingID: nil, now: now.addingTimeInterval(1))!
        // Berichten kruisen elkaar: iedereen ontvangt beide, in verschillende volgorde.
        XCTAssertNotNil(pad.receive(m)); XCTAssertNotNil(pad.receive(p))
        XCTAssertNotNil(mac.receive(p))
        XCTAssertNil(phone.receive(m), "the older Mac snapshot must not overwrite the newer iPhone one")
        XCTAssertEqual(mac.current, p); XCTAssertEqual(pad.current, p); XCTAssertEqual(phone.current, p)
        // Een wijziging ná het ontvangen heeft altijd een hoger nummer (Lamport).
        let next = mac.makeLocal(name: "Mac", tabs: [tab(b, "bbbbbbbbbbb"), tab(c, "ccccccccccc")], selectedID: c, playingID: nil, now: now)!
        XCTAssertGreaterThan(next.version, p.version)
        XCTAssertNotNil(phone.receive(next)); XCTAssertNotNil(pad.receive(next))
    }

    func testEqualVersionsBreakTiesByDeviceID() {
        let x = SyncSnapshot(version: 10, origin: "aaa", originName: "A", tabs: [], selectedID: a, playingID: nil)
        let y = SyncSnapshot(version: 10, origin: "bbb", originName: "B", tabs: [], selectedID: a, playingID: nil)
        XCTAssertTrue(y.supersedes(x)); XCTAssertFalse(x.supersedes(y))
    }

    func testOwnEchoIsIgnored() {
        var ledger = SyncLedger(deviceID: "mac")
        let own = ledger.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: nil)!
        XCTAssertNil(ledger.receive(own))
    }

    func testMessagesRoundTripAsJSON() throws {
        let snap = SyncSnapshot(version: 5, origin: "x", originName: "X", tabs: [tab(a, "aaaaaaaaaaa", time: 12)], selectedID: a, playingID: a)
        for message in [SyncMessage.snapshot(snap), .command(SyncCommand(kind: .play, target: "y", url: snap.tabs[0].url, value: nil)),
                        .hello(deviceID: "x", name: "X")] {
            let data = try XCTUnwrap(message.encoded())
            XCTAssertEqual(SyncMessage.decode(data), message)
        }
    }

    // MARK: Sync — diff

    func testDiffAddsRemovesNavigatesAndOrders() {
        let local: [(id: UUID, url: URL?)] = [(a, URL(string: "https://m.youtube.com/watch?v=aaaaaaaaaaa&pp=xyz")),
                                              (b, URL(string: "https://www.youtube.com/watch?v=bbbbbbbbbbb"))]
        let remote = [tab(c, "ccccccccccc"), tab(a, "aaaaaaaaaaa"), SyncTab(id: b, url: URL(string: "https://www.youtube.com/feed/subscriptions"))]
        let diff = SyncDiff.plan(local: local, remote: remote)
        XCTAssertEqual(diff.add.map(\.id), [c])
        XCTAssertEqual(diff.remove, [])
        XCTAssertEqual(diff.navigate.map(\.id), [b], "mobile vs desktop URL of the same video is not a navigation")
        XCTAssertEqual(diff.order, [c, a, b])
        let closing = SyncDiff.plan(local: local, remote: [tab(a, "aaaaaaaaaaa")])
        XCTAssertEqual(closing.remove, [b])
    }

    func testCanonicalURLUnifiesMobileAndDesktop() {
        let m = SyncTab(id: a, url: URL(string: "https://m.youtube.com/watch?v=abcdefghijk&si=track"))
        let d = SyncTab(id: a, url: URL(string: "https://www.youtube.com/watch?v=abcdefghijk"))
        XCTAssertEqual(m.url, d.url)
        XCTAssertTrue(SyncDiff.sameDestination(URL(string: "https://www.youtube.com/watch?v=abcdefghijk&t=40s"), d.url))
        XCTAssertFalse(SyncDiff.sameDestination(URL(string: "https://www.youtube.com/watch?v=zzzzzzzzzzz"), d.url))
    }

    func testTwoDeviceSimulationStaysConsistentUnderRandomEdits() {
        // 500 willekeurige wijzigingen op twee apparaten, berichten in willekeurige volgorde:
        // aan het eind moeten beide exact dezelfde snapshot hebben.
        var devices = [SyncLedger(deviceID: "mac"), SyncLedger(deviceID: "phone"), SyncLedger(deviceID: "pad")]
        var inbox: [[SyncSnapshot]] = [[], [], []]
        var rng = SystemRandomNumberGenerator()
        let ids = (0..<6).map { _ in UUID() }
        for step in 0..<500 {
            let who = Int.random(in: 0..<3, using: &rng)
            let count = Int.random(in: 1...ids.count, using: &rng)
            let tabs = ids.prefix(count).map { tab($0, String(format: "%011d", step % 97)) }
            if let snap = devices[who].makeLocal(name: "d\(who)", tabs: Array(tabs), selectedID: tabs[0].id, playingID: nil,
                                                 now: Date(timeIntervalSince1970: 1_000_000)) {
                for other in 0..<3 where other != who { inbox[other].append(snap) }
            }
            // Soms een paar berichten afleveren, in willekeurige volgorde.
            for d in 0..<3 where !inbox[d].isEmpty && Bool.random(using: &rng) {
                inbox[d].shuffle(using: &rng)
                _ = devices[d].receive(inbox[d].removeFirst())
            }
        }
        for d in 0..<3 { for message in inbox[d].shuffled() { _ = devices[d].receive(message) } }
        XCTAssertEqual(devices[0].current, devices[1].current)
        XCTAssertEqual(devices[1].current, devices[2].current)
    }

    // MARK: Watch feed

    func testParserReadsClassicAndLockupVideosAndSkipsShorts() throws {
        let data: [String: Any] = ["contents": ["richGridRenderer": ["contents": [
            ["richItemRenderer": ["content": ["videoRenderer": [
                "videoId": "abcdefghijk", "title": ["runs": [["text": "Classic video"]]],
                "ownerText": ["runs": [["text": "Channel A"]]], "lengthText": ["simpleText": "12:34"]]]]],
            ["richItemRenderer": ["content": ["lockupViewModel": [
                "contentId": "lmnopqrstuv", "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
                "metadata": ["lockupMetadataViewModel": [
                    "title": ["content": "New layout video"],
                    "metadata": ["contentMetadataViewModel": ["metadataRows": [["metadataParts": [["text": ["content": "Channel B"]]]]]]]]],
                "contentImage": ["thumbnailViewModel": ["overlays": [["thumbnailOverlayBadgeViewModel": ["thumbnailBadges": [
                    ["thumbnailBadgeViewModel": ["text": "3:21"]]]]]]]]]]]],
            ["richSectionRenderer": ["content": ["reelShelfRenderer": ["items": [["videoRenderer": [
                "videoId": "shortshorts", "title": ["simpleText": "A short"]]]]]]]],
            ["richItemRenderer": ["content": ["lockupViewModel": ["contentId": "PLplaylist1", "contentType": "LOCKUP_CONTENT_TYPE_PLAYLIST"]]]]
        ]]]]
        let json = try JSONSerialization.data(withJSONObject: data)
        let html = "<html><script>var ytInitialData = " + String(data: json, encoding: .utf8)! + ";</script></html>"
        let videos = YouTubeFeedParser.videos(fromHTML: html)
        XCTAssertEqual(videos.map(\.id), ["abcdefghijk", "lmnopqrstuv"])
        XCTAssertEqual(videos[0], FeedVideo(id: "abcdefghijk", title: "Classic video", channel: "Channel A", duration: "12:34"))
        XCTAssertEqual(videos[1].channel, "Channel B"); XCTAssertEqual(videos[1].duration, "3:21")
        XCTAssertEqual(FeedVideo(plist: videos[1].plist), videos[1], "compact Watch transfer round-trips")
    }

    func testParserHandlesBracesInsideStringsAndLimit() throws {
        var items: [[String: Any]] = []
        for i in 0..<50 { items.append(["videoRenderer": ["videoId": String(format: "vid%08d", i), "title": ["simpleText": "Title {with} \"braces\" \(i)"]]]) }
        let json = String(data: try JSONSerialization.data(withJSONObject: ["items": items]), encoding: .utf8)!
        let videos = YouTubeFeedParser.videos(fromHTML: "x ytInitialData = " + json + "; y")
        XCTAssertEqual(videos.count, YouTubeFeedParser.limit)
        XCTAssertTrue(videos[0].title.contains("{with}"))
        XCTAssertTrue(YouTubeFeedParser.videos(fromHTML: "<html>no data</html>").isEmpty)
    }

    // MARK: Instellingen

    func testV18DefaultsAndHelpTexts() throws {
        let suite = "V18Tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.smartMultiMonitorPiP); XCTAssertTrue(settings.tabSync); XCTAssertTrue(settings.showSpeedControl)
        XCTAssertTrue(settings.snapshot.smartMultiMonitorPiP)
        settings.tabSync = false
        XCTAssertFalse(AppSettings(defaults: defaults).tabSync, "setting persists")
        for key in ["Live tab sync", "Smart PiP with multiple displays", "Show speed buttons (slower / faster)", "Automatic PiP when switching apps"] {
            XCTAssertNotNil(SettingHelp.text(for: key), key)
        }
    }

    // MARK: Standaardbrowser-omweg

    func testCustomSchemeLinksOpenAsWebPages() {
        XCTAssertEqual(DefaultBrowser.webURL(fromCustom: URL(string: "joetoep://open?url=https://www.youtube.com/watch?v%3Dabc")!)?.absoluteString,
                       "https://www.youtube.com/watch?v=abc")
        XCTAssertEqual(DefaultBrowser.webURL(fromCustom: URL(string: "joetoep://www.youtube.com/feed/subscriptions")!)?.absoluteString,
                       "https://www.youtube.com/feed/subscriptions")
        XCTAssertNil(DefaultBrowser.webURL(fromCustom: URL(string: "https://example.com")!))
        XCTAssertNil(DefaultBrowser.webURL(fromCustom: URL(string: "joetoep://open?url=javascript:alert(1)")!), "only web links")
    }

    func testAckMessageRoundTrips() throws {
        let ack = SyncMessage.ack(deviceID: "x", name: "iPhone", version: 42, tabs: 3)
        XCTAssertEqual(SyncMessage.decode(try XCTUnwrap(ack.encoded())), ack)
    }

    // MARK: V19.1

    func testHandoffCommandsRoundTripAndOldMessagesStillDecode() throws {
        let cmd = SyncCommand(kind: .handoffTime, target: "mac", url: URL(string: "https://www.youtube.com/watch?v=abcdefghijk"), value: 123.456, from: "phone")
        let msg = SyncMessage.command(cmd)
        XCTAssertEqual(SyncMessage.decode(try XCTUnwrap(msg.encoded())), msg)
        // Een bericht van een oudere versie (zonder "from") moet gewoon blijven werken.
        let old = #"{"command":{"_0":{"kind":"toggle","target":"mac"}}}"#
        if case .command(let decoded)? = SyncMessage.decode(Data(old.utf8)) {
            XCTAssertEqual(decoded.kind, .toggle); XCTAssertNil(decoded.from)
        } else { XCTFail("old command format no longer decodes") }
    }

    func testToolbarPresetsChangeVisibleButtons() throws {
        let suite = "V191Preset." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: "redesignAppliedV19"), "minimal redesign applied once")
        XCTAssertFalse(settings.showLibraryButton); XCTAssertTrue(settings.showPiPButton); XCTAssertTrue(settings.showSpeedControl)
        ToolbarPreset.everything.apply(to: settings)
        XCTAssertTrue(settings.showLibraryButton); XCTAssertTrue(settings.showHistoryButton); XCTAssertTrue(settings.showCreatorTools)
        XCTAssertTrue(AppSettings(defaults: defaults).showHistoryButton, "a chosen layout is not overwritten on the next launch")
    }

    func testSpeedStepDefaults() throws {
        let suite = "V191Speed." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.speedStepSmall, 0.05); XCTAssertEqual(settings.speedStepMedium, 0.25); XCTAssertEqual(settings.speedStepLarge, 0.5)
        XCTAssertEqual(settings.swipeSeekSeconds, 5); XCTAssertEqual(settings.volumeStepPercent, 1)
    }

    func testRateLabels() {
        XCTAssertEqual(PlayerControlBar.rateLabel(1), "1×")
        XCTAssertEqual(PlayerControlBar.rateLabel(1.5), "1.5×")
        XCTAssertEqual(PlayerControlBar.rateLabel(1.05), "1.05×")
        XCTAssertEqual(PlayerControlBar.rateLabel(0.25), "0.25×")
    }

    // MARK: V19.2 — sync onder zware omstandigheden (Mac ↔ iPhone)

    func testDuplicateAndLateMessagesAreHarmless() {
        var mac = SyncLedger(deviceID: "mac"), phone = SyncLedger(deviceID: "phone")
        let base = Date(timeIntervalSince1970: 2_000_000)
        let s1 = phone.makeLocal(name: "iPhone", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: a, now: base)!
        let s2 = phone.makeLocal(name: "iPhone", tabs: [tab(a, "aaaaaaaaaaa"), tab(b, "bbbbbbbbbbb")], selectedID: b, playingID: nil, now: base)!
        XCTAssertNotNil(mac.receive(s2))
        XCTAssertNil(mac.receive(s1), "a late, older message never undoes a newer one")
        XCTAssertNil(mac.receive(s2), "the same message twice is applied once")
        XCTAssertEqual(mac.current?.tabs.count, 2)
    }

    func testReconnectAfterOfflineEditsConvergesToNewest() {
        var mac = SyncLedger(deviceID: "mac"), phone = SyncLedger(deviceID: "phone")
        let t0 = Date(timeIntervalSince1970: 3_000_000)
        let shared = mac.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa")], selectedID: a, playingID: nil, now: t0)!
        _ = phone.receive(shared)
        // Verbinding weg: beide apparaten wijzigen iets; de iPhone later.
        let macOffline = mac.makeLocal(name: "Mac", tabs: [tab(a, "aaaaaaaaaaa"), tab(b, "bbbbbbbbbbb")], selectedID: b, playingID: nil, now: t0.addingTimeInterval(10))!
        let phoneOffline = phone.makeLocal(name: "iPhone", tabs: [tab(c, "ccccccccccc")], selectedID: c, playingID: c, now: t0.addingTimeInterval(20))!
        // Weer verbonden: berichten kruisen.
        XCTAssertNil(phone.receive(macOffline))
        XCTAssertNotNil(mac.receive(phoneOffline))
        XCTAssertEqual(mac.current, phone.current, "both end on the newest change")
    }

    func testTenThousandInterleavedMessagesStayConsistent() {
        var devices = [SyncLedger(deviceID: "mac"), SyncLedger(deviceID: "phone")]
        var queues: [[SyncSnapshot]] = [[], []]
        var rng = SystemRandomNumberGenerator()
        let ids = (0..<5).map { _ in UUID() }
        for step in 0..<10_000 {
            let who = Int.random(in: 0..<2, using: &rng)
            let n = Int.random(in: 1...ids.count, using: &rng)
            let tabs = ids.prefix(n).map { tab($0, String(format: "%011d", step % 13), time: Double(step % 600)) }
            if let snap = devices[who].makeLocal(name: "d\(who)", tabs: Array(tabs), selectedID: tabs[0].id,
                                                 playingID: Bool.random(using: &rng) ? tabs[0].id : nil,
                                                 now: Date(timeIntervalSince1970: 4_000_000 + Double(step / 50))) {
                queues[1 - who].append(snap)
                if Int.random(in: 0..<10, using: &rng) == 0 { queues[1 - who].append(snap) }   // dubbel verzonden
            }
            for d in 0..<2 where !queues[d].isEmpty && Int.random(in: 0..<3, using: &rng) == 0 {
                queues[d].shuffle(using: &rng)                                                   // willekeurige volgorde
                _ = devices[d].receive(queues[d].removeFirst())
            }
        }
        for d in 0..<2 { for m in queues[d] { _ = devices[d].receive(m) } }
        XCTAssertEqual(devices[0].current, devices[1].current)
    }

    func testNewTabPlatformsBuildSearchAndDirectURLs() {
        XCTAssertEqual(MediaPlatform.youtube.url(for: "lofi beats", webEngine: .youtube)?.absoluteString,
                       "https://www.youtube.com/results?search_query=lofi%20beats")
        XCTAssertEqual(MediaPlatform.vimeo.url(for: "skate", webEngine: .youtube)?.host, "vimeo.com")
        XCTAssertEqual(MediaPlatform.youtube.url(for: "vimeo.com/123", webEngine: .youtube)?.absoluteString, "https://vimeo.com/123",
                       "a typed web address opens directly")
        XCTAssertNil(MediaPlatform.twitch.url(for: "   ", webEngine: .youtube))
    }

    func testSettingsSearchFindsByNameAndExplanation() {
        XCTAssertTrue(SettingHelp.search("pip").contains { $0.title == "Automatic PiP when switching apps" })
        XCTAssertTrue(SettingHelp.search("airpods").contains { $0.title.hasPrefix("Spatial audio") }, "matches the explanation too")
        XCTAssertTrue(SettingHelp.search("zzzz-nothing").isEmpty)
        XCTAssertEqual(SettingHelp.search("cookie banners").first?.page, "Privacy & cookies")
    }
}
