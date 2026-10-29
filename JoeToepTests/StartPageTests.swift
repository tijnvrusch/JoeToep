import XCTest
@testable import JoeToep

final class StartPageTests: XCTestCase {
    func testAllFiveStartPagesAreSecure() {
        XCTAssertEqual(StartPage.allCases.count, 5)
        for page in StartPage.allCases {
            XCTAssertEqual(page.url.scheme, "https")
            XCTAssertTrue(NavigationPolicy.isYouTubeHost(page.url.host ?? ""))
        }
    }
    func testWatchLaterHasCorrectPlaylist() {
        let items = URLComponents(url: StartPage.watchLater.url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertTrue(items?.contains(where: { $0.name == "list" && $0.value == "WL" }) == true)
    }
    func testQualityMigrationDoesNotForceDesktopOnIPhone() {
        for legacy in ["automatic", "ultraHD", "highDefinition", "dataSaver", "invalid"] {
            XCTAssertEqual(PlaybackQualityPreference.restored(legacy), .automatic)
        }
        XCTAssertEqual(PlaybackQualityPreference.restored("hd2160"), .p2160)
        XCTAssertEqual(SitePresentation.mobile.contentMode, .mobile)
    }
}
