import Foundation

/// V17.1 — "Open link in new window" (Mac en iPad).
///
/// Een nieuw venster openen kan in SwiftUI alleen vanuit een scherm (`openWindow`). Daarom:
///  1. de link wordt hier klaargezet (`pending`),
///  2. er gaat een melding (Notification) rond; alleen het actieve venster reageert en opent
///     een nieuw venster,
///  3. het nieuwe venster pakt bij het verschijnen de klaargezette link op en opent hem.
@MainActor
enum WindowOpener {
    private(set) static var pending: URL?
    static let notification = Notification.Name("nl.tijn.JoeToep.openWindow")
    /// Zet `url` klaar en vraagt het actieve venster om een nieuw venster te openen.
    static func open(_ url: URL) {
        pending = url
        NotificationCenter.default.post(name: notification, object: nil)
    }
    /// Voor het nieuwe venster: geeft de klaargezette link één keer terug (en wist hem).
    static func takePending() -> URL? {
        defer { pending = nil }
        return pending
    }
}
