#if os(macOS)
import AppKit

/// V19.1 — Scrubben (horizontaal) en volume (verticaal) met het trackpad of de muis, in
/// fullscreen, rechtstreeks vanuit macOS-scroll-events.
///
/// Waarom native en niet in de webpagina? Alleen hier weten we WELK apparaat het is
/// (trackpad = events met een "fase"; muis/Mac Mouse Fix = zonder), of "natuurlijk scrollen"
/// aan staat, en krijgen we de ruwe, vloeiende delta's. Zo kan elk apparaat zijn eigen richting
/// en gevoeligheid hebben, en voelt het net zo soepel als de Mac-gebaren.
@MainActor
final class GestureScrubber {
    static let shared = GestureScrubber()

    enum Device: String { case trackpad, mouse }
    enum Axis { case none, horizontal, vertical }

    /// Laatst gezien (voor de "nerd"-diagnose in Instellingen).
    private(set) var lastDevice: Device = .trackpad
    private(set) var lastSummary = ""

    private var axis: Axis = .none
    private var lockDistanceX: CGFloat = 0, lockDistanceY: CGFloat = 0
    private var pendingSeek: Double = 0, pendingVolume: Double = 0
    private var stepAccumulator: Double = 0
    private var flushQueued = false
    private var lastEventTime: TimeInterval = 0

    private let defaults = UserDefaults.standard
    private func double(_ key: String, _ fallback: Double) -> Double { defaults.object(forKey: key) as? Double ?? fallback }
    private func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }

    /// Geeft true als het event door ons is afgehandeld (dan niet doorgeven aan de pagina).
    func handle(_ event: NSEvent) -> Bool {
        guard flag("nativeGesturesV191", true),
              let workspace = BrowserWorkspace.active else { return false }
        let session = workspace.selected.session
        // V19.2: in fullscreen alles (scrub + volume); inline op een videopagina alleen HORIZONTAAL
        // scrubben (verticaal blijft gewoon de pagina scrollen).
        let fullscreen = isFullscreenContext(event, session: session)
        let inline = !fullscreen && flag("scrubInlineV192", true) && NavigationPolicy.isPlaybackPage(session.currentURL)
        guard fullscreen || inline else { reset(); return false }

        let device: Device = (event.phase.isEmpty && event.momentumPhase.isEmpty) ? .mouse : .trackpad
        // Uitloop (momentum) na het loslaten van het trackpad negeren: anders "schiet" het door.
        // V21: inline alleen de uitloop van een SCRUB-gebaar inslikken; verticale uitloop = gewoon scrollen.
        if device == .trackpad && !event.momentumPhase.isEmpty && flag("ignoreMomentumV191", true) {
            return fullscreen || axis == .horizontal
        }
        if event.phase == .began || event.timestamp - lastEventTime > 0.25 { reset() }
        lastEventTime = event.timestamp
        lastDevice = device

        // Ruwe delta's → "vingerrichting": + rechts, + omhoog, los van natuurlijk scrollen.
        var dx = Double(event.scrollingDeltaX), dy = Double(event.scrollingDeltaY)
        if !event.hasPreciseScrollingDeltas { dx *= 10; dy *= 10 }        // muiswiel geeft regels, geen punten
        if event.isDirectionInvertedFromDevice { dy = -dy } else { dx = -dx }
        // Instelbare richting per apparaat.
        if flag(device == .trackpad ? "invertTrackpadXV191" : "invertMouseXV191", false) { dx = -dx }
        if flag(device == .trackpad ? "invertTrackpadYV191" : "invertMouseYV191", false) { dy = -dy }

        // As vastzetten: de eerste ±6 pt beslissen of dit scrubben of volume is (geen gemengde bewegingen).
        if axis == .none {
            lockDistanceX += abs(dx); lockDistanceY += abs(dy)
            let lock = double("axisLockPointsV191", 6)
            // V21: inline ook al tijdens het "beslissen" horizontale bewegingen inslikken, anders
            // begint WebKit's elastische overscroll en schuift de pagina mee.
            if max(lockDistanceX, lockDistanceY) < lock && device == .trackpad { return fullscreen || lockDistanceX >= lockDistanceY }
            let ratio = double("axisRatioV191", 1.3)
            axis = lockDistanceX >= lockDistanceY * ratio ? .horizontal : (lockDistanceY >= lockDistanceX * ratio ? .vertical : (lockDistanceX >= lockDistanceY ? .horizontal : .vertical))
        }

        if inline && axis != .horizontal { return false }     // inline: verticaal = pagina scrollen
        let continuous = (defaults.string(forKey: "gestureModeV191") ?? "continuous") == "continuous"
        switch axis {
        case .horizontal:
            let perPoint = double(device == .trackpad ? "seekPerPointTrackpadV191" : "seekPerPointMouseV191", device == .trackpad ? 0.05 : 0.2)
            if continuous { pendingSeek += dx * perPoint }
            else { stepped(dx, threshold: double("stepThresholdV191", 28)) { self.pendingSeek += $0 * self.double("swipeSeekSecondsV19", 5) } }
        case .vertical:
            let perPoint = double(device == .trackpad ? "volumePerPointTrackpadV191" : "volumePerPointMouseV191", device == .trackpad ? 0.3 : 1.0)
            if continuous { pendingVolume += dy * perPoint / 100 }
            else { stepped(dy, threshold: double("stepThresholdV191", 28)) { self.pendingVolume += $0 * self.double("volumeStepPercentV19", 1) / 100 } }
        case .none: break
        }
        lastSummary = String(format: "%@ · dx %.1f dy %.1f · %@", device.rawValue, dx, dy, axis == .horizontal ? "scrub" : "volume")
        scheduleFlush(session)
        return true
    }

    private func stepped(_ delta: Double, threshold: Double, _ apply: (Double) -> Void) {
        stepAccumulator += delta
        while abs(stepAccumulator) >= threshold {
            apply(stepAccumulator > 0 ? 1 : -1)
            stepAccumulator -= stepAccumulator > 0 ? threshold : -threshold
        }
    }

    /// Hooguit één JavaScript-aanroep per runloop-beurt (±120/s): vloeiend, zonder de pagina te overspoelen.
    private func scheduleFlush(_ session: WebSession) {
        guard !flushQueued else { return }
        flushQueued = true
        DispatchQueue.main.async { [weak self, weak session] in
            guard let self, let session else { return }
            self.flushQueued = false
            let reveal = self.flag("showControlsWhileScrubbingV19", true)
            if abs(self.pendingSeek) >= 0.01 {
                session.webView.evaluateJavaScript("window.JoeToepControls && window.JoeToepControls.seek(\(self.pendingSeek), \(reveal)); 0", completionHandler: nil)
                self.pendingSeek = 0
            }
            if abs(self.pendingVolume) >= 0.001 {
                session.webView.evaluateJavaScript("window.JoeToepControls && window.JoeToepControls.volume(\(self.pendingVolume), \(reveal)); 0", completionHandler: nil)
                self.pendingVolume = 0
            }
        }
    }

    private func reset() {
        axis = .none; lockDistanceX = 0; lockDistanceY = 0; stepAccumulator = 0
    }

    /// Fullscreen = WebKit's eigen fullscreen-venster, een macOS-fullscreen-venster, of de
    /// app weet zelf dat de video fullscreen is.
    private func isFullscreenContext(_ event: NSEvent, session: WebSession) -> Bool {
        if session.isFullscreen { return true }
        guard let window = event.window else { return false }
        if String(describing: type(of: window)).contains("FullScreen") { return true }
        return window.styleMask.contains(.fullScreen) && flag("gesturesInWindowFullscreenV191", true)
            && NavigationPolicy.isPlaybackPage(session.currentURL)
    }
}
#endif
