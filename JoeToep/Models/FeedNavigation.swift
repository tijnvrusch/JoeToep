// "import Foundation" haalt Apple's basisraamwerk binnen: hierin zitten
// bouwstenen zoals URL, String-hulpfuncties, Data, etc. Bijna elk Swift-bestand
// heeft dit nodig zodra het met dit soort basistypes werkt.
import Foundation

/// Keep account feeds off the mobile-only routes that can render an empty shell.
/// Playback pages retain the user's selected presentation.
// FeedNavigation is een "struct" (een simpel datatype/waarde-type in Swift).
// Deze struct bevat geen eigen data, maar groepeert alleen een hulp-functie
// die bepaalt of een YouTube-pagina beter in de "desktop"-weergave getoond
// moet worden in plaats van de mobiele weergave.
struct FeedNavigation {
    // "static" betekent: deze functie hoort bij het type FeedNavigation zelf,
    // niet bij een specifiek "instance" (exemplaar) ervan. Je roept hem dus aan
    // als FeedNavigation.needsDesktop(...), zonder eerst een FeedNavigation te maken.
    static func needsDesktop(_ url: URL, isPhone: Bool) -> Bool {
        // "guard ... else { return ... }" is een vroege-uitstap-check: als de
        // voorwaarde niet klopt (dit is geen YouTube-host), stoppen we meteen
        // en geven we false terug. Zo hoeven we de rest van de functie niet
        // in een grote if-blok te zetten.
        guard NavigationPolicy.isYouTubeHost(url.host ?? "") else { return false }
        // Hier kijken we naar het pad van de URL (het stuk na youtube.com/).
        // "/feed/history" moet altijd naar desktop-weergave, ongeacht apparaat.
        // De andere twee paden ("/feed/you" en "/feed/library") moeten dat
        // alleen op een telefoon (isPhone == true), omdat ze daar leeg kunnen
        // renderen in de mobiele opmaak.
        return url.path == "/feed/history" || (isPhone && ["/feed/you", "/feed/library"].contains(url.path))
    }
}
