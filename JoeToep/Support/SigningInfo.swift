import Foundation

/// V15: when does this build's (free) provisioning profile expire? A personal Apple team signs
/// for 7 days; afterwards iOS reports "This app is no longer available" until it is rebuilt.
enum SigningInfo {
    static let expirationDate: Date? = {
        #if os(iOS)
        let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
        #else
        let url: URL? = Bundle.main.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
        #endif
        guard let url, let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { return nil }
        return plist["ExpirationDate"] as? Date
    }()

    static var summary: String {
        guard let date = expirationDate else { return "No expiring profile (Mac or distribution build)" }
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "Expired " + formatter.string(from: date) + " – rebuild from Xcode" }
        let days = Int(remaining / 86_400), hours = Int(remaining.truncatingRemainder(dividingBy: 86_400) / 3600)
        return "Valid until \(formatter.string(from: date)) (\(days) d \(hours) h)"
    }
    static var expiresSoon: Bool {
        guard let date = expirationDate else { return false }
        return date.timeIntervalSinceNow < 36 * 3600
    }
}
