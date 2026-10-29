import SwiftUI

/// Exclusive gestures prevent a long press from also executing a normal toggle.
// PiPButton is de knop waarmee de gebruiker Picture-in-Picture (het zwevende
// videovenstertje) kan aan/uitzetten, of via lang indrukken kan resetten.
struct PiPButton: View {
    // "@ObservedObject" betekent: deze View "luistert" naar wijzigingen in
    // "session" (een class die ergens anders eigenaar van is) en tekent
    // zichzelf opnieuw zodra daar iets in verandert.
    @ObservedObject var session: WebSession
    // "let" (constante) eigenschappen die van buitenaf worden meegegeven bij
    // het aanmaken van deze knop.
    let size: CGFloat
    // Property met een standaardwaarde: mag overschreven worden, maar hoeft niet.
    var iconSize: CGFloat = 17
    // "@Environment" leest een waarde uit de omgeving van de View-hiërarchie,
    // hier het huidige kleurthema van de app, ingesteld op een hoger niveau.
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        // Een "pip"-icoon (systeemicoon voor Picture-in-Picture).
        HoldButton(action: { if !session.isPiPRequesting { session.togglePictureInPicture() } },
                   hold: session.resetPictureInPicture, holdDuration: 0.4) {
            Image(systemName: "pip")
                .themedIcon(theme, size: iconSize, active: session.isInPictureInPicture)
                .frame(width: size, height: max(size, 44)).contentShape(Rectangle())
        }
            // Toont een klein laad-draaitje bovenop de knop zolang er een PiP-
            // aanvraag loopt. ".allowsHitTesting(false)" zorgt dat dit draaitje
            // zelf niet aanklikbaar is en de knop eronder niet blokkeert.
            .overlay { if session.isPiPRequesting { ProgressView().controlSize(.mini).allowsHitTesting(false) } }
            // De volgende regels maken de knop bruikbaar voor VoiceOver
            // (schermlezer): het wordt als één "knop"-element voorgelezen.
            .accessibilityElement().accessibilityAddTraits(.isButton)
            .accessibilityLabel("Picture in Picture")
            .accessibilityHint("Hold for 0.3 seconds to reset Picture in Picture")
            // Geeft VoiceOver-gebruikers (die niet makkelijk "lang indrukken"
            // kunnen doen) alternatieve acties om dezelfde functies te
            // activeren via het toegankelijkheidsmenu.
            .accessibilityAction { session.togglePictureInPicture() }
            .accessibilityAction(named: "Reset Picture in Picture") { session.resetPictureInPicture() }
            // Vaste identifier voor UI-tests.
            .accessibilityIdentifier("toolbar.pip")
            // Tekst die verschijnt als je (op macOS) met de muis over de knop
            // zweeft.
            .help("Picture in Picture · hold 0.3s to reset")
    }
}
