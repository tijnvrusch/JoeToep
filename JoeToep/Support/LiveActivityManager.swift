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
    private var idleEnd: Task<Void, Never>?     // V22.2

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
        if anyPlaying { idleSince = nil; idleEnd?.cancel(); idleEnd = nil } else if idleSince == nil {
            idleSince = Date()
            // V22.2: zelf na 10 min beëindigen — niet pas bij de volgende update (die komt bij stilstand niet).
            idleEnd?.cancel()
            idleEnd = Task { @MainActor in
                try? await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled else { return }
                LiveActivityManager.shared.endIfNeeded()
            }
        }
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
        // V22.2: de "bijna gelijk"-snelweg alleen als er echt een lopende activiteit is.
        let live = activity.map { $0.activityState == .active || $0.activityState == .stale } ?? false
        if live, let lastState, Self.similar(lastState, state) { return }
        // V22.2: niets meer aan het spelen → na 10 min verouderd (sluit aan op het automatisch beëindigen).
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(!anyPlaying ? 600 : (state.playing ? 900 : 3600)))
        if live, let activity {
            lastState = state
            Task { await activity.update(content) }
        } else if anyPlaying {
            // V22.2: lastState pas bewaren na een geslaagde start (op de achtergrond kan request mislukken).
            do {
                activity = try Activity.request(attributes: NowPlayingActivityAttributes(), content: content, pushType: nil)
                lastState = state
            } catch {
                activity = nil; lastState = nil
            }
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
