import Foundation
import WebKit

enum SitePresentation: String, CaseIterable, Identifiable, Sendable {
    case automatic, mobile, desktop
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var contentMode: WKWebpagePreferences.ContentMode {
        switch self {
        case .automatic: .recommended
        case .mobile: .mobile
        case .desktop: .desktop
        }
    }
}
enum VideoFit: String, CaseIterable, Identifiable, Sendable {
    case fit, fill
    var id: String { rawValue }
    var title: String { self == .fit ? "Fit · entire frame" : "Fill · crop edges" }
}
enum PinchMode: String, CaseIterable, Identifiable, Sendable {
    case video, page, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .video: "Zoom video"
        case .page: "Zoom webpage"
        case .off: "Disabled"
        }
    }
}
/// V15: eight menu-bar sizes. Cozy, Medium and Roomy sit just below Large (all platforms).
enum ToolbarDensity: String, CaseIterable, Identifiable, Sendable {
    case compact, comfortable, cozy, medium, roomy, large, extraLarge, maximum
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: "Compact"
        case .comfortable: "Comfortable"
        case .cozy: "Cozy"
        case .medium: "Medium"
        case .roomy: "Roomy"
        case .large: "Large"
        case .extraLarge: "Extra large"
        case .maximum: "Maximum"
        }
    }
    /// Icon scale relative to the compact 17 pt symbols.
    var scale: Double {
        switch self {
        case .compact: 1
        case .comfortable: 1.1
        case .cozy: 1.15
        case .medium: 1.2
        case .roomy: 1.25
        case .large: 1.3
        case .extraLarge: 1.5
        case .maximum: 1.75
        }
    }
    var isEnlarged: Bool { scale >= 1.15 }
    var height: Double {
        #if os(macOS)
        switch self {
        case .compact: 36
        case .comfortable: 44
        case .cozy: 46
        case .medium: 48
        case .roomy: 50
        case .large: 52
        case .extraLarge: 60
        case .maximum: 70
        }
        #else
        switch self {
        case .compact: 44
        case .comfortable: 50
        case .cozy: 52
        case .medium: 54
        case .roomy: 56
        case .large: 58
        case .extraLarge: 66
        case .maximum: 76
        }
        #endif
    }
}

/// V13: inactive tabs close automatically after this time (default two days).
enum TabLifetime: Int, CaseIterable, Identifiable, Sendable {
    case hour1 = 1, hours6 = 6, hours12 = 12, hours24 = 24, days2 = 48, days3 = 72, days4 = 96,
         days5 = 120, days6 = 144, days7 = 168, month = 720
    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue) * 3600 }
    var title: String {
        switch self {
        case .hour1: "1 hour"
        case .hours6: "6 hours"
        case .hours12: "12 hours"
        case .hours24: "24 hours"
        case .month: "1 month"
        default: "\(rawValue / 24) days"
        }
    }
    static let storageKey = "tabLifetimeHoursV13"
    static func stored(_ defaults: UserDefaults = .standard) -> TabLifetime {
        TabLifetime(rawValue: defaults.integer(forKey: storageKey)) ?? .days2
    }
}

/// YouTube's own player is the default; custom modes require an explicit choice.
enum MacFullscreenMode: String, CaseIterable, Identifiable, Sendable {
    case youtube, enhanced, safe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .youtube: "YouTube fullscreen"
        case .enhanced: "Enhanced fullscreen controls"
        case .safe: "Safe fullscreen (compatibility)"
        }
    }
}
