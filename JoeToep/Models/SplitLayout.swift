// V26 — Split View (zoals Arc en Dia): twee tabs naast (of onder) elkaar in één venster. Beide pagina's
// zijn live; de tab met de focus krijgt de knoppen en sneltoetsen. Alleen Foundation (testbaar op Linux).
import Foundation

struct SplitPair: Codable, Equatable, Sendable {
    /// Linker (of bovenste) paneel.
    var primary: UUID
    /// Rechter (of onderste) paneel.
    var secondary: UUID
    /// Deel van de ruimte voor het eerste paneel (0,2…0,8).
    var fraction: Double = 0.5
    /// true = boven elkaar in plaats van naast elkaar.
    var vertical = false

    func contains(_ id: UUID) -> Bool { primary == id || secondary == id }
    /// Het andere paneel.
    func partner(of id: UUID) -> UUID? { id == primary ? secondary : (id == secondary ? primary : nil) }
    /// Panelen omwisselen (links ⇄ rechts).
    func swapped() -> SplitPair { SplitPair(primary: secondary, secondary: primary, fraction: 1 - fraction, vertical: vertical) }
}

enum SplitLayout {
    static let minimumFraction = 0.2
    static let maximumFraction = 0.8
    /// Smaller dan dit (punten) passen twee pagina's niet naast elkaar; dan worden ze boven elkaar gezet.
    static let minimumSideBySideWidth = 640.0
    /// Lager dan dit passen ze ook niet boven elkaar; dan toont de app alleen de tab met de focus.
    static let minimumStackedHeight = 520.0

    static func clamp(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0.5 }
        return min(max(fraction, minimumFraction), maximumFraction)
    }

    enum Arrangement: Equatable, Sendable { case sideBySide, stacked, single }

    /// Welke opstelling past in deze ruimte (de voorkeur "boven elkaar" telt mee).
    static func arrangement(width: Double, height: Double, prefersVertical: Bool) -> Arrangement {
        if prefersVertical { return height >= minimumStackedHeight ? .stacked : (width >= minimumSideBySideWidth ? .sideBySide : .single) }
        if width >= minimumSideBySideWidth { return .sideBySide }
        return height >= minimumStackedHeight ? .stacked : .single
    }

    /// Kaders van de twee panelen (eerste, tweede) binnen een ruimte van `width` × `height`, met `gap` ertussen.
    static func frames(width: Double, height: Double, fraction: Double, arrangement: Arrangement, gap: Double)
        -> (first: CGRect, second: CGRect) {
        let f = clamp(fraction)
        let g = max(0, gap)
        switch arrangement {
        case .sideBySide:
            let firstWidth = max(0, ((width - g) * f).rounded())
            return (CGRect(x: 0, y: 0, width: firstWidth, height: height),
                    CGRect(x: firstWidth + g, y: 0, width: max(0, width - firstWidth - g), height: height))
        case .stacked:
            let firstHeight = max(0, ((height - g) * f).rounded())
            return (CGRect(x: 0, y: 0, width: width, height: firstHeight),
                    CGRect(x: 0, y: firstHeight + g, width: width, height: max(0, height - firstHeight - g)))
        case .single:
            return (CGRect(x: 0, y: 0, width: width, height: height), .zero)
        }
    }

    /// Nieuwe verdeling tijdens het slepen van de scheidingslijn (vanaf de verdeling bij het begin).
    static func fraction(start: Double, translation: Double, total: Double) -> Double {
        guard total > 1 else { return clamp(start) }
        return clamp(start + translation / total)
    }

    /// Een opgeslagen of gesynchroniseerde split is alleen geldig als beide tabs (nog) bestaan en verschillen.
    static func validated(_ pair: SplitPair?, existing: Set<UUID>) -> SplitPair? {
        guard var pair, pair.primary != pair.secondary, existing.contains(pair.primary), existing.contains(pair.secondary) else { return nil }
        pair.fraction = clamp(pair.fraction)
        return pair
    }

    /// Welke tab komt naast de huidige als je Split View opent zonder iets te kiezen: de vorige recente
    /// tab, anders de buurtab. nil = er is geen andere tab (dan opent de app een nieuwe tab ernaast).
    static func partnerCandidate(for current: UUID, recent: [UUID], order: [UUID], excluded: Set<UUID> = []) -> UUID? {
        if let previous = recent.reversed().first(where: { $0 != current && order.contains($0) && !excluded.contains($0) }) { return previous }
        guard let index = order.firstIndex(of: current) else { return nil }
        let after = order.suffix(from: index + 1).first { !excluded.contains($0) }
        let before = order.prefix(upTo: index).last { !excluded.contains($0) }
        return after ?? before
    }
}
