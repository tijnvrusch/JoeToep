// SwiftUI is Apple's raamwerk om schermen (user interfaces) mee te bouwen met
// declaratieve code: je beschrijft HOE iets eruit moet zien, en SwiftUI regelt
// zelf hoe het getekend en bijgewerkt wordt.
import SwiftUI

// AmbientBackground is een "View": een bouwsteentje van het scherm. Elke struct
// die het "View"-protocol volgt (protocol = een lijst met eisen waaraan een
// type moet voldoen) moet een "body" hebben die beschrijft wat er getoond wordt.
// Deze View is simpelweg een donkere achtergrondkleur voor de hele app.
struct AmbientBackground: View {
    // "body" is een "computed property": in plaats van een opgeslagen waarde
    // wordt hier elke keer opnieuw berekend (en getekend) wat de inhoud is.
    var body: some View {
        // A background must never contribute a 460pt intrinsic width on a 390pt phone.
        // Color(red:green:blue:) maakt een eigen kleur met waardes van 0 tot 1
        // per kleurkanaal (rood, groen, blauw) in plaats van een systeemkleur.
        Color(red: 0.035, green: 0.035, blue: 0.04)
            // .ignoresSafeArea() zorgt dat de kleur ook doorloopt tot achter de
            // notch/statusbalk/homebar, in plaats van daar netjes voor te stoppen.
            .ignoresSafeArea()
            // Verbergt dit element voor VoiceOver (schermlezer): het is puur
            // decoratief en heeft geen betekenis om voor te lezen.
            .accessibilityHidden(true)
    }
}
