// Dit bestand tekent het allereerste scherm dat je ziet als je de app opent:
// het welkomstscherm (onboarding) met uitleg over wat de app doet.
import SwiftUI

// Een "struct" die een SwiftUI-scherm (View) beschrijft. In SwiftUI bouw je de
// interface door kleine bouwstenen (Text, Image, Button, ...) te combineren.
struct OnboardingView: View {
    // @ObservedObject betekent: dit object (settings) bestaat al ergens anders
    // en wordt hier alleen "gevolgd". Als een waarde in settings verandert,
    // tekent SwiftUI dit scherm automatisch opnieuw.
    @ObservedObject var settings: AppSettings
    // Elke View moet een "body" hebben: dit is de eigenlijke inhoud/opmaak
    // die op het scherm getoond wordt.
    var body: some View {
        // ScrollView zorgt dat de inhoud kan scrollen als hij niet past
        // (bijvoorbeeld op een klein scherm).
        ScrollView {
            // VStack zet alles verticaal (van boven naar beneden) onder elkaar.
            // spacing: 22 is de ruimte tussen de onderdelen.
            VStack(spacing: 22) {
                // Een systeemicoon (afbeelding die iOS/macOS meelevert) met
                // een grote lettergrootte en rode kleur.
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 68)).foregroundStyle(Color.red)
                // De titel-tekst van de app, met een groot vet lettertype.
                Text("JoeToep").font(.largeTitle.bold())
                Text("#yolo").font(.headline).foregroundStyle(.secondary)
                // Korte omschrijving van de app.
                Text("More video. Less interface.")
                    .font(.title3.weight(.medium)).multilineTextAlignment(.center)
                // Een lijstje met kenmerken van de app, links uitgelijnd.
                VStack(alignment: .leading, spacing: 16) {
                    // Label combineert automatisch een icoon met een stukje tekst.
                    Label("One black bar, five direct destinations", systemImage: "rectangle.bottomthird.inset.filled")
                    Label("Automatic PiP requests and playback fallbacks", systemImage: "pip")
                    Label("Fill, pinch zoom and quick resolution selection", systemImage: "arrow.up.left.and.arrow.down.right")
                }.font(.subheadline)
                // Extra uitleg over Picture-in-Picture (PiP), in kleinere grijze tekst.
                Text("Enable automatic PiP in your device settings. Apple and the video website decide when system PiP is available.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                // Button is een aanklikbare knop. De code tussen { } (de "action")
                // wordt uitgevoerd zodra de gebruiker erop tikt/klikt.
                Button {
                    // Dit vertelt de instellingen dat de gebruiker akkoord is
                    // met de welkomstmelding, waarna RootView naar het
                    // hoofdscherm (PlayerShellView) schakelt.
                    settings.acceptServiceNotice()
                } label: {
                    // "label" is hoe de knop eruitziet: hier tekst die de
                    // volledige breedte inneemt met wat verticale padding (ruimte).
                    Text("Open JoeToep").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                // buttonStyle en tint bepalen het uiterlijk van de knop (opvallend, rood).
                .buttonStyle(.borderedProminent).tint(.red)
                // Een identifier die gebruikt wordt door geautomatiseerde UI-tests
                // om deze knop te kunnen terugvinden.
                .accessibilityIdentifier("onboarding.continue")
                Text("Personal project · not affiliated with YouTube")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            // padding voegt lege ruimte toe rondom de VStack; frame beperkt de
            // maximale breedte zodat het er op grote schermen niet uitgerekt uitziet.
            .padding(24).frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
        // Een decoratieve achtergrond, en preferredColorScheme(.dark) dwingt
        // dit scherm om altijd in donkere modus getoond te worden.
        .background(AmbientBackground()).preferredColorScheme(.dark)
    }
}
