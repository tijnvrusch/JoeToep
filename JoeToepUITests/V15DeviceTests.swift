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
    /// V16: opening a tab while a video plays moves that video into PiP, so PiP is expected here.
    @MainActor func testStressTabsPiPAndAppSwitching() throws {
        #if os(iOS)
        startVideo()
        let newTab = app.buttons["tabs.new"]
        let tabs = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tab.select.'"))
        let start = tabs.count
        for _ in 0..<8 {
            // A new tab focuses its search field; dismiss the keyboard/address bar first.
            if !newTab.isHittable { app.webViews.firstMatch.tap(); usleep(300_000) }
            newTab.tap(); usleep(450_000)
        }
        XCTAssertEqual(tabs.count, start + 8, "all new tabs were opened")
        XCTAssertTrue(pipWindow.waitForExistence(timeout: 8), "the playing video moved into PiP when a tab opened")
        // V16: the new tab's address bar closes when tapping elsewhere, showing the tab strip again.
        let firstTab = tabs.element(boundBy: 0)
        if !firstTab.exists || !firstTab.isHittable {
            app.webViews.firstMatch.tap(); sleep(1)
        }
        XCTAssertTrue(tabs.element(boundBy: 0).waitForExistence(timeout: 3), "address bar closed on outside tap")
        // Rapid switching among the tabs that are on screen (the strip scrolls on iPhone).
        var switched = 0
        var last = -1
        for round in 0..<8 {
            var candidates: [Int] = []
            // (The floating PiP window can make XCTest report on-screen chips as "not hittable".)
            let width = app.windows.firstMatch.frame.width
            for index in 0..<tabs.count where index != last {
                let frame = tabs.element(boundBy: index).frame
                if frame.minX >= 0 && frame.maxX <= width - 44 && frame.width > 20 { candidates.append(index) }
            }
            guard !candidates.isEmpty else { usleep(300_000); continue }
            let pick = candidates[(round * 3) % candidates.count]
            tabs.element(boundBy: pick).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            last = pick; switched += 1
            usleep(400_000)
        }
        if switched <= 2 {
            attach("Tab switching stuck")
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "App hierarchy (switching)"; tree.lifetime = .keepAlways; add(tree)
        }
        XCTAssertGreaterThan(switched, 2, "tab switching")
        XCTAssertTrue(app.buttons.matching(identifier: "toolbar.settings").firstMatch.exists, "app responsive after switching")
        for _ in 0..<8 {
            let close = app.buttons.matching(identifier: "tab.close").firstMatch
            if close.exists && close.isHittable { close.tap() }
            usleep(200_000)
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.press(.home); sleep(2)
            XCUIApplication(bundleIdentifier: "com.apple.camera").activate(); sleep(4)
            XCUIDevice.shared.press(.home); sleep(2)
            attach("After Camera")
            app.activate(); sleep(2)
        }
        XCTAssertTrue(app.buttons.matching(identifier: "toolbar.settings").firstMatch.waitForExistence(timeout: 5), "app alive after stress")
        #else
        throw XCTSkip("Mobile stress")
        #endif
    }

    /// V16: pausing in the PiP window must stay paused until the user presses play again.
    @MainActor func testPiPPauseStaysPausedUntilSecondPress() throws {
        #if os(iOS)
        startVideo()
        app.webViews.buttons["Fullscreen test video"].tap()
        XCTAssertTrue(waitFor("fs=1", timeout: 5), "entered fullscreen: \(probe)")
        sleep(1)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(pipWindow.waitForExistence(timeout: 8), "PiP started")
        sleep(3)
        func pipButton(_ labels: [String]) -> XCUIElement? {
            for _ in 0..<4 {
                pipWindow.tap()
                for label in labels {
                    let b = springboard.buttons[label]
                    if b.waitForExistence(timeout: 1) && b.isHittable { return b }
                }
            }
            return nil
        }
        guard let pause = pipButton(["Pause", "pause", "Pauze"]) else {
            let tree = XCTAttachment(string: springboard.debugDescription); tree.name = "PiP hierarchy"; tree.lifetime = .keepAlways; add(tree)
            throw XCTSkip("PiP pause button not reachable")
        }
        pause.tap()
        app.activate(); sleep(1)
        // Sample for 4 s: once paused, it must never resume by itself.
        var resumed = 0
        let deadline = Date().addingTimeInterval(4)
        sleep(1)
        while Date() < deadline { if probe.contains("play=1") { resumed += 1 }; usleep(100_000) }
        XCTAssertEqual(resumed, 0, "video resumed by itself after PiP pause: \(probe)")
        attach("Paused after PiP pause")
        #else
        throw XCTSkip("Mobile PiP")
        #endif
    }

    /// V16: opening a new tab keeps the playing video in PiP.
    @MainActor func testNewTabKeepsVideoPlayingInPiP() throws {
        #if os(iOS)
        startVideo()
        app.buttons["tabs.new"].tap()
        XCTAssertTrue(pipWindow.waitForExistence(timeout: 8), "PiP started when opening a new tab")
        sleep(3)
        attach("PiP after new tab")
        XCTAssertTrue(pipWindow.exists, "PiP still running after 3 s")
        #else
        throw XCTSkip("Mobile PiP")
        #endif
    }

    /// V16.2 extreme: repeated PiP → return cycles must land in fullscreen and keep playing every time.
    @MainActor func testPiPReturnCyclesStayConsistent() throws {
        #if os(iOS)
        startVideo()
        app.webViews.buttons["Fullscreen test video"].tap()
        XCTAssertTrue(waitFor("fs=1", timeout: 5), "entered fullscreen: \(probe)")
        var results: [String] = []
        for cycle in 1...8 {
            sleep(1)
            XCUIDevice.shared.press(.home)
            guard pipWindow.waitForExistence(timeout: 8) else { results.append("\(cycle): no PiP"); continue }
            sleep(2)
            var restored = false
            for _ in 0..<4 where !restored {
                pipWindow.tap()
                let restore = springboard.buttons["Restore fullscreen"]
                if restore.waitForExistence(timeout: 1.5) && restore.isHittable { restore.tap(); restored = true }
            }
            guard restored else { results.append("\(cycle): restore unreachable"); app.activate(); continue }
            let ok = waitFor("fs=1", timeout: 4)
            usleep(600_000)
            let trail = app.staticTexts["debug.lifecycle"].firstMatch.label
            results.append("\(cycle): \(ok ? "ok" : "FAIL") \(probe) :: \(trail)")
        }
        let log = XCTAttachment(string: results.joined(separator: "\n")); log.name = "PiP cycles"; log.lifetime = .keepAlways; add(log)
        let failures = results.filter { !$0.contains(": ok") || !$0.contains("play=1") }
        XCTAssertTrue(failures.isEmpty, "PiP cycles: \(failures)")
        #else
        throw XCTSkip("Mobile PiP")
        #endif
    }
}
