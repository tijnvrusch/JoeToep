// V20 — Spotify-integratie.
//
// Mac: praat rechtstreeks met de Spotify-desktopapp via Apple Events (AppleScript). Spotify
// meldt zelf elke wijziging (volgend nummer, pauze, …) met een systeemnotificatie, dus we
// hoeven niet voortdurend te pollen; alleen de positie wordt tussendoor geschat.
// iPhone/iPad: tonen wat er op de Mac in Spotify speelt en die bedienen via de bestaande
// sync-verbinding (Mac ⇄ iPhone ⇄ iPad), plus openen in de Spotify-app.
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Wat er in Spotify speelt (op één apparaat).
struct SpotifyState: Codable, Equatable, Sendable {
    var running = false
    var playing = false
    var track = ""
    var artist = ""
    var album = ""
    var artworkURL: URL?
    var duration: Double = 0          // seconden
    var position: Double = 0          // seconden, op moment `updated`
    var volume: Double = 50           // 0…100
    var shuffling = false
    var repeating = false
    var trackURI = ""
    var device = ""                   // apparaatnaam (voor "Spotify op <Mac>")
    var deviceID = ""
    var updated = Date()

    /// Geschatte positie nu (loopt door terwijl er gespeeld wordt).
    func livePosition(at now: Date = Date()) -> Double {
        guard playing else { return position }
        return min(duration > 0 ? duration : .infinity, position + now.timeIntervalSince(updated))
    }
    var hasTrack: Bool { running && !track.isEmpty }
    /// Link naar het nummer op open.spotify.com (voor delen / openen op iPhone).
    var webURL: URL? {
        let parts = trackURI.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify" else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[1])/\(parts[2])")
    }
}

enum SpotifyAction: String, Codable, Sendable, CaseIterable {
    case playPause, play, pause, next, previous, setVolume, seek, toggleShuffle, toggleRepeat, openURI, launch, refresh
}

@MainActor
final class SpotifyController: ObservableObject {
    static let shared = SpotifyController()
    static let bundleID = "com.spotify.client"

    /// Spotify op dít apparaat (alleen Mac).
    @Published private(set) var local: SpotifyState?
    /// Spotify op andere apparaten (via sync), per apparaat-id.
    @Published private(set) var remote: [String: SpotifyState] = [:]
    /// Laatste foutmelding (bijv. toestemming geweigerd) — getoond in het mediacentrum.
    @Published private(set) var problem: String?

    /// Wat de UI toont: lokaal als dat er is, anders het meest recente externe apparaat.
    var current: SpotifyState? {
        if let local, local.running { return local }
        return remote.values.filter(\.running).max { $0.updated < $1.updated }
    }
    var isLocal: Bool { local?.running == true }

    private init() {
        #if os(macOS)
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == Self.bundleID else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    self?.refresh()
                }
            }
        }
        refresh()
        #endif
    }

    // MARK: Waarnemers (positie tussendoor bijwerken zolang iemand kijkt)

    private var observers = 0
    private var ticker: Task<Void, Never>?
    func beginObserving() {
        observers += 1
        guard ticker == nil else { return }
        refresh()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, self.observers > 0 else { return }
                if self.local?.running == true { self.refresh() }
            }
        }
    }
    func endObserving() {
        observers = max(0, observers - 1)
        if observers == 0 { ticker?.cancel(); ticker = nil }
    }

    // MARK: Bediening

    /// Voert uit op dit apparaat (Mac) of stuurt door naar het apparaat waar Spotify speelt.
    func perform(_ action: SpotifyAction, value: Double? = nil, uri: String? = nil) {
        #if os(macOS)
        if isLocal || action == .launch || action == .openURI || remote.isEmpty {
            performLocally(action, value: value, uri: uri); return
        }
        #endif
        if let target = current?.deviceID, !target.isEmpty {
            optimistic(action, value: value, deviceID: target)
            TabSyncService.shared.sendSpotify(action, value: value, uri: uri, to: target)
        } else if action == .openURI || action == .launch {
            openInSpotifyApp(uri: uri)
        }
    }

    /// Vanaf een ander apparaat ontvangen opdracht.
    func performRemote(_ action: SpotifyAction, value: Double?, uri: String?) {
        #if os(macOS)
        performLocally(action, value: value, uri: uri)
        #endif
    }

    /// Nieuwe toestand van een ander apparaat.
    func receive(_ state: SpotifyState, from deviceID: String) {
        var s = state; s.deviceID = deviceID
        if s.running { remote[deviceID] = s } else { remote[deviceID] = nil }
        WidgetBridge.shared.setNeedsUpdate()
    }
    func forget(deviceID: String) { remote[deviceID] = nil }

    /// Meteen de UI bijwerken, zodat een klik direct voelt (echte toestand volgt vanzelf).
    private func optimistic(_ action: SpotifyAction, value: Double?, deviceID: String) {
        guard var s = remote[deviceID] else { return }
        s.position = s.livePosition(); s.updated = Date()
        switch action {
        case .playPause: s.playing.toggle()
        case .play: s.playing = true
        case .pause: s.playing = false
        case .setVolume: s.volume = value ?? s.volume
        case .seek: s.position = value ?? s.position
        case .toggleShuffle: s.shuffling.toggle()
        case .toggleRepeat: s.repeating.toggle()
        default: break
        }
        remote[deviceID] = s
    }

    func openInSpotifyApp(uri: String? = nil) {
        let target = uri.flatMap(URL.init(string:)) ?? URL(string: "spotify:")!
        #if os(macOS)
        NSWorkspace.shared.open(target)
        #else
        UIApplication.shared.open(target) { ok in
            if !ok, let web = URL(string: "https://open.spotify.com") { UIApplication.shared.open(web) }
        }
        #endif
    }

    // MARK: Mac — Apple Events

    #if os(macOS)
    private let queue = DispatchQueue(label: "joetoep.spotify", qos: .userInitiated)
    private var refreshQueued = false

    var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) != nil }
    private var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty }

    private func performLocally(_ action: SpotifyAction, value: Double?, uri: String?) {
        if action == .launch { openInSpotifyApp(); return }
        if action == .openURI, let uri {
            // "play track" speelt meteen af; start Spotify als dat nodig is.
            if !isRunning { openInSpotifyApp(uri: uri); return }
            run("tell application id \"\(Self.bundleID)\" to play track \"\(uri.replacingOccurrences(of: "\"", with: ""))\"") { [weak self] _ in self?.refreshSoon() }
            return
        }
        guard isRunning else { publish(SpotifyState(running: false)); return }
        // Direct optimistisch bijwerken.
        if var s = local {
            s.position = s.livePosition(); s.updated = Date()
            switch action {
            case .playPause: s.playing.toggle()
            case .play: s.playing = true
            case .pause: s.playing = false
            case .setVolume: s.volume = value ?? s.volume
            case .seek: s.position = value ?? s.position
            case .toggleShuffle: s.shuffling.toggle()
            case .toggleRepeat: s.repeating.toggle()
            default: break
            }
            publish(s)
        }
        let verb: String
        switch action {
        case .playPause: verb = "playpause"
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        case .setVolume: verb = "set sound volume to \(Int((value ?? 50).rounded()).clamped(0, 100))"
        case .seek: verb = "set player position to \(max(0, value ?? 0))"
        case .toggleShuffle: verb = "set shuffling to not shuffling"
        case .toggleRepeat: verb = "set repeating to not repeating"
        case .refresh, .launch, .openURI: refresh(); return
        }
        run("tell application id \"\(Self.bundleID)\" to \(verb)") { [weak self] _ in
            // Volume verandert Spotify niet met een notificatie → zelf even opvragen.
            self?.refreshSoon(delay: action == .setVolume ? 150 : 250)
        }
    }

    private func refreshSoon(delay: Int = 250) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            self?.refresh()
        }
    }

    /// Leest de volledige toestand uit Spotify (één Apple Event).
    func refresh() {
        guard isRunning else {
            if local?.running != false { publish(SpotifyState(running: false)) }
            return
        }
        guard !refreshQueued else { return }
        refreshQueued = true
        let sep = "\u{1F}"
        let script = """
        tell application id "\(Self.bundleID)"
            set s to (player state as string)
            if s is "stopped" then return s
            set t to current track
            return s & "\(sep)" & (name of t) & "\(sep)" & (artist of t) & "\(sep)" & (album of t) & "\(sep)" & (artwork url of t) & "\(sep)" & ((duration of t) as string) & "\(sep)" & ((player position) as string) & "\(sep)" & ((sound volume) as string) & "\(sep)" & ((shuffling) as string) & "\(sep)" & ((repeating) as string) & "\(sep)" & (id of t)
        end tell
        """
        run(script) { [weak self] output in
            guard let self else { return }
            self.refreshQueued = false
            guard let output else { return }
            let f = output.components(separatedBy: sep)
            var s = SpotifyState(running: true)
            s.device = TabSyncService.shared.deviceName; s.deviceID = TabSyncService.shared.deviceID
            s.playing = f.first == "playing"
            if f.count >= 11 {
                s.track = f[1]; s.artist = f[2]; s.album = f[3]
                s.artworkURL = URL(string: f[4])
                s.duration = (Double(f[5].replacingOccurrences(of: ",", with: ".")) ?? 0) / 1000
                s.position = Double(f[6].replacingOccurrences(of: ",", with: ".")) ?? 0
                s.volume = Double(f[7]) ?? 50
                s.shuffling = f[8] == "true"; s.repeating = f[9] == "true"
                s.trackURI = f[10]
            }
            s.updated = Date()
            self.publish(s)
        }
    }

    private func publish(_ state: SpotifyState) {
        let changedForSync = local.map { old in
            old.running != state.running || old.playing != state.playing || old.trackURI != state.trackURI
                || abs(old.volume - state.volume) >= 1 || old.shuffling != state.shuffling || old.repeating != state.repeating
                || abs(old.livePosition() - state.position) > 2.5
        } ?? true
        local = state
        if changedForSync { TabSyncService.shared.publishSpotify(state) }
        MediaHub.shared.spotifyChanged(state)
        WidgetBridge.shared.setNeedsUpdate()
    }

    /// Voert AppleScript uit op een eigen wachtrij (nooit de hoofdthread blokkeren).
    private func run(_ source: String, completion: @escaping @MainActor (String?) -> Void) {
        queue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let text = result?.stringValue
            let message: String? = error.map { e in
                let code = (e[NSAppleScript.errorNumber] as? Int) ?? 0
                return code == -1743
                    ? "Allow JoeToep to control Spotify in System Settings › Privacy & Security › Automation."
                    : ((e[NSAppleScript.errorMessage] as? String) ?? "Spotify did not respond.")
            }
            Task { @MainActor in
                self.problem = message
                completion(text)
            }
        }
    }
    #else
    /// iPhone/iPad: de toestand komt via sync van de Mac; niets zelf op te vragen.
    func refresh() {}
    #endif
}

extension Comparable {
    func clamped(_ low: Self, _ high: Self) -> Self { min(max(self, low), high) }
}

/// V20 — Muziekfuncties rond Spotify: automatisch pauzeren/zachter zetten als een video start
/// (en daarna hervatten), en een slaaptimer die alles na X minuten pauzeert.
@MainActor
final class SpotifyCoordinator: ObservableObject {
    static let shared = SpotifyCoordinator()
    enum VideoBehaviour: String, CaseIterable, Identifiable {
        case nothing, pause, duck
        var id: String { rawValue }
        var title: String {
            switch self {
            case .nothing: "Keep playing"
            case .pause: "Pause Spotify, resume after the video"
            case .duck: "Lower Spotify's volume during the video"
            }
        }
    }
    private static let d = UserDefaults.standard
    @Published var behaviourRaw: String = UserDefaults.standard.string(forKey: "spotifyVideoBehaviourV20") ?? VideoBehaviour.pause.rawValue {
        didSet { Self.d.set(behaviourRaw, forKey: "spotifyVideoBehaviourV20") } }
    @Published var duckPercent: Double = UserDefaults.standard.object(forKey: "spotifyDuckPercentV20") as? Double ?? 20 {
        didSet { Self.d.set(duckPercent, forKey: "spotifyDuckPercentV20") } }
    @Published var resumeAfterVideo: Bool = UserDefaults.standard.object(forKey: "spotifyResumeAfterVideoV20") as? Bool ?? true {
        didSet { Self.d.set(resumeAfterVideo, forKey: "spotifyResumeAfterVideoV20") } }
    var behaviour: VideoBehaviour { VideoBehaviour(rawValue: behaviourRaw) ?? .pause }

    /// Wat wij veranderd hebben (om het precies terug te zetten).
    private var pausedByUs = false
    private var volumeBeforeDuck: Double?
    private var resumeTask: Task<Void, Never>?

    func videoPlaybackChanged(anyPlaying: Bool) {
        let spotify = SpotifyController.shared
        resumeTask?.cancel()
        if anyPlaying {
            guard let s = spotify.local, s.running else { return }   // alleen Spotify op dít apparaat
            switch behaviour {
            case .nothing: break
            case .pause:
                if s.playing { pausedByUs = true; spotify.perform(.pause) }
            case .duck:
                if s.playing && volumeBeforeDuck == nil {
                    volumeBeforeDuck = s.volume
                    spotify.perform(.setVolume, value: min(s.volume, s.volume * duckPercent / 100))
                }
            }
        } else {
            // Even wachten: een korte pauze (buffering, volgende video) moet Spotify niet laten starten.
            resumeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                if let v = self.volumeBeforeDuck { spotify.perform(.setVolume, value: v); self.volumeBeforeDuck = nil }
                if self.pausedByUs {
                    self.pausedByUs = false
                    if self.resumeAfterVideo, spotify.current?.playing == false { spotify.perform(.play) }
                }
            }
        }
    }

    // MARK: Slaaptimer

    @Published private(set) var sleepEnds: Date?
    private var sleepTask: Task<Void, Never>?
    func startSleepTimer(minutes: Int) {
        sleepTask?.cancel()
        guard minutes > 0 else { sleepEnds = nil; return }
        let end = Date().addingTimeInterval(Double(minutes) * 60)
        sleepEnds = end
        sleepTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes) * 60))
            guard let self, !Task.isCancelled else { return }
            self.sleepEnds = nil
            self.pausedByUs = false
            MediaHub.shared.scan()
            SpotifyController.shared.perform(.pause)
            for ws in BrowserWorkspace.registry.allObjects {
                for tab in ws.tabs where tab.session.isPlaying {
                    tab.session.webView.evaluateJavaScript("(\(MediaHub.helpers))('pause')", completionHandler: nil)
                }
            }
        }
    }
    func cancelSleepTimer() { sleepTask?.cancel(); sleepEnds = nil }
}
