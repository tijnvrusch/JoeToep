import SwiftUI

/// V15: visual customisation. Every option is a separate setting.
enum ThemeStyle: String, CaseIterable, Identifiable, Sendable {
    case youtube, black, graphite, midnight, ocean, forest, plum, espresso, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .youtube: "YouTube dark"
        case .black: "OLED black"
        case .graphite: "Graphite"
        case .midnight: "Midnight"
        case .ocean: "Deep ocean"
        case .forest: "Forest"
        case .plum: "Plum"
        case .espresso: "Espresso"
        case .light: "Light"
        }
    }
    var isLight: Bool { self == .light }
    /// Menu bar / window background.
    var background: Color {
        switch self {
        case .youtube: Color(hex: 0x0F0F0F)
        case .black: .black
        case .graphite: Color(hex: 0x1C1C1E)
        case .midnight: Color(hex: 0x0B1020)
        case .ocean: Color(hex: 0x06161F)
        case .forest: Color(hex: 0x0C1510)
        case .plum: Color(hex: 0x160C1A)
        case .espresso: Color(hex: 0x17110D)
        case .light: Color(hex: 0xF2F2F5)
        }
    }
    /// Selected tab / raised surfaces.
    var surface: Color { isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.13) }
    var hover: Color { isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.07) }
    var foreground: Color { isLight ? Color(hex: 0x111111) : Color.white.opacity(0.92) }
    var secondary: Color { isLight ? Color.black.opacity(0.55) : Color.white.opacity(0.55) }
    var separator: Color { isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.09) }
    var colorScheme: ColorScheme { isLight ? .light : .dark }
}

enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case youtubeRed, red, orange, amber, yellow, lime, green, mint, teal, cyan, blue, indigo, purple, pink, rose, white, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .custom: "Custom"
        case .youtubeRed: "YouTube Red (Tjoep)"
        default: rawValue.capitalized
        }
    }
    func color(custom: String) -> Color {
        switch self {
        case .youtubeRed: Color(hex: 0xFF0033)
        case .red: Color(hex: 0xFF3B30)
        case .orange: Color(hex: 0xFF8A00)
        case .amber: Color(hex: 0xFFB300)
        case .yellow: Color(hex: 0xFFD60A)
        case .lime: Color(hex: 0xA4E400)
        case .green: Color(hex: 0x30D158)
        case .mint: Color(hex: 0x63E6BE)
        case .teal: Color(hex: 0x2EC4B6)
        case .cyan: Color(hex: 0x32D2FF)
        case .blue: Color(hex: 0x0A84FF)
        case .indigo: Color(hex: 0x5E5CE6)
        case .purple: Color(hex: 0xBF5AF2)
        case .pink: Color(hex: 0xFF2D92)
        case .rose: Color(hex: 0xFF6B8B)
        case .white: Color(hex: 0xF5F5F5)
        case .custom: Color(hexString: custom) ?? Color(hex: 0xFF3B30)
        }
    }
}

enum IconVariant: String, CaseIterable, Identifiable, Sendable {
    case outline, filled, circle, circleFilled, square, squareFilled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .outline: "Outline"
        case .filled: "Filled"
        case .circle: "Circle"
        case .circleFilled: "Circle filled"
        case .square: "Square"
        case .squareFilled: "Square filled"
        }
    }
    var variants: SymbolVariants {
        switch self {
        case .outline: .none
        case .filled: .fill
        case .circle: .circle
        case .circleFilled: .circle.fill
        case .square: .square
        case .squareFilled: .square.fill
        }
    }
}

enum IconWeightChoice: String, CaseIterable, Identifiable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ultraLight: "Ultra light"
        case .semibold: "Semibold"
        default: rawValue.capitalized
        }
    }
    var weight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

enum IconRendering: String, CaseIterable, Identifiable, Sendable {
    case monochrome, hierarchical, accent, palette
    var id: String { rawValue }
    var title: String {
        switch self {
        case .monochrome: "Monochrome"
        case .hierarchical: "Hierarchical"
        case .accent: "Accent colour"
        case .palette: "Two-tone (accent)"
        }
    }
}

enum AnimationStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case off, snappy, smooth, bouncy, relaxed, spring, easeOut, linear
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .snappy: "Snappy"
        case .smooth: "Smooth"
        case .bouncy: "Bouncy"
        case .relaxed: "Relaxed"
        case .spring: "Spring"
        case .easeOut: "Ease out"
        case .linear: "Linear"
        }
    }
    var animation: Animation? { animation(speed: 1) }
    /// `speed` > 1 is faster (shorter), < 1 slower.
    func animation(speed: Double) -> Animation? {
        let s = max(0.2, min(speed, 5))
        switch self {
        case .off: return nil
        case .snappy: return .snappy(duration: 0.2 / s)
        case .smooth: return .smooth(duration: 0.26 / s)
        case .bouncy: return .bouncy(duration: 0.34 / s, extraBounce: 0.08)
        case .relaxed: return .easeInOut(duration: 0.42 / s)
        case .spring: return .spring(response: 0.3 / s, dampingFraction: 0.82)
        case .easeOut: return .easeOut(duration: 0.2 / s)
        case .linear: return .linear(duration: 0.18 / s)
        }
    }
}

/// V16: every animated part of the app can have its own curve and speed (Advanced settings).
enum AnimationKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case tabs, addressBar, toolbar, notices, sheets, findBar, visualizer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tabs: "Tabs (open, close, switch)"
        case .addressBar: "Address bar"
        case .toolbar: "Menu bar & buttons"
        case .notices: "Notices"
        case .sheets: "Pages & panels"
        case .findBar: "Find bar"
        case .visualizer: "Audio visualizer"
        }
    }
}
struct AnimationProfile: Codable, Equatable, Sendable {
    var style: AnimationStyle? = nil   // nil = follow the global style
    var speed: Double = 1
}

/// V16: menu-bar audio visualizer.
enum VisualizerStyle: String, CaseIterable, Identifiable, Sendable {
    case bars, wave, glow, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bars: "Bars"
        case .wave: "Wave"
        case .glow: "Glow"
        case .off: "Off"
        }
    }
}

enum TabShape: String, CaseIterable, Identifiable, Sendable {
    case rounded, pill, square, underline
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TabCloseButtons: String, CaseIterable, Identifiable, Sendable {
    case always, selected, hover, never
    var id: String { rawValue }
    var title: String {
        switch self {
        case .always: "Always"
        case .selected: "Selected tab only"
        case .hover: "On hover / selected"
        case .never: "Never (use menu or ⌘W)"
        }
    }
}

enum TabTextSize: String, CaseIterable, Identifiable, Sendable {
    case small, regular, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var font: Font {
        switch self {
        case .small: .caption
        case .regular: .footnote
        case .large: .subheadline
        }
    }
}

/// V15: automatic tab summaries.
enum TabSummaryLength: String, CaseIterable, Identifiable, Sendable {
    case tiny, short, medium, long
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tiny: "Very short (1–2 words)"
        case .short: "Short (2–4 words)"
        case .medium: "Medium (4–6 words)"
        case .long: "Long (6–9 words)"
        }
    }
    var maxWords: Int {
        switch self {
        case .tiny: 2
        case .short: 4
        case .medium: 6
        case .long: 9
        }
    }
}

enum SearchEngine: String, CaseIterable, Identifiable, Sendable {
    case youtube, google, duckDuckGo, brave, bing, ecosia, startpage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .youtube: "YouTube"
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        case .brave: "Brave Search"
        case .bing: "Bing"
        case .ecosia: "Ecosia"
        case .startpage: "Startpage"
        }
    }
    func url(for query: String) -> URL? {
        var parts: URLComponents?
        switch self {
        case .youtube:
            parts = URLComponents(string: "https://www.youtube.com/results")
            parts?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        case .google:
            parts = URLComponents(string: "https://www.google.com/search")
            parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        case .duckDuckGo:
            parts = URLComponents(string: "https://duckduckgo.com/")
            parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        case .brave:
            parts = URLComponents(string: "https://search.brave.com/search")
            parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        case .bing:
            parts = URLComponents(string: "https://www.bing.com/search")
            parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        case .ecosia:
            parts = URLComponents(string: "https://www.ecosia.org/search")
            parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        case .startpage:
            parts = URLComponents(string: "https://www.startpage.com/do/search")
            parts?.queryItems = [URLQueryItem(name: "query", value: query)]
        }
        return parts?.url
    }
}

/// V15: where the PiP window's return button takes the video.
enum PiPReturnTarget: String, CaseIterable, Identifiable, Sendable {
    case fullscreen, origin, inline
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fullscreen: "Always fullscreen"
        case .origin: "Where PiP started"
        case .inline: "Inline player"
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
