import Foundation
import WatchConnectivity
import SwiftUI

/// Een video uit de feed (zelfde velden als FeedVideo op de iPhone, compact overgestuurd).
struct WatchVideo: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let channel: String
    let duration: String?
    var thumbnail: URL { URL(string: "https://i.ytimg.com/vi/\(id)/default.jpg")! }
    init?(_ d: [String: String]) {
        guard let id = d["id"], let t = d["t"] else { return nil }
        self.id = id; title = t; channel = d["c"] ?? ""; duration = d["d"]
    }
}

struct WatchDevice: Identifiable, Equatable, Hashable { let id: String; let name: String }

/// Alle toestand van de Watch-app + de verbinding met de iPhone (WatchConnectivity).
@MainActor
final class WatchStore: NSObject, ObservableObject {
    @Published var feed: [WatchVideo] = []
    @Published var results: [WatchVideo] = []
    /// Downloads op de iPhone (offline afspeelbaar op de iPhone).
    @Published var downloads: [WatchVideo] = []
    @Published var query = ""
    @Published var loadingFeed = false
    @Published var searching = false
    @Published var nowTitle = ""
    @Published var playing = false
    @Published var rate: Double = 1
    @Published var devices: [WatchDevice] = []
    @Published var target: String = UserDefaults.standard.string(forKey: "target") ?? "" {
        didSet { UserDefaults.standard.set(target, forKey: "target") }
    }
    @Published var message: String?
    private var lastFeed = Date.distantPast

    var targetName: String { devices.first { $0.id == target }?.name ?? "iPhone" }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Acties

    func refreshFeedIfNeeded() async {
        guard feed.isEmpty || Date().timeIntervalSince(lastFeed) > 120 else { return }
        await refreshFeed()
    }

    func refreshFeed() async {
        guard !loadingFeed else { return }
        loadingFeed = true; defer { loadingFeed = false }
        if let reply = await send(["op": "feed"], timeout: 12) {
            let items = Self.videos(reply)
            if !items.isEmpty { feed = items; lastFeed = Date() }
            message = items.isEmpty && feed.isEmpty ? "Nothing yet — open YouTube in JoeToep on your iPhone once." : nil
        }
    }

    func search(_ text: String) async {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        query = q; searching = true; results = []
        defer { searching = false }
        if let reply = await send(["op": "search", "q": q], timeout: 12) { results = Self.videos(reply) }
    }

    func play(_ video: WatchVideo) async {
        nowTitle = video.title; playing = true           // meteen tonen (optimistisch), status volgt
        apply(await send(["op": "play", "id": video.id, "target": target], timeout: 8))
    }
    func refreshDownloads() async {
        if let reply = await send(["op": "downloads"], timeout: 5) { downloads = Self.videos(reply) }
    }
    func playDownload(_ item: WatchVideo) async {
        nowTitle = item.title; playing = true
        apply(await send(["op": "playDownload", "id": item.id], timeout: 5))
    }
    func toggle() async { playing.toggle(); apply(await send(["op": "toggle", "target": target])) }
    func seek(_ seconds: Double) async { apply(await send(["op": "seek", "v": seconds, "target": target])) }
    func rate(_ step: Int) async { apply(await send(["op": "rate", "v": Double(step), "target": target])) }
    func refreshStatus() async { apply(await send(["op": "status", "target": target], timeout: 5)) }

    private func apply(_ reply: [String: Any]?) {
        guard let reply else { return }
        if let list = reply["devices"] as? [[String: String]] {
            devices = list.compactMap { d in d["id"].map { WatchDevice(id: $0, name: d["n"] ?? "Device") } }
            if target.isEmpty || !devices.contains(where: { $0.id == target }) { target = reply["self"] as? String ?? devices.first?.id ?? "" }
        }
        if let t = reply["title"] as? String, !t.isEmpty { nowTitle = t }
        if let p = reply["playing"] as? Bool { playing = p }
        if let r = reply["rate"] as? Double { rate = r }
        message = reply["error"] as? String
    }

    private static func videos(_ reply: [String: Any]) -> [WatchVideo] {
        (reply["items"] as? [[String: String]] ?? []).compactMap(WatchVideo.init)
    }

    /// Stuurt een bericht naar de iPhone en wacht (max. `timeout` s) op het antwoord.
    private func send(_ payload: [String: Any], timeout: Double = 4) async -> [String: Any]? {
        let session = WCSession.default
        guard session.activationState == .activated else { message = "Connecting to iPhone…"; return nil }
        guard session.isReachable else { message = "iPhone not reachable. Keep it nearby with Bluetooth on."; return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[String: Any]?, Never>) in
            let once = Once(continuation)
            session.sendMessage(payload, replyHandler: { reply in once.resume(reply) },
                                errorHandler: { _ in once.resume(nil) })
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once.resume(nil) }
        }
    }
}

/// Zorgt dat een continuation precies één keer wordt afgerond (antwoord óf time-out).
private final class Once: @unchecked Sendable {
    private var continuation: CheckedContinuation<[String: Any]?, Never>?
    private let lock = NSLock()
    init(_ c: CheckedContinuation<[String: Any]?, Never>) { continuation = c }
    func resume(_ value: [String: Any]?) {
        lock.lock(); let c = continuation; continuation = nil; lock.unlock()
        c?.resume(returning: value)
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            await self.refreshStatus()
            await self.refreshFeedIfNeeded()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            self.message = nil
            await self.refreshFeedIfNeeded()
        }
    }
}
