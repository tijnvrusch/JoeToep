import XCTest
@testable import JoeToep

/// V17: standaardinstellingen, link-opschoning en de "snelste modus" met animaties uit.
@MainActor
final class V17FeatureTests: XCTestCase {
    private func freshSettings() throws -> (AppSettings, () -> Void) {
        let suite = "V17Tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (AppSettings(defaults: defaults), { defaults.removePersistentDomain(forName: suite) })
    }
    func testPrivacyAndNavigationDefaults() throws {
        let (settings, cleanup) = try freshSettings(); defer { cleanup() }
        XCTAssertEqual(settings.cookieBannerMode, .rejectAll, "cookie banners are rejected automatically by default")
        XCTAssertTrue(settings.stripTrackingParameters)
        XCTAssertTrue(settings.globalPrivacyControl)
        XCTAssertTrue(settings.blockTrackers)
        XCTAssertFalse(settings.clearDataOnQuit, "stay signed in by default")
        XCTAssertTrue(settings.spatialAudio)
        XCTAssertTrue(settings.backClosesTab)
        XCTAssertTrue(settings.switchToNewTabs)
        XCTAssertTrue(settings.pipOnAllSites)
        XCTAssertEqual(settings.snapshot.cookieBannerMode, .rejectAll)
    }
    func testSettingsPersistAndReset() throws {
        let suite = "V17Persist." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppSettings(defaults: defaults)
        first.cookieBannerMode = .hideOnly; first.backClosesTab = false; first.spatialAudio = false
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.cookieBannerMode, .hideOnly)
        XCTAssertFalse(second.backClosesTab); XCTAssertFalse(second.spatialAudio)
    }
    func testAnimationsOffSelectsFastestTransitions() throws {
        let (settings, cleanup) = try freshSettings(); defer { cleanup() }
        settings.instantTransitions = false
        settings.animationStyle = .off
        XCTAssertTrue(settings.snapshot.animationsOff)
        XCTAssertTrue(settings.snapshot.instantTransitions, "animations off always uses the fastest transitions")
    }
    func testTrackingParametersAreRemovedButContentParametersStay() throws {
        let dirty = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc123DEF45&si=XYZ&t=42&utm_source=share&pp=ygU"))
        XCTAssertEqual(TrackingParameters.clean(dirty).absoluteString, "https://www.youtube.com/watch?v=abc123DEF45&t=42")
        let shop = try XCTUnwrap(URL(string: "https://shop.nl/p?fbclid=1&gclid=2&kleur=rood"))
        XCTAssertEqual(TrackingParameters.clean(shop).absoluteString, "https://shop.nl/p?kleur=rood")
        let onlyTracking = try XCTUnwrap(URL(string: "https://site.nl/a?utm_campaign=x"))
        XCTAssertEqual(TrackingParameters.clean(onlyTracking).absoluteString, "https://site.nl/a")
        let clean = try XCTUnwrap(URL(string: "https://site.nl/a?q=1"))
        XCTAssertEqual(TrackingParameters.clean(clean), clean)
    }
}
