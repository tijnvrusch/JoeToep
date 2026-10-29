import Foundation

// StartPage beschrijft welke YouTube-pagina de app opent bij het opstarten
// (of via de tabbalk): Home, Abonnementen, Bibliotheek, Geschiedenis of
// Later kijken. Omdat er geen "= tekst" achter elke case staat, is de
// rawValue automatisch gelijk aan de naam van de case zelf (dus "home",
// "subscriptions", enz.).
enum StartPage: String, CaseIterable, Codable, Identifiable, Sendable {
    case home
    case subscriptions
    case library
    case history
    case watchLater

    // Vervult "Identifiable": elke case is uniek te herkennen via zijn rawValue.
    var id: String { rawValue }

    // Leesbare naam voor in bijv. een instellingenmenu.
    var title: String {
        switch self {
        case .home: "Home"
        case .subscriptions: "Subscriptions"
        case .library: "Library"
        case .history: "History"
        case .watchLater: "Watch later"
        }
    }

    // Naam van het SF Symbols-icoon dat bij deze pagina hoort.
    var symbolName: String {
        switch self {
        case .home: "house"
        case .subscriptions: "rectangle.stack"
        case .library: "books.vertical"
        case .history: "clock.arrow.circlepath"
        case .watchLater: "bookmark"
        }
    }

    // Geeft de daadwerkelijke webadres (URL) terug die geladen moet worden
    // voor deze pagina.
    var url: URL {
        // Eerst wordt de tekst van de URL bepaald per case...
        let rawURL: String
        switch self {
        case .home: rawURL = "https://m.youtube.com/"
        case .subscriptions: rawURL = "https://m.youtube.com/feed/subscriptions"
        case .library: rawURL = "https://www.youtube.com/feed/you"
        case .history: rawURL = "https://www.youtube.com/feed/history"
        case .watchLater: rawURL = "https://m.youtube.com/playlist?list=WL"
        }
        // ...en dan omgezet naar een echt URL-object. "URL(string:)" geeft een
        // optional terug (kan mislukken bij een ongeldige tekst); met "??"
        // geven we een veilige terugval-URL ("/") als dat toch zou gebeuren.
        return URL(string: rawURL) ?? URL(fileURLWithPath: "/")
    }
}
