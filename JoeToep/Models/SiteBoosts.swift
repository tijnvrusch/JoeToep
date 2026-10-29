// V26 — Boosts (zoals in Arc): pas een website blijvend aan. Per site: onderdelen verbergen ("Zap": klik
// een element aan en het is weg), kant-en-klare opties (reacties verbergen, eindkaarten weg, rustige
// pagina …), een ander lettertype, een kleurfilter, een eigen achtergrondkleur, een leesbreedte en
// eigen CSS. De CSS wordt in `boosts.js` op de pagina gezet (DOM-API's, geen innerHTML → Trusted Types-
// veilig). Alleen Foundation: testbaar op Linux.
import Foundation

enum BoostPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case hideComments, hideRelated, hideEndCards, hideLiveChat, hideMerch, hideHomeFeed, hideHoverPreviews, hideBadges
    case noAnimations, underlineLinks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hideComments: "Hide comments"
        case .hideRelated: "Hide recommendations next to the video"
        case .hideEndCards: "Hide end screen cards and info cards"
        case .hideLiveChat: "Hide live chat"
        case .hideMerch: "Hide merchandise and ticket shelves"
        case .hideHomeFeed: "Hide the home feed (search and subscriptions only)"
        case .hideHoverPreviews: "No video previews on hover"
        case .hideBadges: "Hide notification counters"
        case .noAnimations: "Turn off animations"
        case .underlineLinks: "Underline every link"
        }
    }
    var symbol: String {
        switch self {
        case .hideComments: "text.bubble"
        case .hideRelated: "rectangle.stack"
        case .hideEndCards: "rectangle.on.rectangle.slash"
        case .hideLiveChat: "bubble.left.and.bubble.right"
        case .hideMerch: "bag"
        case .hideHomeFeed: "house.slash"
        case .hideHoverPreviews: "play.slash"
        case .hideBadges: "bell.slash"
        case .noAnimations: "figure.walk.motion"
        case .underlineLinks: "underline"
        }
    }
    /// nil = werkt op elke site; anders alleen op deze sites (sleutels zoals `BoostStore.siteKey`).
    var sites: Set<String>? {
        switch self {
        case .noAnimations, .underlineLinks: nil
        default: ["youtube.com", "music.youtube.com"]
        }
    }
    func applies(to site: String) -> Bool { sites?.contains(site) ?? true }
    var css: String {
        switch self {
        case .hideComments: "ytd-comments#comments, ytm-comment-section-renderer, ytd-comments-entry-point-header-renderer, ytm-comments-entry-point-header-renderer"
        case .hideRelated: "#secondary #related, ytd-watch-next-secondary-results-renderer, ytm-item-section-renderer[section-identifier=\"related-items\"]"
        case .hideEndCards: ".ytp-ce-element, .ytp-endscreen-content, .ytp-cards-teaser, .ytp-cards-button, .iv-branding"
        case .hideLiveChat: "#chat, #chat-container, ytd-live-chat-frame"
        case .hideMerch: "ytd-merch-shelf-renderer, ytd-ticket-shelf-renderer, ytm-merch-shelf-renderer"
        case .hideHomeFeed: "ytd-browse[page-subtype=\"home\"] #primary, ytm-browse[page-subtype=\"home\"] ytm-rich-grid-renderer"
        case .hideHoverPreviews: "ytd-video-preview, #video-preview, ytd-moving-thumbnail-renderer"
        case .hideBadges: ".yt-spec-icon-badge-shape__badge, #notification-count, ytd-notification-topbar-button-renderer .yt-spec-icon-badge-shape__badge"
        case .noAnimations: "*, *::before, *::after"
        case .underlineLinks: "a[href]"
        }
    }
    var declarations: String {
        switch self {
        case .noAnimations: "animation-duration: 0s !important; animation-delay: 0s !important; transition: none !important; scroll-behavior: auto !important;"
        case .underlineLinks: "text-decoration: underline !important;"
        default: "display: none !important;"
        }
    }
}

enum BoostFont: String, CaseIterable, Codable, Identifiable, Sendable {
    case site, system, rounded, serif, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .site: "Website's own"
        case .system: "System (SF Pro)"
        case .rounded: "Rounded"
        case .serif: "Serif (New York)"
        case .mono: "Monospaced"
        }
    }
    var family: String? {
        switch self {
        case .site: nil
        case .system: "-apple-system, system-ui, \"Helvetica Neue\", sans-serif"
        case .rounded: "ui-rounded, \"SF Pro Rounded\", -apple-system, system-ui, sans-serif"
        case .serif: "\"New York\", ui-serif, Georgia, serif"
        case .mono: "ui-monospace, \"SF Mono\", Menlo, monospace"
        }
    }
}

enum BoostFilter: String, CaseIterable, Codable, Identifiable, Sendable {
    case none, dark, grayscale, sepia, warm, contrast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "None"
        case .dark: "Force dark (invert)"
        case .grayscale: "Grayscale"
        case .sepia: "Sepia"
        case .warm: "Warm (less blue light)"
        case .contrast: "Higher contrast"
        }
    }
    var cssFilter: String? {
        switch self {
        case .none: nil
        case .dark: "invert(1) hue-rotate(180deg)"
        case .grayscale: "grayscale(1)"
        case .sepia: "sepia(0.6)"
        case .warm: "sepia(0.25) saturate(1.1) hue-rotate(-12deg)"
        case .contrast: "contrast(1.25)"
        }
    }
}

struct SiteBoost: Codable, Equatable, Sendable {
    var site: String
    var enabled = true
    var presets: [BoostPreset] = []
    var hiddenSelectors: [String] = []
    var font: BoostFont = .site
    var filter: BoostFilter = .none
    /// Eigen achtergrondkleur als "#RRGGBB" (nil = die van de site).
    var backgroundHex: String? = nil
    /// Maximale breedte van de hoofdtekst in punten (nil = die van de site). Handig op brede schermen.
    var readingWidth: Int? = nil
    var customCSS = ""

    init(site: String) { self.site = site }

    /// Doet deze boost iets? (Een lege boost wordt niet opgeslagen.)
    var isEmpty: Bool {
        presets.isEmpty && hiddenSelectors.isEmpty && font == .site && filter == .none && backgroundHex == nil &&
            readingWidth == nil && customCSS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Aantal actieve aanpassingen (voor het badge-getal bij de Boost-knop).
    var changeCount: Int {
        presets.count + hiddenSelectors.count + (font == .site ? 0 : 1) + (filter == .none ? 0 : 1) +
            (backgroundHex == nil ? 0 : 1) + (readingWidth == nil ? 0 : 1) +
            (customCSS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    /// De volledige stylesheet. Eén regel per verborgen selector: een ongeldige selector maakt in CSS de
    /// hele regel ongeldig, zo raakt één foute Zap nooit de andere.
    var stylesheet: String {
        guard enabled else { return "" }
        var rules: [String] = []
        for preset in BoostPreset.allCases where presets.contains(preset) && preset.applies(to: site) {
            rules.append("\(preset.css) { \(preset.declarations) }")
        }
        for selector in hiddenSelectors { rules.append("\(selector) { display: none !important; }") }
        if let family = font.family {
            rules.append("body, body *:not(code):not(pre):not(kbd):not(samp):not(i):not(svg):not(svg *):not([class*=\"icon\"]):not([class*=\"Icon\"]):not(.material-icons):not(.material-symbols-outlined) { font-family: \(family) !important; }")
        }
        if let css = filter.cssFilter {
            rules.append("html { filter: \(css) !important; }")
            if filter == .dark {
                // Foto's en video's terug-inverteren, anders zijn ze negatief.
                rules.append("img, picture, video, canvas, iframe, [style*=\"background-image\"] { filter: invert(1) hue-rotate(180deg) !important; }")
            }
        }
        if let hex = backgroundHex.flatMap(Self.validHex) {
            rules.append("html, body { background-color: \(hex) !important; }")
        }
        if let width = readingWidth.map(Self.clampWidth) {
            rules.append("article, main, [role=\"main\"] { max-width: \(width)px !important; margin-left: auto !important; margin-right: auto !important; }")
        }
        let custom = Self.sanitizedCSS(customCSS)
        if !custom.isEmpty { rules.append(custom) }
        return rules.joined(separator: "\n")
    }

    static func clampWidth(_ width: Int) -> Int { min(max(width, 480), 2400) }

    /// "#abc" / "#AABBCC" / "aabbcc" → "#AABBCC"; al het andere → nil.
    static func validHex(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.allSatisfy({ $0.isHexDigit }) else { return nil }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        return value.count == 6 ? "#" + value : nil
    }

    /// Een Zap-selector: niet leeg, niet absurd lang en zonder tekens waarmee je uit de CSS-regel breekt.
    static func sanitizedSelector(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 400, !value.contains(where: { "{}<;@\\\n\r".contains($0) }),
              !value.lowercased().contains("</") else { return nil }
        // Haakjes en aanhalingstekens moeten in balans zijn (anders "lekt" de selector).
        var depth = 0, bracket = 0
        for ch in value {
            if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 }
            if ch == "[" { bracket += 1 } else if ch == "]" { bracket -= 1 }
            if depth < 0 || bracket < 0 { return nil }
        }
        guard depth == 0, bracket == 0,
              value.filter({ $0 == "\"" }).count % 2 == 0, value.filter({ $0 == "'" }).count % 2 == 0 else { return nil }
        return value
    }

    /// Eigen CSS: geen @import (extra verzoeken/tracking), geen "</" en hooguit 20.000 tekens.
    static func sanitizedCSS(_ raw: String) -> String {
        let lines = raw.prefix(20_000).components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("@import") }
        return lines.joined(separator: "\n").replacingOccurrences(of: "</", with: "<\\/").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Een Zap toevoegen (dubbele en ongeldige selectors worden genegeerd). Geeft true als er iets bij kwam.
    @discardableResult
    mutating func addHidden(_ selector: String) -> Bool {
        guard let clean = Self.sanitizedSelector(selector), !hiddenSelectors.contains(clean), hiddenSelectors.count < 200 else { return false }
        hiddenSelectors.append(clean)
        return true
    }

    /// Wat het script nodig heeft, als JSON-tekst (veilig in te voegen in JavaScript).
    var scriptPayload: String {
        struct Payload: Encodable { let enabled: Bool; let css: String; let site: String }
        let payload = Payload(enabled: enabled && !isEmpty, css: stylesheet, site: site)
        guard let data = try? JSONEncoder().encode(payload), var json = String(data: data, encoding: .utf8) else {
            return "{\"enabled\":false,\"css\":\"\",\"site\":\"\"}"
        }
        // U+2028/U+2029 zijn geldig in JSON maar breken oudere JavaScript-parsers.
        json = json.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return json
    }
}

enum BoostStore {
    static let key = "siteBoostsV26"
    static let didChange = Notification.Name("nl.tijn.JoeToep.boostsChanged")
    static let emptyPayload = "{\"enabled\":false,\"css\":\"\",\"site\":\"\"}"

    /// Eén sleutel per website: kleine letters, zonder "www.", "m." of "mobile." (zo delen
    /// www.youtube.com en m.youtube.com één boost; music.youtube.com heeft een eigen boost).
    static func siteKey(for url: URL?) -> String? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              var host = url.host?.lowercased(), !host.isEmpty else { return nil }
        for prefix in ["www.", "m.", "mobile."] where host.hasPrefix(prefix) && host.split(separator: ".").count > 2 {
            host.removeFirst(prefix.count); break
        }
        return host
    }

    static func loadAll(_ defaults: UserDefaults = .standard) -> [String: SiteBoost] {
        guard let data = defaults.data(forKey: key),
              let all = try? JSONDecoder().decode([String: SiteBoost].self, from: data) else { return [:] }
        return all
    }
    static func saveAll(_ all: [String: SiteBoost], _ defaults: UserDefaults = .standard) {
        let kept = all.filter { !$0.value.isEmpty }
        if kept.isEmpty { defaults.removeObject(forKey: key) }
        else if let data = try? JSONEncoder().encode(kept) { defaults.set(data, forKey: key) }
        NotificationCenter.default.post(name: didChange, object: nil)
    }
    static func boost(for url: URL?, _ defaults: UserDefaults = .standard) -> SiteBoost? {
        guard let site = siteKey(for: url) else { return nil }
        return loadAll(defaults)[site]
    }
    static func save(_ boost: SiteBoost, _ defaults: UserDefaults = .standard) {
        var all = loadAll(defaults)
        all[boost.site] = boost.isEmpty ? nil : boost
        saveAll(all, defaults)
    }
    static func remove(site: String, _ defaults: UserDefaults = .standard) {
        var all = loadAll(defaults)
        all[site] = nil
        saveAll(all, defaults)
    }
    /// Alle actieve Boosts als `{ "youtube.com": {enabled, css, site}, … }` voor documentStart (boosts.js kiest
    /// zelf die van de geladen site). Leeg object als Boosts uit staan.
    static func bootstrap(globallyEnabled: Bool, _ defaults: UserDefaults = .standard) -> String {
        guard globallyEnabled else { return "{}" }
        let parts = loadAll(defaults).values.sorted { $0.site < $1.site }.compactMap { boost -> String? in
            guard boost.enabled, !boost.isEmpty,
                  let keyData = try? JSONEncoder().encode(boost.site), let key = String(data: keyData, encoding: .utf8) else { return nil }
            return key + ":" + boost.scriptPayload
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    /// JSON voor `boosts.js` (ook als er geen boost is: dan ruimt het script zijn stylesheet op).
    static func payload(for url: URL?, globallyEnabled: Bool, _ defaults: UserDefaults = .standard) -> String {
        guard globallyEnabled, let boost = boost(for: url, defaults) else { return emptyPayload }
        return boost.scriptPayload
    }
}
