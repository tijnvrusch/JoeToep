import XCTest
@testable import JoeToep

final class ForegroundReturnGateTests: XCTestCase {
    func testPresenterAndControlCenterActivationDoNotDismissPiP() {
        var gate = ForegroundReturnGate()
        for _ in 0..<100 { XCTAssertFalse(gate.consumeActivation()) }
    }
    func testActualForegroundReturnIsConsumedExactlyOnce() {
        var gate = ForegroundReturnGate()
        for _ in 0..<100 {
            gate.willEnterForeground()
            XCTAssertTrue(gate.consumeActivation())
            XCTAssertFalse(gate.consumeActivation())
        }
    }
}
