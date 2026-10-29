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
    private static func request(_ mask: UIInterfaceOrientationMask) {
        // iPad's native video controller owns presentation, including Split View.
        // Forcing scene geometry while it presents can produce an empty fullscreen.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) else { return }
        scene.windows.first(where: \.isKeyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
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
        if portraitLocked && isAppInterfaceWindow(window) { return .portrait }
        return .allButUpsideDown
    }
}

final class JoeToepAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationCoordinator.supportedOrientations(for: window) }
    }
}
#endif
