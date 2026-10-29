import SwiftUI
import WebKit

#if os(iOS)
struct WebContentView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.clipsToBounds = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        return host
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    // Prevent WebKit's intrinsic content width from expanding the iPhone's SwiftUI hierarchy.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
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
        if webView.superview === nsView { webView.frame = nsView.bounds }
    }
}
#endif
