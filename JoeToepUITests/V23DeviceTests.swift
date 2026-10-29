import XCTest

/// V23: nieuwe instelling "Switch devices automatically" en PiP-stabiliteit (iPhone/iPad/Mac).
final class V23DeviceTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
    }
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    /// De hoofdschakelaar staat standaard aan, is uit te zetten, en dan verschijnt de uitleg
    /// "only Continue here / Play here".
    @MainActor func testAutomaticDeviceSwitchingCanBeTurnedOff() throws {
        app.launch()
        let settings = app.buttons["toolbar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.v23Activate()
        let page = app.descendants(matching: .any)["settings.page.Sync & devices"].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.v23Activate()
        let toggle = app.descendants(matching: .any)["settings.autoDeviceSwitch"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "new master switch is present")
        XCTAssertEqual(toggle.value as? String, "1", "automatic switching is on by default")
        #if os(iOS)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        #else
        toggle.click()
        #endif
        XCTAssertEqual(toggle.value as? String, "0")
        let footer = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Continue here'")).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 3), "explains that only Continue here / Play here moves a video")
        attach("Switch devices automatically: off")
        #if os(iOS)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        #else
        toggle.click()
        #endif
        XCTAssertEqual(toggle.value as? String, "1")
    }

    /// PiP blijft werken na herhaald wegleggen en terugkomen, ook met tabwissels ertussen (belasting).
    @MainActor func testPiPStaysConsistentAcrossRepeatedBackgrounding() throws {
        #if os(iOS)
        app.launch()
        let play = app.webViews.buttons["Play test video"]
        XCTAssertTrue(play.waitForExistence(timeout: 20)); play.tap()
        XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 10))
        app.webViews.buttons["Fullscreen test video"].tap()
        sleep(2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let pip = springboard.windows["PIP-SBInteractionPassThroughView"]
        for cycle in 1...8 {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(pip.waitForExistence(timeout: 8), "PiP visible after backgrounding (cycle \(cycle))")
            if cycle == 1 || cycle == 8 { attach("PiP cycle \(cycle)") }
            app.activate()
            sleep(2)
            XCTAssertTrue(app.webViews.staticTexts["State: playing"].waitForExistence(timeout: 8), "still playing after return (cycle \(cycle))")
        }
        #else
        throw XCTSkip("Physical iPhone/iPad PiP test")
        #endif
    }
}

private extension XCUIElement {
    func v23Activate() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
