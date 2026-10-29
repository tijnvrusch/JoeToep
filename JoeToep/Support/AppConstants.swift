// Dit bestand importeert Foundation, de basisbibliotheek van Apple met simpele bouwstenen
// zoals String, URL en Date. Bijna elk Swift-bestand heeft dit nodig.
import Foundation

// Een "enum" (enumeratie) is normaal een lijst van keuzes (bijvoorbeeld dagen van de week).
// Hier wordt de enum zonder eigen "cases" gebruikt als simpele naamruimte: een plek om
// constante waarden (static let) bij elkaar te zetten, zodat je overal in de app
// AppConstants.appName kunt gebruiken in plaats van de tekst steeds opnieuw te typen.
enum AppConstants {
    // "static let" betekent: een vaste waarde die bij het type zelf hoort (niet per instantie)
    // en die nooit meer verandert nadat hij is gezet.
    static let appName = "JoeToep"
    static let version = "18.0.0"
    // URL(string:) probeert een tekst om te zetten naar een geldige URL. Dit kan mislukken
    // (bijvoorbeeld bij een typefout), daarom is het resultaat optioneel (URL?).
    static let youtubeTermsURL = URL(string: "https://www.youtube.com/t/terms")
    static let googlePrivacyURL = URL(string: "https://policies.google.com/privacy")
    static let projectPrivacyURL = URL(string: "https://www.youtube.com/howyoutubeworks/user-settings/privacy/")
    // Deze namen worden gebruikt om berichten tussen de webpagina (JavaScript) en de
    // native app te herkennen, en om het los bijgeleverde JavaScript-bestand te vinden.
    static let scriptMessageName = "joeToep"
    static let linkMessageName = "joeToepLinks"
    static let bridgeResourceName = "playerBridge"
    static let bridgeResourceExtension = "js"
}
