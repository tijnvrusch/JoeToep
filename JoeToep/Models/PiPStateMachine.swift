import Foundation

/// A late rejection cannot overwrite a successful native entry.
// PiPStateMachine houdt bij in welke fase Picture-in-Picture (het kleine
// zwevende videovenstertje) zich bevindt: uit, bezig met starten, actief als
// systeem-PiP, of actief als eigen zwevend venster. "Equatable" betekent dat
// je twee PiPStateMachine-waarden met == kunt vergelijken (nodig omdat "State"
// hieronder ook Equatable moet zijn).
struct PiPStateMachine: Equatable {
    // Een "enum" (opsomming) beschrijft een vaste set mogelijke waarden.
    // "String" als basistype (rawValue) betekent dat elke case ook een tekst-
    // waarde heeft (hier gelijk aan de naam), handig voor bijv. loggen.
    enum Reason: String { case manual, appSwitch, fullscreenExit }
    // Deze enum heeft een "associated value": .requesting(Int) draagt een
    // getal (het volgnummer van de aanvraag) met zich mee, de andere cases niet.
    enum State: Equatable { case idle, requesting(Int), native, floating }
    // "private(set)" betekent: van buitenaf mag je deze property wel LEZEN,
    // maar niet rechtstreeks wijzigen — dat mag alleen via de functies hieronder.
    private(set) var state: State = .idle
    // Een oplopend volgnummer, gebruikt om te herkennen of een mislukking nog
    // wel bij de "huidige" aanvraag hoort (zie fail(_:message:)).
    private(set) var serial = 0
    private(set) var reason: Reason = .manual
    // "String?" betekent: deze waarde mag ook "nil" (leeg/afwezig) zijn.
    private(set) var lastFailure: String?
    // Computed property: berekent of PiP op dit moment echt actief is (native
    // systeem-PiP of het eigen zwevende venster).
    var isActive: Bool { state == .native || state == .floating }
    // "switch"/"if case" wordt hier gebruikt om te checken of "state" specifiek
    // de .requesting-case is, ongeacht welk getal erin zit.
    var isRequesting: Bool { if case .requesting = state { return true }; return false }
    // Start een nieuwe PiP-aanvraag. Geeft niets terug (nil) als er al een
    // aanvraag of actieve sessie bezig is; anders geeft het het nieuwe
    // volgnummer terug, dat de aanroeper moet bewaren om later fail() ermee
    // aan te roepen.
    mutating func begin(_ reason: Reason) -> Int? {
        guard state == .idle else { return nil }
        serial += 1; state = .requesting(serial); self.reason = reason; lastFailure = nil
        return serial
    }
    // Bevestigt dat het systeem-eigen PiP-venster succesvol is gestart.
    mutating func confirmNative() { state = .native; lastFailure = nil }
    // Bevestigt dat het eigen (zelfgebouwde) zwevende venster is gestart.
    mutating func confirmFloating() { state = .floating; lastFailure = nil }
    // "@discardableResult" betekent: de aanroeper mag de teruggegeven waarde
    // negeren zonder een compiler-waarschuwing te krijgen.
    @discardableResult
    mutating func fail(_ token: Int, message: String) -> Bool {
        // Alleen als de state nog exact op de aanvraag met dit "token" (nummer)
        // staat te wachten, wordt de mislukking verwerkt. Zo kan een te-laat
        // binnenkomend mislukkingsbericht een intussen wél gelukte, nieuwere
        // aanvraag niet meer overschrijven (zie de opmerking bovenaan het bestand).
        guard state == .requesting(token) else { return false }
        state = .idle; lastFailure = message; return true
    }
    // Verlaat de systeem-PiP-modus, maar alleen als die ook echt actief was.
    mutating func exitNative() { if state == .native { state = .idle } }
    // Verlaat het eigen zwevende venster, alleen als dat actief was.
    mutating func exitFloating() { if state == .floating { state = .idle } }
    // Zet alles hard terug naar de beginstatus, bijvoorbeeld bij een reset-actie.
    mutating func reset() { state = .idle; serial += 1; lastFailure = nil }
}
