#if os(iOS)
import UIKit

@MainActor
enum OrientationCoordinator {
    /// V15 (iPhone): the main interface stays in portrait; Apple's fullscreen video window may
    /// rotate freely. Turning the phone then goes straight into landscape fullscreen instead
    /// of first rotating the whole page (one animation instead of two).
    static var portraitLocked = false {
        didSet { if oldValue != portraitLocked { refreshSupportedOrientations() } }
    }
    static func requestLandscape() { request(.landscape) }
    static func requestPortrait() { request(.portrait) }

    // MARK: V23.1 — automatisch draaien bij fullscreen (iPhone), óók met rotatievergrendeling aan
    /// Instelling "Auto-rotate fullscreen" (standaard aan, per apparaat).
    static var autoRotateEnabled: Bool {
        UserDefaults.standard.object(forKey: autoRotateKey) as? Bool ?? true
    }
    static let autoRotateKey = "autoRotateFullscreenV231"
    /// Zolang dit aan staat (fullscreen, automatisch gedraaid) mag de interface alleen landscape zijn.
    /// Daardoor draait iOS niet meteen terug als de telefoon fysiek rechtop blijft of de
    /// rotatievergrendeling aan staat. Draai je de telefoon zelf naar landscape, dan gaat de klem eraf
    /// en werkt "rechtop = fullscreen uit" weer zoals altijd.
    private(set) static var fullscreenLandscape = false
    /// "Veilige fullscreen" (JoeToep's eigen weergave) zit in het app-venster zelf: dat moet dan meedraaien.
    private(set) static var appWindowRotates = false
    private static var retryWork: [DispatchWorkItem] = []
    static var log: ((String) -> Void)?

    /// Fullscreen gaat open → meteen naar landscape (+ twee controles, want iOS weigert een verzoek
    /// soms tijdens de presentatie-animatie van de fullscreen-speler).
    static func beginFullscreenLandscape(appWindow: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let already = fullscreenLandscape && appWindowRotates == appWindow
        fullscreenLandscape = true
        appWindowRotates = appWindow
        fullscreenExpectedUntil = nil
        // V24: staat de interface al in landscape (bijv. het venster-signaal hieronder was eerder),
        // dan géén tweede verzoek — een dubbel verzoek tijdens de draai gaf een zichtbare schok.
        if already, let scene = activeScene(), scene.interfaceOrientation.isLandscape { return }
        refreshSupportedOrientations()
        requestRepeatedly(.landscape, until: { $0.isLandscape })
    }
    /// V24: bewust GEEN klem-vrijgave meer bij fysiek kantelen. Met rotatievergrendeling aan liet
    /// die vrijgave iOS meteen terugspringen naar portrait terwijl de video fullscreen bleef.
    /// "Rechtop = fullscreen uit" werkt via de apparaat-oriëntatie en heeft de vrijgave niet nodig.
    static func releaseFullscreenLandscapeClamp() {}

    // MARK: V24 — draaien vanaf het allereerste frame
    /// De zichtbare tab staat op een pagina met een video (gezet door WebSession).
    static var videoContextActive = false
    /// Een fullscreen-verzoek is net gedaan (knop, automatisch, terug uit PiP).
    private static var fullscreenExpectedUntil: Date?
    static func expectFullscreen() {
        guard UIDevice.current.userInterfaceIdiom == .phone, autoRotateEnabled else { return }
        fullscreenExpectedUntil = Date().addingTimeInterval(2)
    }
    private static var expectingFullscreen: Bool { (fullscreenExpectedUntil ?? .distantPast) > Date() }
    /// Is dit (vermoedelijk) het fullscreen-venster van WebKit/AVKit? Toetsenbord-, tekst-, menu- en
    /// meldingsvensters tellen nooit mee.
    static func isVideoFullscreenWindow(_ window: UIWindow?) -> Bool {
        guard let window, window.windowLevel == .normal, !isAppInterfaceWindow(window) else { return false }
        let name = String(describing: type(of: window)) + "|" + window.rootViewController.map { String(describing: type(of: $0)) }.orEmpty
        for bad in ["Keyboard", "TextEffects", "Remote", "Alert", "Menu", "Callout", "Status", "Sheet", "Edit"] where name.contains(bad) { return false }
        return true
    }
    private static var windowObserver: NSObjectProtocol?
    /// Zodra WebKit/AVKit zijn fullscreen-venster zichtbaar maakt — nog vóór het bridge-event — al de
    /// landscape-klem zetten. Dan presenteert iOS de video direct liggend: één beweging, geen
    /// tussenbeeld in portrait en geen tweede draai erachteraan.
    static func installWindowObserver() {
        guard windowObserver == nil, UIDevice.current.userInterfaceIdiom == .phone else { return }
        windowObserver = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil, queue: .main) { note in
            let window = note.object as? UIWindow
            MainActor.assumeIsolated {
                guard autoRotateEnabled, videoContextActive || expectingFullscreen, isVideoFullscreenWindow(window),
                      UIApplication.shared.applicationState == .active else { return }
                log?("fullscreen window visible: landscape from first frame")
                beginFullscreenLandscape(appWindow: false)
                // Vangnet: bleek het geen blijvend fullscreen-venster, dan na 1,5 s de klem eraf.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    MainActor.assumeIsolated {
                        guard fullscreenLandscape, !appWindowRotates, let scene = activeScene() else { return }
                        let stillThere = scene.windows.contains { !$0.isHidden && isVideoFullscreenWindow($0) }
                        if !stillThere {
                            log?("fullscreen window gone: release landscape")
                            endFullscreenLandscape(returnToPortrait: true)
                        }
                    }
                }
            }
        }
    }
    /// Fullscreen dicht → klem eraf en (optioneel) meteen terug naar portrait.
    static func endFullscreenLandscape(returnToPortrait: Bool) {
        let wasClamped = fullscreenLandscape
        fullscreenLandscape = false
        appWindowRotates = false
        retryWork.forEach { $0.cancel() }; retryWork.removeAll()
        refreshSupportedOrientations()
        guard UIDevice.current.userInterfaceIdiom == .phone, returnToPortrait || wasClamped else { return }
        requestRepeatedly(.portrait, until: { $0.isPortrait })
    }
    private static func requestRepeatedly(_ mask: UIInterfaceOrientationMask, until done: @escaping @MainActor (UIInterfaceOrientation) -> Bool) {
        retryWork.forEach { $0.cancel() }; retryWork.removeAll()
        request(mask)
        for delay in [0.35, 0.8] {
            let work = DispatchWorkItem {
                MainActor.assumeIsolated {
                    guard let scene = activeScene() else { return }
                    if done(scene.interfaceOrientation) { return }
                    if mask == .landscape && !fullscreenLandscape { return }        // intussen gesloten
                    log?("rotation retry (\(mask == .landscape ? "landscape" : "portrait"), \(delay) s)")
                    request(mask)
                }
            }
            retryWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
    private static func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
    private static func request(_ mask: UIInterfaceOrientationMask) {
        // iPad's native video controller owns presentation, including Split View.
        // Forcing scene geometry while it presents can produce an empty fullscreen.
        guard let scene = activeScene() else { return }
        for window in scene.windows { window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            let text = "rotation request failed: \(error.localizedDescription)"
            DispatchQueue.main.async { MainActor.assumeIsolated { log?(text) } }
        }
    }
    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows { window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }
    /// SwiftUI's own windows host a UIHostingController; WebKit/AVKit fullscreen windows do not.
    static func isAppInterfaceWindow(_ window: UIWindow?) -> Bool {
        guard let root = window?.rootViewController else { return false }
        return String(describing: type(of: root)).contains("HostingController")
    }
    static func supportedOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        // V23.1: fullscreen automatisch gedraaid → alleen landscape (het app-venster zelf blijft
        // rechtop, behalve bij JoeToep's eigen "veilige" fullscreen die ín dat venster zit).
        if fullscreenLandscape {
            // V24: het app-venster blijft ALTIJD rechtop onder een automatisch gedraaide video (ook
            // zonder portretklem) — anders draaide de hele pagina mee en verschoof hij na het sluiten.
            if isAppInterfaceWindow(window) && !appWindowRotates { return .portrait }
            return .landscape
        }
        // V24: een fullscreen-venster dat net verschijnt, meteen liggend presenteren.
        if autoRotateEnabled && (expectingFullscreen || videoContextActive) && isVideoFullscreenWindow(window) {
            return .landscape
        }
        if portraitLocked && isAppInterfaceWindow(window) { return .portrait }
        return .allButUpsideDown
    }
}

final class JoeToepAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationCoordinator.supportedOrientations(for: window) }
    }
    /// V18: de Watch kan de iPhone-app op de achtergrond wekken; dan moet de verbinding er al
    /// zijn vóórdat er een venster bestaat.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated {
            OrientationCoordinator.installWindowObserver()   // V24
            WatchBridge.shared.activateSession()
            if UserDefaults.standard.object(forKey: "tabSyncV18") as? Bool ?? true { TabSyncService.shared.start() }
            // V22.2: ook bij een achtergrondstart widgets/Live Activity/Watch-toestand bijhouden (idempotent).
            WidgetBridge.shared.startOnce()
        }
        return true
    }
}
#endif

#if os(iOS)
private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
#endif
