import Foundation

// ─────────────────────────────────────────────────────────────────────────────────────────────
// V17 — keuzes voor cookiebanners en privacy.
// Een `enum` is een lijstje vaste keuzes. `String` achter de naam betekent dat elke keuze een
// tekstwaarde heeft (rawValue) waarmee we hem opslaan in UserDefaults (het instellingenbestand).
// `CaseIterable` geeft ons `.allCases` (handig voor een Picker), `Identifiable` geeft elke keuze
// een uniek `id` zodat SwiftUI ze in een lijst kan tonen, `Sendable` betekent veilig tussen threads.
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// Hoe JoeToep met cookiebanners omgaat (Instellingen › Privacy).
enum CookieBannerMode: String, CaseIterable, Identifiable, Sendable {
    // Zoek de "Alles weigeren"/"Alleen noodzakelijk"-knop en klik hem automatisch (standaard).
    case rejectAll
    // Klik niets, maar verberg de banner (de site ziet dan: nog geen keuze gemaakt).
    case hideOnly
    // Doe niets: je ziet de banners zoals de site ze toont.
    case off

    // `id` is gewoon de tekstwaarde zelf.
    var id: String { rawValue }

    // De tekst die in de instellingen staat.
    var title: String {
        switch self {
        case .rejectAll: "Automatisch weigeren (aanbevolen)"
        case .hideOnly: "Alleen verbergen, niets klikken"
        case .off: "Uit — banners gewoon tonen"
        }
    }
}

/// V17 privacyhulpjes: welke volg-parameters (tracking) we uit links halen.
/// Voorbeeld: `https://site.nl/pagina?utm_source=nieuwsbrief&id=5` wordt `…/pagina?id=5`.
enum TrackingParameters {
    // Exacte namen van parameters die alleen dienen om jou te volgen.
    static let exact: Set<String> = [
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid",
        "igshid", "igsh", "mc_eid", "mc_cid", "_hsenc", "_hsmi", "mkt_tok", "ref_src", "ref_url",
        "si", "pp", "feature", "spm", "vero_id", "oly_enc_id", "oly_anon_id", "__s", "s_cid"
    ]
    // Alles wat met deze letters begint (bijv. utm_source, utm_medium, utm_campaign …).
    static let prefixes = ["utm_", "hsa_", "pk_", "mtm_", "at_"]

    /// Geeft een schone versie van `url` terug (of dezelfde als er niets te halen viel).
    /// - YouTube's `si` en `pp` zijn volg-codes bij gedeelde links; `v`, `t`, `list` blijven staan.
    static func clean(_ url: URL) -> URL {
        // URLComponents knipt een URL in stukjes (host, pad, parameters …).
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = parts.queryItems, !items.isEmpty else { return url }
        // `filter` houdt alleen de parameters over die NIET op de volglijst staan.
        let kept = items.filter { item in
            let name = item.name.lowercased()
            return !exact.contains(name) && !prefixes.contains { name.hasPrefix($0) }
        }
        // Niets veranderd? Dan de originele URL teruggeven (sneller, geen nieuwe navigatie).
        guard kept.count != items.count else { return url }
        // Geen parameters meer over → zet queryItems op nil zodat er geen losse "?" achterblijft.
        parts.queryItems = kept.isEmpty ? nil : kept
        return parts.url ?? url
    }
}
