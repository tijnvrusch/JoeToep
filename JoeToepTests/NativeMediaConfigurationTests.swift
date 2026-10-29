import XCTest
import WebKit
@testable import JoeToep

final class NativeMediaConfigurationTests: XCTestCase {
    @MainActor
    func testNativeMediaConfigurationIsInstalled() {
        let session = WebSession()
        XCTAssertTrue(session.mediaCompatibilityStatus.hasPrefix("Native PiP configured"), session.mediaCompatibilityStatus)
        #if os(iOS)
        XCTAssertTrue(session.webView.configuration.allowsPictureInPictureMediaPlayback)
        XCTAssertTrue(session.webView.configuration.allowsInlineMediaPlayback)
        #endif
        let scripts = session.webView.configuration.userContentController.userScripts
        XCTAssertTrue(scripts.contains { $0.source.contains("JoeToepMedia") && $0.injectionTime == .atDocumentStart })
        XCTAssertTrue(scripts.contains { $0.source.contains("JoeToepStage") })
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "JoeToep")
    }
}
