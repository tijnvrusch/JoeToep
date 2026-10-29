import Foundation

/// V18 — Beslist of automatische PiP moet starten bij een app-wissel op de Mac.
/// • Eén scherm (alleen de MacBook): altijd PiP, precies zoals vóór V18.
/// • Twee of meer schermen: alleen PiP als de nieuwe app op HETZELFDE scherm komt als JoeToep.
///   Op een ander scherm blijft de video gewoon fullscreen doorspelen.
/// Puur model zonder AppKit, zodat de regel met unit-tests vast te leggen is.
enum MultiMonitorPiPPolicy {
    /// - Parameters:
    ///   - screenCount: aantal aangesloten schermen.
    ///   - joeToepScreen: id van het scherm waar JoeToep's venster staat (nil = onbekend).
    ///   - targetScreen: id van het scherm van de app die nu naar voren kwam (nil = onbekend).
    ///   - enabled: de instelling "Slim PiP bij meerdere schermen" (uit = altijd oud gedrag).
    static func shouldStartPiP(screenCount: Int, joeToepScreen: String?, targetScreen: String?, enabled: Bool = true) -> Bool {
        guard enabled, screenCount > 1 else { return true }
        // Onbekend scherm: wees voorzichtig en val terug op het oude, vertrouwde gedrag.
        guard let joeToepScreen, let targetScreen else { return true }
        return joeToepScreen == targetScreen
    }
}
