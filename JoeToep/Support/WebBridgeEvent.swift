import Foundation

struct WebBridgeEvent {
    enum Name: String { case ready, automaticFullscreen, state, pipFailure, windowFullscreen, enterWindowFullscreen, exitWindowFullscreen, sponsorSkipped }
    let name: Name
    let documentID: String
    let videoID: Int
    let playing: Bool
    let buffering: Bool
    let fullscreen: Bool
    let stage: Bool
    let pip: Bool
    let width: Int
    let height: Int
    let token: Int
    let message: String
    let seconds: Double
    init?(body: Any) {
        guard let d = body as? [String: Any], let raw = d["event"] as? String,
              let name = Name(rawValue: raw), let documentID = d["documentID"] as? String,
              !documentID.isEmpty, documentID.count <= 80 else { return nil }
        self.name = name; self.documentID = documentID
        videoID = (d["videoID"] as? Int) ?? 0
        playing = (d["playing"] as? Bool) ?? false
        buffering = (d["buffering"] as? Bool) ?? false
        fullscreen = (d["fullscreen"] as? Bool) ?? false
        stage = (d["stage"] as? Bool) ?? false
        pip = (d["pip"] as? Bool) ?? false
        width = min(max((d["width"] as? Int) ?? 0, 0), 16384)
        height = min(max((d["height"] as? Int) ?? 0, 0), 16384)
        token = (d["token"] as? Int) ?? 0
        message = String(((d["message"] as? String) ?? "Unavailable").prefix(180))
        let rawSeconds = (d["seconds"] as? Double) ?? 0
        seconds = rawSeconds.isFinite ? min(max(rawSeconds, 0), 36_000) : 0
    }
}
