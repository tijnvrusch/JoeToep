import XCTest
@testable import JoeToep

/// V24: crash-regressie (recursieve singleton-init), automatische fullscreen en iPhone-rotatie.
@MainActor
final class V24FeatureTests: XCTestCase {

    /// De Mac-crash van 23.1: SpotifyController.init → publish → MediaHub.rebuild → SpotifyController.shared
    /// (nog in init) → libdispatch "trying to lock recursively". Beide singletons moeten in elke
    /// volgorde zonder her-intree op te vragen zijn, ook als Spotify niet draait.
    func testSpotifyAndMediaHubSingletonsInitialiseWithoutReentrancy() {
        let hub = MediaHub.shared
        let spotify = SpotifyController.shared
        XCTAssertNotNil(hub); XCTAssertNotNil(spotify)
        // Uitgestelde verversing + herbouw laten lopen.
        let done = expectation(description: "deferred refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done.fulfill() }
        wait(for: [done], timeout: 2)
        // Herbouwen vanuit Spotify mag nooit synchroon gebeuren (stress: 2.000 meldingen → één herbouw).
        for _ in 0..<2_000 { hub.spotifyChanged(SpotifyState(running: false)) }
        let rebuilt = expectation(description: "coalesced rebuild")
        DispatchQueue.main.async { rebuilt.fulfill() }
        wait(for: [rebuilt], timeout: 2)
        XCTAssertFalse(hub.sources.contains { $0.kind == .spotify && $0.title.isEmpty })
    }

    func testVersionIsAtLeast24() {
        // V25: exacte versie staat in V25FeatureTests; hier alleen: nooit terug naar vóór 24.
        XCTAssertGreaterThanOrEqual(Int(AppConstants.version.split(separator: ".").first ?? "0") ?? 0, 24)
    }

    #if os(iOS)
    func testAppWindowStaysPortraitUnderAutoRotatedFullscreen() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        // Zonder klem: een gewoon (niet-SwiftUI) venster zonder videocontext volgt het toestel.
        OrientationCoordinator.videoContextActive = false
        XCTAssertFalse(OrientationCoordinator.isVideoFullscreenWindow(nil))
        let plain = UIWindow(frame: .zero)
        plain.rootViewController = UIViewController()
        XCTAssertTrue(OrientationCoordinator.isVideoFullscreenWindow(plain))
        XCTAssertEqual(OrientationCoordinator.supportedOrientations(for: plain), .allButUpsideDown)
        // Met videocontext en auto-draaien aan: fullscreen-venster direct liggend.
        if OrientationCoordinator.autoRotateEnabled {
            OrientationCoordinator.videoContextActive = true
            XCTAssertEqual(OrientationCoordinator.supportedOrientations(for: plain), .landscape)
            OrientationCoordinator.videoContextActive = false
        }
    }
    #endif
}
