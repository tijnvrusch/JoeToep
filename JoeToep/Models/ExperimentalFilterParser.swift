import Foundation

/// Only simple YouTube ad-container selectors are imported. No scriptlets,
/// arbitrary CSS, network redirects or playback-element rules are executable here.
enum ExperimentalFilterParser {
    static let source = URL(string: "https://raw.githubusercontent.com/easylist/easylist/master/easylist/easylist_specific_hide.txt")!
    static func selectors(from text: String) -> [String] {
        let adNames = ["ad-slot-renderer", "display-ad-renderer", "in-feed-ad-layout-renderer",
                       "banner-promo-renderer", "action-companion-ad-renderer", "companion-ad-renderer",
                       "promoted-sparkles-web-renderer", "promoted-sparkles-text-search-renderer",
                       "promoted-video-renderer", "search-pyv-renderer"]
        let allowed = Set(["ytd-", "ytm-"].flatMap { prefix in adNames.map { prefix + $0 } } + ["#player-ads", "#masthead-ad", ".ytp-ad-overlay-container"])
        var result = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.components(separatedBy: "##")
            guard parts.count == 2 else { continue }
            let domains = parts[0].split(separator: ",").map(String.init)
            guard !domains.contains(where: { $0.hasPrefix("~") }) else { continue }
            guard domains.contains("youtube.com") || domains.contains("www.youtube.com") || domains.contains("m.youtube.com") else { continue }
            for selector in parts[1].split(separator: ",") {
                let value = selector.trimmingCharacters(in: .whitespaces)
                if allowed.contains(value) { result.insert(value) }
            }
        }
        return result.sorted()
    }
    static func rulesJSON(from text: String) throws -> String {
        let selectors = selectors(from: text)
        guard !selectors.isEmpty else { throw FilterUpdateError.noCompatibleRules }
        let rules: [[String: Any]] = [["trigger": ["url-filter": ".*", "if-domain": ["youtube.com", "www.youtube.com", "m.youtube.com"]],
                                     "action": ["type": "css-display-none", "selector": selectors.joined(separator: ", ")]]]
        let data = try JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

enum FilterUpdateError: LocalizedError {
    case download, tooLarge, noCompatibleRules, compile
    var errorDescription: String? {
        switch self {
        case .download: "The filter source could not be downloaded. Previous rules remain active."
        case .tooLarge: "The filter response exceeded the size limit. Previous rules remain active."
        case .noCompatibleRules: "No supported YouTube ad-container rules were found. Previous rules remain active."
        case .compile: "WebKit rejected the updated rules. Previous rules remain active."
        }
    }
}
