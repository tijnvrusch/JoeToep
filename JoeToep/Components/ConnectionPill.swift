import SwiftUI

// ConnectionPill is een klein "pilletje" (capsule-vormig label) dat de status
// van de internetverbinding en het laden/bufferen van de video toont, met
// optioneel de huidige resolutie ernaast.
struct ConnectionPill: View {
    // Alle waarden hieronder worden van buitenaf meegegeven en liggen vast
    // (geen "var"): deze View toont enkel wat hem verteld wordt, ze verandert
    // zelf niets.
    let state: NetworkMonitor.State
    let isLoading: Bool
    let isBuffering: Bool
    // "String?" : de resolutie is optioneel; als er geen video speelt is dit nil.
    let resolution: String?

    var body: some View {
        HStack(spacing: 7) {
            // Als er geladen of gebufferd wordt, toon een draaiend laad-
            // icoontje in plaats van het netwerkicoon.
            if isLoading || isBuffering {
                ProgressView()
                    .controlSize(.mini)
            } else {
                // Toon het icoon dat bij de netwerkstatus hoort, groen (mint)
                // als online, oranje als offline.
                Image(systemName: state.symbolName)
                    .foregroundStyle(state.isOnline ? Color.mint : Color.orange)
            }

            // Toont "Buffering" tijdens het bufferen, anders de normale
            // statustekst (bijv. "Online"/"Offline").
            Text(isBuffering ? "Buffering" : state.label)
                .font(.caption.weight(.medium))

            // "if let resolution" pakt de waarde uit de optional uit: dit
            // blokje wordt alleen getoond als er wél een resolutie bekend is.
            if let resolution {
                // Een verticaal streepje ter scheiding tussen status en
                // resolutie.
                Divider()
                    .frame(height: 12)
                Text(resolution)
                    // "monospacedDigit()" zorgt dat cijfers allemaal even
                    // breed zijn, zodat de tekst niet "trilt" als het getal
                    // verandert (bijv. van 720p naar 1080p).
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        // Zelfgemaakte modifier (uit Design/AdaptiveGlass.swift) die het
        // glaseffect geeft, in de vorm van een Capsule (pilvorm).
        .joeToepGlass(in: Capsule())
        // Laat VoiceOver dit hele pilletje als één geheel voorlezen.
        .accessibilityElement(children: .combine)
    }
}

