import XCTest
@testable import JoeToep

final class PiPStateMachineTests: XCTestCase {
    func testDeduplicatesOverlappingRequests() throws {
        var state = PiPStateMachine()
        let token = try XCTUnwrap(state.begin(.manual))
        XCTAssertNil(state.begin(.appSwitch))
        XCTAssertTrue(state.isRequesting)
        XCTAssertTrue(state.fail(token, message: "Denied"))
        XCTAssertNotNil(state.begin(.manual))
    }
    func testLateFailureCannotOverrideNativeSuccess() throws {
        var state = PiPStateMachine()
        let token = try XCTUnwrap(state.begin(.appSwitch))
        state.confirmNative()
        XCTAssertFalse(state.fail(token, message: "late"))
        XCTAssertEqual(state.state, .native)
    }
    func testStaleTokenCannotCancelNewRequest() throws {
        var state = PiPStateMachine()
        let first = try XCTUnwrap(state.begin(.manual))
        state.reset()
        let second = try XCTUnwrap(state.begin(.manual))
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(state.fail(first, message: "stale"))
        XCTAssertEqual(state.state, .requesting(second))
    }
    func testFloatingAndNativeDoNotExitEachOtherAccidentally() {
        var state = PiPStateMachine()
        state.confirmFloating(); state.exitNative()
        XCTAssertEqual(state.state, .floating)
        state.confirmNative(); state.exitFloating()
        XCTAssertEqual(state.state, .native)
    }
    func testTenThousandTransitionCycles() throws {
        var state = PiPStateMachine()
        for _ in 0..<10000 {
            let token = try XCTUnwrap(state.begin(.appSwitch))
            state.confirmNative()
            XCTAssertFalse(state.fail(token, message: "late"))
            state.exitNative()
            XCTAssertEqual(state.state, .idle)
        }
    }
}
