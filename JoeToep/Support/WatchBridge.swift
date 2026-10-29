#if os(iOS)
import Foundation
import WatchConnectivity

/// V18 — De iPhone-kant van de Apple Watch-app.
///
/// watchOS heeft geen webbrowser, dus de Watch kan YouTube niet zelf afspelen. De Watch is een
/// supersnelle afstandsbediening: hij vraagt de iPhone om de feed of zoekresultaten, en laat de
/// gekozen video afspelen op de iPhone — of op een ander apparaat met JoeToep open (Mac/iPad),
/// via de tab-sync. Berichten zijn klein (alleen tekst; plaatjes haalt de Watch zelf, 4 kB per stuk).
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()
    private weak var workspace: BrowserWorkspace?
    private var activated = false

    func activate(workspace: BrowserWorkspace) {
        self.workspace = workspace
        activateSession()
    }

    func activateSession() {
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

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
            if workspace == nil && target(message) == TabSyncService.shared.deviceID {
                return status().merging(["error": "Open JoeToep on your iPhone once, then try again."]) { a, _ in a }
            }
            let url = FeedVideo(id: id, title: "", channel: "").url
            TabSyncService.shared.send(SyncCommand(kind: .play, target: target(message), url: url, value: nil))
            try? await Task.sleep(for: .milliseconds(400))
            return status(for: target(message))
        case "downloads":
            let items = DownloadManager.shared.items.filter { $0.state == .done }
            return ["items": items.map { ["id": $0.id.uuidString, "t": $0.title, "c": $0.format.isAudio ? "Audio" : "Video"] }]
        case "playDownload":
            guard let raw = message["id"] as? String, let id = UUID(uuidString: raw),
                  let item = DownloadManager.shared.items.first(where: { $0.id == id }) else { return ["ok": false] }
            NotificationCenter.default.post(name: DownloadManager.playOffline, object: item.id)
            return status().merging(["title": item.title, "playing": true]) { _, new in new }
        case "toggle", "seek", "rate":
            let kind = SyncCommand.Kind(rawValue: op) ?? .toggle
            TabSyncService.shared.send(SyncCommand(kind: kind, target: target(message), url: nil, value: message["v"] as? Double))
            try? await Task.sleep(for: .milliseconds(250))     // even laten verwerken → verse status
            return status(for: target(message))
        default:
            return status(for: target(message))
        }
    }

    private func target(_ message: [String: Any]) -> String {
        let requested = message["target"] as? String ?? ""
        let sync = TabSyncService.shared
        return requested.isEmpty || (requested != sync.deviceID && sync.devices[requested] == nil) ? sync.deviceID : requested
    }

    /// Wat de Watch toont: welke video, speelt hij, snelheid, en op welke apparaten je kunt afspelen.
    func status(for device: String? = nil) -> [String: Any] {
        let sync = TabSyncService.shared
        var devices: [[String: String]] = [["id": sync.deviceID, "n": "iPhone"]]
        devices += sync.devices.sorted { $0.value < $1.value }.map { ["id": $0.key, "n": $0.value] }
        var result: [String: Any] = ["devices": devices, "self": sync.deviceID]
        if let device, device != sync.deviceID, let remote = sync.latestByDevice[device] {
            // Ander apparaat: wat het laatst meldde (spelende tab, anders de geselecteerde).
            let id = remote.playingID ?? remote.selectedID
            result["title"] = remote.tabs.first { $0.id == id }?.title ?? ""
            result["playing"] = remote.playingID != nil
        } else if let tab = workspace?.mediaTab {
            result["title"] = tab.fullTitle
            result["playing"] = tab.session.isPlaying
            result["rate"] = tab.session.playbackRate
        }
        return result
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let box = UncheckedBox(value: message)
        Task { @MainActor in
            let reply = await WatchBridge.shared.handle(box.value)
            replyHandler(reply)
        }
    }
}

/// WatchConnectivity-woordenboeken zijn niet `Sendable`; ze gaan hier ongewijzigd naar de hoofdthread.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }
#endif
