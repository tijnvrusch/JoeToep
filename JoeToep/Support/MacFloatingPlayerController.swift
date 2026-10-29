// Deze code compileert alleen mee op macOS (#if os(macOS) ... #endif). Zo kan hetzelfde
// project zowel iOS/iPadOS als Mac ondersteunen, met per platform net andere code.
#if os(macOS)
// AppKit levert macOS's UI-bouwstenen zoals NSWindow, NSView en NSScreen.
import AppKit
import WebKit

/// Public AppKit fallback. This is a floating web mini-player, not system PiP.
/// The SAME WKWebView is moved; no second player, stream extraction or reload.
// Deze controller maakt een klein, zwevend vensterrand (paneel) op het Mac-bureaublad waarin
// dezelfde webweergave verder kan spelen, als alternatief voor systeem-Picture-in-Picture.
@MainActor
// NSObject is de basisklasse van bijna alle Objective-C/AppKit-objecten; NSWindowDelegate is
// een protocol waarmee dit object gebeurtenissen van een venster kan afhandelen (zoals sluiten).
final class MacFloatingPlayerController: NSObject, NSWindowDelegate {
    // Het zwevende venster zelf. "weak" hieronder betekent: deze eigenschap houdt het object
    // niet actief in leven; als het elders wordt opgeruimd, wordt de eigenschap automatisch nil.
    private var panel: NSWindow?
    private weak var origin: NSView?
    private weak var webView: WKWebView?
    // Een closure (functie als waarde) die wordt aangeroepen wanneer het zwevende venster sluit.
    var onClose: (() -> Void)?
    var isVisible: Bool { panel?.isVisible == true }

    // Toont het zwevende venster met de gegeven webweergave erin. Geeft terug of het gelukt is.
    func show(_ webView: WKWebView) -> Bool {
        if isVisible { return true }
        // Zoekt het venster en scherm waarop de webweergave nu staat, zodat het zwevende
        // paneel op hetzelfde scherm verschijnt.
        guard let host = webView.superview, let screen = host.window?.screen ?? NSScreen.main else { return false }
        origin = host; self.webView = webView
        let visible = screen.visibleFrame
        // Berekent een venstergrootte: maximaal 520 punten breed, of 45% van het scherm als
        // dat kleiner is. "min(...)" kiest de kleinste van de twee waarden.
        let width = min(520.0, visible.width * 0.45)
        let rect = NSRect(x: visible.maxX - width - 20, y: visible.minY + 20, width: width, height: width * 0.68)
        // Maakt een nieuw macOS-venster met een titelbalk, sluit-, formaatwijzig- en
        // minimaliseerknop.
        let floating = NSWindow(contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        floating.title = "JoeToep · Video fallback"
        // .floating houdt het venster altijd bovenop andere gewone vensters.
        floating.level = .floating
        floating.hidesOnDeactivate = false
        // isReleasedWhenClosed = false: het venster wordt niet automatisch uit het geheugen
        // gehaald zodra het sluit, zodat wij zelf kunnen bepalen wanneer dat gebeurt.
        floating.isReleasedWhenClosed = false
        floating.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        floating.minSize = NSSize(width: 320, height: 220)
        floating.delegate = self
        floating.backgroundColor = .black
        guard let content = floating.contentView else { return false }
        // De webweergave wordt VERPLAATST (niet gekopieerd) van zijn huidige plek naar dit
        // nieuwe venster: eerst losmaken van de oude ouder (removeFromSuperview), dan
        // toevoegen aan de inhoud van het nieuwe venster.
        webView.removeFromSuperview()
        webView.frame = content.bounds
        // autoresizingMask zorgt dat de webweergave automatisch meeschaalt als het venster
        // van grootte verandert (breedte en hoogte volgen mee).
        webView.autoresizingMask = [.width, .height]
        content.addSubview(webView)
        panel = floating
        // orderFrontRegardless() toont het venster vooraan, ook als de app zelf niet actief is.
        floating.orderFrontRegardless()
        // evaluateJavaScript voert JavaScript-code uit IN de webpagina; hier wordt de pagina
        // op de hoogte gebracht dat hij nu in het "podium"-formaat (mini-player) getoond wordt,
        // zodat de webpagina zijn eigen weergave kan aanpassen. completionHandler: nil betekent
        // dat we niet geïnteresseerd zijn in het resultaat van die JavaScript-uitvoering.
        webView.evaluateJavaScript("window.JoeToepStage?.enter()", completionHandler: nil)
        return true
    }

    // Verplaatst de webweergave terug naar zijn oorspronkelijke plek en sluit het zwevende venster.
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
    // NSWindowDelegate-methode: wordt aangeroepen wanneer de gebruiker op het sluitkruisje
    // klikt. We voeren zelf restore() uit en geven "false" terug zodat AppKit het venster
    // niet nog een keer op zijn eigen manier probeert te sluiten (wij doen dat al).
    func windowShouldClose(_ sender: NSWindow) -> Bool { restore(); return false }
    // Wanneer het venster volledig scherm gaat, hoeft het niet meer "altijd bovenop" te zijn.
    func windowWillEnterFullScreen(_ notification: Notification) { panel?.level = .normal }
    func windowDidExitFullScreen(_ notification: Notification) { panel?.level = .floating }
}
#endif
