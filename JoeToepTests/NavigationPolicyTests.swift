import XCTest
@testable import JoeToep

final class NavigationPolicyTests: XCTestCase {
    private func url(_ value: String) throws -> URL {
        try XCTUnwrap(URL(string: value))
    }

    func testNormalYouTubeNavigationIsAllowed() throws {
        let policy = NavigationPolicy(settings: .standard)
        XCTAssertEqual(policy.decision(for: try url("https://m.youtube.com/watch?v=abc123")), .allow)
        XCTAssertEqual(policy.decision(for: try url("https://youtu.be/abc123")), .allow)
    }

    func testGoogleSignInHostsAreAllowed() throws {
        let policy = NavigationPolicy(settings: .standard)
        XCTAssertEqual(policy.decision(for: try url("https://accounts.google.com/ServiceLogin")), .allow)
        XCTAssertEqual(policy.decision(for: try url("https://ssl.gstatic.com/example")), .allow)
    }

    func testV15OtherWebsitesOpenInAppByDefault() throws {
        let policy = NavigationPolicy(settings: .standard)
        XCTAssertEqual(policy.decision(for: try url("https://example.com/story")), .allow)
        XCTAssertEqual(policy.decision(for: try url("mailto:hello@example.com")), .openExternally)
    }

    func testExternalWebsiteIsRoutedOutOfApp() throws {
        var settings = SettingsSnapshot.standard
        settings.openWebLinksInApp = false
        let policy = NavigationPolicy(settings: settings)
        XCTAssertEqual(policy.decision(for: try url("https://example.com/story")), .openExternally)
        XCTAssertEqual(policy.decision(for: try url("https://youtube.com.example.com/watch?v=fake")), .openExternally)
        XCTAssertEqual(policy.decision(for: try url("mailto:hello@example.com")), .openExternally)
    }

    func testShortsFilterOnlyBlocksShorts() throws {
        var settings = SettingsSnapshot.standard
        settings.blockShortsNavigation = true
        let policy = NavigationPolicy(settings: settings)

        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/shorts/abc")), .block(.shorts))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/watch?v=abc")), .allow)
    }

    func testPostAndCommunityFilter() throws {
        var settings = SettingsSnapshot.standard
        settings.blockPostsNavigation = true
        let policy = NavigationPolicy(settings: settings)

        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/post/Ug123")), .block(.posts))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/@creator/community")), .block(.posts))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/@creator/posts")), .block(.posts))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/@creator/videos")), .allow)
    }

    func testPremiumFilter() throws {
        var settings = SettingsSnapshot.standard
        settings.blockPremiumDestinations = true
        let policy = NavigationPolicy(settings: settings)

        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/premium")), .block(.premium))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/paid_memberships")), .block(.premium))
        XCTAssertEqual(policy.decision(for: try url("https://www.youtube.com/watch?v=abc")), .allow)
    }

    func testAutomaticPiPExcludesHomePreviewsAndLookalikeHosts() throws {
        XCTAssertTrue(NavigationPolicy.isPlaybackPage(try url("https://m.youtube.com/watch?v=abc")))
        XCTAssertTrue(NavigationPolicy.isPlaybackPage(try url("https://www.youtube.com/live/abc")))
        XCTAssertFalse(NavigationPolicy.isPlaybackPage(try url("https://m.youtube.com/")))
        XCTAssertFalse(NavigationPolicy.isPlaybackPage(try url("https://youtube.com.example.org/watch?v=abc")))
        XCTAssertFalse(NavigationPolicy.isPlaybackPage(nil))
    }
}
