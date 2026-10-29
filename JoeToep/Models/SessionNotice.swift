import Foundation

// SessionNotice beschrijft één melding die tijdelijk aan de gebruiker getoond
// wordt (bijv. een bannertje bovenin het scherm), zoals "Verbinding hersteld"
// of een foutmelding.
// "Identifiable" betekent: dit type heeft een uniek "id", wat SwiftUI nodig
// heeft om bijv. lijsten van dit type netjes te kunnen bijhouden en animeren.
// "Equatable" betekent dat je twee SessionNotice-waarden met == kan vergelijken.
struct SessionNotice: Identifiable, Equatable {
    // Het soort melding. Dit bepaalt straks kleur/icoon in de UI.
    enum Kind: Equatable {
        case information
        case success
        case warning
        case error
    }

    // "let" betekent: eenmaal gezet, kan deze waarde niet meer wijzigen
    // (in tegenstelling tot "var"). UUID() genereert een uniek willekeurig
    // identificatienummer, zodat elke SessionNotice zijn eigen "id" heeft.
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String

    // Hiermee overschrijven we zelf hoe "==" werkt voor dit type: we vinden
    // twee meldingen gelijk als kind, title en message overeenkomen — het
    // (altijd unieke) "id" wordt hierbij bewust genegeerd.
    static func == (lhs: SessionNotice, rhs: SessionNotice) -> Bool {
        lhs.kind == rhs.kind && lhs.title == rhs.title && lhs.message == rhs.message
    }

    // Computed property die het juiste SF Symbols-icoonnaam teruggeeft,
    // afhankelijk van het soort melding. "switch" vergelijkt "kind" met elke
    // mogelijke case; hier hoeft geen "return" te worden getypt omdat elke
    // case-tak direct de waarde is die teruggegeven wordt.
    var symbolName: String {
        switch kind {
        case .information: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

