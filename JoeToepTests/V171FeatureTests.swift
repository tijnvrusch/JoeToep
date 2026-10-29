import XCTest
@testable import JoeToep
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// V17.1: visualizer standaard uit + instellingen, 153 app-iconen aanwezig, tabs en standaardbrowser.
@MainActor
final class V171FeatureTests: XCTestCase {
    func testVisualizerIsOffByDefaultAndConfigPersists() throws {
        let suite = "V171." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.visualizerStyle, .off, "the audio visualizer is off by default")
        XCTAssertEqual(settings.theme.visualizer, .off)
        settings.visualizerStyle = .mirror
        settings.visualizerConfig.bars = 96; settings.visualizerConfig.bpm = 124; settings.visualizerConfig.colorMode = .rainbow
        let again = AppSettings(defaults: defaults)
        XCTAssertEqual(again.visualizerStyle, .mirror)
        XCTAssertEqual(again.visualizerConfig.bars, 96)
        XCTAssertEqual(again.visualizerConfig.bpm, 124)
        XCTAssertEqual(again.visualizerConfig.colorMode, .rainbow)
    }
    func testBeatPulsesExactlyOnTheTempo() {
        // 120 BPM = een tel per 0,5 s: op de tel is de puls maximaal, halverwege veel lager.
        XCTAssertEqual(AudioVisualizer.beat(t: 10.0, bpm: 120), 1, accuracy: 0.001)
        XCTAssertLessThan(AudioVisualizer.beat(t: 10.25, bpm: 120), 0.2)
        for t in stride(from: 0.0, to: 5, by: 0.37) {
            let e = AudioVisualizer.energy(0.4, t)
            XCTAssertTrue((0...1).contains(e))
        }
    }
    func testAll153AppIconsExistWithPreviews() {
        // V23: inmiddels 43 klassieke + 150 nieuwe iconen (zeven series).
        XCTAssertEqual(AppIconController.names.count, 193, "43 classic + 150 new icons")
        XCTAssertEqual(Set(AppIconController.names).count, AppIconController.names.count, "names are unique")
        XCTAssertEqual(AppIconController.series.map(\.names.count), [20, 20, 20, 20, 20, 20, 30])
        for name in AppIconController.names {
            #if os(macOS)
            XCTAssertNotNil(NSImage(named: "IconPreview" + name), "preview for \(name)")
            #else
            XCTAssertNotNil(UIImage(named: "IconPreview" + name), "preview for \(name)")
            #endif
        }
        XCTAssertEqual(AppIconController.title("UniqueNebula"), "Nebula")
        XCTAssertEqual(AppIconController.title("Red07"), "Red 07")
    }
    func testAppClaimsWebLinksForDefaultBrowser() throws {
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(schemes.contains("http")); XCTAssertTrue(schemes.contains("https"))
    }
}
