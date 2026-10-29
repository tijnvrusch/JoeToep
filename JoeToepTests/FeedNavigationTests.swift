import XCTest
@testable import JoeToep

final class FeedNavigationTests: XCTestCase {
    func testHistoryUsesCanonicalHostAndDesktopAcrossDevices() {
        XCTAssertEqual(StartPage.history.url.absoluteString, "https://www.youtube.com/feed/history")
        for phone in [false, true] {
            XCTAssertTrue(FeedNavigation.needsDesktop(StartPage.history.url, isPhone: phone))
        }
    }
    func testLibraryOnlyOverridesPhonePresentation() {
        XCTAssertEqual(StartPage.library.url.host, "www.youtube.com")
        XCTAssertTrue(FeedNavigation.needsDesktop(StartPage.library.url, isPhone: true))
        XCTAssertFalse(FeedNavigation.needsDesktop(StartPage.library.url, isPhone: false))
    }
    func testVideoAndLoginPresentationAreNotForcedToDesktop() throws {
        for raw in ["https://m.youtube.com/watch?v=test", "https://accounts.google.com/feed/history", "https://example.org/feed/history"] {
            XCTAssertFalse(FeedNavigation.needsDesktop(try XCTUnwrap(URL(string: raw)), isPhone: true))
        }
    }
}
