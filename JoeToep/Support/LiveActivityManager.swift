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
        // V23: een activiteit die iOS al beëindigde/wegveegde (ended/dismissed) niet meer gebruiken → nieuwe starten.
        if let current = activity, current.activityState == .ended || current.activityState == .dismissed {
            activity = nil; lastState = nil
        }
        if activity == nil, let adopted = Activity<NowPlayingActivityAttributes>.activities.first(where: { $0.activityState == .active || $0.activityState == .stale }) {
            activity = adopted
        }
        let live = activity.map { $0.activityState == .active || $0.activityState == .stale } ?? false
        let forced = forceNext; forceNext = false
        // V23: net een knop ingedrukt → oude (nog niet bijgewerkte) info mag die tik niet terugdraaien.
        if !forced, Date() < optimisticUntil { return }
        // V23: een verouderde (stale) activiteit altijd verversen, ook als de inhoud gelijk is.
        let stale = activity?.activityState == .stale
        if live, !forced, !stale, let lastState, Self.similar(lastState, state) { return }
        let content = ActivityContent(state: state, staleDate: Self.staleDate(for: state, anyPlaying: anyPlaying))
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

    /// V23: volgende update altijd doorvoeren (na terugkomst, na een knop, na een nieuwe stand).
    private var forceNext = false
    private var optimisticUntil = Date.distantPast
    func forceNextUpdate() { forceNext = true }

    /// V23: tot wanneer is de getoonde stand betrouwbaar? Speelt er iets met bekende lengte, dan tot
    /// (ruim) het einde van de video — de voortgang loopt vanzelf door; anders 1 uur. Niets aan het
    /// spelen: 10 min (sluit aan op het automatisch beëindigen).
    static func staleDate(for state: NowPlayingActivityAttributes.ContentState, anyPlaying: Bool, now: Date = Date()) -> Date {
        guard anyPlaying else { return now.addingTimeInterval(600) }
        guard state.playing, state.duration > 0 else { return now.addingTimeInterval(3600) }
        let remaining = max(0, state.duration - state.time)
        return now.addingTimeInterval(min(4 * 3600, max(180, remaining + 120)))
    }

    /// V23: je tik in de Live Activity meteen laten zien (play/pauze, spoelen), nog vóór het andere
    /// apparaat antwoordt. De echte stand volgt binnen een paar tellen en corrigeert zo nodig.
    func applyOptimistic(_ command: WidgetCommand) {
        guard let activity, activity.activityState == .active || activity.activityState == .stale, var state = lastState else { return }
        let target = command.deviceID ?? TabSyncService.shared.deviceID
        guard target == state.deviceID || (command.deviceID == nil && state.isThisDevice) else { return }
        let now = Date()
        var position = state.playing ? state.time + now.timeIntervalSince(state.updated) : state.time
        switch command.action {
        case .playPause: state.playing.toggle()
        case .play: state.playing = true
        case .pause: state.playing = false
        case .skipForward: position += 10
        case .skipBack: position -= 10
        case .skipForward30: position += 30
        case .skipBack30: position -= 30
        default: return
        }
        position = max(0, state.duration > 0 ? min(state.duration, position) : position)
        state.time = position; state.updated = now
        lastState = state
        optimisticUntil = now.addingTimeInterval(3)
        let content = ActivityContent(state: state, staleDate: Self.staleDate(for: state, anyPlaying: state.playing))
        Task { await activity.update(content) }
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
