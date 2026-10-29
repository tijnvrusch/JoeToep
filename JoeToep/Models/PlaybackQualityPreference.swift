import Foundation

enum PlaybackQualityPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic = "auto"
    case p144 = "tiny"
    case p240 = "small"
    case p360 = "medium"
    case p480 = "large"
    case p720 = "hd720"
    case p1080 = "hd1080"
    case p1440 = "hd1440"
    case p2160 = "hd2160"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Auto"
        case .p144: "144p"
        case .p240: "240p"
        case .p360: "360p"
        case .p480: "480p"
        case .p720: "720p"
        case .p1080: "1080p"
        case .p1440: "1440p"
        case .p2160: "2160p · 4K"
        }
    }
    static func restored(_ raw: String?) -> Self {
        if let raw, let exact = Self(rawValue: raw) { return exact }
        // V1 changed site presentation, not actual stream quality.
        return .automatic
    }
}
