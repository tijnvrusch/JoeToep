import SwiftUI

// NoticeBanner tekent één melding (van het type SessionNotice) als een
// bannertje met icoon, titel, boodschap en een kruisje om te sluiten.
struct NoticeBanner: View {
    let notice: SessionNotice
    // Een functie zonder parameters/resultaat die wordt aangeroepen als de
    // gebruiker op het kruisje tikt; de aanroeper van NoticeBanner bepaalt
    // zelf wat er dan gebeurt (bijv. de melding uit een lijst verwijderen).
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icoon dat bij het soort melding hoort (info/succes/waarschuwing/fout).
            Image(systemName: notice.symbolName)
                .font(.title3)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // Zorgt dat de tekst verticaal mag groeien (meerdere
                    // regels) in plaats van horizontaal afgekapt te worden.
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Een flexibele lege ruimte die de rest van de HStack opvult,
            // zodat het kruisje-knopje naar rechts wordt geduwd.
            Spacer(minLength: 6)

            // Knop met een kruisje om de melding te sluiten. "action: dismiss"
            // koppelt de knop direct aan de meegegeven dismiss-functie.
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            // ".plain" verwijdert de standaard knopopmaak (zoals een blauwe
            // achtergrond), zodat alleen het kruisje zichtbaar blijft.
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        // Beperkt de maximale breedte, zodat het bannertje op grote schermen
        // niet eindeloos breed wordt.
        .frame(maxWidth: 520)
        .joeToepGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Geeft het bannertje een zachte schaduw zodat het lijkt te zweven
        // boven de rest van het scherm.
        .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
    }

    // Computed property die de kleur van het icoon bepaalt op basis van het
    // soort melding.
    private var tint: Color {
        switch notice.kind {
        case .information: .cyan
        case .success: .mint
        case .warning: .orange
        case .error: .red
        }
    }
}

