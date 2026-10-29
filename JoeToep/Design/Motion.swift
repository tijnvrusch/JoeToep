// V22.2 — Eén plek voor korte UI-animaties: altijd extra snel, en met "Animaties uit" echt direct.
import SwiftUI

enum Motion {
    static var off: Bool { UserDefaults.standard.string(forKey: "animationStyleV15") == "off" }
    /// Snelheid uit Instellingen (standaard 1,6×).
    static var speed: Double { max(0.25, UserDefaults.standard.object(forKey: "animationSpeedV16") as? Double ?? 1.6) }
    /// Korte, strakke overgang (basis in seconden bij snelheid 1×). nil = zonder animatie.
    static func quick(_ base: Double = 0.2) -> Animation? {
        off ? nil : .snappy(duration: max(0.06, base * 0.7 / speed))
    }
    static func fade(_ base: Double = 0.15) -> Animation? {
        off ? nil : .easeOut(duration: max(0.05, base * 0.7 / speed))
    }
}
