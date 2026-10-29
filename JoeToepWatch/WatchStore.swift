import Foundation
import WatchConnectivity
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Een video uit de feed (zelfde velden als FeedVideo op de iPhone, compact overgestuurd).
struct WatchVideo: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let channel: String
    let duration: String?
    var sentToWatch = false
    var thumbnail: URL { URL(string: "https://i.ytimg.com/vi/\(id)/default.jpg")! }
    init?(_ d: [String: String]) {
        guard let id = d["id"], let t = d["t"] else { return nil }
        self.id = id; title = t; channel = d["c"] ?? ""; duration = d["d"]; sentToWatch = d["w"] == "1"
    }
}

struct WatchDevice: Identifiable, Equatable, Hashable { let id: String; let name: String }

/// V22: een bestand dat echt op de Watch staat (offline afspelen).
struct LocalDownload: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var fileName: String
    var audio: Bool
    var bytes: Int64
    var added = Date()
    var position: Double = 0
}

/// Alle toestand van de Watch-app + de verbinding met de iPhone (WatchConnectivity).
@MainActor
final class WatchStore: NSObject, ObservableObject {
    @Published var feed: [WatchVideo] = []
    @Published var results: [WatchVideo] = []
    /// Downloads op de iPhone.
    @Published var downloads: [WatchVideo] = []
    /// V22: downloads die op de Watch zelf staan.
    @Published var local: [LocalDownload] = []
    @Published var incoming: Int = 0
    @Published var query = ""
    @Published var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "recentSearchesV22") ?? []
    @Published var loadingFeed = false
    @Published var searching = false
    @Published var nowTitle = ""
    @Published var playing = false
    @Published var rate: Double = 1
    @Published var devices: [WatchDevice] = []
    /// V22: live toestand van alle apparaten (van de iPhone).
    @Published var state = WatchState.loadFromGroup() ?? WatchState()
    @Published var target: String = UserDefaults.standard.string(forKey: "target") ?? "" {
        didSet { UserDefaults.standard.set(target, forKey: "target") }
    }
    @Published var message: String?
    @Published var reachable = false
    // Instellingen
    @Published var quality: String = UserDefaults.standard.string(forKey: "watchQualityV22") ?? "medium" {
        didSet { UserDefaults.standard.set(quality, forKey: "watchQualityV22"); Task { await pushSettings() } }
    }
    @Published var autoSync: Bool = UserDefaults.standard.bool(forKey: "watchAutoSyncV22") {
        didSet { UserDefaults.standard.set(autoSync, forKey: "watchAutoSyncV22"); Task { await pushSettings() } }
    }
    @Published var followPlaying: Bool = UserDefaults.standard.object(forKey: "watchFollowV22") as? Bool ?? true {
        didSet { UserDefaults.standard.set(followPlaying, forKey: "watchFollowV22") }
    }
    @Published var skipSeconds: Double = UserDefaults.standard.object(forKey: "watchSkipV22") as? Double ?? 10 {
        didSet { UserDefaults.standard.set(skipSeconds, forKey: "watchSkipV22") }
    }
    private var lastFeed = Date.distantPast
    private var ticker: Task<Void, Never>?

    var targetName: String { devices.first { $0.id == target }?.name ?? state.devices.first { $0.id == target }?.name ?? "iPhone" }
    /// Het apparaat dat je nu bedient (met live toestand).
    var targetState: WatchDeviceState? {
        state.devices.first { $0.id == target } ?? state.nowPlaying
    }

    /// V22.2: één gedeelde store, zodat de app-delegate de verbinding al bij het starten kan openen.
    static let shared = WatchStore()
    private var started = false

    func start() {
        guard !started else { return }     // V22.2: idempotent (delegate én onAppear)
        started = true
        loadLocal()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Zolang de app voorin staat: elke 2 s verse toestand (naast de pushes van de iPhone).
    func beginLive() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refreshState()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    func endLive() { ticker?.cancel(); ticker = nil }

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
        recentSearches = Array(([q] + recentSearches.filter { $0 != q }).prefix(8))
        UserDefaults.standard.set(recentSearches, forKey: "recentSearchesV22")
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
    /// V22: een iPhone-download op de Watch zetten.
    func sendToWatch(_ item: WatchVideo) async {
        message = "Sending “\(item.title)” to your Watch…"
        let reply = await send(["op": "sendToWatch", "id": item.id, "quality": quality], timeout: 6)
        // V22.2: pas meetellen als de iPhone bevestigt dat het overzetten echt begon.
        if reply?["ok"] as? Bool == true { incoming += 1 }
        else if let error = reply?["error"] as? String { message = error }
        else if reply != nil { message = "Couldn't send “\(item.title)” to your Watch." }
    }
    /// V22.2: de iPhone meldt een mislukte overdracht → teller omlaag en foutmelding tonen.
    func transferFailed(_ title: String) {
        incoming = max(0, incoming - 1)
        message = title.isEmpty ? "A download couldn't be sent to your Watch." : "Couldn't send “\(title)” to your Watch."
    }
    /// V22: de video op de huidige iPhone-pagina downloaden en op de Watch zetten.
    func downloadCurrentPage() async {
        let reply = await send(["op": "downloadCurrent"], timeout: 12)
        if let error = reply?["error"] as? String { message = error }
        else if let title = reply?["title"] as? String { incoming += 1; message = "Downloading “\(title)”… it appears here when ready." }
    }
    func toggle(_ device: String? = nil) async {
        let id = device ?? target
        optimisticToggle(id)
        apply(await send(["op": "toggle", "target": id]))
    }
    func seek(_ seconds: Double, device: String? = nil) async { apply(await send(["op": "seek", "v": seconds, "target": device ?? target])) }
    func rate(_ step: Int) async { apply(await send(["op": "rate", "v": Double(step), "target": target])) }
    func refreshStatus() async { apply(await send(["op": "status", "target": target], timeout: 5)) }
    func refreshState() async {
        guard WCSession.default.isReachable else { return }
        if let reply = await send(["op": "state"], timeout: 3, quiet: true), let data = reply["state"] as? Data, let s = WatchState.decode(data) { apply(state: s) }
    }
    func takeOver(_ device: String) async { apply(await send(["op": "takeover", "device": device], timeout: 6)) }
    func continueOn(_ device: String) async { apply(await send(["op": "continueOn", "device": device], timeout: 6)) }
    func move(from: String, to: String) async { apply(await send(["op": "moveTo", "from": from, "to": to], timeout: 6)) }
    func spotify(_ action: String, value: Double? = nil) async {
        if action == "playPause", var sp = state.spotify { sp.playing.toggle(); state.spotify = sp }
        var payload: [String: Any] = ["op": "spotify", "a": action]
        if let value { payload["v"] = value }
        apply(await send(payload, timeout: 5))
    }
    private func pushSettings() async { _ = await send(["op": "settings", "autoSync": autoSync, "quality": quality], timeout: 4, quiet: true) }

    private func optimisticToggle(_ id: String) {
        if let i = state.devices.firstIndex(where: { $0.id == id }) {
            state.devices[i].time = state.devices[i].livePosition(); state.devices[i].updated = Date()
            state.devices[i].playing.toggle()
        }
        if id == target { playing.toggle() }
    }

    private func apply(_ reply: [String: Any]?) {
        guard let reply else { return }
        if let list = reply["devices"] as? [[String: String]] {
            devices = list.compactMap { d in d["id"].map { WatchDevice(id: $0, name: d["n"] ?? "Device") } }
            if target.isEmpty || !devices.contains(where: { $0.id == target }) { target = reply["self"] as? String ?? devices.first?.id ?? "" }
        }
        if let t = reply["title"] as? String, !t.isEmpty { nowTitle = t }
        if let p = reply["playing"] as? Bool { playing = p }
        if let r = reply["rate"] as? Double { rate = r }
        if let data = reply["state"] as? Data, let s = WatchState.decode(data) { apply(state: s) }
        if let e = reply["error"] as? String { message = e } else if reply["ok"] as? Bool == true || reply["devices"] != nil { message = nil }
    }

    /// Nieuwe live toestand: tonen, bewaren voor de complicaties, en (optioneel) het spelende
    /// apparaat automatisch als doel kiezen.
    private var lastWidgetKey = ""
    /// V22.2: laatst spelende apparaat — "volgen" wisselt alleen als dát verandert, niet elke 2 s
    /// (anders wordt een zelf gekozen apparaat steeds teruggezet).
    private var lastPlayingID: String?
    func apply(state new: WatchState) {
        state = new
        if let playingID = new.devices.first(where: { $0.playing })?.id, playingID != lastPlayingID {
            lastPlayingID = playingID
            if followPlaying, playingID != target { target = playingID }
        }
        if let t = targetState {
            if let title = t.title { nowTitle = title }
            playing = t.playing
            if let r = t.rate { rate = r }
        }
        if devices.isEmpty { devices = new.devices.map { WatchDevice(id: $0.id, name: $0.name) } }
        new.saveToGroup()
        // Complicaties alleen herladen als er iets zichtbaars veranderde (budget sparen).
        let n = new.nowPlaying
        let key = [n?.id ?? "", n?.title ?? "", String(n?.playing ?? false), String(Int((n?.time ?? 0) / 30)),
                   new.spotify?.track ?? "", String(new.spotify?.playing ?? false), String(new.devices.count)].joined(separator: "|")
        if key != lastWidgetKey {
            lastWidgetKey = key
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private static func videos(_ reply: [String: Any]) -> [WatchVideo] {
        (reply["items"] as? [[String: String]] ?? []).compactMap(WatchVideo.init)
    }

    /// Stuurt een bericht naar de iPhone en wacht (max. `timeout` s) op het antwoord.
    private func send(_ payload: [String: Any], timeout: Double = 4, quiet: Bool = false) async -> [String: Any]? {
        let session = WCSession.default
        guard session.activationState == .activated else { if !quiet { message = "Connecting to iPhone…" }; return nil }
        guard session.isReachable else {
            if !quiet { message = "iPhone not reachable. Keep it nearby with Bluetooth or Wi‑Fi on." }
            return nil
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[String: Any]?, Never>) in
            let once = Once(continuation)
            session.sendMessage(payload, replyHandler: { reply in once.resume(reply) },
                                errorHandler: { _ in once.resume(nil) })
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once.resume(nil) }
        }
    }

    // MARK: Downloads op de Watch

    private var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("WatchDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var indexURL: URL { folder.appendingPathComponent("index.json") }
    func fileURL(_ item: LocalDownload) -> URL { folder.appendingPathComponent(item.fileName) }

    private func loadLocal() {
        guard let data = try? Data(contentsOf: indexURL), let list = try? JSONDecoder().decode([LocalDownload].self, from: data) else { return }
        local = list.filter { FileManager.default.fileExists(atPath: fileURL($0).path) }
    }
    private func saveLocal() { if let data = try? JSONEncoder().encode(local) { try? data.write(to: indexURL, options: .atomic) } }

    func receive(file: URL, metadata: [String: Any]?) {
        let id = metadata?["id"] as? String ?? UUID().uuidString
        let title = metadata?["t"] as? String ?? file.lastPathComponent
        let audio = metadata?["audio"] as? Bool ?? false
        let name = id + "." + (file.pathExtension.isEmpty ? (audio ? "m4a" : "mp4") : file.pathExtension)
        let target = folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: target)
        do { try FileManager.default.moveItem(at: file, to: target) } catch { return }
        let size = (try? FileManager.default.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.int64Value ?? 0
        local.removeAll { $0.id == id }
        local.insert(LocalDownload(id: id, title: title, fileName: name, audio: audio, bytes: size), at: 0)
        incoming = max(0, incoming - 1)
        message = "“\(title)” is on your Watch."
        saveLocal()
    }
    func remove(_ item: LocalDownload) {
        try? FileManager.default.removeItem(at: fileURL(item))
        local.removeAll { $0.id == item.id }; saveLocal()
    }
    func savePosition(_ item: LocalDownload, _ time: Double) {
        guard let i = local.firstIndex(where: { $0.id == item.id }) else { return }
        local[i].position = time; saveLocal()
    }
    var localBytes: Int64 { local.reduce(0) { $0 + $1.bytes } }
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

private struct Box<T>: @unchecked Sendable { let value: T }

extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = Box(value: session.receivedApplicationContext)
        Task { @MainActor in
            if let data = context.value[WatchState.contextKey] as? Data, let s = WatchState.decode(data) { self.apply(state: s) }
            self.reachable = session.isReachable
            await self.refreshStatus()
            await self.refreshFeedIfNeeded()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.reachable = reachable
            guard reachable else { return }
            self.message = nil
            await self.refreshState()
            await self.refreshFeedIfNeeded()
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in if let s = WatchState.decode(data) { self.apply(state: s) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in if let s = WatchState.decode(data) { self.apply(state: s) } }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // V22.2: mislukte overdracht vanaf de iPhone.
        if let failed = userInfo["transferFailed"] as? String {
            Task { @MainActor in self.transferFailed(failed) }
            return
        }
        guard let data = userInfo[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in if let s = WatchState.decode(data) { self.apply(state: s) } }
    }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Het bestand verdwijnt na deze methode: eerst (synchroon) naar een eigen plek verplaatsen.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + file.fileURL.pathExtension)
        try? FileManager.default.moveItem(at: file.fileURL, to: temp)
        let meta = Box(value: file.metadata)
        Task { @MainActor in self.receive(file: temp, metadata: meta.value) }
    }
}
