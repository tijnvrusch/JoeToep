#if os(iOS)
import Foundation
import WatchConnectivity
import AVFoundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// V18/V22 — De iPhone-kant van de Apple Watch-app.
///
/// • Afstandsbediening: feed/zoeken via de iPhone, afspelen/pauzeren/spoelen op élk apparaat
///   (iPhone, Mac, iPad via de tab-sync), overnemen ("hier verder") en doorsturen ("verder op …").
/// • Live toestand: bij elke wijziging stuurt de iPhone meteen een compacte toestand naar de Watch
///   (application context), zodat de Watch-app én de complicaties altijd kloppen.
/// • Spotify: bediening van Spotify op je Mac (via de iPhone).
/// • Downloads naar de Watch: bestanden die je in JoeToep downloadde (geen YouTube — die streams
///   zijn beveiligd) worden in een Watch-vriendelijk formaat overgezet en zijn daarna offline te
///   kijken/luisteren op de Watch. Optioneel automatisch.
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()
    private weak var workspace: BrowserWorkspace?
    private var activated = false
    private var lastPushed: WatchState?
    private var pushQueued = false
    private var lastComplicationKey = ""
    private var transfers: [UUID: WCSessionFileTransfer] = [:]

    /// Watch-instellingen die de Watch zelf doorgeeft.
    var autoSyncDownloads: Bool {
        get { UserDefaults.standard.bool(forKey: "watchAutoSyncV22") }
        set { UserDefaults.standard.set(newValue, forKey: "watchAutoSyncV22") }
    }
    var watchQuality: String {
        get { UserDefaults.standard.string(forKey: "watchQualityV22") ?? "medium" }
        set { UserDefaults.standard.set(newValue, forKey: "watchQualityV22") }
    }
    /// Downloads die al naar de Watch gingen (niet dubbel versturen).
    private var sentToWatch: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "watchSentV22") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "watchSentV22") }
    }

    func activate(workspace: BrowserWorkspace) {
        self.workspace = workspace
        activateSession()
    }

    func activateSession() {
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
        NotificationCenter.default.addObserver(forName: DownloadManager.didComplete, object: nil, queue: .main) { note in
            guard let id = note.object as? UUID else { return }
            Task { @MainActor in
                let bridge = WatchBridge.shared
                if bridge.autoSyncDownloads || bridge.pendingDownloadForWatch == id { bridge.sendDownload(id) }
            }
        }
    }
    /// V22: via de Watch gestarte download → na afloop meteen naar de Watch.
    private var pendingDownloadForWatch: UUID?

    // MARK: Live toestand naar de Watch

    /// Door WidgetBridge aangeroepen bij elke wijziging (gebundeld tot max. 4× per seconde).
    func setNeedsPush() {
        guard activated, !pushQueued else { return }
        pushQueued = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.pushQueued = false
            self?.push()
        }
    }

    private func push(force: Bool = false) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let state = makeState()
        var comparable = state; comparable.updated = .distantPast
        var previous = lastPushed; previous?.updated = .distantPast
        // Posities lopen vanzelf; alleen versturen bij een echte wijziging (of > 1,5 s verschil).
        if !force, let previous, Self.equivalent(previous, comparable) { return }
        lastPushed = state
        guard let data = state.encoded() else { return }
        try? session.updateApplicationContext([WatchState.contextKey: data])
        // Direct bericht als de Watch-app open is (sneller dan de context).
        if session.isReachable { session.sendMessage([WatchState.contextKey: data], replyHandler: nil, errorHandler: nil) }
        // Complicaties: alleen bij een nieuwe titel / play-pauze (dagelijks budget).
        let key = (state.nowPlaying?.title ?? "") + "|" + String(state.nowPlaying?.playing ?? false) + "|" + (state.spotify?.track ?? "")
        if key != lastComplicationKey, session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            lastComplicationKey = key
            session.transferCurrentComplicationUserInfo([WatchState.contextKey: data])
        }
    }

    private static func equivalent(_ a: WatchState, _ b: WatchState) -> Bool {
        guard a.devices.count == b.devices.count, a.spotify?.track == b.spotify?.track, a.spotify?.playing == b.spotify?.playing,
              abs((a.spotify?.volume ?? 0) - (b.spotify?.volume ?? 0)) < 1 else { return false }
        // V22.2: ook Spotify-positie (±2 s, gespoeld), -duur en shuffle/repeat meenemen.
        if let x = a.spotify, let y = b.spotify {
            guard abs(x.duration - y.duration) < 1, x.shuffling == y.shuffling, x.repeating == y.repeating,
                  abs(x.livePosition(at: y.updated) - y.position) <= 2 else { return false }
        }
        for (x, y) in zip(a.devices, b.devices) {
            guard x.id == y.id, x.title == y.title, x.playing == y.playing, x.connected == y.connected, x.url == y.url,
                  x.rate == y.rate, abs((x.duration ?? 0) - (y.duration ?? 0)) < 1 else { return false }     // V22.2: snelheid/duur
            let ex = x.livePosition(at: y.updated) ?? 0, ey = y.time ?? 0
            if abs(ex - ey) > 1.5 { return false }
        }
        return true
    }

    func makeState() -> WatchState {
        let widget = WidgetBridge.shared.makeSnapshot()
        let sync = TabSyncService.shared
        var state = WatchState()
        state.phoneID = sync.deviceID
        state.devices = widget.devices.map { d in
            WatchDeviceState(id: d.id, name: d.isThisDevice ? "iPhone" : d.name, kind: d.kind, isPhone: d.isThisDevice,
                             connected: d.isThisDevice || sync.devices[d.id] != nil, title: d.title, url: d.url?.absoluteString,
                             playing: d.playing, time: d.livePosition(), duration: d.duration,
                             rate: d.isThisDevice ? workspace?.mediaTab.session.playbackRate : nil, updated: Date())
        }
        if let sp = SpotifyController.shared.current, sp.hasTrack {
            state.spotify = WatchSpotifyState(device: sp.device, playing: sp.playing, track: sp.track, artist: sp.artist,
                                              artwork: sp.artworkURL?.absoluteString, position: sp.livePosition(), duration: sp.duration,
                                              volume: sp.volume, shuffling: sp.shuffling, repeating: sp.repeating, updated: Date())
        }
        return state
    }

    // MARK: Verzoeken van de Watch

    /// Verwerkt één verzoek van de Watch en geeft het antwoord terug (plist-typen).
    func handle(_ message: [String: Any]) async -> [String: Any] {
        let op = message["op"] as? String ?? ""
        switch op {
        case "feed":
            return ["items": await YouTubeFeedService.home().map(\.plist)]
        case "search":
            return ["items": await YouTubeFeedService.search(message["q"] as? String ?? "").map(\.plist)]
        case "play":
            guard let id = message["id"] as? String else { return ["ok": false] }
            guard let dest = target(message) else { return offlineReply() }     // V22.2
            if workspace == nil && dest == TabSyncService.shared.deviceID { return noWorkspaceReply() }
            let url = FeedVideo(id: id, title: "", channel: "").url
            TabSyncService.shared.send(SyncCommand(kind: .play, target: dest, url: url, value: nil))
            try? await Task.sleep(for: .milliseconds(400))
            return status(for: dest)
        case "downloads":
            let items = DownloadManager.shared.items.filter { $0.state == .done }
            let sent = sentToWatch
            return ["items": items.map { ["id": $0.id.uuidString, "t": $0.title, "c": $0.format.isAudio ? "Audio" : "Video",
                                          "d": ByteCountFormatter.string(fromByteCount: $0.bytes, countStyle: .file),
                                          "w": sent.contains($0.id.uuidString) ? "1" : "0"] }]
        case "playDownload":
            guard let raw = message["id"] as? String, let id = UUID(uuidString: raw),
                  let item = DownloadManager.shared.items.first(where: { $0.id == id }) else { return ["ok": false] }
            if workspace == nil { return noWorkspaceReply() }     // V22.2: de offline-speler hoort bij het venster
            NotificationCenter.default.post(name: DownloadManager.playOffline, object: item.id)
            return status().merging(["title": item.title, "playing": true]) { _, new in new }
        case "sendToWatch":
            guard let raw = message["id"] as? String, let id = UUID(uuidString: raw) else { return ["ok": false] }
            if let q = message["quality"] as? String { watchQuality = q }
            // V22.2: alleen "ok" als het overzetten echt kon starten.
            return sendDownload(id) ? ["ok": true] : ["ok": false, "error": "Can't send this download to your Watch right now."]
        case "downloadCurrent":
            // Download de video op de huidige pagina (alleen openlijk aangeboden bestanden, geen YouTube)
            // en zet hem daarna meteen op de Watch.
            return await downloadCurrentForWatch()
        case "settings":
            if let a = message["autoSync"] as? Bool { autoSyncDownloads = a }
            if let q = message["quality"] as? String { watchQuality = q }
            return ["ok": true, "autoSync": autoSyncDownloads, "quality": watchQuality]
        case "toggle", "seek", "rate":
            let kind = SyncCommand.Kind(rawValue: op) ?? .toggle
            guard let dest = target(message) else { return offlineReply() }     // V22.2
            if workspace == nil && dest == TabSyncService.shared.deviceID { return noWorkspaceReply() }
            TabSyncService.shared.send(SyncCommand(kind: kind, target: dest, url: nil, value: message["v"] as? Double))
            try? await Task.sleep(for: .milliseconds(250))     // even laten verwerken → verse status
            push(force: true)
            return status(for: dest)
        case "takeover":
            // "Hier verder" op de iPhone: neem de video van dat apparaat over.
            if workspace == nil { return noWorkspaceReply() }     // V22.2
            if let device = message["device"] as? String { workspace?.takeOverFrom(device: device) }
            try? await Task.sleep(for: .milliseconds(400)); push(force: true)
            return status()
        case "continueOn":
            // De video van de iPhone naar een ander apparaat sturen.
            if workspace == nil { return noWorkspaceReply() }     // V22.2
            if let device = message["device"] as? String { workspace?.continuePlayback(on: device) }
            try? await Task.sleep(for: .milliseconds(400)); push(force: true)
            return status()
        case "moveTo":
            // Van apparaat A naar B (bijv. Mac → iPad) — via "verder daar" op A.
            guard let from = message["from"] as? String, let to = message["to"] as? String else { return status() }
            let sync = TabSyncService.shared
            // V22.2: van/naar de iPhone kan alleen met een venster.
            if workspace == nil && (from == sync.deviceID || to == sync.deviceID) { return noWorkspaceReply() }
            if from == sync.deviceID { workspace?.continuePlayback(on: to) }
            else if to == sync.deviceID { workspace?.takeOverFrom(device: from) }
            else if let snap = sync.latestByDevice[from], let tab = snap.playingID.flatMap({ id in snap.tabs.first { $0.id == id } }), let url = tab.url {
                if snap.closed != nil {
                    // V22.2: bron pauzeert zelf en stuurt zijn EXACTE tijd naar `to` (continuePlayback) — geen blinde toggle.
                    sync.send(SyncCommand(kind: .continueOn, target: from, url: url, value: nil, to: to))
                } else {
                    // Oudere app-versie op de bron (kent .continueOn niet): oude manier.
                    sync.send(SyncCommand(kind: .toggle, target: from, url: nil, value: nil))
                    sync.send(SyncCommand(kind: .continueThere, target: to, url: url, value: tab.time ?? 0, from: from))
                }
            }
            try? await Task.sleep(for: .milliseconds(400)); push(force: true)
            return status()
        case "spotify":
            let action = SpotifyAction(rawValue: message["a"] as? String ?? "") ?? .playPause
            SpotifyController.shared.perform(action, value: message["v"] as? Double)
            try? await Task.sleep(for: .milliseconds(350)); push(force: true)
            return status()
        case "state":
            // V22.2: een poll krijgt de toestand in het antwoord; niet óók nog een geforceerde push.
            return ["state": makeState().encoded() ?? Data()]
        default:
            return status(for: target(message))
        }
    }

    /// V22.2: nil = het gevraagde apparaat is niet (meer) verbonden — niet stilletjes de iPhone bedienen.
    private func target(_ message: [String: Any]) -> String? {
        let requested = message["target"] as? String ?? ""
        let sync = TabSyncService.shared
        if requested.isEmpty || requested == sync.deviceID { return sync.deviceID }
        return sync.devices[requested] == nil ? nil : requested
    }
    /// V22.2: foutantwoorden (met verse status, zodat de Watch de apparatenlijst bijwerkt).
    private func offlineReply() -> [String: Any] {
        status().merging(["ok": false, "error": "That device is offline."]) { _, new in new }
    }
    private func noWorkspaceReply() -> [String: Any] {
        status().merging(["ok": false, "error": "Open JoeToep on your iPhone once, then try again."]) { _, new in new }
    }

    /// Wat de Watch toont: welke video, speelt hij, snelheid, en op welke apparaten je kunt afspelen.
    func status(for device: String? = nil) -> [String: Any] {
        let sync = TabSyncService.shared
        var devices: [[String: String]] = [["id": sync.deviceID, "n": "iPhone"]]
        devices += sync.devices.sorted { $0.value < $1.value }.map { ["id": $0.key, "n": $0.value] }
        var result: [String: Any] = ["devices": devices, "self": sync.deviceID]
        if let device, device != sync.deviceID, let remote = sync.latestByDevice[device] {
            let id = remote.playingID ?? remote.handoffID ?? remote.selectedID
            result["title"] = remote.tabs.first { $0.id == id }?.title ?? ""
            result["playing"] = remote.playingID != nil
        } else if let tab = workspace?.mediaTab {
            result["title"] = tab.fullTitle
            result["playing"] = tab.session.isPlaying
            result["rate"] = tab.session.playbackRate
        }
        if let data = makeState().encoded() { result["state"] = data }
        return result
    }

    // MARK: Downloads naar de Watch

    private func downloadCurrentForWatch() async -> [String: Any] {
        guard let session = workspace?.selected.session else { return ["error": "Open JoeToep on your iPhone first."] }
        if session.isOnYouTube { return ["error": "YouTube videos can't be downloaded (protected). Use a video from another site."] }
        let sources: [MediaSource] = await withCheckedContinuation { c in session.findDownloadableMedia { c.resume(returning: $0) } }
        guard let source = sources.first(where: { $0.kind == .video }) ?? sources.first else {
            return ["error": "No downloadable video on this page."]
        }
        let format: DownloadFormat = watchQuality == "audio" || source.kind == .audio ? .audioAAC : .video480
        guard let item = DownloadManager.shared.start(source: source.url, title: session.pageTitle ?? source.label,
                                                      page: session.currentURL, format: format) else {
            return ["error": "This video can't be downloaded."]
        }
        pendingDownloadForWatch = item.id
        return ["ok": true, "title": item.title]
    }

    /// V22.2: geeft `false` als het overzetten niet kon starten (de Watch telt dan niet op).
    @discardableResult
    func sendDownload(_ id: UUID) -> Bool {
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled,
              let item = DownloadManager.shared.items.first(where: { $0.id == id }),
              let file = DownloadManager.shared.fileURL(for: item) else { return false }
        let quality = watchQuality
        Task.detached(priority: .utility) {
            let prepared = await Self.prepareForWatch(file, audioOnly: item.format.isAudio || quality == "audio", quality: quality) ?? file
            await MainActor.run {
                let meta: [String: Any] = ["id": item.id.uuidString, "t": item.title, "audio": item.format.isAudio || quality == "audio"]
                let transfer = session.transferFile(prepared, metadata: meta)
                WatchBridge.shared.transfers[item.id] = transfer
                var sent = WatchBridge.shared.sentToWatch; sent.insert(item.id.uuidString); WatchBridge.shared.sentToWatch = sent
            }
        }
        return true
    }

    /// Kleiner maken voor de Watch (scherm 200-ish px breed; scheelt opslag en overzettijd).
    nonisolated static func prepareForWatch(_ file: URL, audioOnly: Bool, quality: String) async -> URL? {
        let asset = AVURLAsset(url: file)
        let preset: String
        if audioOnly { preset = AVAssetExportPresetAppleM4A }
        else {
            switch quality {
            case "low": preset = AVAssetExportPresetLowQuality
            case "high": preset = AVAssetExportPreset960x540
            default: preset = AVAssetExportPreset640x480
            }
        }
        guard let export = AVAssetExportSession(asset: asset, presetName: preset) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("watch-\(UUID().uuidString).\(audioOnly ? "m4a" : "mp4")")
        export.outputURL = out
        export.outputFileType = audioOnly ? .m4a : .mp4
        export.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in export.exportAsynchronously { c.resume() } }
        return export.status == .completed ? out : nil
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchBridge.shared.push(force: true) }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in WatchBridge.shared.push(force: true) }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in WatchBridge.shared.push(force: true) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let box = UncheckedBox(value: message)
        let reply = UncheckedBox(value: replyHandler)
        Task { @MainActor in
            let answer = await WatchBridge.shared.handle(box.value)
            reply.value(answer)
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = UncheckedBox(value: message)
        Task { @MainActor in _ = await WatchBridge.shared.handle(box.value) }
    }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // Tijdelijk (verkleind) bestand opruimen.
        let url = fileTransfer.file.fileURL
        if url.lastPathComponent.hasPrefix("watch-") { try? FileManager.default.removeItem(at: url) }
        // V22.2: mislukte overdracht aan de Watch melden (anders blijft "Receiving…" staan).
        let meta = UncheckedBox(value: fileTransfer.file.metadata ?? [:])
        let failed = error != nil
        Task { @MainActor in
            let raw = meta.value["id"] as? String ?? ""
            if let id = UUID(uuidString: raw) { WatchBridge.shared.transfers[id] = nil }
            guard failed else { return }
            var sent = WatchBridge.shared.sentToWatch; sent.remove(raw); WatchBridge.shared.sentToWatch = sent
            let wc = WCSession.default
            if wc.activationState == .activated, wc.isWatchAppInstalled {
                wc.transferUserInfo(["transferFailed": meta.value["t"] as? String ?? ""])     // sleutel ook in WatchStore
            }
        }
    }
}

/// WatchConnectivity-woordenboeken zijn niet `Sendable`; ze gaan hier ongewijzigd naar de hoofdthread.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }
#endif
