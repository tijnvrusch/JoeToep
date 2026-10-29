import Foundation

// Dit is een "enum met rawValue": elke mogelijke case heeft een bijbehorende
// tekstwaarde (rawValue), hier de interne naam die YouTube zelf gebruikt voor
// een videokwaliteit (bijv. "hd720"). Zo kun je makkelijk wisselen tussen de
// Swift-case en de tekst die de website/API verwacht.
// De protocollen na de dubbele punt geven extra vermogens aan dit type:
// - CaseIterable: je kan met "PlaybackQualityPreference.allCases" alle cases
//   in één keer oplijsten (handig voor bijv. een instellingenlijst).
// - Codable: dit type kan automatisch worden omgezet naar/van JSON of andere
//   opslagformaten (bijv. voor UserDefaults).
// - Identifiable: heeft een "id", nodig voor gebruik in SwiftUI-lijsten.
// - Sendable: dit type is veilig om tussen verschillende threads (parallelle
//   uitvoeringspaden) door te geven, belangrijk voor Swift's concurrency-checks.
enum PlaybackQualityPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic = "auto"
    case p144 = "tiny"
    case p240 = "small"
    case p360 = "medium"
    case p480 = "large"
    case p720 = "hd720"
    case p1080 = "hd1080"
    case p1440 = "hd1440"
    case p2160 = "hd2160"
    // Vervult de eis van "Identifiable": de rawValue zelf dient als unieke id.
    var id: String { rawValue }
    // Leesbare naam voor in de gebruikersinterface, per case anders.
    var title: String {
        switch self {
        case .automatic: "Auto"
        case .p144: "144p"
        case .p240: "240p"
        case .p360: "360p"
        case .p480: "480p"
        case .p720: "720p"
        case .p1080: "1080p"
        case .p1440: "1440p"
        case .p2160: "2160p · 4K"
        }
    }
    // Zet een eerder opgeslagen tekstwaarde (bijv. uit instellingen) terug om
    // in een geldige case. "static" betekent dat je dit aanroept als
    // PlaybackQualityPreference.restored(...), zonder eerst een instantie te
    // hebben.
    static func restored(_ raw: String?) -> Self {
        // "if let raw, let exact = ..." is optionele-binding: we controleren
        // eerst of "raw" niet nil is, en dan of er een case bestaat met die
        // rawValue. Als beide kloppen, geven we die case terug.
        if let raw, let exact = Self(rawValue: raw) { return exact }
        // V1 changed site presentation, not actual stream quality.
        // Als er niets bruikbaars was opgeslagen (bijv. eerste keer starten,
        // of een oude/ongeldige waarde), vallen we terug op "automatic".
        return .automatic
    }
}
