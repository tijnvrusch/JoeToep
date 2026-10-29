// V21 — Houdt de widgets up-to-date en voert widget-knoppen uit.
//
// Elke wijziging (tabs, wat er speelt, positie, andere apparaten via sync, Spotify, favorieten)
// → hooguit twee keer per seconde een nieuw JSON-bestand in de App Group + widgets opnieuw laten
// tekenen (gebundeld, zodat het systeem niet overspoeld wordt). Omdat de sync ook de toestand van
// je andere apparaten binnenhaalt, laten de widgets op elk apparaat hetzelfde zien.
import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()
    private var pending = false
    private var lastWritten: WidgetSnapshot?
    private var lastReload = Date.distantPast
    private var reloadQueued = false
    private var observers: Set<AnyCancellable> = []
    private(set) var lastWriteOK = true

    private init() {}

    private var started = false
    /// V22.2: veilig om vaker aan te roepen (app-delegate bij achtergrondstart én het venster);
    /// een latere aanroep verwerkt alleen nog de opdrachten die op een venster wachtten.
    func startOnce() { guard !started else { processQueuedCommands(); return }; started = true; start() }
    /// Eén keer bij het starten.
    func start() {
        // V22.2: nog geen venster (koude start via widget)? In de wachtrij; het venster pakt hem op.
        WidgetIntentRouter.handler = { command in Task { @MainActor in
            if BrowserWorkspace.registry.allObjects.isEmpty { WidgetShared.enqueue(command) }
            else { WidgetBridge.shared.perform(command) }
        } }
        BrowserLibrary.shared.objectWillChange
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.setNeedsUpdate() }
            .store(in: &observers)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            Task { @MainActor in WidgetBridge.shared.processQueuedCommands() }
        }, WidgetShared.commandNotification as CFString, nil, .deliverImmediately)
        processQueuedCommands()
        setNeedsUpdate()
    }

    /// Er is iets veranderd: binnen een halve seconde opnieuw schrijven (gebundeld).
    func setNeedsUpdate() {
        guard !pending else { return }
        pending = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self else { return }
            self.pending = false
            self.write()
        }
    }

    private func write() {
        let snapshot = makeSnapshot()
        #if os(iOS) && canImport(ActivityKit)
        LiveActivityManager.shared.update(from: snapshot)   // V22
        #endif
        #if os(iOS)
        WatchBridge.shared.setNeedsPush()                   // V22: Watch + complicaties live
        #endif
        // V22.2: `updated`/`time`/`position` veranderen bij elk bericht; de widgets rekenen de positie
        // zelf door (livePosition). Alleen schrijven + herladen bij een echte wijziging (titel, url,
        // spelen, apparaten, Spotify-nummer), een sprong in de positie (> 5 s), of hooguit elke 60 s
        // terwijl er iets speelt (live voortgang bijstellen).
        if let previous = lastWritten {
            let changed = Self.normalized(snapshot) != Self.normalized(previous) || Self.positionJumped(snapshot, from: previous)
            let periodic = snapshot.devices.contains(where: \.playing) && Date().timeIntervalSince(previous.updated) >= 60
            guard changed || periodic else { return }
        }
        lastWriteOK = WidgetShared.save(snapshot)
        lastWritten = snapshot
        reloadWidgets()
    }

    /// V22.2: kopie zonder de velden die elke tik veranderen.
    private static func normalized(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
        var s = snapshot; s.updated = .distantPast
        s.devices = s.devices.map { var d = $0; d.updated = nil; d.time = d.time == nil ? nil : 0; return d }
        if var sp = s.spotify { sp.position = 0; sp.updated = .distantPast; s.spotify = sp }
        return s
    }
    /// V22.2: wijkt de nieuwe positie > 5 s af van wat de widget zelf zou doorrekenen (spoelen)?
    private static func positionJumped(_ new: WidgetSnapshot, from old: WidgetSnapshot) -> Bool {
        func expected(_ time: Double, playing: Bool, from: Date?, to: Date?) -> Double {
            guard playing, let from, let to else { return time }
            return time + to.timeIntervalSince(from)
        }
        for d in new.devices {
            guard let t = d.time, let o = old.devices.first(where: { $0.id == d.id }), let ot = o.time else { continue }
            if abs(t - expected(ot, playing: o.playing, from: o.updated, to: d.updated)) > 5 { return true }
        }
        if let sp = new.spotify, let os = old.spotify,
           abs(sp.position - expected(os.position, playing: os.playing, from: os.updated, to: sp.updated)) > 5 { return true }
        return false
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        let since = Date().timeIntervalSince(lastReload)
        if since >= 1.0 {
            lastReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        } else if !reloadQueued {
            reloadQueued = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.0 - since))
                guard let self else { return }
                self.reloadQueued = false; self.lastReload = Date()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
    }

    // MARK: Snapshot opbouwen

    static var thisKind: String {
        #if os(macOS)
        return "mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
    }
    static func kind(forName name: String) -> String {
        let n = name.lowercased()
        if n.contains("mac") { return "mac" }
        if n.contains("ipad") { return "ipad" }
        return "iphone"
    }

    func makeSnapshot() -> WidgetSnapshot {
        let sync = TabSyncService.shared
        var s = WidgetSnapshot()
        s.thisDeviceID = sync.deviceID; s.thisDeviceName = sync.deviceName
        s.connectedPeers = sync.peers

        // Dit apparaat.
        let workspaces = BrowserWorkspace.registry.allObjects
        let allTabs = workspaces.flatMap(\.tabs).filter { !$0.isPrivate }
        let playing = allTabs.first { $0.session.isPlaying || $0.session.isInPictureInPicture }
        let focus = playing ?? BrowserWorkspace.active?.selected
        var me = WidgetDevice(id: sync.deviceID, name: sync.deviceName, kind: Self.thisKind, isThisDevice: true)
        if let focus, let url = focus.currentURL, NavigationPolicy.isPlaybackPage(url) || playing != nil {
            me.title = focus.fullTitle; me.url = url
            me.playing = playing != nil
            me.time = focus.session.resumePoint?.time
            me.duration = focus.session.resumePoint?.duration
            me.updated = Date()
        }
        me.tabCount = allTabs.count
        me.tabs = allTabs.prefix(10).compactMap { t in t.currentURL.map { WidgetLink(title: t.fullTitle, url: $0) } }
        s.devices.append(me)

        // Andere apparaten (wat de sync het laatst van ze hoorde).
        for (id, snap) in sync.latestByDevice where id != sync.deviceID {
            var d = WidgetDevice(id: id, name: snap.originName, kind: Self.kind(forName: snap.originName), isThisDevice: false)
            let tab = snap.playingID.flatMap { pid in snap.tabs.first { $0.id == pid } }
                ?? snap.handoffID.flatMap { hid in snap.tabs.first { $0.id == hid } }
                ?? snap.tabs.first { $0.id == snap.selectedID }
            if let tab, let url = tab.url {
                d.title = tab.title; d.url = url; d.time = tab.time; d.duration = tab.duration
                d.playing = snap.playingID == tab.id && sync.devices[id] != nil
                d.updated = snap.sentAt
            }
            d.tabCount = snap.tabs.count
            d.tabs = snap.tabs.prefix(10).compactMap { t in t.url.map { WidgetLink(title: t.title ?? $0.host ?? "Tab", url: $0) } }
            s.devices.append(d)
        }

        if let sp = SpotifyController.shared.current, sp.hasTrack {
            s.spotify = WidgetSpotify(deviceID: sp.deviceID, deviceName: sp.device, playing: sp.playing, track: sp.track, artist: sp.artist,
                                      artworkURL: sp.artworkURL, position: sp.position, duration: sp.duration, updated: sp.updated,
                                      album: sp.album, volume: sp.volume, shuffling: sp.shuffling, repeating: sp.repeating)
        }
        let lib = BrowserLibrary.shared
        s.favourites = lib.bookmarks.prefix(12).map { WidgetLink(title: $0.title, url: $0.url) }
        s.history = lib.history.prefix(12).map { WidgetLink(title: $0.title, url: $0.url) }
        s.continueWatching = lib.recentVideos(8).map { WidgetLink(title: $0.title, url: $0.url) }
        return s
    }

    // MARK: Opdrachten uit widgets

    func processQueuedCommands() {
        // V22.2: zonder venster (achtergrondstart) laten staan; startOnce() vanuit het venster pakt ze op.
        guard !BrowserWorkspace.registry.allObjects.isEmpty else { return }
        for command in WidgetShared.drain() { perform(command) }
    }

    func perform(_ command: WidgetCommand) {
        let sync = TabSyncService.shared
        let local = command.deviceID == nil || command.deviceID == sync.deviceID
        let workspace = BrowserWorkspace.active ?? BrowserWorkspace.registry.allObjects.first
        switch command.action {
        case .spotifyPlayPause: SpotifyController.shared.perform(.playPause)
        case .spotifyNext: SpotifyController.shared.perform(.next)
        case .spotifyPrevious: SpotifyController.shared.perform(.previous)
        case .open:
            if let url = command.url { workspace?.addTab(url: url) }
        case .takeOver:
            if let id = command.deviceID { workspace?.takeOverFrom(device: id) }
        case .continueOn:
            if let id = command.deviceID { workspace?.continuePlayback(on: id) }
        case .spotifyVolumeUp, .spotifyVolumeDown:
            let v = SpotifyController.shared.current?.volume ?? 50
            SpotifyController.shared.perform(.setVolume, value: min(100, max(0, v + (command.action == .spotifyVolumeUp ? 10 : -10))))
        case .pauseAll:
            MediaHub.shared.scan(); MediaHub.shared.pauseAll()
            for id in sync.devices.keys where sync.latestByDevice[id]?.playingID != nil {
                sync.send(SyncCommand(kind: .pause, target: id, url: nil, value: nil))   // V22.2: nooit per ongeluk starten
            }
        case .skipForward30, .skipBack30:
            let delta: Double = command.action == .skipForward30 ? 30 : -30
            if local { workspace?.mediaTab.session.remoteSeek(by: delta) }
            else if let target = command.deviceID { sync.send(SyncCommand(kind: .seek, target: target, url: nil, value: delta)) }
        case .playPause, .play, .pause, .skipForward, .skipBack:
            if local {
                guard let session = workspace?.mediaTab.session else { return }
                switch command.action {
                case .playPause: session.remoteToggle()
                case .play: session.remoteToggleIfPaused()
                case .pause: session.pauseForRemotePlayback()
                case .skipForward: session.remoteSeek(by: 10)
                case .skipBack: session.remoteSeek(by: -10)
                default: break
                }
            } else if let target = command.deviceID {
                switch command.action {
                case .skipForward: sync.send(SyncCommand(kind: .seek, target: target, url: nil, value: 10))
                case .skipBack: sync.send(SyncCommand(kind: .seek, target: target, url: nil, value: -10))
                case .pause: sync.send(SyncCommand(kind: .pause, target: target, url: nil, value: nil))   // V22.2
                default: sync.send(SyncCommand(kind: .toggle, target: target, url: nil, value: nil))
                }
            }
        }
        setNeedsUpdate()
    }
}
