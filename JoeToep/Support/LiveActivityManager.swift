// V22 — Live Activity "Nu aan het spelen" (iPhone/iPad).
//
// Verschijnt op het vergrendelscherm, in het Dynamic Island en (via de iPhone) in de Smart Stack
// van je Apple Watch. Laat zien wat er op welk apparaat speelt — ook je Mac — met play/pauze,
// spoelen en "hier verder". De voortgangsbalk loopt vanzelf door (klok-tijd), zodat er niet
// elke seconde een update nodig is. Updates komen van dezelfde bron als de widgets.
#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "liveActivityV22") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivityV22") }
    }
    private var activity: Activity<NowPlayingActivityAttributes>?
    private var lastState: NowPlayingActivityAttributes.ContentState?
    private var idleSince: Date?

    private init() {
        // Een activiteit van een vorige keer (app herstart) overnemen in plaats van een tweede starten.
        activity = Activity<NowPlayingActivityAttributes>.activities.first
        for extra in Activity<NowPlayingActivityAttributes>.activities.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func update(from snapshot: WidgetSnapshot) {
        guard Self.enabled, ActivityAuthorizationInfo().areActivitiesEnabled else { endIfNeeded(); return }
        let device = snapshot.nowPlaying
        let anyPlaying = snapshot.devices.contains { $0.playing } || snapshot.spotify?.playing == true
        if anyPlaying { idleSince = nil } else if idleSince == nil { idleSince = Date() }
        // Niets meer aan het spelen sinds 10 min → activiteit weg.
        if let idleSince, Date().timeIntervalSince(idleSince) > 600 { endIfNeeded(); return }
        guard let device, let title = device.title else {
            if !anyPlaying { endIfNeeded() }
            return
        }
        let state = NowPlayingActivityAttributes.ContentState(
            title: title, deviceName: device.name, deviceKind: device.kind, deviceID: device.id, isThisDevice: device.isThisDevice,
            playing: device.playing, time: device.livePosition() ?? 0, duration: device.duration ?? 0, updated: Date(),
            thumbnail: WidgetShared.thumbnail(for: device.url),
            spotifyTrack: snapshot.spotify?.track, spotifyArtist: snapshot.spotify?.artist, spotifyPlaying: snapshot.spotify?.playing)
        if let lastState, Self.similar(lastState, state) { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(state.playing ? 900 : 3600))
        if let activity, activity.activityState == .active || activity.activityState == .stale {
            Task { await activity.update(content) }
        } else if anyPlaying {
            activity = try? Activity.request(attributes: NowPlayingActivityAttributes(), content: content, pushType: nil)
        }
    }

    func endIfNeeded() {
        guard let activity else { return }
        self.activity = nil; lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .default) }
    }

    /// Alleen bijwerken als er echt iets veranderde (positie loopt vanzelf door via de klok).
    private static func similar(_ a: NowPlayingActivityAttributes.ContentState, _ b: NowPlayingActivityAttributes.ContentState) -> Bool {
        guard a.title == b.title, a.deviceID == b.deviceID, a.playing == b.playing, a.spotifyTrack == b.spotifyTrack,
              a.spotifyPlaying == b.spotifyPlaying, abs(a.duration - b.duration) < 1 else { return false }
        // Verwachte positie van de oude toestand nu vs. gemelde positie: > 2 s verschil = gespoeld.
        let expected = a.playing ? a.time + b.updated.timeIntervalSince(a.updated) : a.time
        return abs(expected - b.time) < 2
    }
}
#endif
