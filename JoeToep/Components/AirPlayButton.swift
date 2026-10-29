// "#if os(iOS)" is een compiler-check: alles tussen dit "#if" en de "#endif"
// verderop wordt alleen meegecompileerd als de app op iOS gebouwd wordt. Op
// macOS bestaat dit bestand dan in feite niet. Dit wordt gebruikt omdat
// AVRoutePickerView (de AirPlay-knop) alleen op iOS beschikbaar is.
#if os(iOS)
import SwiftUI
// AVKit is Apple's raamwerk voor audio/video-afspeelinterfaces, zoals de
// ingebouwde AirPlay-knop die we hier gebruiken.
import AVKit
// UIViewRepresentable is een protocol waarmee je een "ouderwetse" UIKit-view
// (zoals AVRoutePickerView, die geen SwiftUI-versie heeft) kunt inpakken zodat
// je hem gewoon als SwiftUI-view kunt gebruiken.
struct AirPlayButton: UIViewRepresentable {
    // Wordt één keer aangeroepen om de onderliggende UIKit-view aan te maken.
    // "context" bevat extra SwiftUI-informatie die we hier niet nodig hebben.
    func makeUIView(context: Context) -> AVRoutePickerView {
        // AVRoutePickerView is de systeemknop waarmee de gebruiker een AirPlay-
        // ontvanger (bijv. Apple TV) kan kiezen.
        let picker = AVRoutePickerView()
        // Zorgt dat de knop apparaten met videosupport bovenaan toont.
        picker.prioritizesVideoDevices = true
        // Kleur van het AirPlay-icoon in rust.
        picker.tintColor = .white
        // Kleur van het icoon zodra AirPlay actief is (verbonden met een apparaat).
        picker.activeTintColor = .systemRed
        // Tekst die VoiceOver (schermlezer) voorleest voor deze knop.
        picker.accessibilityLabel = "AirPlay"
        // Een vaste identifier, handig voor geautomatiseerde UI-tests om deze
        // specifieke knop terug te vinden.
        picker.accessibilityIdentifier = "toolbar.airplay"
        return picker
    }
    // Wordt aangeroepen als SwiftUI de view wil bijwerken. Hier hoeft niets te
    // gebeuren, dus de functie is leeg.
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
#endif
