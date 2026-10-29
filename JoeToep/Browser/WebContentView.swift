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
        let host = NSView()
        webView.frame = host.bounds
        webView.autoresizingMask = [.width, .height]
        host.addSubview(webView)
        return host
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        // Do not steal the web view back while it lives in the floating fallback panel.
        if webView.superview === nsView { webView.frame = nsView.bounds; if webView.isHidden { webView.isHidden = false } }
        // V22.2: wees-webview (na mislukte fullscreen-terugkeer) → terugzetten.
        else if webView.superview == nil || webView.window == nil {
            webView.frame = nsView.bounds
            webView.autoresizingMask = [.width, .height]
            nsView.addSubview(webView)
        }
    }
}
#endif
