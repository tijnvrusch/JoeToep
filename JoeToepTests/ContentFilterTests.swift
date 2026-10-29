import XCTest
@testable import JoeToep

final class ContentFilterTests: XCTestCase {
    @MainActor
    func testBundledRulesAreAvailableToWebKit() async {
        let failures = await ContentFilterController().prepare()
        XCTAssertTrue(failures.isEmpty, "WebKit rejected filter groups: \(failures)")
    }
}
