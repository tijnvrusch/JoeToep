import WebKit
#if os(macOS)
import AppKit

/// V15 (Mac): right-click on a link offers "Open in New Tab and Switch" (top) and
/// "Open in New Tab"; WebKit's "Open Link in New Window" is replaced by these.
final class JoeToepWebView: WKWebView {
    var contextLink: (() -> URL?)?
    var openInNewTab: ((URL, Bool) -> Void)?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        guard let url = contextLink?() else { return }
        let removable: Set<String> = ["WKMenuItemIdentifierOpenLinkInNewWindow"]
        for item in menu.items where removable.contains(item.identifier?.rawValue ?? "") { menu.removeItem(item) }
        let switchItem = NSMenuItem(title: "Open in New Tab and Switch", action: #selector(openSwitching(_:)), keyEquivalent: "")
        switchItem.representedObject = url; switchItem.target = self
        switchItem.image = NSImage(systemSymbolName: "plus.square.on.square", accessibilityDescription: nil)
        let backgroundItem = NSMenuItem(title: "Open in New Tab", action: #selector(openBackground(_:)), keyEquivalent: "")
        backgroundItem.representedObject = url; backgroundItem.target = self
        backgroundItem.image = NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil)
        menu.insertItem(switchItem, at: 0)
        menu.insertItem(backgroundItem, at: 1)
        menu.insertItem(.separator(), at: 2)
    }
    @objc private func openSwitching(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInNewTab?(url, true) }
    }
    @objc private func openBackground(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInNewTab?(url, false) }
    }
}
#else
typealias JoeToepWebView = WKWebView
#endif
