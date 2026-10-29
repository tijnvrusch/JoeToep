import XCTest
@testable import JoeToep

final class WebBridgeEventTests: XCTestCase {
    func testWholeSnapshotIsDecodedTogether() throws {
        let e = try XCTUnwrap(WebBridgeEvent(body: ["event": "state", "documentID": "doc1",
            "videoID": 4, "playing": true, "fullscreen": false, "pip": true, "width": 3840, "height": 2160] as [String: Any]))
        XCTAssertTrue(e.pip); XCTAssertFalse(e.fullscreen)
        XCTAssertEqual(e.width, 3840); XCTAssertEqual(e.height, 2160)
    }
    func testUnknownAndUnscopedEventsAreRejected() {
        XCTAssertNil(WebBridgeEvent(body: ["event": "unknown", "documentID": "x"]))
        XCTAssertNil(WebBridgeEvent(body: ["event": "state"]))
        XCTAssertNil(WebBridgeEvent(body: ["event": "state", "documentID": ""]))
        XCTAssertNil(WebBridgeEvent(body: "play"))
    }
    func testHostileDimensionsAreClamped() throws {
        let e = try XCTUnwrap(WebBridgeEvent(body: ["event": "state", "documentID": "x",
            "width": -10, "height": 999999] as [String: Any]))
        XCTAssertEqual(e.width, 0); XCTAssertEqual(e.height, 16384)
    }
}
