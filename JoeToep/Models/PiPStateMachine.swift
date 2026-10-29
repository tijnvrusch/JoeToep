import Foundation

/// A late rejection cannot overwrite a successful native entry.
struct PiPStateMachine: Equatable {
    enum Reason: String { case manual, appSwitch, fullscreenExit }
    enum State: Equatable { case idle, requesting(Int), native, floating }
    private(set) var state: State = .idle
    private(set) var serial = 0
    private(set) var reason: Reason = .manual
    private(set) var lastFailure: String?
    var isActive: Bool { state == .native || state == .floating }
    var isRequesting: Bool { if case .requesting = state { return true }; return false }
    mutating func begin(_ reason: Reason) -> Int? {
        guard state == .idle else { return nil }
        serial += 1; state = .requesting(serial); self.reason = reason; lastFailure = nil
        return serial
    }
    mutating func confirmNative() { state = .native; lastFailure = nil }
    mutating func confirmFloating() { state = .floating; lastFailure = nil }
    @discardableResult
    mutating func fail(_ token: Int, message: String) -> Bool {
        guard state == .requesting(token) else { return false }
        state = .idle; lastFailure = message; return true
    }
    mutating func exitNative() { if state == .native { state = .idle } }
    mutating func exitFloating() { if state == .floating { state = .idle } }
    mutating func reset() { state = .idle; serial += 1; lastFailure = nil }
}
