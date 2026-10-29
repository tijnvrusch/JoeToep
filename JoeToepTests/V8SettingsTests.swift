import XCTest
@testable import JoeToep
final class V8SettingsTests: XCTestCase {
    @MainActor func testV8PreferencesPersistAndReset() {
        let name = "JoeToepV8Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.automaticFullscreen)
        XCTAssertTrue(settings.disableCaptions)
        XCTAssertTrue(settings.disablePreviewCaptions)
        settings.automaticFullscreen = false; settings.disableCaptions = false; settings.disablePreviewCaptions = false
        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.snapshot.automaticFullscreen)
        XCTAssertFalse(restored.snapshot.disableCaptions)
        XCTAssertFalse(restored.snapshot.disablePreviewCaptions)
        restored.resetPreferences()
        XCTAssertTrue(restored.snapshot.automaticFullscreen)
        XCTAssertTrue(restored.snapshot.disableCaptions)
        XCTAssertTrue(restored.snapshot.disablePreviewCaptions)
    }
}
