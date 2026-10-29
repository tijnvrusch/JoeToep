#if os(macOS)
import AppKit
import WebKit

/// V23 — fullscreen altijd 100 % breed en hoog.
///
/// Op de BenQ (1440p) en de HP (1920x1200) bleef de fullscreen-video soms op ±75 % staan met zwarte
/// balken; na een herstart was het weg. Er zijn drie oorzaken die dit opleveren, en die alle drie
/// "blijven hangen" tot de app opnieuw start:
///  1. Een monitorwissel/slaapstand of een andere schaal (backing scale) terwijl de webview leeft:
///     WebKit's fullscreen-venster of de webview zelf krijgt de maat van het VORIGE scherm
///     (2560 ↔ 1920 = precies 75 %).
///  2. YouTube rekent de grootte van de video uit bij een `resize`. Komt die tijdens de
///     fullscreen-animatie te vroeg (of terwijl de pagina zich verborgen voelt), dan houdt de
///     video de oude pixelmaat (inline-stijl op de <video>) in een groter fullscreen-vlak.
///  3. Een trackpad-vergroting (magnification) of een oude schaal van de webview.
///
/// Deze bewaker kijkt na het ingaan van fullscreen, na een scherm-/schaalwissel en bij het wisselen
/// van monitor een paar keer (0,15 / 0,6 / 1,4 / 3 s) of het klopt en herstelt in oplopende stappen:
/// vergroting → 1, webview-frame = zijn venster, YouTube een `resize` laten doen, en als laatste een
/// CSS-regel die de video het hele fullscreen-vlak laat vullen (beeldverhouding blijft `contain`).
/// Klopt het venster zelf niet, dan wordt het op het scherm gezet; lukt ook dat niet, dan gaat
/// fullscreen één keer uit en weer aan. Geen permanente polling: alleen na een gebeurtenis.
@MainActor
final class MacFullscreenFitGuard {
    private weak var webView: WKWebView?
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    private var pending: [DispatchWorkItem] = []
    private var savedMagnification: CGFloat?
    private var viewportMisses = 0
    private var reentered = false
    private var wasFullscreen = false

    /// Is dit de zichtbare tab en speelt/staat hij in fullscreen (door WebSession ingevuld).
    var isFullscreen: () -> Bool = { false }
    var log: (String) -> Void = { _ in }
    /// Laatste redmiddel: fullscreen één keer uit en weer aan.
    var reenterFullscreen: () -> Void = {}

    init(webView: WKWebView) {
        self.webView = webView
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSWindow.didChangeScreenNotification,
            NSWindow.didChangeBackingPropertiesNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didResizeNotification
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.handle(note) }
            })
        }
    }

    deinit { for token in observers { NotificationCenter.default.removeObserver(token) } }

    func stop() {
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers.removeAll()
        pending.forEach { $0.cancel() }; pending.removeAll()
    }

    /// V25: jij bediende fullscreen zelf (Esc/F/dubbelklik): geplande controles vervallen en deze
    /// fullscreen-sessie gaat nooit meer "uit en weer aan".
    func userIntervened() {
        pending.forEach { $0.cancel() }; pending.removeAll()
        reentered = true
    }

    /// WebSession meldt een wissel van de fullscreen-stand van de pagina.
    func fullscreenChanged(_ fullscreen: Bool) {
        if fullscreen && !wasFullscreen { viewportMisses = 0; reentered = false }
        wasFullscreen = fullscreen
        if fullscreen { schedule(reason: "enter") } else { left() }
    }

    private func handle(_ note: Notification) {
        guard let webView else { return }
        if let window = note.object as? NSWindow {
            guard window === webView.window else { return }
            if note.name == NSWindow.didResizeNotification && !window.styleMask.contains(.fullScreen) { return }
        }
        guard isFullscreen() || (webView.window?.styleMask.contains(.fullScreen) ?? false) else { return }
        if note.name == NSApplication.didChangeScreenParametersNotification || note.name == NSWindow.didChangeScreenNotification ||
            note.name == NSWindow.didChangeBackingPropertiesNotification {
            viewportMisses = 0; reentered = false
        }
        schedule(reason: note.name.rawValue.replacingOccurrences(of: "Notification", with: ""))
    }

    private func schedule(reason: String) {
        pending.forEach { $0.cancel() }; pending.removeAll()
        for (index, delay) in [0.15, 0.6, 1.4, 3.0].enumerated() {
            let item = DispatchWorkItem { [weak self] in self?.check(pass: index, reason: reason) }
            pending.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func left() {
        pending.forEach { $0.cancel() }; pending.removeAll()
        guard let webView else { return }
        if let saved = savedMagnification, webView.allowsMagnification { webView.magnification = saved }
        savedMagnification = nil
        webView.evaluateJavaScript(Self.cleanupScript, completionHandler: nil)
    }

    private func check(pass: Int, reason: String) {
        guard let webView, isFullscreen() || (webView.window?.styleMask.contains(.fullScreen) ?? false) else { return }
        // 1. Trackpad-vergroting staat fullscreen nooit kleiner (of groter) dan het scherm.
        if abs(webView.magnification - 1) > 0.001 {
            if savedMagnification == nil { savedMagnification = webView.magnification }
            log("fullscreen fit: magnification \(String(format: "%.2f", webView.magnification)) → 1")
            webView.magnification = 1
        }
        // 2. Webview vult zijn eigen houder (onze host-view; nooit WebKit's eigen fullscreen-views).
        if let host = webView.superview, host is WebHostNSView,          // V23.1: alleen onze eigen houder
           webView.translatesAutoresizingMaskIntoConstraints,
           Self.differs(webView.frame.size, host.bounds.size) {
            log("fullscreen fit: web view frame \(Int(webView.frame.width))x\(Int(webView.frame.height)) → \(Int(host.bounds.width))x\(Int(host.bounds.height))")
            webView.frame = host.bounds
            webView.autoresizingMask = [.width, .height]
        }
        webView.needsLayout = true
        webView.evaluateJavaScript(Self.fitScript) { [weak self] value, _ in
            guard let self, let webView = self.webView, let text = value as? String else { return }
            let parts = text.split(separator: "|").map(String.init)
            let state = parts.first ?? "?"
            let elementFullscreen = parts.count > 1 && parts[1] == "1"
            if state != "ok" && state != "inline" && state != "novideo" {
                self.log("fullscreen fit (\(reason), pass \(pass + 1)): \(state)")
            }
            // 3. Het fullscreen-vlak zelf (de webview in WebKit's fullscreen-venster) moet het scherm vullen.
            guard elementFullscreen, let window = webView.window, let screen = window.screen,
                  window.styleMask.contains(.fullScreen) else { return }
            let size = webView.convert(webView.bounds, to: nil).size
            // V25: op een MacBook met notch laat macOS de strook van de camera vrij in fullscreen. Dat is
            // geen "te klein" fullscreen: vergelijk met het bruikbare vlak (scherm min veilige marges),
            // anders zette de bewaker fullscreen op het ingebouwde scherm telkens uit en weer aan (hapering).
            let insets = screen.safeAreaInsets
            let usable = CGSize(width: screen.frame.width - insets.left - insets.right,
                                height: screen.frame.height - insets.top - insets.bottom)
            guard Self.smaller(size, than: usable) else { self.viewportMisses = 0; return }
            self.viewportMisses += 1
            self.log("fullscreen fit: viewport \(Int(size.width))x\(Int(size.height)) on screen \(Int(screen.frame.width))x\(Int(screen.frame.height))")
            if self.viewportMisses == 1 {
                if Self.differs(window.frame.size, screen.frame.size) { window.setFrame(screen.frame, display: true) }
                if let host = webView.superview, webView.translatesAutoresizingMaskIntoConstraints { webView.frame = host.bounds }
                webView.needsLayout = true
                webView.evaluateJavaScript("window.dispatchEvent(new Event('resize'));0", completionHandler: nil)
            } else if self.viewportMisses >= 2 && !self.reentered && pass >= 2 {
                self.reentered = true
                self.log("fullscreen fit: re-enter fullscreen")
                self.reenterFullscreen()
            }
        }
    }

    private static func differs(_ a: CGSize, _ b: CGSize) -> Bool {
        b.width > 10 && b.height > 10 && (abs(a.width - b.width) > 2 || abs(a.height - b.height) > 2)
    }
    private static func smaller(_ a: CGSize, than b: CGSize) -> Bool {
        b.width > 10 && b.height > 10 && (a.width < b.width * 0.97 || a.height < b.height * 0.97)
    }

    /// Geeft "status|elementFullscreen" terug. Status: inline, novideo, ok, nudged, forced.
    static let fitScript = """
    (()=>{const d=document,ID='joetoep-fs-fit';
    const fs=d.fullscreenElement||d.webkitFullscreenElement;
    const flexy=d.querySelector('ytd-watch-flexy');
    const on=!!(fs||(flexy&&flexy.hasAttribute('fullscreen'))||d.documentElement.hasAttribute('data-joetoep-stage'));
    if(!window.__joetoepFitHook){window.__joetoepFitHook=1;
      const off=()=>{if(!(d.fullscreenElement||d.webkitFullscreenElement)){d.getElementById(ID)?.remove();window.__joetoepFitNudged=0}};
      d.addEventListener('fullscreenchange',off);d.addEventListener('webkitfullscreenchange',off);}
    if(!on){d.getElementById(ID)?.remove();window.__joetoepFitNudged=0;return 'inline|0'}
    const v=d.querySelector('video[data-joetoep-video]')||d.querySelector('video.html5-main-video')||d.querySelector('video');
    const ef=fs?'1':'0';
    if(!v||!v.videoWidth||!v.videoHeight)return 'novideo|'+ef;
    const host=fs||d.querySelector('#movie_player')||d.documentElement;const b=host.getBoundingClientRect();
    const cw=Math.min(b.width||innerWidth,innerWidth),ch=Math.min(b.height||innerHeight,innerHeight);
    const s=Math.min(cw/v.videoWidth,ch/v.videoHeight),ew=v.videoWidth*s,eh=v.videoHeight*s;
    const r=v.getBoundingClientRect();
    const fits=r.width>=ew*0.97&&r.height>=eh*0.97&&r.left<=(cw-ew)/2+cw*0.02+1&&r.top<=(ch-eh)/2+ch*0.02+1;
    if(fits)return 'ok|'+ef;
    if(!window.__joetoepFitNudged){window.__joetoepFitNudged=1;window.dispatchEvent(new Event('resize'));
      return 'nudged '+Math.round(r.width)+'x'+Math.round(r.height)+' in '+Math.round(cw)+'x'+Math.round(ch)+'|'+ef}
    if(!d.getElementById(ID)){const st=d.createElement('style');st.id=ID;
      st.textContent='#movie_player .html5-video-container{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;transform:none!important}'+
      '#movie_player video.html5-main-video,video[data-joetoep-video]{position:absolute!important;left:0!important;top:0!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;object-fit:contain!important}';
      (d.head||d.documentElement).appendChild(st);}
    return 'forced '+Math.round(r.width)+'x'+Math.round(r.height)+' in '+Math.round(cw)+'x'+Math.round(ch)+'|'+ef})()
    """
    static let cleanupScript = "document.getElementById('joetoep-fs-fit')?.remove();window.__joetoepFitNudged=0;0"
}
#endif
