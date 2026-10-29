import XCTest
import SwiftUI
@testable import JoeToep

@MainActor
final class V16FeatureTests: XCTestCase {
    func testYouTubeRedAccentIsExactBrandColour() {
        XCTAssertEqual(AccentChoice.youtubeRed.title, "YouTube Red (Tjoep)")
        XCTAssertEqual(AccentChoice.youtubeRed.color(custom: "").hexString, "#FF0033")
    }
    func testDefaultsAndAnimationProfiles() throws {
        let suite = "V16Tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.theaterMode)
        XCTAssertFalse(settings.dataSaverOnCellular, "no data saving by default, also on cellular/hotspot")
        XCTAssertTrue(settings.pipOnTabSwitch)
        XCTAssertEqual(settings.accentChoice, .youtubeRed)
        XCTAssertNotNil(settings.animation(.tabs))
        settings.animationProfiles[AnimationKind.tabs.rawValue] = AnimationProfile(style: .off, speed: 1)
        XCTAssertNil(settings.animation(.tabs), "per-kind override")
        XCTAssertNotNil(settings.animation(.addressBar), "other kinds follow the global style")
        settings.dataSaverOnCellular = true; settings.cellularQuality = .p480; settings.showHomeButton = false
        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.dataSaverOnCellular); XCTAssertEqual(restored.cellularQuality, .p480)
        XCTAssertFalse(restored.showHomeButton)
        XCTAssertEqual(restored.animationProfiles[AnimationKind.tabs.rawValue]?.style, .off)
        restored.resetPreferences()
        XCTAssertTrue(restored.animationProfiles.isEmpty); XCTAssertTrue(restored.showHomeButton)
    }
    func testAnimationSpeedScalesDuration() {
        XCTAssertNil(AnimationStyle.off.animation(speed: 2))
        for style in AnimationStyle.allCases where style != .off { XCTAssertNotNil(style.animation(speed: 0.1)) }
    }
    func testJavaScriptStringEscaping() {
        XCTAssertEqual(WebSession.jsString("a\"b"), "\"a\\\"b\"")
    }
}
