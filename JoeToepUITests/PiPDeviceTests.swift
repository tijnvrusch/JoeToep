import XCTest
final class PiPDeviceTests: XCTestCase {
    @MainActor func testAutomaticInlinePiPSurvivesBackgroundAndReturnsPlaying() throws {
        #if os(iOS)
        // Known WebKit limit (V10 analysis): with MediaSource, iOS only prepares automatic PiP for
        // fullscreen video; a small inline player cannot enter PiP after the app is left.
        XCTExpectFailure("Inline automatic PiP needs the Apple streaming engine (360p)", strict: false)
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 20)); play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        sleep(6)
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = "Native PiP after six seconds in background"; evidence.lifetime = .keepAlways; add(evidence)
        let hierarchy = XCTAttachment(string: springboard.debugDescription)
        hierarchy.name = "SpringBoard PiP hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        let pip = springboard.descendants(matching: .any).matching(NSPredicate(format:
            "identifier CONTAINS[c] 'picture' OR label CONTAINS[c] 'picture in picture' OR identifier CONTAINS[c] 'PiP'")).firstMatch
        XCTAssertTrue(pip.exists, "System PiP must remain visible after six seconds; inspect attached screenshot/hierarchy.")
        app.activate()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 10))
        #else
        throw XCTSkip("This home-swipe test targets a physical iPhone or iPad.")
        #endif
    }
    @MainActor func testManualPiPRemainsVisible() throws { try compareEntry(fullscreen: false) }
    @MainActor func testSystemFullscreenPiPRemainsVisible() throws { try compareEntry(fullscreen: true) }
    @MainActor private func compareEntry(fullscreen: Bool) throws {
        #if os(iOS)
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--skip-onboarding"];app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 15));play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 8))
        app.webViews.buttons[fullscreen ? "Fullscreen test video" : "Native PiP gesture"].tap()
        sleep(2)
        XCUIDevice.shared.press(.home);sleep(8)
        let shot=XCTAttachment(screenshot:XCUIScreen.main.screenshot());shot.name=fullscreen ? "System fullscreen PiP 8s" : "Manual PiP 8s";shot.lifetime = .keepAlways;add(shot)
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        XCTAssertTrue(springboard.windows["PIP-SBInteractionPassThroughView"].exists, "Real system PiP window must still be visible")
        let tree=XCTAttachment(string:springboard.debugDescription);tree.name="PiP comparison hierarchy";tree.lifetime = .keepAlways;add(tree)
        app.activate()
        #else
        throw XCTSkip("Physical mobile comparison")
        #endif
    }

}

extension PiPDeviceTests {
    @MainActor func testRepeatedFullscreenBackgroundReturnsAndCamera() throws {
        #if os(iOS)
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--skip-onboarding"]; app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 15)); play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 8))
        app.webViews.buttons["Fullscreen test video"].tap()
        sleep(2)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for cycle in 1...5 {
            XCUIDevice.shared.press(.home)
            sleep(8)
            XCTAssertTrue(system.windows["PIP-SBInteractionPassThroughView"].exists, "PiP visible after cycle \(cycle)")
            let frame = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); frame.name = "PiP cycle \(cycle)"; frame.lifetime = .keepAlways; add(frame)
            app.activate(); sleep(2)
            let tree = XCTAttachment(string: app.debugDescription); tree.name = "Returned player cycle \(cycle)"; tree.lifetime = .keepAlways; add(tree)
        }
        XCUIDevice.shared.press(.home);sleep(2)
        let camera = XCUIApplication(bundleIdentifier: "com.apple.camera")
        camera.activate();sleep(5)
        XCUIDevice.shared.press(.home);sleep(5)
        XCTAssertTrue(system.windows["PIP-SBInteractionPassThroughView"].exists, "PiP must still have a visible video window after Camera")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot());shot.name = "PiP after Camera";shot.lifetime = .keepAlways;add(shot)
        app.activate()
        #else
        throw XCTSkip("Physical mobile lifecycle test")
        #endif
    }
    @MainActor func testVideoAirPlayToolbarOpensRoutePicker() throws {
        #if os(iOS)
        let app = XCUIApplication();app.launchArguments = ["--uitesting", "--skip-onboarding"];app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 15));play.tap()
        app.buttons["toolbar.airplay"].tap();sleep(2)
        let image = XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Video AirPlay route picker";image.lifetime = .keepAlways;add(image)
        let tree = XCTAttachment(string:app.debugDescription);tree.name="Video AirPlay hierarchy";tree.lifetime = .keepAlways;add(tree)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.collectionViews["Route Picker Items"].waitForExistence(timeout: 5), "The system video route picker must be visible")
        let systemTree = XCTAttachment(string: system.debugDescription);systemTree.name="AirPlay system hierarchy";systemTree.lifetime = .keepAlways;add(systemTree)
        #else
        throw XCTSkip("Mobile video route picker")
        #endif
    }
}

extension PiPDeviceTests {
    @MainActor func testLongPressResetsNativePiPWithoutReloadingVideo() throws {
        #if os(iOS)
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--skip-onboarding"];app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 15));play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 10))
        let control = app.buttons["toolbar.pip"]
        control.press(forDuration: 0.5)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(system.windows["PIP-SBInteractionPassThroughView"].waitForExistence(timeout: 8))
        sleep(2)
        control.press(forDuration: 0.5)
        sleep(3)
        XCTAssertTrue(system.windows["PIP-SBInteractionPassThroughView"].exists)
        XCUIDevice.shared.press(.home);sleep(8)
        XCTAssertTrue(system.windows["PIP-SBInteractionPassThroughView"].exists)
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot());proof.name="Long press reset then background PiP";proof.lifetime = .keepAlways;add(proof)
        app.activate()
        #else
        throw XCTSkip("Mobile native PiP reset")
        #endif
    }
}
