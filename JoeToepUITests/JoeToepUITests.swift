import XCTest

final class JoeToepUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
    }
    private var tabs: XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'tab.select.'"))
    }
    func testTabsSurviveRelaunchAndCloseStaysClosed() {
        launch(["--skip-onboarding"])
        let add = app.buttons["tabs.new"]
        XCTAssertTrue(add.waitForExistence(timeout: 10));add.activateControl();add.activateControl()
        XCTAssertEqual(tabs.count, 3)
        app.terminate();launch(["--skip-onboarding", "--restore-tabs"])
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 10))
        XCTAssertEqual(tabs.count, 3)
        tabs.element(boundBy: 1).activateControl()
        let close = app.buttons.matching(identifier: "tab.close").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.activateControl()
        XCTAssertEqual(tabs.count, 2)
        app.terminate();launch(["--skip-onboarding", "--restore-tabs"])
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 10))
        XCTAssertEqual(tabs.count, 2)
    }
    /// V15: tabs share the whole strip when there are few, shrink when there are many.
    func testTabsFillWidthAndShrinkWhenMany() {
        launch(["--skip-onboarding", "--tab-close-always"])
        let add = app.buttons["tabs.new"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        let single = tabs.firstMatch.frame.width
        XCTAssertGreaterThan(single, window.width * 0.5, "one tab uses most of the width")
        add.activateControl()
        let two = tabs.firstMatch.frame.width
        XCTAssertLessThan(two, single); XCTAssertGreaterThan(two, window.width * 0.3)
        for _ in 0..<10 { add.activateControl() }
        XCTAssertEqual(tabs.count, 12)
        XCTAssertGreaterThanOrEqual(tabs.element(boundBy: 11).frame.width, 80, "minimum readable width")
        // Stress: close everything back to one tab quickly.
        for _ in 0..<11 {
            let close = app.buttons.matching(identifier: "tab.close").firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 3)); close.activateControl()
        }
        XCTAssertEqual(tabs.count, 1)
        XCTAssertTrue(app.buttons["toolbar.settings"].isHittable)
    }
    /// V15: tapping the selected tab turns it into an address bar.
    func testSelectedTabBecomesAddressBar() {
        launch(["--skip-onboarding"])
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 10))
        tabs.firstMatch.activateControl()
        let field = app.textFields["tabs.address"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.buttons["tabs.address.cancel"].activateControl()
        XCTAssertTrue(app.buttons["tabs.new"].waitForExistence(timeout: 5))
    }
    func testEnhancedFullscreenKeyboardSeekingAndVolume() throws {
        #if os(macOS)
        launch(["--skip-onboarding"])
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 10));play.click()
        app.webViews.buttons["Reset test clock"].click()
        app.webViews.buttons["Safe fullscreen test"].click()
        func expectTime(_ value: String) {
            XCTAssertTrue(app.webViews.staticTexts[value + " / 1:36"].waitForExistence(timeout: 4))
        }
        expectTime("0:00")
        app.typeKey(.rightArrow, modifierFlags: []);expectTime("0:05")
        app.typeKey(.rightArrow, modifierFlags: .option);expectTime("0:35")
        app.typeKey(.rightArrow, modifierFlags: [.command, .option]);expectTime("1:35")
        app.typeKey(.leftArrow, modifierFlags: [.command, .option]);expectTime("0:35")
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(app.webViews.staticTexts["65%"].waitForExistence(timeout: 4))
        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(app.webViews.staticTexts["70%"].waitForExistence(timeout: 4))
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(app.webViews.buttons["Pause"].waitForExistence(timeout: 4))
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(app.webViews.buttons["Play"].waitForExistence(timeout: 4))
        app.webViews.buttons["Close fullscreen"].click()
        #else
        throw XCTSkip("Mac hardware keyboard controls")
        #endif
    }
    func testOnboardingAndSettings() {
        launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.activateControl()
        let settings = app.buttons["toolbar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.activateControl()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].activateControl()
    }
    func testNavigationFitsWindowAndPinnedControlsStayVisible() {
        launch(["--skip-onboarding"])
        let settings = app.buttons["toolbar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        #if os(iOS)
        XCTAssertGreaterThan(settings.frame.midY, window.midY, "Mobile navigation must be at the bottom")
        #else
        XCTAssertLessThan(settings.frame.midY, window.midY, "Mac navigation must be at the top")
        #endif
        for key in ["toolbar.settings", "toolbar.back", "toolbar.forward", "toolbar.quality"] {
            let element = app.descendants(matching: .any)[key].firstMatch
            XCTAssertTrue(element.exists)
            XCTAssertGreaterThanOrEqual(element.frame.minX, window.minX - 1)
            XCTAssertLessThanOrEqual(element.frame.maxX, window.maxX + 1)
            XCTAssertTrue(element.isHittable)
        }
    }
    func testPiPResetButtonVisibleByDefaultAndCanBeHidden() {
        launch(["--skip-onboarding"])
        let settings = app.buttons["toolbar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toolbar.pip"].exists)
        settings.activateControl()
        openSettingsPage("Playback & Picture in Picture")
        let toggle = app.descendants(matching: .any)["settings.showPiPButton"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        #if os(iOS)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).activateControl()
        XCTAssertEqual(toggle.value as? String, "0")
        #else
        toggle.activateControl()
        #endif
        app.buttons["settings.done"].firstMatch.activateControl()
        XCTAssertFalse(app.buttons["toolbar.pip"].waitForExistence(timeout: 2))
    }
    private func openSettingsPage(_ title: String) {
        let link = app.descendants(matching: .any)["settings.page." + title].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5)); link.activateControl()
    }
    func testDefaultDestinationsExcludeHistoryAndPlaylist() {
        launch(["--skip-onboarding"])
        for key in ["home", "subscriptions", "library"] {
            XCTAssertTrue(app.buttons["toolbar." + key].waitForExistence(timeout: 5))
        }
    }
    func testRefreshIsImmediatelyBeforeHome() {
        launch(["--skip-onboarding"])
        let refresh = app.buttons["toolbar.refresh"]
        let home = app.buttons["toolbar.home"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(home.exists)
        XCTAssertLessThanOrEqual(refresh.frame.maxX, home.frame.minX + 1)
        XCTAssertTrue(refresh.isHittable)
    }
    func testSafeFullscreenCanAlwaysBeClosed() {
        launch(["--skip-onboarding"])
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 8)); play.activateControl()
        let fullscreen = app.webViews.buttons["Safe fullscreen test"]
        XCTAssertTrue(fullscreen.exists); fullscreen.activateControl()
        let close = app.webViews.buttons["Close fullscreen"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.activateControl()
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(play.exists)
    }
    func testNoticeDisappearsAfterFiveSeconds() {
        launch(["--skip-onboarding", "--show-test-notice"])
        let banner = app.descendants(matching: .any)["notice.banner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 7), .completed)
    }
    func testVideoDoesNotImmediatelyPauseAfterPlay() {
        launch(["--skip-onboarding"])
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 8)); play.activateControl()
        let playing = app.webViews.staticTexts["State: playing"]
        XCTAssertTrue(playing.waitForExistence(timeout: 5))
        let paused = app.webViews.staticTexts["State: pause"]
        let pauseExpectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: paused)
        pauseExpectation.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [pauseExpectation], timeout: 8), .completed)
    }

    func testNativeFullscreenAndFallbackPreferences() {
        launch(["--skip-onboarding"])
        let settings = app.buttons["toolbar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.activateControl()
        // V16: PiP internals and the Apple-player switch live in Advanced settings.
        let advanced = app.descendants(matching: .any)["settings.page.Advanced settings"].firstMatch
        #if os(iOS)
        for _ in 0..<4 where !advanced.exists { app.swipeUp() }
        #endif
        openSettingsPage("Advanced settings")
        let fallback = app.descendants(matching: .any)["settings.pipFallback"].firstMatch
        #if os(iOS)
        for _ in 0..<4 where !fallback.exists { app.swipeUp() }
        #endif
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        fallback.activateControl(); fallback.activateControl()
        #if os(iOS)
        let fullscreen = app.descendants(matching: .any)["settings.nativeFullscreen"].firstMatch
        for _ in 0..<4 where !fullscreen.exists { app.swipeUp() }
        XCTAssertTrue(fullscreen.exists)
        #endif
    }
}

private extension XCUIElement {
    func activateControl() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
private extension XCUICoordinate {
    func activateControl() { tap() }
}
