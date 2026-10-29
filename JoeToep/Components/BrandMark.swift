import SwiftUI

// BrandMark tekent het logo van de app: een play-icoontje plus (optioneel) de
// naam "JoeToep" eronder. Wordt gebruikt op plekken zoals de startpagina of
// een header, waar het "merk" van de app getoond moet worden.
struct BrandMark: View {
    // Een gewone (niet-computed) property met een standaardwaarde. Als iemand
    // BrandMark(compact: true) gebruikt, wordt alleen het icoon getoond, zonder
    // tekst eronder.
    var compact = false
    var body: some View {
        // HStack zet zijn inhoud horizontaal naast elkaar, met 6 punten ruimte
        // tussen de onderdelen.
        HStack(spacing: 6) {
            // Image(systemName:) haalt een icoon uit Apple's ingebouwde
            // "SF Symbols" icoonset op, hier een gevuld play-vierkantje.
            Image(systemName: "play.rectangle.fill")
                // De grootte van het icoon hangt af van "compact": kleiner
                // (20) in compacte modus, anders 23.
                .font(.system(size: compact ? 20 : 23, weight: .semibold))
                // Geeft het icoon een eigen rode kleur (in plaats van de
                // systeemkleur).
                .foregroundStyle(Color(red: 1, green: 0, blue: 0))
            // Alleen als "compact" false is, tonen we ook de naam en tagline.
            if !compact {
                // VStack zet zijn inhoud verticaal onder elkaar, hier zonder
                // extra ruimte (spacing: 0) en links uitgelijnd.
                VStack(alignment: .leading, spacing: 0) {
                    // De naam van de app in een afgeronde, halfvette stijl.
                    Text("JoeToep").font(.system(size: 12, weight: .semibold, design: .rounded))
                    // Een klein ondertiteltekstje in een gedempte (secundaire)
                    // kleur.
                    Text("#yolo").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
        // Zorgt dat dit blokje precies zo groot blijft als zijn inhoud nodig
        // heeft, en niet uitrekt om extra ruimte te vullen.
        .fixedSize()
        // Vertelt VoiceOver om icoon en tekst als één geheel voor te lezen in
        // plaats van los van elkaar.
        .accessibilityElement(children: .combine)
        // De tekst die VoiceOver voorleest voor dit hele blokje.
        .accessibilityLabel("JoeToep, YouTube Home")
    }
}
