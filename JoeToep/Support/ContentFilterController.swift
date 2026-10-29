import Foundation
import WebKit
import CryptoKit

/// Versioned WebKit rules with an opt-in, bounded EasyList cosmetic subset update.
@MainActor
final class ContentFilterController {
    private var lists: [String: WKContentRuleList] = [:]
    private var applied: Set<String> = []
    private(set) var experimentalStatus = "No downloaded experimental rules"
    private let defaults = UserDefaults.standard

    func prepare() async -> [String] {
        guard let url = Bundle.main.url(forResource: "contentFilters", withExtension: "json", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "contentFilters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var definitions = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let store = WKContentRuleListStore.default() else { return ["Rules unavailable"] }
        var failures: [String] = []
        if let ads = definitions["ads"] as? [[String: Any]] {
            definitions["adCards"] = ads.filter { ($0["action"] as? [String: Any])?["type"] as? String == "css-display-none" }
            definitions["ads"] = ads.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
        }
        if let url = Bundle.main.url(forResource: "strictAds", withExtension: "json", subdirectory: "Resources") ?? Bundle.main.url(forResource: "strictAds", withExtension: "json"),
           let data = try? Data(contentsOf: url), let rules = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            definitions["strictAds"] = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
            definitions["strictCards"] = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "css-display-none" }
        }
        for name in definitions.keys.sorted() {
            let identifier = "JoeToepV8.filters.1." + name
            let cached: WKContentRuleList? = await withCheckedContinuation { continuation in
                store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                    continuation.resume(returning: list)
                }
            }
            if let cached { lists[name] = cached; continue }
            guard let definition = definitions[name],
                  let encoded = try? JSONSerialization.data(withJSONObject: definition),
                  let json = String(data: encoded, encoding: .utf8) else {
                failures.append(name); continue
            }
            let compiled: WKContentRuleList? = await withCheckedContinuation { continuation in
                store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, _ in
                    continuation.resume(returning: list)
                }
            }
            if let compiled { lists[name] = compiled } else { failures.append(name) }
        }
        if let cached = defaults.string(forKey: "experimentalRulesV5") {
            do {
                lists["experimental"] = try await compileExperimental(cached)
                experimentalStatus = "Cached compatible EasyList subset · " + (defaults.string(forKey: "experimentalDateV5") ?? "date unknown")
            } catch { failures.append("cached experimental rules") }
        }
        return failures
    }

    func apply(_ settings: SettingsSnapshot, to controller: WKUserContentController) {
        var wanted: Set<String> = []
        if settings.blockAds {
            let level = settings.adBlockLevel
            if level.blocksAdServers { wanted.insert("ads") }
            if settings.hideAdCards { wanted.insert("adCards") }
            if level.blocksMeasurement {
                wanted.insert("strictAds")
                if settings.hideAdCards { wanted.insert("strictCards") }
            }
            if settings.experimentalFilters && settings.hideAdCards { wanted.insert("experimental") }
        }
        if settings.blockShortsNavigation { wanted.insert("shorts") }
        if settings.blockPostsNavigation { wanted.insert("posts") }
        if settings.blockPremiumDestinations { wanted.insert("premium") }
        wanted = wanted.intersection(Set(lists.keys))
        guard wanted != applied else { return }
        controller.removeAllContentRuleLists()
        for name in wanted.sorted() {
            if let list = lists[name] { controller.add(list) }
        }
        applied = wanted
    }

    func refreshExperimental() async throws {
        let (json, count) = try await Self.downloadExperimentalRules()
        let compiled = try await compileExperimental(json)
        lists["experimental"] = compiled
        applied.remove("experimental")
        let date = ISO8601DateFormatter().string(from: Date())
        defaults.set(json, forKey: "experimentalRulesV5")
        defaults.set(date, forKey: "experimentalDateV5")
        experimentalStatus = "EasyList compatible subset · \(count) selectors · checked \(date)"
    }

    nonisolated private static func downloadExperimentalRules() async throws -> (String, Int) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(from: ExperimentalFilterParser.source)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw FilterUpdateError.download }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw FilterUpdateError.tooLarge }
            data.append(byte)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw FilterUpdateError.download }
        let json = try ExperimentalFilterParser.rulesJSON(from: text)
        return (json, ExperimentalFilterParser.selectors(from: text).count)
    }

    private func compileExperimental(_ json: String) async throws -> WKContentRuleList {
        guard let store = WKContentRuleListStore.default() else { throw FilterUpdateError.compile }
        let hash = SHA256.hash(data: Data(json.utf8)).map { String(format: "%02x", $0) }.joined()
        let identifier = "JoeToepV5.experimental." + hash
        let list: WKContentRuleList? = await withCheckedContinuation { continuation in
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, _ in continuation.resume(returning: list) }
        }
        guard let list else { throw FilterUpdateError.compile }
        let previous = defaults.string(forKey: "experimentalIDV5")
        defaults.set(identifier, forKey: "experimentalIDV5")
        if let previous, previous != identifier, previous.hasPrefix("JoeToepV5.experimental.") {
            store.removeContentRuleList(forIdentifier: previous) { _ in }
        }
        return list
    }
}
