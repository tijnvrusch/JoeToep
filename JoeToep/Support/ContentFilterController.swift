import Foundation
// WebKit is Apple's raamwerk voor het tonen van webpagina's (WKWebView). Hier gebruiken we
// zijn "content rule list"-systeem om advertenties/tracking te blokkeren of te verbergen.
import WebKit
// CryptoKit levert cryptografische functies zoals SHA-256 hashing (zie compileExperimental).
import CryptoKit

/// Versioned WebKit rules with an opt-in, bounded EasyList cosmetic subset update.
// Deze class beheert de "advertentiefilters": lijsten met regels die WebKit vertelt welke
// netwerkverzoeken geblokkeerd moeten worden of welke onderdelen van een pagina verborgen
// moeten worden (bijvoorbeeld advertentiekaders).
@MainActor
final class ContentFilterController {
    // Woordenboek (Dictionary): koppelt de naam van een filterlijst aan de gecompileerde
    // WKContentRuleList die WebKit daadwerkelijk kan toepassen.
    private var lists: [String: WKContentRuleList] = [:]
    // Onthoudt welke filterlijsten op dit moment actief zijn toegepast.
    private var applied: Set<String> = []
    private(set) var experimentalStatus = "No downloaded experimental rules"
    private let defaults = UserDefaults.standard

    /// V22.2: de meegeleverde filter-JSON één keer inlezen en parsen (gedeeld door alle tabs).
    private static var cachedDefinitions: [String: Any]?
    private static func bundledDefinitions() -> [String: Any]? {
        if let cachedDefinitions { return cachedDefinitions }
        guard let url = Bundle.main.url(forResource: "contentFilters", withExtension: "json", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "contentFilters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var definitions = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        // Splitst de "ads"-lijst in twee delen: regels die verzoeken blokkeren ("block") en
        // regels die alleen elementen visueel verbergen ("css-display-none", de advertentiekaarten).
        if let ads = definitions["ads"] as? [[String: Any]] {
            definitions["adCards"] = ads.filter { ($0["action"] as? [String: Any])?["type"] as? String == "css-display-none" }
            definitions["ads"] = ads.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
        }
        // Laadt eventueel een tweede, strengere filterlijst en splitst die op dezelfde manier.
        if let url = Bundle.main.url(forResource: "strictAds", withExtension: "json", subdirectory: "Resources") ?? Bundle.main.url(forResource: "strictAds", withExtension: "json"),
           let data = try? Data(contentsOf: url), let rules = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            definitions["strictAds"] = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
            definitions["strictCards"] = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "css-display-none" }
        }
        cachedDefinitions = definitions
        return definitions
    }

    // "async" betekent: deze functie kan tijd kosten (bijv. wachten op WebKit) zonder de
    // hoofdthread te blokkeren; de aanroeper moet "await" gebruiken. Ze geeft een lijst met
    // namen van filters terug die NIET geladen konden worden (voor foutmeldingen/logging).
    func prepare() async -> [String] {
        // Zoekt het meegeleverde bestand "contentFilters.json" in de app-bundel en probeert
        // het in te lezen en om te zetten naar JSON. Als iets hiervan mislukt (try? geeft dan
        // nil), stopt de functie meteen via guard.
        guard let definitions = Self.bundledDefinitions(),
              let store = WKContentRuleListStore.default() else { return ["Rules unavailable"] }
        var failures: [String] = []
        // Voor elke filterlijst-naam (gesorteerd, voor voorspelbaarheid): probeer eerst een
        // eerder gecompileerde versie uit WebKit's eigen opslag te hergebruiken (sneller dan
        // opnieuw compileren). "identifier" is de unieke sleutel waaronder WebKit dit bewaart.
        for name in definitions.keys.sorted() {
            let identifier = "JoeToepV8.filters.1." + name
            // withCheckedContinuation bouwt een brug tussen een ouderwetse callback-API
            // (lookUpContentRuleList met een completion-closure) en Swifts moderne async/await:
            // de code "pauzeert" hier tot de closure continuation.resume(...) aanroept.
            let cached: WKContentRuleList? = await withCheckedContinuation { continuation in
                store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                    continuation.resume(returning: list)
                }
            }
            // "continue" slaat de rest van deze iteratie van de lus over en gaat door met de
            // volgende naam in de lijst.
            if let cached { lists[name] = cached; continue }
            // Zet de JSON-definitie van deze regel om naar tekst, zodat WebKit die kan compileren.
            guard let definition = definitions[name],
                  let encoded = try? JSONSerialization.data(withJSONObject: definition),
                  let json = String(data: encoded, encoding: .utf8) else {
                failures.append(name); continue
            }
            // Laat WebKit de regels compileren tot een snel toepasbare WKContentRuleList.
            let compiled: WKContentRuleList? = await withCheckedContinuation { continuation in
                store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, _ in
                    continuation.resume(returning: list)
                }
            }
            if let compiled { lists[name] = compiled } else { failures.append(name) }
        }
        // Als er eerder al experimentele regels gedownload en opgeslagen zijn, worden die
        // nu ook opnieuw gecompileerd, zodat ze meteen beschikbaar zijn.
        if let cached = defaults.string(forKey: "experimentalRulesV5") {
            do {
                lists["experimental"] = try await compileExperimental(cached)
                experimentalStatus = "Cached compatible EasyList subset · " + (defaults.string(forKey: "experimentalDateV5") ?? "date unknown")
            } catch { failures.append("cached experimental rules") }
        }
        return failures
    }

    // Bepaalt, op basis van de huidige instellingen, welke filterlijsten actief moeten zijn,
    // en past dat toe op de WKUserContentController die bij een webweergave hoort.
    func apply(_ settings: SettingsSnapshot, to controller: WKUserContentController) {
        var wanted: Set<String> = []
        if settings.blockAds {
            let level = settings.adBlockLevel
            if level.blocksAdServers { wanted.insert("ads") }
            if settings.hideAdCards { wanted.insert("adCards") }
            if level.blocksMeasurement {
                wanted.insert("strictAds")
                if settings.hideAdCards { wanted.insert("strictCards") }
            }
            if settings.experimentalFilters && settings.hideAdCards { wanted.insert("experimental") }
        }
        if settings.blockShortsNavigation { wanted.insert("shorts") }
        if settings.blockPostsNavigation { wanted.insert("posts") }
        if settings.blockPremiumDestinations { wanted.insert("premium") }
        // Alleen lijsten gebruiken die daadwerkelijk geladen zijn (voorkomt crashes op
        // ontbrekende namen).
        wanted = wanted.intersection(Set(lists.keys))
        // Als er niets veranderd is ten opzichte van wat al actief is, hoeven we niets te doen.
        guard wanted != applied else { return }
        controller.removeAllContentRuleLists()
        for name in wanted.sorted() {
            if let list = lists[name] { controller.add(list) }
        }
        applied = wanted
    }

    // Haalt een nieuwe, actuele versie van de experimentele filterregels op van internet
    // en compileert die. "throws" betekent dat deze functie een fout kan opgooien in plaats
    // van een normale waarde terug te geven; de aanroeper vangt dat op met "try".
    func refreshExperimental() async throws {
        let (json, count) = try await Self.downloadExperimentalRules()
        let compiled = try await compileExperimental(json)
        lists["experimental"] = compiled
        applied.remove("experimental")
        let date = ISO8601DateFormatter().string(from: Date())
        defaults.set(json, forKey: "experimentalRulesV5")
        defaults.set(date, forKey: "experimentalDateV5")
        experimentalStatus = "EasyList compatible subset · \(count) selectors · checked \(date)"
    }

    // "nonisolated" betekent: deze functie hoeft NIET op de hoofdthread te draaien (in
    // tegenstelling tot de rest van deze @MainActor-class), wat logisch is omdat ze alleen
    // met het netwerk werkt en geen UI aanraakt. "private static" betekent: alleen bruikbaar
    // binnen dit bestand/type, en hoort niet bij een specifiek object maar bij het type zelf.
    nonisolated private static func downloadExperimentalRules() async throws -> (String, Int) {
        // URLSessionConfiguration.ephemeral maakt een sessie die niets bewaart op schijf
        // (geen cache, geen cookies) — praktisch voor een eenmalige download.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        // "defer" voert deze code altijd uit vlak voordat de functie eindigt (ongeacht hoe
        // ze eindigt), hier om de sessie netjes op te ruimen.
        defer { session.invalidateAndCancel() }
        // session.bytes(from:) streamt de download byte voor byte in plaats van in één keer
        // alles in het geheugen te laden, zodat we de omvang kunnen beperken (zie hieronder).
        let (bytes, response) = try await session.bytes(from: ExperimentalFilterParser.source)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw FilterUpdateError.download }
        var data = Data()
        // "for try await byte in bytes" leest de gedownloade bytes één voor één, wat toelaat
        // om te stoppen zodra een limiet bereikt is (bescherming tegen een enorm bestand).
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw FilterUpdateError.tooLarge }
            data.append(byte)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw FilterUpdateError.download }
        let json = try ExperimentalFilterParser.rulesJSON(from: text)
        return (json, ExperimentalFilterParser.selectors(from: text).count)
    }

    // Compileert JSON-tekst met filterregels tot een WKContentRuleList die WebKit begrijpt,
    // en ruimt de vorige (verouderde) experimentele lijst op als er een nieuwe is.
    private func compileExperimental(_ json: String) async throws -> WKContentRuleList {
        guard let store = WKContentRuleListStore.default() else { throw FilterUpdateError.compile }
        // SHA256 hashing zet de inhoud om in een unieke "vingerafdruk" van vaste lengte.
        // Zo krijgt elke unieke inhoud een eigen identifier, en verandert die identifier
        // vanzelf als de regels wijzigen (handig om oude/nieuwe versies te herkennen).
        let hash = SHA256.hash(data: Data(json.utf8)).map { String(format: "%02x", $0) }.joined()
        let identifier = "JoeToepV5.experimental." + hash
        let list: WKContentRuleList? = await withCheckedContinuation { continuation in
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, _ in continuation.resume(returning: list) }
        }
        guard let list else { throw FilterUpdateError.compile }
        let previous = defaults.string(forKey: "experimentalIDV5")
        defaults.set(identifier, forKey: "experimentalIDV5")
        // Als er een vorige versie van de experimentele lijst was (met een andere hash),
        // wordt die verwijderd uit WebKit's opslag zodat er geen oude regels blijven hangen.
        if let previous, previous != identifier, previous.hasPrefix("JoeToepV5.experimental.") {
            store.removeContentRuleList(forIdentifier: previous) { _ in }
        }
        return list
    }
}
