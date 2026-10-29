import XCTest
#if os(iOS)
import UIKit
#endif

/// V15 device tests (iPhone / iPad). They use the offline test player and read the real
/// presentation state from the app's test probe ("fs=… pip=… play=…").
final class V15DeviceTests: XCTestCase {
    private var app: XCUIApplication!
    // Computed: creating a SpringBoard proxy on macOS throws during suite construction.
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }
    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }
    override func tearDownWithError() throws {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }
    private var probe: String { (app.staticTexts["debug.state"].firstMatch.label) }
    private func waitFor(_ text: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe.contains(text) { return true }
            usleep(100_000)
        }
        return probe.contains(text)
    }
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func startVideo() {
        app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 20)); play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 10))
    }
    private var pipWindow: XCUIElement { springboard.windows["PIP-SBInteractionPassThroughView"] }
    /// Every tab keeps its own (hidden) player; act on the visible one.
    private func visible(_ query: XCUIElementQuery) -> XCUIElement {
        for index in 0..<query.count where query.element(boundBy: index).isHittable { return query.element(boundBy: index) }
        return query.firstMatch
    }

    /// The PiP window's return button (top right) must bring the video straight into fullscreen,
    /// still playing, without an inline step.
    @MainActor func testPiPReturnButtonGoesStraightToFullscreenAndKeepsPlaying() throws {
        #if os(iOS)
        startVideo()
        app.webViews.buttons["Fullscreen test video"].tap()
        XCTAssertTrue(waitFor("fs=1", timeout: 5), "entered fullscreen: \(probe)")
        sleep(1)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(pipWindow.waitForExistence(timeout: 8), "PiP started from fullscreen")
        sleep(3)
        attach("PiP running")
        // Show the PiP controls, then press the restore button (identifier "Restore fullscreen")
        // before they fade out again.
        var restored = false
        for _ in 0..<4 where !restored {
            pipWindow.tap()
            let restore = springboard.buttons["Restore fullscreen"]
            if restore.waitForExistence(timeout: 1.5) && restore.isHittable { restore.tap(); restored = true }
        }
        guard restored else {
            let tree = XCTAttachment(string: springboard.debugDescription); tree.name = "PiP controls hierarchy"; tree.lifetime = .keepAlways; add(tree)
            XCTFail("PiP restore button not reachable"); return
        }
        // Sample the state during the transition: it must never show an inline step (fs=0 pip=0).
        var samples: [String] = []
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline { samples.append(probe); usleep(80_000) }
        let log = XCTAttachment(string: samples.joined(separator: "\n")); log.name = "Return samples"; log.lifetime = .keepAlways; add(log)
        attach("After return")
        XCTAssertTrue(waitFor("fs=1", timeout: 3), "back in fullscreen: \(probe)")
        XCTAssertTrue(probe.contains("play=1"), "still playing: \(probe)")
        let inlineSteps = samples.filter { $0.contains("fs=0 pip=0") }
        XCTAssertTrue(inlineSteps.count <= 1, "inline step visible during return: \(inlineSteps.count) samples")
        #else
        throw XCTSkip("Mobile PiP")
        #endif
    }

    /// iPhone: landscape enters fullscreen quickly, portrait returns inline and keeps playing.
    @MainActor func testRotationEntersAndLeavesFullscreenQuickly() throws {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone rotation feature") }
        startVideo()
        XCUIDevice.shared.orientation = .portrait; sleep(1)
        for cycle in 1...3 {
            let start = Date()
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(waitFor("fs=1", timeout: 3), "cycle \(cycle): landscape → fullscreen (\(probe))")
            let enter = Date().timeIntervalSince(start)
            attach("Landscape \(cycle)")
            sleep(1)
            let back = Date()
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(waitFor("fs=0", timeout: 3), "cycle \(cycle): portrait → inline (\(probe))")
            let exit = Date().timeIntervalSince(back)
            sleep(1)
            XCTAssertTrue(probe.contains("play=1"), "cycle \(cycle): keeps playing (\(probe))")
            let timing = XCTAttachment(string: String(format: "enter %.2fs exit %.2fs", enter, exit)); timing.name = "Rotation timing \(cycle)"; timing.lifetime = .keepAlways; add(timing)
            XCTAssertLessThan(enter, 1.5); XCTAssertLessThan(exit, 1.5)
        }
        #else
        throw XCTSkip("Mobile rotation")
        #endif
    }

    /// Heavy load: many tabs, rapid switching, PiP toggles and app switches (Camera on iPhone).
    @MainActor func testStressTabsPiPAndAppSwitching() throws {
        #if os(iOS)
        startVideo()
        let add = app.buttons["tabs.new"]
        for _ in 0..<8 { add.tap() }
        let tabs = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tab.select.'"))
        XCTAssertEqual(tabs.count, 9)
        // (Tapping the tab that is already selected opens the address bar, so never repeat one.)
        for index in [5, 2, 7, 0] { tabs.element(boundBy: index).tap(); usleep(250_000) }
        sleep(1)
        // Every tab has its own (hidden) web view; press the visible one.
        visible(app.webViews.buttons.matching(identifier: "Play test video")).tap()
        XCTAssertTrue(waitFor("play=1", timeout: 6), "first tab plays again: \(probe)")
        let pip = visible(app.buttons.matching(identifier: "toolbar.pip"))
        for cycle in 1...4 {
            pip.tap()
            XCTAssertTrue(pipWindow.waitForExistence(timeout: 8), "manual PiP \(cycle)")
            sleep(2)
            pip.tap(); sleep(2)
        }
        for _ in 0..<8 {
            let close = app.buttons.matching(identifier: "tab.close").firstMatch
            if close.exists { close.tap() }
            usleep(200_000)
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            visible(app.webViews.buttons.matching(identifier: "Fullscreen test video")).tap(); sleep(1)
            XCUIDevice.shared.press(.home); sleep(3)
            XCUIApplication(bundleIdentifier: "com.apple.camera").activate(); sleep(4)
            XCUIDevice.shared.press(.home); sleep(3)
            attach("After Camera")
            XCTAssertTrue(pipWindow.exists, "PiP survives opening the Camera")
            app.activate(); sleep(2)
        }
        XCTAssertTrue(app.buttons.matching(identifier: "toolbar.settings").firstMatch.waitForExistence(timeout: 5))
        #else
        throw XCTSkip("Mobile stress")
        #endif
    }
}
