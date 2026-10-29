import SwiftUI
import WebKit

#if os(iOS)
struct WebContentView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> UIView {
        let host = WebHostView()
        host.clipsToBounds = true
        host.adopt(webView)
        return host
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? WebHostView)?.repairIfOrphaned()
    }
    // Prevent WebKit's intrinsic content width from expanding the iPhone's SwiftUI hierarchy.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
}
/// V22.2: houdt de webview vast. Na een mislukte fullscreen-/PiP-terugkeer liet WebKit de webview
/// soms los (of verborgen) achter → de tab bleef zwart. De host zet hem dan stil terug, maar nooit
/// terwijl WebKit hem echt in zijn eigen fullscreen-venster toont.
final class WebHostView: UIView {
    private weak var webView: WKWebView?
    func adopt(_ view: WKWebView) {
        webView = view
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    func repairIfOrphaned() {
        guard let webView, window != nil else { return }
        if webView.superview === self {
            if webView.isHidden { webView.isHidden = false }
            if webView.alpha < 0.01 { webView.alpha = 1 }
            return
        }
        // Alleen echt verweesde webviews terugzetten (los van elk venster). Hangt hij in een ander
        // venster (WebKit-fullscreen) of in een andere host, dan niet afpakken.
        guard webView.window == nil else { return }
        // Volgende runloop opnieuw kijken: tijdens een fullscreen-overgang hangt hij heel even nergens.
        DispatchQueue.main.async { [weak self] in
            guard let self, let webView = self.webView, webView.window == nil, self.window != nil else { return }
            self.adopt(webView)
        }
    }
    override func didMoveToWindow() { super.didMoveToWindow(); repairIfOrphaned() }
    override func layoutSubviews() { super.layoutSubviews(); repairIfOrphaned() }
}
#elseif os(macOS)
struct WebContentView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> NSView {
        let host = WebHostNSView()
        host.adopt(webView)
        return host
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        // Do not steal the web view back while it lives in the floating fallback panel.
        if webView.superview === nsView { webView.frame = nsView.bounds; if webView.isHidden { webView.isHidden = false } }
        // V22.2: wees-webview (na mislukte fullscreen-terugkeer) → terugzetten.
        else if webView.superview == nil || webView.window == nil {
            (nsView as? WebHostNSView)?.adopt(webView)
        }
    }
}

/// V23.1 (Mac): houder van de webview die zelf kan zien dat zijn webview "los" is geraakt. Na een
/// mislukte terugkeer uit WebKit's fullscreen hing de webview soms nergens meer (superview en venster
/// nil) en bleef de tab zwart tot een herstart — ook herladen hielp niet. WebSession vraagt na elke
/// fullscreen-wissel om een controle; de houder zet een verweesde webview dan stil terug.
final class WebHostNSView: NSView {
    private weak var webView: WKWebView?
    private static let hosts = NSHashTable<WebHostNSView>.weakObjects()
    func adopt(_ view: WKWebView) {
        webView = view
        Self.hosts.add(self)
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        if view.superview !== self { addSubview(view) }
        if view.isHidden { view.isHidden = false }
    }
    /// Alleen echt verweesde webviews (los van elk venster) terugzetten — nooit afpakken van WebKit's
    /// fullscreen-venster of het zwevende paneel.
    @discardableResult
    func repairIfOrphaned() -> Bool {
        guard let webView, window != nil, webView.superview == nil || webView.window == nil else { return false }
        adopt(webView)
        return true
    }
    @discardableResult
    static func repair(_ webView: WKWebView) -> Bool {
        guard webView.superview == nil || webView.window == nil else { return false }
        for host in hosts.allObjects where host.webView === webView { if host.repairIfOrphaned() { return true } }
        return false
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); repairIfOrphaned() }
}
#endif
