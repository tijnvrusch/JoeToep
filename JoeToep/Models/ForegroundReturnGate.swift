/// Native fullscreen and Control Center can reactivate the app without a trip
/// through the background. Such activation must not dismiss a new PiP session.
struct ForegroundReturnGate {
    private var returningFromBackground = false
    mutating func willEnterForeground() { returningFromBackground = true }
    mutating func consumeActivation() -> Bool {
        let result = returningFromBackground
        returningFromBackground = false
        return result
    }
}
