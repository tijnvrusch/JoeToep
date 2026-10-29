import XCTest
@testable import JoeToep

/// V25: play/pauze precies één keer (iPhone), fullscreen altijd te verlaten en geen hapering (Mac).
@MainActor
final class V25FeatureTests: XCTestCase {

    func testVersionIs25() {
        XCTAssertEqual(AppConstants.version, "25.0.0")
    }

    /// De klokwaarde van het moment dat het andere apparaat begon te spelen reist mee, zodat het alleen
    /// activeren van deze app een net gestarte video daar niet "afpakt".
    func testRemotePlaybackCarriesPlayStamp() {
        let url = URL(string: "https://www.youtube.com/watch?v=abcdefghijk")!
        let stamp = UInt64(Date().timeIntervalSince1970 * 1000)
        let remote = BrowserWorkspace.RemotePlayback(device: "iphone", tabID: UUID(), url: url, time: 12, receivedAt: Date(),
                                                     playStamp: stamp)
        XCTAssertEqual(remote.playStamp, stamp)
        XCTAssertFalse(remote.paused)
        let legacy = BrowserWorkspace.RemotePlayback(device: "iphone", tabID: UUID(), url: url, time: 12, receivedAt: Date())
        XCTAssertNil(legacy.playStamp, "older devices without a stamp keep the old behaviour")
    }

    /// De pagina-scripts in de app-bundel bevatten de V25-bewaking (geen oude kopie in de build).
    func testBundledScriptsContainV25PlayPauseGuards() throws {
        let media = try XCTUnwrap(Bundle.main.url(forResource: "mediaCompatibility", withExtension: "js"))
        let prefs = try XCTUnwrap(Bundle.main.url(forResource: "sitePreferences", withExtension: "js"))
        let mediaText = try String(contentsOf: media, encoding: .utf8)
        let prefsText = try String(contentsOf: prefs, encoding: .utf8)
        XCTAssertTrue(mediaText.contains("userPlayIntent"))
        XCTAssertTrue(mediaText.contains("nativeUserPlay"), "▶ in Apple's fullscreen player counts as your tap")
        XCTAssertTrue(mediaText.contains("allowedPlay"), "a started video is judged once, not again on every 'playing'")
        XCTAssertTrue(prefsText.contains("userPlayIntent"), "restore step never pauses your own start")
    }
}
