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
        // V19.1: snelheid met sneltoetsen (ook in fullscreen):
        //   ⌥, / ⌥.  klein   ·   ⌥⇧, / ⌥⇧.  medium   ·   ⌃⌥, / ⌃⌥.  groot   ·   ⌥0  terug naar 1×
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            let flags = event.modifierFlags.intersection([.control, .shift, .command, .option])
            guard flags.contains(.option), !flags.contains(.command), [43, 47, 29].contains(event.keyCode),
                  !(event.window?.firstResponder is NSTextView) else { return event }
            MainActor.assumeIsolated {
                guard let workspace = BrowserWorkspace.active else { return }
                let session = workspace.mediaTab.session
                let defaults = UserDefaults.standard
                if event.keyCode == 29 { session.setPlaybackRate(1); return }
                let step: Double
                if flags.contains(.control) { step = defaults.object(forKey: "speedStepLargeV191") as? Double ?? 0.5 }
                else if flags.contains(.shift) { step = defaults.object(forKey: "speedStepMediumV191") as? Double ?? 0.25 }
                else { step = defaults.object(forKey: "speedStepSmallV191") as? Double ?? 0.05 }
                session.adjustPlaybackRate(by: event.keyCode == 47 ? step : -step)
            }
            return nil
        }) { monitors.append(m) }
        // V22.2: Esc sluit ALTIJD eerst de zoekbalk/overlay — wat de focus ook is (webview, knop, niets).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            // Esc: hardwaretoets 53, of het Esc-teken (externe/assistieve toetsenborden sturen soms keyCode 0).
            guard event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}", !event.isARepeat else { return event }
            let number = event.window?.windowNumber
            let handled = MainActor.assumeIsolated { EscapeStack.handle(in: number) }
            return handled ? nil : event
        }) { monitors.append(m) }
        // V19.2: "vast in fullscreen"-fix. Staat het VENSTER in macOS-fullscreen (eigen Space) terwijl
        // de pagina zelf niet fullscreen is, dan deden F, dubbelklik en Esc niets zichtbaars. Nu verlaten
        // ze dan het macOS-fullscreen van het venster.
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown], handler: { event in
            if event.type == .keyDown, event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}",
               MainActor.assumeIsolated({ EscapeStack.hasPanel(in: event.window?.windowNumber) }) { return event }
            guard let window = event.window, window.styleMask.contains(.fullScreen),
                  !(window.firstResponder is NSTextView) else { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isF = event.type == .keyDown && event.keyCode == 3 && flags.isEmpty
            let isEsc = event.type == .keyDown && (event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}")
            let isDouble = event.type == .leftMouseDown && event.clickCount == 2
            guard isF || isEsc || isDouble else { return event }
            MainActor.assumeIsolated { MacNavigationMonitor.exitWindowFullscreenIfPageIsInline(window) }
            return event
        }) { monitors.append(m) }
        // V24.0.1: jij bedient fullscreen zelf (F, Esc, dubbelklik) → JoeToep's automatische
        // fullscreen-controle stopt meteen en gaat nooit meer "terug" fullscreen voor deze video.
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown], handler: { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isF = event.type == .keyDown && event.keyCode == 3 && flags.isEmpty && !event.isARepeat
            let isEsc = event.type == .keyDown && (event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}")
            let isDouble = event.type == .leftMouseDown && event.clickCount == 2
            guard isF || isEsc || isDouble, !(event.window?.firstResponder is NSTextView) else { return event }
            MainActor.assumeIsolated {
                guard let session = BrowserWorkspace.active?.selected.session,
                      NavigationPolicy.isPlaybackPage(session.currentURL) else { return }
                session.cancelAutomaticFullscreenFollowUp(isF ? "F" : isEsc ? "Esc" : "double-click")
            }
            return event
        }) { monitors.append(m) }
        // V23.1: klikken op het beeld in fullscreen komen ALTIJD aan. Op een GEPAUZEERDE video legt WebKit
        // in fullscreen een VisionKit-laag (Live Text: VKCImageAnalysisOverlayView) over het beeld; die
        // slikte elke klik in: klik = afspelen en dubbelklik = fullscreen uit deden niets (toetsen wel).
        // (Die functie uitzetten via WebKit's TextRecognitionInVideosEnabled liet het webproces vastlopen.)
        // Dan geeft JoeToep de klik zelf door aan de pagina (zelfde regels als een gewone klik).
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown], handler: { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard flags.isEmpty, let window = event.window, window.styleMask.contains(.fullScreen) else { return event }
            let handled: Bool = MainActor.assumeIsolated {
                // Alleen in WebKit's eigen fullscreen-venster (daar staat niets van JoeToep zelf boven de video).
                guard let session = BrowserWorkspace.active?.selected.session, session.isFullscreen,
                      session.webView.window === window, window.isWebKitFullScreenWindow,
                      let content = window.contentView else { return false }
                let point = content.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
                guard let hit = content.hitTest(point) else { return false }
                // Valt de klik gewoon op WebKit (de webview of een WebKit-subview)? Dan regelt de pagina het.
                let name = String(describing: type(of: hit))
                if hit === session.webView || MacNavigationMonitor.isWebKitView(hit) || name.hasPrefix("NS") || name.hasPrefix("_NS") { return false }
                let local = session.webView.convert(event.locationInWindow, from: nil)
                guard session.webView.bounds.contains(local) else { return false }
                #if DEBUG
                NSLog("V231 fullscreen click via %@ (count %ld)", String(describing: type(of: hit)), event.clickCount)
                #endif
                session.webView.evaluateJavaScript("window.JoeToepControls?.surfaceClick?.(\(event.clickCount))", completionHandler: nil)
                return true
            }
            return handled ? nil : event
        }) { monitors.append(m) }
        // Ctrl losgelaten → de keuze is definitief (volgende Ctrl+Tab begint weer bij de meest recente).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            if !event.modifierFlags.contains(.control) { MainActor.assumeIsolated { BrowserWorkspace.active?.endRecentCycle() } }
            return event
        }) { monitors.append(m) }
        // Trackpad: horizontaal vegen met twee vingers (alleen als WebKit zelf niet terug kan).
        if let m = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { event in
            MainActor.assumeIsolated {
                // V19.1: in fullscreen gaat een veeg naar scrubben/volume (per apparaat instelbaar).
                if GestureScrubber.shared.handle(event) { return }
                MacNavigationMonitor.shared.trackPullToRefresh(event)
                MacNavigationMonitor.shared.track(event)
            }
            return event   // de pagina krijgt hem ook (die blokkeert in fullscreen alleen het scrollen)
        }) { monitors.append(m) }
    }

    /// V23.1: hoort deze view bij WebKit zelf (dan krijgt de pagina de klik gewoon)?
    static func isWebKitView(_ view: NSView) -> Bool {
        let name = String(describing: type(of: view))
        return name.hasPrefix("WK") || name.hasPrefix("_WK") || name.hasPrefix("Web") || view is WKWebView
    }

    /// Is de pagina NIET (meer) fullscreen maar het venster wel? Dan het venster uit macOS-fullscreen halen.
    /// Kleine vertraging: eerst mag de pagina zelf reageren (YouTube's eigen F/dubbelklik).
    static func exitWindowFullscreenIfPageIsInline(_ window: NSWindow) {
        // V23.1: WebKit's eigen fullscreen-venster sluit zichzelf; het hier omschakelen brak die
        // overgang halverwege (webview bleef los → zwarte tab).
        guard !window.isWebKitFullScreenWindow else { return }
        guard let session = BrowserWorkspace.active?.selected.session,
              NavigationPolicy.isPlaybackPage(session.currentURL) else { return }   // alleen op videopagina's
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {   // V23.1: was 0,35 s
            let probe = "!!(document.fullscreenElement||document.webkitFullscreenElement||document.querySelector('ytd-watch-flexy')?.hasAttribute('fullscreen'))"
            session.webView.evaluateJavaScript(probe) { value, _ in
                guard (value as? Bool) == false, window.styleMask.contains(.fullScreen), !window.isWebKitFullScreenWindow else { return }
                window.toggleFullScreen(nil)
            }
        }
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

    // MARK: V19.1 — trekken om te verversen (trackpad, bovenaan de pagina)
    private var pullDistance: CGFloat = 0
    private var pullAtTop = false
    private var pullChecked = false
    /// Twee vingers omlaag terwijl de pagina al helemaal bovenaan staat → na ±120 pt en loslaten: verversen.
    func trackPullToRefresh(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas, WebSession.pullAction != "off",
              let session = BrowserWorkspace.active?.selected.session else { return }
        if event.phase == .began {
            pullDistance = 0; pullAtTop = false; pullChecked = false
            session.webView.evaluateJavaScript("(window.scrollY||document.documentElement.scrollTop||0)<=0") { [weak self] value, _ in
                MainActor.assumeIsolated { self?.pullAtTop = (value as? Bool) == true; self?.pullChecked = true }
            }
        }
        // Vingers omlaag = inhoud naar beneden trekken (met natuurlijk scrollen: deltaY positief).
        let fingersDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        if event.phase == .changed, pullChecked, pullAtTop { pullDistance += max(0, fingersDown) - max(0, -fingersDown) }
        if event.phase == .ended {
            defer { pullDistance = 0; pullAtTop = false }
            if pullAtTop && pullDistance > 120 && !session.isFullscreen { session.performPullAction() }
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
            guard UserDefaults.standard.object(forKey: "backSwipeV192") as? Bool ?? false,
                  !swipeHandled, swipeDistance > 300,
                  let workspace = BrowserWorkspace.active, !workspace.selected.session.canGoBack else { return }
            swipeHandled = true
            workspace.closeFromBack(workspace.selected)
        }
    }
}

extension NSWindow {
    /// V23.1: WebKit's eigen fullscreen-venster (element-fullscreen), niet een venster van JoeToep zelf.
    var isWebKitFullScreenWindow: Bool {
        let name = String(describing: type(of: self))
        // macOS 27: "WebCoreFullScreenWindow" (eerder "WKFullScreenWindow").
        return name.contains("FullScreenWindow")
    }
}
#endif
