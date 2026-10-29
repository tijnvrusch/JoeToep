import Foundation

/// Only simple YouTube ad-container selectors are imported. No scriptlets,
/// arbitrary CSS, network redirects or playback-element rules are executable here.
// Een "enum zonder cases" (alleen static leden) wordt in Swift vaak gebruikt
// als een soort "naamruimte" om bij elkaar horende functies/constantes te
// groeperen, zonder dat je er ooit een instantie van maakt.
enum ExperimentalFilterParser {
    // "!" na URL(string:) forceert het uitpakken van de optional: we zijn
    // hier zo zeker dat deze tekst een geldige URL is, dat we de app laten
    // crashen als dat toch niet zo zou zijn (in plaats van een optional netjes
    // af te handelen). Dit is de bron waar de advertentie-filterlijst
    // vandaan gehaald wordt.
    static let source = URL(string: "https://raw.githubusercontent.com/easylist/easylist/master/easylist/easylist_specific_hide.txt")!
    // Haalt uit een ruwe filterlijst-tekst alleen de CSS-selectors die
    // overeenkomen met bekende YouTube-advertentie-elementen. "-> [String]"
    // betekent: geeft een lijst (array) van teksten terug.
    static func selectors(from text: String) -> [String] {
        // De "kale" namen van bekende advertentie-onderdelen in YouTube's
        // eigen HTML-structuur (zonder het ytd-/ytm- voorvoegsel).
        let adNames = ["ad-slot-renderer", "display-ad-renderer", "in-feed-ad-layout-renderer",
                       "banner-promo-renderer", "action-companion-ad-renderer", "companion-ad-renderer",
                       "promoted-sparkles-web-renderer", "promoted-sparkles-text-search-renderer",
                       "promoted-video-renderer", "search-pyv-renderer"]
        // "flatMap" combineert twee lijsten door voor élk voorvoegsel
        // ("ytd-"/"ytm-") elke naam uit adNames ervoor te plakken, en al die
        // resultaten in één platte lijst te zetten. Daarna voegen we nog een
        // paar losse, bekende selectors toe. "Set(...)" maakt er een
        // verzameling van: snel te doorzoeken en zonder duplicaten.
        let allowed = Set(["ytd-", "ytm-"].flatMap { prefix in adNames.map { prefix + $0 } } + ["#player-ads", "#masthead-ad", ".ytp-ad-overlay-container"])
        // "var" omdat we dit resultaat stap voor stap gaan vullen.
        var result = Set<String>()
        // We lopen door elke regel van de meegegeven tekst. "\.isNewline" is
        // een "key path": een compacte manier om te zeggen "splits op het
        // punt waar isNewline waar is", zonder een losse closure te schrijven.
        for line in text.split(whereSeparator: \.isNewline) {
            // Een regel in dit bestandsformaat ziet eruit als
            // "domein1,domein2##selector1,selector2". We splitsen op "##".
            let parts = line.components(separatedBy: "##")
            // Als een regel niet precies uit 2 delen bestaat, is het geen
            // bruikbare regel; sla hem over met "continue".
            guard parts.count == 2 else { continue }
            let domains = parts[0].split(separator: ",").map(String.init)
            // Regels met een "~" ervoor zijn juist UITZONDERINGEN
            // (niet-toepasselijk op dat domein) — die slaan we over, want wij
            // willen alleen regels die YouTube expliciet targeten.
            guard !domains.contains(where: { $0.hasPrefix("~") }) else { continue }
            // Alleen regels die (ook) voor een van de YouTube-domeinen gelden
            // worden meegenomen.
            guard domains.contains("youtube.com") || domains.contains("www.youtube.com") || domains.contains("m.youtube.com") else { continue }
            // Van de selectors in het tweede deel houden we alleen degene over
            // die letterlijk voorkomen in onze eigen "allowed"-lijst hierboven
            // — dit is de veiligheidsmaatregel uit de opmerking bovenaan:
            // alleen bekende, simpele advertentie-selectors worden toegelaten.
            for selector in parts[1].split(separator: ",") {
                let value = selector.trimmingCharacters(in: .whitespaces)
                if allowed.contains(value) { result.insert(value) }
            }
        }
        // ".sorted()" zet de verzameling om in een alfabetisch gesorteerde
        // lijst, zodat de uitvoer altijd in dezelfde, voorspelbare volgorde staat.
        return result.sorted()
    }
    // Zet de gevonden selectors om in een JSON-tekst die WebKit (de browser-
    // motor) kan gebruiken als contentblokkeringsregel. "throws" betekent dat
    // deze functie een fout kan opgooien in plaats van altijd netjes een
    // waarde terug te geven; de aanroeper moet dat afhandelen met "try".
    static func rulesJSON(from text: String) throws -> String {
        let selectors = selectors(from: text)
        // Als er geen enkele bruikbare selector gevonden is, heeft het geen
        // zin om regels te maken: we gooien een eigen foutmelding.
        guard !selectors.isEmpty else { throw FilterUpdateError.noCompatibleRules }
        // Bouwt de regel-structuur op zoals WebKit die verwacht: "verberg met
        // CSS" alle elementen die matchen met onze selectors, op elk van de
        // genoemde YouTube-domeinen.
        let rules: [[String: Any]] = [["trigger": ["url-filter": ".*", "if-domain": ["youtube.com", "www.youtube.com", "m.youtube.com"]],
                                     "action": ["type": "css-display-none", "selector": selectors.joined(separator: ", ")]]]
        // Zet de Swift-datastructuur om in ruwe JSON-data. "try" geeft aan
        // dat dit kan mislukken (en dan de fout doorgeeft aan de aanroeper).
        // ".sortedKeys" zorgt voor een voorspelbare, gesorteerde volgorde van
        // de sleutels in de JSON-tekst.
        let data = try JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        // Zet de ruwe bytes om in een leesbare tekst (String), met UTF-8 als
        // tekstcodering.
        return String(decoding: data, as: UTF8.self)
    }
}

// Een aparte enum met foutmeldingen die bij het bijwerken van de
// advertentiefilter kunnen optreden. "LocalizedError" is een protocol
// waarmee je een nette, door de gebruiker leesbare foutomschrijving kunt geven.
enum FilterUpdateError: LocalizedError {
    case download, tooLarge, noCompatibleRules, compile
    // Geeft de bijpassende, leesbare Engelse foutmelding terug per soort fout.
    var errorDescription: String? {
        switch self {
        case .download: "The filter source could not be downloaded. Previous rules remain active."
        case .tooLarge: "The filter response exceeded the size limit. Previous rules remain active."
        case .noCompatibleRules: "No supported YouTube ad-container rules were found. Previous rules remain active."
        case .compile: "WebKit rejected the updated rules. Previous rules remain active."
        }
    }
}
