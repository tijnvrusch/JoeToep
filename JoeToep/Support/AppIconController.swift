// SwiftUI: Apple's moderne raamwerk om schermen (views) te bouwen met declaratieve code
// (je beschrijft HOE het eruit moet zien, niet stap voor stap hoe het getekend wordt).
import SwiftUI
#if os(iOS)
// UIKit: de "oudere" laag onder iOS die dingen zoals UIApplication en UIImage levert.
// Deze code draait op zowel iPhone/iPad (iOS) als Mac (macOS), en die twee platforms
// hebben ieder hun eigen systeembibliotheek voor dit soort taken.
import UIKit
#else
// AppKit is het macOS-equivalent van UIKit (NSWindow, NSImage, enzovoort).
import AppKit
#endif

// @MainActor betekent: alle code in deze class moet op de hoofdthread (main thread) draaien.
// De hoofdthread is de thread die het scherm tekent en gebruikersinteractie afhandelt; UI-code
// moet daar altijd op draaien, anders kan de app crashen of het scherm niet goed bijwerken.
@MainActor
// "final class" is een blauwdruk voor objecten; "final" betekent dat niemand deze class kan
// overerven (uitbreiden) met een subklasse. ObservableObject is een protocol (afspraak) uit
// SwiftUI: het zegt dat deze class @Published eigenschappen mag hebben waar views naar kunnen
// "luisteren" zodat het scherm automatisch bijwerkt als de waarde verandert.
final class AppIconController: ObservableObject {
    // "static let shared" is het zogeheten singleton-patroon: er is maar één AppIconController
    // voor de hele app, en iedereen gebruikt AppIconController.shared om erbij te kunnen.
    static let shared = AppIconController()
    /// V15: 43 icons. Every entry has an .appiconset (iOS alternate icon, macOS-shaped Mac sizes)
    /// and an IconPreview<name> image used for the picker and the Mac Dock.
    // Een lijst (Array) met alle beschikbare namen van app-iconen, als tekst (String).
    static let names = ["AppIcon", "White", "Ocean", "Mint", "Sunset", "Neon", "Candy", "Arcade", "Vinyl", "Orbit", "Aurora",
                        "Lava", "Blueprint", "Cassette", "Prism", "Monochrome", "Jelly", "Sunrise", "Cyberpunk",
                        "Midnight", "Gold", "Rose", "Forest", "Grape", "Coral", "Sky", "Slate", "Carbon", "Paper", "Glass",
                        "Sakura", "Ice", "Ember", "Lime", "Terminal", "Pixel", "RetroTV", "Bubble", "Synthwave", "Rainbow",
                        "Holo", "Heart", "Noir"]
        // V17.1: 110 nieuwe iconen in vijf series (zie Scripts/generate_icons_v171.py).
        + series.flatMap { $0.names }
    /// V17.1: iconen per serie, voor de kiezer in Instellingen › Weergave › App-icoon.
    /// `(title: String, names: [String])` is een "tuple": twee waarden als één pakketje.
    static let series: [(title: String, names: [String])] = [
        ("Unique", ["UniqueNebula", "UniqueMosaic", "UniqueHalo", "UniqueTangram", "UniqueGramophone", "UniqueBlueprint2", "UniqueSunburst", "UniquePastel", "UniqueTide", "UniqueWatcher", "UniqueSupernova", "UniqueTape", "UniqueMatrix", "UniqueInferno", "UniqueRipple", "UniqueShard", "UniqueValentine", "UniqueRave", "UniqueTerra", "UniqueMidas"]),
        ("Creative", ["CreativeTropic", "CreativePopsicle", "CreativeDisco", "CreativeLagoon", "CreativeDesert", "CreativeBauhaus", "CreativeGrape", "CreativeCandyfloss", "CreativeGlacier", "CreativeBlush", "CreativeStudio", "CreativeMixtape", "CreativeIris", "CreativeStarlight", "CreativeCrush", "CreativeSorbet", "CreativeCurrent", "CreativeBurst", "CreativeGraph", "CreativeEcho"]),
        ("Eccentric", ["EccentricAcid", "EccentricGlitch", "EccentricCircus", "EccentricHypno", "EccentricBubblegum", "EccentricVortex", "EccentricWobble", "EccentricChecker", "EccentricLava", "EccentricAlien", "EccentricCyclops", "EccentricArcade", "EccentricStarfish", "EccentricPunk", "EccentricTarget", "EccentricBoombox", "EccentricRecord", "EccentricPulse", "EccentricChunky", "EccentricNeonframe"]),
        ("Bold", ["BoldSignal", "BoldHazard", "BoldMint", "BoldBlaze", "BoldVolt", "BoldSnow", "BoldCobalt", "BoldRadioactive", "BoldHotpink", "BoldShadow", "BoldBarcode", "BoldBurst", "BoldPolka", "BoldBullseye", "BoldTile", "BoldFlag", "BoldBeam", "BoldSpot", "BoldOrbit", "BoldFrame"]),
        ("Outline", ["OutlineClassic", "OutlineRed", "OutlinePaper", "OutlineHairline", "OutlineBold", "OutlineCircle", "OutlineRedCircle", "OutlineSquare", "OutlineTriangle", "OutlineOcean", "OutlineMint", "OutlineSunset", "OutlineLavender", "OutlineNight", "OutlineGold", "OutlineDouble", "OutlineNeon", "OutlinePink", "OutlineSky", "OutlineSlate"]),
        ("Minimal", ["MinimalWhite", "MinimalBlack", "MinimalRed", "MinimalRedDot", "MinimalInk", "MinimalSand", "MinimalStone", "MinimalFog", "MinimalGraphite", "MinimalBlush", "MinimalSage", "MinimalNavy", "MinimalButter", "MinimalLilac", "MinimalOcean", "MinimalMono", "MinimalNight", "MinimalClay", "MinimalMint", "MinimalCream"]),
        ("YouTube Red", ["Red01", "Red02", "Red03", "Red04", "Red05", "Red06", "Red07", "Red08", "Red09", "Red10", "Red11", "Red12", "Red13", "Red14", "Red15", "Red16", "Red17", "Red18", "Red19", "Red20", "Red21", "Red22", "Red23", "Red24", "Red25", "Red26", "Red27", "Red28", "Red29", "Red30"]),
    ]
    /// De oorspronkelijke 43 iconen (V8–V15).
    static var classicNames: [String] { Array(names.prefix(43)) }
    // Een functie die de "mooie" weergavenaam voor een icoonnaam teruggeeft. "switch" vergelijkt
    // de waarde met meerdere mogelijke gevallen; "default" vangt alle overige gevallen op.
    static func title(_ name: String) -> String {
        if name == "AppIcon" { return "Classic" }
        if name == "RetroTV" { return "Retro TV" }
        // V17.1: "UniqueNebula" → "Nebula", "Red07" → "Red 07"
        if name.hasPrefix("Red"), name.count == 5 { return "Red " + name.dropFirst(3) }
        for prefix in ["Unique", "Creative", "Eccentric", "Bold", "Outline", "Minimal"] where name.hasPrefix(prefix) && name.count > prefix.count {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }
    // @Published zorgt dat SwiftUI-views die naar deze eigenschap kijken automatisch
    // opnieuw tekenen zodra de waarde verandert. "private(set)" betekent: van buitenaf mag
    // je de waarde alleen LEZEN, niet rechtstreeks aanpassen (dat mag alleen deze class zelf).
    // UserDefaults is een klein, permanent sleutel-waarde-opslagsysteem van Apple (blijft
    // bewaard na het afsluiten van de app), hier gebruikt om het gekozen icoon te onthouden.
    @Published private(set) var selection = UserDefaults.standard.string(forKey: "appIconV8") ?? "AppIcon"
    // Foutmelding die aan de gebruiker getoond kan worden; String? betekent "String of niets (nil)".
    @Published private(set) var error: String?
    // Geeft aan of het icoon op dit moment aan het wisselen is (om dubbele acties te voorkomen).
    @Published private(set) var changing = false
    // Wordt bij het opstarten aangeroepen om het huidige icoon opnieuw toe te passen.
    func restore() {
        #if os(macOS)
        applyDockIcon()
        #endif
    }
    // Kiest een nieuw app-icoon. "guard ... else { return }" is een vroege-uitstap-check:
    // als de voorwaarde niet klopt, stopt de functie meteen (hier: onbekende naam, of al bezig).
    func select(_ name: String) {
        guard Self.names.contains(name), !changing else { return }
        error = nil
        #if os(iOS)
        // Niet elk iOS-toestel/context ondersteunt alternatieve iconen; dat wordt hier gecheckt.
        guard UIApplication.shared.supportsAlternateIcons else { error = "Alternate icons are unavailable on this device."; return }
        changing = true
        // setAlternateIconName vraagt iOS om het app-icoon te wisselen. "nil" betekent: terug
        // naar het standaardicoon. De closure ([weak self] problem in ...) wordt later
        // aangeroepen zodra iOS klaar is (dit gebeurt asynchroon, dus niet meteen).
        UIApplication.shared.setAlternateIconName(name == "AppIcon" ? nil : name) { [weak self] problem in
            // Task { @MainActor in ... } start nieuwe code die weer netjes op de hoofdthread
            // draait, want de callback hierboven kan op een andere thread binnenkomen.
            Task { @MainActor in
                // "[weak self]" voorkomt dat deze closure de controller voor altijd vasthoudt
                // (een geheugenlek); als self al is opgeruimd, stopt de functie hier.
                guard let self else { return }
                self.changing = false
                if let problem { self.error = problem.localizedDescription; return }
                self.selection = name
                UserDefaults.standard.set(name, forKey: "appIconV8")
            }
        }
        #else
        // Op macOS is er geen systeem-API voor iconen wisselen; we onthouden de keuze zelf
        // en tekenen het Dock-icoon met eigen code (zie applyDockIcon hieronder).
        selection = name
        UserDefaults.standard.set(name, forKey: "appIconV8")
        applyDockIcon()
        #endif
    }
    #if os(macOS)
    /// V15: the Dock showed the square preview (straight corners, too large). Draw it on the
    /// macOS icon grid instead: 824 pt rounded rectangle centred on a 1024 pt canvas, with shadow.
    // Deze functie stelt het icoon in dat in het macOS Dock te zien is.
    private func applyDockIcon() {
        // Als de klassieke "AppIcon" gekozen is, of de afbeelding niet gevonden wordt,
        // gebruiken we het standaard bundelicoon (nil zet het terug naar de standaard).
        guard selection != "AppIcon", let source = NSImage(named: "IconPreview" + selection) else {
            NSApp.applicationIconImage = nil   // bundle icon (already macOS-shaped)
            return
        }
        NSApp.applicationIconImage = Self.macShaped(source)
    }
    // Tekent een afbeelding opnieuw in de vorm die macOS-iconen horen te hebben: een
    // afgeronde rechthoek gecentreerd op een canvas, met een subtiele schaduw eronder.
    static func macShaped(_ image: NSImage) -> NSImage {
        // NSImage(size:flipped:drawingHandler:) maakt een nieuwe afbeelding waarvan de
        // inhoud "getekend" wordt door de closure hieronder (dit heet lazy drawing).
        NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
            let body = NSRect(x: 100, y: 100, width: 824, height: 824)
            // Een NSBezierPath is een tekenpad; hier een rechthoek met afgeronde hoeken.
            let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
            // saveGraphicsState/restoreGraphicsState omsluiten tekenacties zodat instellingen
            // (zoals de schaduw hieronder) niet blijven "plakken" voor latere tekenopdrachten.
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -8)
            shadow.set()
            NSColor.black.setFill(); path.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            // addClip() zorgt dat alles wat we hierna tekenen (de eigenlijke afbeelding)
            // wordt afgesneden tot de vorm van het pad (de afgeronde rechthoek).
            path.addClip()
            image.draw(in: body, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
    #endif
}

/// Grid of all icons (Settings › Appearance).
// Een SwiftUI "View" beschrijft een stuk scherm. Deze view toont een raster (grid) met
// alle beschikbare app-iconen, waar de gebruiker op kan tikken om te wisselen.
struct IconPickerGrid: View {
    // @ObservedObject verbindt deze view met een bestaand ObservableObject (hier de shared
    // controller): als selection/changing/error veranderen, tekent deze view zichzelf opnieuw.
    @ObservedObject var icons = AppIconController.shared
    // @Environment leest een waarde die ergens hogerop in de view-hiërarchie is ingesteld
    // (hier het app-thema, met kleuren zoals theme.accent).
    @Environment(\.joeToepTheme) private var theme
    // Definitie van de kolommen van het raster: adaptief, dus zoveel kolommen als passen
    // tussen 68 en 84 punten breed, met 12 punten ruimte ertussen.
    private let columns = [GridItem(.adaptive(minimum: 68, maximum: 84), spacing: 12)]
    // "body" is de verplichte eigenschap van elke SwiftUI View: hij beschrijft wat er getekend wordt.
    // V17.1: één raster per serie, met een kopje erboven.
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Classic", AppIconController.classicNames)
            ForEach(AppIconController.series, id: \.title) { group in section(group.title, group.names) }
        }
    }
    private func section(_ title: String, _ list: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            grid(list)
        }
    }
    private func grid(_ list: [String]) -> some View {
        // LazyVGrid tekent alleen de vakjes die op het scherm zichtbaar (of bijna zichtbaar) zijn,
        // wat sneller is dan alles in één keer tekenen bij een lange lijst.
        LazyVGrid(columns: columns, spacing: 14) {
            // ForEach herhaalt de inhoud voor elk element in de lijst met iconnamen.
            // "id: \.self" zegt dat elke naam zelf als unieke identiteit gebruikt wordt.
            ForEach(list, id: \.self) { name in
                // Button voert een actie uit (icons.select(name)) wanneer erop getikt wordt;
                // de "label:" closure beschrijft hoe de knop eruitziet.
                Button { icons.select(name) } label: {
                    VStack(spacing: 5) {
                        Image("IconPreview" + name).resizable().interpolation(.high)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(icons.selection == name ? theme.accent : Color.gray.opacity(0.25), lineWidth: icons.selection == name ? 3 : 0.5))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        Text(AppIconController.title(name)).font(.caption2).lineLimit(1)
                            .foregroundStyle(icons.selection == name ? theme.accent : .secondary)
                    }
                }
                // .buttonStyle(.plain) verwijdert de standaard knopopmaak van het systeem.
                .buttonStyle(.plain)
                // Terwijl er al een wissel bezig is, kan de gebruiker niet nog een keuze maken.
                .disabled(icons.changing)
                // Toegankelijkheidslabels helpen gebruikers met bijvoorbeeld VoiceOver.
                .accessibilityLabel(AppIconController.title(name) + " icon")
                .accessibilityAddTraits(icons.selection == name ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
