#if os(macOS)
import AppKit
import WebKit

/// Public AppKit fallback. This is a floating web mini-player, not system PiP.
/// The SAME WKWebView is moved; no second player, stream extraction or reload.
@MainActor
final class MacFloatingPlayerController: NSObject, NSWindowDelegate {
    private var panel: NSWindow?
    private weak var origin: NSView?
    private weak var webView: WKWebView?
    var onClose: (() -> Void)?
    var isVisible: Bool { panel?.isVisible == true }

    func show(_ webView: WKWebView) -> Bool {
        if isVisible { return true }
        guard let host = webView.superview, let screen = host.window?.screen ?? NSScreen.main else { return false }
        origin = host; self.webView = webView
        let visible = screen.visibleFrame
        let width = min(520.0, visible.width * 0.45)
        let rect = NSRect(x: visible.maxX - width - 20, y: visible.minY + 20, width: width, height: width * 0.68)
        let floating = NSWindow(contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        floating.title = "JoeToep · Video fallback"
        floating.level = .floating
        floating.hidesOnDeactivate = false
        floating.isReleasedWhenClosed = false
        floating.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        floating.minSize = NSSize(width: 320, height: 220)
        floating.delegate = self
        floating.backgroundColor = .black
        guard let content = floating.contentView else { return false }
        webView.removeFromSuperview()
        webView.frame = content.bounds
        webView.autoresizingMask = [.width, .height]
        content.addSubview(webView)
        panel = floating
        floating.orderFrontRegardless()
        webView.evaluateJavaScript("window.JoeToepStage?.enter()", completionHandler: nil)
        return true
    }

    func restore() {
        guard let panel else { return }
        webView?.evaluateJavaScript("window.JoeToepStage?.exit()", completionHandler: nil)
        if let webView, let origin {
            webView.removeFromSuperview()
            webView.frame = origin.bounds
            webView.autoresizingMask = [.width, .height]
            origin.addSubview(webView)
        }
        panel.delegate = nil
        panel.orderOut(nil)
        panel.close()
        self.panel = nil
        self.webView = nil
        origin = nil
        onClose?()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { restore(); return false }
    func windowWillEnterFullScreen(_ notification: Notification) { panel?.level = .normal }
    func windowDidExitFullScreen(_ notification: Notification) { panel?.level = .floating }
}
#endif
