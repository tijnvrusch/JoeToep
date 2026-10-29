#if os(macOS)
import AppKit

/// V18 — Zoekt uit op welk scherm de app staat die net naar voren kwam, en meldt
/// (zolang JoeToep op de achtergrond is) wanneer een app op JoeToep's scherm actief wordt.
@MainActor
final class ScreenFocusMonitor {
    private var observer: NSObjectProtocol?

    /// Unieke naam voor een scherm (het display-nummer blijft gelijk zolang het aangesloten is).
    static func id(of screen: NSScreen?) -> String? {
        guard let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return number.stringValue
    }

    /// Het scherm van het voorste normale venster van `app`; valt terug op de muispositie
    /// (je hebt immers net op dat scherm geklikt) als de app geen zichtbaar venster heeft.
    static func screenID(of app: NSRunningApplication?) -> String? {
        if let app, let frame = frontWindowFrame(pid: app.processIdentifier),
           let screen = NSScreen.screens.max(by: { overlap($0.frame, frame) < overlap($1.frame, frame) }),
           overlap(screen.frame, frame) > 0 {
            return id(of: screen)
        }
        let mouse = NSEvent.mouseLocation
        return id(of: NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) })
    }

    /// Venster-rechthoek in AppKit-coördinaten (oorsprong linksonder).
    private static func frontWindowFrame(pid: pid_t) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        for info in list {   // van voor naar achter
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  ((info[kCGWindowAlpha as String] as? Double) ?? 1) > 0.05,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: dict), cg.width > 60, cg.height > 60 else { continue }
            return CGRect(x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
        }
        return nil
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b); return i.isNull ? 0 : i.width * i.height
    }

    /// Roept `handler` aan voor elke app die actief wordt (niet JoeToep zelf), met haar scherm-id.
    func start(_ handler: @escaping @MainActor (String?) -> Void) {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            MainActor.assumeIsolated { handler(ScreenFocusMonitor.screenID(of: app)) }
        }
    }

    func stop() {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }
}
#endif

#if os(macOS)
/// V18 — merkt de eerste klik/toets/scroll in JoeToep op (goedkoop: één lokale event-monitor,
/// en de actie zelf doet niets als er niets klaarstaat).
@MainActor
final class UserActivityMonitor {
    static let shared = UserActivityMonitor()
    private var monitor: Any?
    func install(_ action: @escaping @MainActor () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown, .scrollWheel]) { event in
            MainActor.assumeIsolated { action() }
            return event
        }
    }
}
#endif
