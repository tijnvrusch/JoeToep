#if os(macOS)
import AppKit
import WebKit

/// V17 (Mac) — navigeren met de muis, het toetsenbord en het trackpad, ook als de pagina zelf
/// niet terug kan (dan sluit "terug" de tab, zie BrowserWorkspace.closeFromBack).
///
///  • Muisknop 4 (zijknop "terug") en 5 ("vooruit"), zoals op de meeste muizen.
///  • ⌘← en ⌘→ — maar NIET als je aan het typen bent (adresbalk of een tekstveld op de site),
///    want dan betekent ⌘← "naar het begin van de regel".
///  • Veeg met twee vingers naar rechts op de eerste pagina van een tab (als WebKit zelf niet
///    terug kan; kan het wel terug, dan doet WebKit zijn eigen veeg-animatie).
///
/// Een "local monitor" is een stukje code dat elk muis-/toetsenbord-/scroll-gebeurtenis van
/// DEZE app te zien krijgt vóór de rest van de app. Geven we `nil` terug, dan is de
/// gebeurtenis "opgegeten"; geven we `event` terug, dan gaat hij gewoon door.
@MainActor
final class MacNavigationMonitor {
    static let shared = MacNavigationMonitor()
    private var monitors: [Any] = []
    private var swipeDistance: CGFloat = 0       // opgetelde horizontale veeg-afstand
    private var swipeHandled = false

    /// Installeert de monitors één keer (meerdere vensters delen ze).
    func install() {
        guard monitors.isEmpty else { return }
        // Muisknoppen: `otherMouseDown` = alle knoppen behalve links/rechts.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown, handler: { event in
            // buttonNumber 3 = "terug"-zijknop, 4 = "vooruit"-zijknop (tellen begint bij 0).
            switch event.buttonNumber {
            case 3: MainActor.assumeIsolated { BrowserWorkspace.active?.selected.session.goBack() }; return nil
            case 4: MainActor.assumeIsolated { BrowserWorkspace.active?.selected.session.goForward() }; return nil
            default: return event
            }
        }) { monitors.append(m) }
        // Toetsenbord: ⌘← (keyCode 123) en ⌘→ (keyCode 124).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            // V17.1: een ingedrukt gehouden toets herhaalt zichzelf; die herhalingen negeren we,
            // anders sluit één lange druk op ⌘← meerdere tabs achter elkaar.
            if event.isARepeat { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == [.command] || flags == [.command, .numericPad, .function] || flags == [.command, .function],
                  event.keyCode == 123 || event.keyCode == 124 else { return event }
            // Typ je in een tekstveld van de app zelf (de adresbalk)? Dan niets doen.
            if event.window?.firstResponder is NSTextView { return event }
            let back = event.keyCode == 123
            MainActor.assumeIsolated { MacNavigationMonitor.navigateUnlessTyping(back: back) }
            return event   // doorlaten: in een webtekstveld werkt ⌘← dan nog gewoon
        }) { monitors.append(m) }
        // V19: Ctrl+Tab / Ctrl+Shift+Tab — door je recente tabs, ook als de video fullscreen speelt
        // (een local monitor ziet ook toetsen in WebKit's eigen fullscreen-venster).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            let flags = event.modifierFlags.intersection([.control, .shift, .command, .option])
            guard event.keyCode == 48, flags == [.control] || flags == [.control, .shift] else { return event }
            let backwards = flags.contains(.shift)
            MainActor.assumeIsolated { BrowserWorkspace.active?.cycleRecent(backwards: backwards) }
            return nil
        }) { monitors.append(m) }
        // Ctrl losgelaten → de keuze is definitief (volgende Ctrl+Tab begint weer bij de meest recente).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            if !event.modifierFlags.contains(.control) { MainActor.assumeIsolated { BrowserWorkspace.active?.endRecentCycle() } }
            return event
        }) { monitors.append(m) }
        // Trackpad: horizontaal vegen met twee vingers (alleen als WebKit zelf niet terug kan).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { event in
            MainActor.assumeIsolated { MacNavigationMonitor.shared.track(event) }
            return event
        }) { monitors.append(m) }
    }

    /// Vraagt de pagina of er een tekstveld actief is; zo niet: terug of vooruit.
    private static func navigateUnlessTyping(back: Bool) {
        guard let session = BrowserWorkspace.active?.selected.session else { return }
        let script = "(()=>{const e=document.activeElement;return !!(e&&(e.isContentEditable||/^(INPUT|TEXTAREA|SELECT)$/.test(e.tagName)))})()"
        session.webView.evaluateJavaScript(script) { result, _ in
            if (result as? Bool) == true { return }          // aan het typen op de site
            if back { session.goBack() } else { session.goForward() }
        }
    }

    /// Telt een veeg op. Alleen precieze trackpad-vegen (geen muiswiel), duidelijk horizontaal,
    /// minimaal 300 punten ver, en alleen als deze tab geen vorige pagina heeft.
    private func track(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return }
        if event.phase == .began { swipeDistance = 0; swipeHandled = false }
        if event.phase == .changed, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 2 {
            swipeDistance += event.scrollingDeltaX
        }
        if event.phase == .ended || event.phase == .cancelled {
            defer { swipeDistance = 0 }
            guard !swipeHandled, swipeDistance > 300,
                  let workspace = BrowserWorkspace.active, !workspace.selected.session.canGoBack else { return }
            swipeHandled = true
            workspace.closeFromBack(workspace.selected)
        }
    }
}
#endif
