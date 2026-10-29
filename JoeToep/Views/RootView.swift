// Dit is het "startpunt" van de zichtbare app: hij beslist of je het
// welkomstscherm (OnboardingView) of het echte hoofdscherm (PlayerShellView) ziet.
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RootView: View {
    // @StateObject maakt hier het settings-object aan en "bezit" het: SwiftUI
    // zorgt dat dit object maar één keer wordt aangemaakt en blijft bestaan
    // zolang RootView bestaat. Andere views krijgen het later door als
    // @ObservedObject (zie OnboardingView/PlayerShellView).
    @StateObject private var settings: AppSettings
    // "static" betekent: deze waarde hoort bij het type zelf (RootView), niet
    // bij één losse instantie, en wordt dus door alle exemplaren gedeeld.
    private static var resetTestDefaults = false
    // init() is de "initialisatie"-functie: code die draait zodra een RootView
    // wordt aangemaakt, vóór het scherm getoond wordt.
    init() {
        // Deze #if/#else blokken worden bij het compileren gekozen: alleen de
        // code in een actieve blok komt echt in de app terecht. DEBUG is actief
        // tijdens ontwikkelen/testen, niet in de uiteindelijke App Store-versie.
        #if DEBUG
        // Als de app gestart is met het testargument "--uitesting" (voor
        // geautomatiseerde UI-tests), gebruiken we aparte, "schone" instellingen.
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let suite = "nl.tijn.joetoep.ui-tests"
            // UserDefaults is Apple's simpele opslag voor kleine instellingen.
            // Hier pakken we een aparte testopslag ("suite"), of anders de
            // standaardopslag.
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            if !Self.resetTestDefaults {
                // Voor tests wissen we eerst alle oude testinstellingen, zodat
                // elke testrun met een schone lei begint.
                defaults.removePersistentDomain(forName: suite)
                if !ProcessInfo.processInfo.arguments.contains("--restore-tabs") {
                    UserDefaults(suiteName: "nl.tijn.joetoep.ui-tabs")?.removePersistentDomain(forName: "nl.tijn.joetoep.ui-tabs")
                }
                Self.resetTestDefaults = true
            }
            let model = AppSettings(defaults: defaults)
            // Extra testargumenten kunnen de onboarding overslaan of ander
            // gedrag forceren, zodat tests sneller/voorspelbaarder verlopen.
            if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { model.acceptServiceNotice() }
            if ProcessInfo.processInfo.arguments.contains("--tab-close-always") { model.tabCloseButtons = .always }
            // De underscore-versie (_settings) geeft toegang tot de "wrapper"
            // zelf (StateObject), zodat we hem hier handmatig met een waarde
            // kunnen vullen — dat mag normaal alleen in init().
            _settings = StateObject(wrappedValue: model)
        } else { _settings = StateObject(wrappedValue: AppSettings()) }
        #else
        // In een normale (niet-test) build maken we gewoon de standaard
        // instellingen aan.
        _settings = StateObject(wrappedValue: AppSettings())
        #endif
    }
    var body: some View {
        // Group bundelt meerdere views zonder zelf iets aan de opmaak toe te
        // voegen; het is puur een manier om een if/else met views te combineren.
        Group {
            // Afhankelijk van of de gebruiker de welkomstmelding al heeft
            // geaccepteerd, tonen we het hoofdscherm of het onboardingscherm.
            if settings.acceptedServiceNotice { PlayerShellView(settings: settings) }
            else { OnboardingView(settings: settings) }
        // .task voert asynchrone code uit zodra deze view verschijnt; hier
        // wordt het app-icoon hersteld naar de laatst gekozen variant.
        }.task { AppIconController.shared.restore() }
        #if os(macOS)
        .background(WindowRestorationGuard())
        #endif
    }
}

#if os(macOS)
/// V22.3 — macOS herstelde bij elke start álle vensters van de vorige keer; omdat het eerste venster
/// alle tabs overneemt, bleven de andere als lege "Home"-vensters staan (die zich ophoopten) en kwam
/// een venster soms in fullscreen op een eigen Space terug. Nu opent JoeToep altijd met één venster
/// met al je tabs; positie en grootte van het hoofdvenster worden wel onthouden.
struct WindowRestorationGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ view: NSView, context: Context) {}
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isRestorable = false
            // Alleen één venster kan deze naam hebben; de rest krijgt gewoon de standaardplek.
            if window.frameAutosaveName.isEmpty { _ = window.setFrameAutosaveName("JoeToepMainWindow") }
        }
    }
}
#endif
