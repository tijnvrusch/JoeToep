import XCTest
@testable import JoeToep

final class ExperimentalFilterParserTests: XCTestCase {
    func testOnlyAllowedYouTubeContainersAreImportedAndDeduplicated() {
        let source = """
        ! Fixture, not a downloaded EasyList snapshot
        youtube.com##ytd-ad-slot-renderer, #player-ads
        m.youtube.com##ytd-ad-slot-renderer
        example.org##ytm-ad-slot-renderer
        youtube.com##video, body, #movie_player
        youtube.com##+js(abort-on-property-read, player)
        youtube.com#@##masthead-ad
        youtube.com##div:has(video)
        youtube.com,~m.youtube.com##ytm-ad-slot-renderer
        """
        XCTAssertEqual(ExperimentalFilterParser.selectors(from: source), ["#player-ads", "ytd-ad-slot-renderer"])
    }
    func testUnsupportedListDoesNotReplaceWorkingRulesWithEmptyRules() {
        XCTAssertThrowsError(try ExperimentalFilterParser.rulesJSON(from: "youtube.com##video"))
    }
    func testGeneratedRulesAreCosmeticAndScoped() throws {
        let text = try ExperimentalFilterParser.rulesJSON(from: "youtube.com##ytd-ad-slot-renderer")
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]])
        XCTAssertEqual(rules.count, 1)
        let trigger = try XCTUnwrap(rules[0]["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["if-domain"] as? [String], ["youtube.com", "www.youtube.com", "m.youtube.com"])
        let action = try XCTUnwrap(rules[0]["action"] as? [String: String])
        XCTAssertEqual(action, ["type": "css-display-none", "selector": "ytd-ad-slot-renderer"])
    }
}
