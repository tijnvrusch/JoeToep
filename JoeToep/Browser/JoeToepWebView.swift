import WebKit
#if os(macOS)
import AppKit

/// V15 (Mac): right-click on a link offers "Open in New Tab and Switch" (top) and
/// "Open in New Tab"; WebKit's "Open Link in New Window" is replaced by these.
final class JoeToepWebView: WKWebView {
    var contextLink: (() -> URL?)?
    var openInNewTab: ((URL, Bool) -> Void)?
    /// V17.1: "Open in nieuw venster".
    var openInNewWindow: ((URL) -> Void)?
    /// V26: "Open in Peek" (zwevend voorbeeld, zoals Arc).
    var openInPeek: ((URL) -> Void)?

    /// V19.1: één klik pauzeert/speelt meteen, ook als het JoeToep-venster nog niet actief was
    /// (anders "verbruikt" macOS de eerste klik om het venster naar voren te halen).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        // V17.1: ook "Open in New Window".
        let windowItem = NSMenuItem(title: "Open in New Window", action: #selector(openWindowItem(_:)), keyEquivalent: "")
        windowItem.representedObject = url; windowItem.target = self
        windowItem.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: nil)
        menu.insertItem(switchItem, at: 0)
        menu.insertItem(backgroundItem, at: 1)
        menu.insertItem(windowItem, at: 2)
        var next = 3
        if openInPeek != nil, V26Prefs.peekEnabled() {
            let peekItem = NSMenuItem(title: "Open in Peek", action: #selector(openPeekItem(_:)), keyEquivalent: "")
            peekItem.representedObject = url; peekItem.target = self
            peekItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
            menu.insertItem(peekItem, at: next); next += 1
        }
        menu.insertItem(.separator(), at: next)
    }
    @objc private func openPeekItem(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInPeek?(url) }
    }
    @objc private func openSwitching(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInNewTab?(url, true) }
    }
    @objc private func openWindowItem(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInNewWindow?(url) }
    }
    @objc private func openBackground(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { openInNewTab?(url, false) }
    }
}
#else
typealias JoeToepWebView = WKWebView
#endif
