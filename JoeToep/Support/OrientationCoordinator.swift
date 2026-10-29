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
        fullscreenLandscape = true
        appWindowRotates = appWindow
        refreshSupportedOrientations()
        requestRepeatedly(.landscape, until: { $0.isLandscape })
    }
    /// De telefoon is fysiek naar landscape gedraaid: klem eraf (normale rotatie werkt weer).
    static func releaseFullscreenLandscapeClamp() {
        guard fullscreenLandscape else { return }
        fullscreenLandscape = false
        appWindowRotates = false
        refreshSupportedOrientations()
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
        for delay in [0.25, 0.7] {
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
            if isAppInterfaceWindow(window) && portraitLocked && !appWindowRotates { return .portrait }
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
            WatchBridge.shared.activateSession()
            if UserDefaults.standard.object(forKey: "tabSyncV18") as? Bool ?? true { TabSyncService.shared.start() }
            // V22.2: ook bij een achtergrondstart widgets/Live Activity/Watch-toestand bijhouden (idempotent).
            WidgetBridge.shared.startOnce()
        }
        return true
    }
}
#endif
