import XCTest
#if os(iOS)
import UIKit
#endif
@testable import JoeToep

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testDefaultsAndPersistenceAndReset() throws {
        let suite = "JoeToepTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let initial = AppSettings(defaults: defaults)
        var expected = SettingsSnapshot.standard
        #if os(iOS)
        expected.sitePresentation = UIDevice.current.userInterfaceIdiom == .pad ? .desktop : .mobile
        #endif
        XCTAssertEqual(initial.snapshot, expected)
        initial.quality = .p2160
        initial.blockAds = false
        initial.adBlockLevel = .strict
        initial.hideAdCards = false
        initial.experimentalFilters = true
        initial.showPiPButton = true
        initial.pipFallbackEnabled = false
        initial.backgroundProtection = false
        initial.nativeFullscreen = false
        initial.activateMacOnPiPExit = false
        initial.macFloatingFallback = true
        initial.showBrand = true
        initial.pipOnFullscreenExit = false
        initial.keepPiPOnReturn = false
        initial.pageZoom = 0.9
        initial.videoFit = .fill
        initial.pinchMode = .page
        initial.showNavigationControls = true
        initial.startPage = .watchLater
        initial.acceptServiceNotice()
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.snapshot, initial.snapshot)
        XCTAssertTrue(restored.acceptedServiceNotice)
        restored.resetPreferences()
        XCTAssertEqual(restored.snapshot, expected)
        XCTAssertTrue(restored.acceptedServiceNotice)
    }
    @MainActor
    func testV10DefaultsOverrideLegacySafeFullscreenAndExposePiPReset() throws {
        let suite = "JoeToepTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "nativeFullscreenV4")
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.nativeFullscreen)
        XCTAssertTrue(settings.showNavigationControls)
        XCTAssertTrue(settings.showPiPButton)
        XCTAssertFalse(settings.keepPiPOnReturn)
        XCTAssertFalse(settings.pipOnFullscreenExit)
        settings.nativeFullscreen = false
        XCTAssertFalse(AppSettings(defaults: defaults).nativeFullscreen)
    }
    @MainActor
    func testCorruptValuesFallBackAndZoomIsClamped() throws {
        let suite = "JoeToepTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("nonsense", forKey: "qualityV9")
        defaults.set("nonsense", forKey: "pinchMode")
        defaults.set(200.0, forKey: "pageZoom")
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.quality, SettingsSnapshot.standard.quality)
        XCTAssertEqual(restored.pinchMode, .video)
        XCTAssertEqual(restored.pageZoom, 1.5)
    }
}
