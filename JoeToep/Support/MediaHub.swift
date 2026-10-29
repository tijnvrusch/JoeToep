// V20 — Mediacentrum: alle tabs met video/audio (spelend én gepauzeerd, in elk venster) plus
// Spotify, met play/pauze en volume per bron. Werkt voor YouTube, Twitch, Vimeo, SoundCloud,
// Spotify Web, … — alles wat een <video> of <audio> gebruikt.
import Foundation
import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#endif

struct MediaSourceState: Identifiable, Equatable {
    enum Kind: Equatable { case tab(UUID), spotify }
    var id: String
    var kind: Kind
    var title: String
    var subtitle: String
    var site: String
    var playing: Bool
    var volume: Double          // 0…1
    var muted: Bool
    var position: Double
    var duration: Double
    var artworkURL: URL?
    var isSelectedTab = false
}

@MainActor
final class MediaHub: ObservableObject {
    static let shared = MediaHub()
    @Published private(set) var sources: [MediaSourceState] = []
    @Published private(set) var isScanning = false

    private var tabStates: [UUID: MediaSourceState] = [:]
    private var pending = 0
    private var observing = 0
    private var ticker: Task<Void, Never>?

    /// Aantal spelende bronnen (voor het bolletje op de knop).
    var playingCount: Int { sources.filter(\.playing).count }

    // MARK: Waarnemen (alleen scannen terwijl het paneel open is)

    func beginObserving() {
        observing += 1
        SpotifyController.shared.beginObserving()
        guard ticker == nil else { return }
        scan(full: true)   // V22.2: bij het openen één keer álle tabs, daarna alleen de relevante
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1500))
                guard let self, self.observing > 0 else { return }
                #if os(iOS)
                // V22.2: op de achtergrond niet scannen (niemand kijkt; scheelt JS-aanroepen per tab).
                if UIApplication.shared.applicationState == .background { continue }
                #endif
                self.scan()
            }
        }
    }
    func endObserving() {
        observing = max(0, observing - 1)
        SpotifyController.shared.endObserving()
        if observing == 0 { ticker?.cancel(); ticker = nil }
    }

    private var allTabs: [(tab: BrowserTab, selected: Bool)] {
        BrowserWorkspace.registry.allObjects.flatMap { ws in ws.tabs.map { ($0, $0.id == ws.selectedID) } }
    }

    /// Vraagt elke geladen tab naar zijn media (één korte JS-aanroep per tab, parallel).
    /// V22.2: standaard alleen tabs die spelen, in PiP zijn, geselecteerd zijn of bij de vorige scan
    /// media hadden — niet elke geladen tab elke 1,5 s. `full` vraagt alle geladen tabs.
    func scan(full: Bool = false) {
        let tabs = allTabs
        let ids = Set(tabs.map(\.tab.id))
        tabStates = tabStates.filter { ids.contains($0.key) }
        let loaded = tabs.filter {
            $0.tab.session.currentURL != nil && (full || $0.selected || $0.tab.session.isPlaying ||
                $0.tab.session.isInPictureInPicture || tabStates[$0.tab.id] != nil)
        }
        for (tab, _) in tabs where tab.session.currentURL == nil { tabStates[tab.id] = nil }
        pending = loaded.count
        isScanning = pending > 0
        if pending == 0 { rebuild(); return }
        for (tab, selected) in loaded {
            tab.session.webView.evaluateJavaScript(Self.probeScript) { [weak self, weak tab] value, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.pending -= 1
                    if let tab {
                        if let text = value as? String, let data = text.data(using: .utf8),
                           let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let host = tab.currentURL?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
                            self.tabStates[tab.id] = MediaSourceState(
                                id: tab.id.uuidString, kind: .tab(tab.id),
                                title: (o["t"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? tab.fullTitle,
                                subtitle: (o["a"] as? String) ?? "",
                                site: Self.siteName(host), playing: (o["p"] as? Bool) ?? false,
                                volume: (o["v"] as? Double) ?? 1, muted: (o["m"] as? Bool) ?? false,
                                position: (o["c"] as? Double) ?? 0, duration: (o["d"] as? Double) ?? 0,
                                artworkURL: (o["i"] as? String).flatMap(URL.init(string:)), isSelectedTab: selected)
                        } else {
                            self.tabStates[tab.id] = nil
                        }
                    }
                    if self.pending <= 0 { self.isScanning = false }
                    // Meteen bijwerken: een achtergrondtab die nooit antwoordt mag de lijst niet ophouden.
                    self.rebuild()
                }
            }
        }
    }

    /// V24: nooit synchroon herbouwen vanuit SpotifyController (kan midden in diens `init` of
    /// `publish` zitten — her-intree gaf een crash). Meerdere wijzigingen → één herbouw.
    private var spotifyRebuildQueued = false
    func spotifyChanged(_ state: SpotifyState) {
        guard !spotifyRebuildQueued else { return }
        spotifyRebuildQueued = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.spotifyRebuildQueued = false
                self.rebuild()
            }
        }
    }

    private func rebuild() {
        var list = Array(tabStates.values)
        if let s = SpotifyController.shared.current, s.running {
            let where_ = SpotifyController.shared.isLocal ? "Spotify" : "Spotify · \(s.device)"
            list.append(MediaSourceState(id: "spotify", kind: .spotify, title: s.track.isEmpty ? "Spotify" : s.track,
                                         subtitle: s.artist, site: where_, playing: s.playing, volume: s.volume / 100,
                                         muted: false, position: s.livePosition(), duration: s.duration, artworkURL: s.artworkURL))
        }
        // Spelend eerst, dan Spotify, dan de rest op titel.
        list.sort { a, b in
            if a.playing != b.playing { return a.playing }
            if (a.kind == .spotify) != (b.kind == .spotify) { return a.kind == .spotify }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        if list != sources { sources = list }
    }

    // MARK: Bediening

    func toggle(_ source: MediaSourceState) {
        switch source.kind {
        case .spotify: SpotifyController.shared.perform(.playPause)
        case .tab(let id):
            guard let tab = tab(id) else { return }
            run(tab, source.playing ? "pause" : "play")
            update(id) { $0.playing.toggle() }
        }
    }
    /// Met één klik: deze bron spelen en alle andere pauzeren.
    func solo(_ source: MediaSourceState) {
        for other in sources where other.id != source.id && other.playing { pauseSource(other) }
        if !source.playing { toggle(source) }
    }
    /// V22.2: pauzeert ÉCHT alles — ook een video die net begon en nog niet in de (asynchrone) scan zit.
    func pauseAll() {
        sources.filter(\.playing).forEach(pauseSource)
        for (tab, _) in allTabs where tab.session.currentURL != nil {
            // V22.2: ook een lopend PiP-verzoek / startende native PiP telt als PiP.
            if tab.session.isPlaying || tab.session.isInPictureInPicture || tab.session.isPiPRequesting ||
                tab.session.isNativePiPStarting { tab.session.pauseForRemotePlayback() }
            run(tab, "pause")          // ook niet-YouTube-media (audio-elementen e.d.)
            update(tab.id) { $0.playing = false }
        }
        if SpotifyController.shared.current?.playing == true { SpotifyController.shared.perform(.pause) }
    }
    private func pauseSource(_ source: MediaSourceState) {
        switch source.kind {
        case .spotify: SpotifyController.shared.perform(.pause)
        case .tab(let id):
            if let tab = tab(id) { run(tab, "pause") }
            update(id) { $0.playing = false }
        }
    }
    func setVolume(_ source: MediaSourceState, _ value: Double) {
        switch source.kind {
        case .spotify: SpotifyController.shared.perform(.setVolume, value: (value * 100).rounded())
        case .tab(let id):
            guard let tab = tab(id) else { return }
            let v = value.clamped(0, 1)
            tab.session.webView.evaluateJavaScript("(\(Self.helpers))('volume',\(v))", completionHandler: nil)
            update(id) { $0.volume = v; $0.muted = v == 0 }
        }
    }
    func toggleMute(_ source: MediaSourceState) {
        guard case .tab(let id) = source.kind, let tab = tab(id) else {
            if source.kind == .spotify { setVolume(source, source.volume > 0 ? 0 : 0.5) }
            return
        }
        run(tab, "mute")
        update(id) { $0.muted.toggle() }
    }
    func skip(_ source: MediaSourceState, forward: Bool) {
        switch source.kind {
        case .spotify: SpotifyController.shared.perform(forward ? .next : .previous)
        case .tab(let id): if let tab = tab(id) { tab.session.webView.evaluateJavaScript("(\(Self.helpers))('skip',\(forward ? 10 : -10))", completionHandler: nil) }
        }
    }
    func show(_ source: MediaSourceState) {
        switch source.kind {
        case .spotify: SpotifyController.shared.perform(.launch)
        case .tab(let id):
            for ws in BrowserWorkspace.registry.allObjects {
                if let tab = ws.tabs.first(where: { $0.id == id }) { ws.select(tab); return }
            }
        }
    }

    private func tab(_ id: UUID) -> BrowserTab? { allTabs.first { $0.tab.id == id }?.tab }
    private func run(_ tab: BrowserTab, _ op: String) {
        tab.session.webView.evaluateJavaScript("(\(Self.helpers))('\(op)')", completionHandler: nil)
    }
    private func update(_ id: UUID, _ change: (inout MediaSourceState) -> Void) {
        guard var s = tabStates[id] else { return }
        change(&s); tabStates[id] = s; rebuild()
        // Echte toestand kort daarna opnieuw opvragen.
        Task { @MainActor [weak self] in try? await Task.sleep(for: .milliseconds(400)); self?.scan() }
    }

    static func siteName(_ host: String) -> String {
        let known = ["youtube.com": "YouTube", "m.youtube.com": "YouTube", "music.youtube.com": "YouTube Music",
                     "twitch.tv": "Twitch", "vimeo.com": "Vimeo", "soundcloud.com": "SoundCloud",
                     "open.spotify.com": "Spotify Web", "dailymotion.com": "Dailymotion"]
        return known[host] ?? host
    }

    // MARK: JavaScript

    /// Zoekt het belangrijkste media-element (spelend > langste). Geeft JSON of null.
    static let probeScript = #"""
    (()=>{try{
    const m=[...document.querySelectorAll('video,audio')].filter(e=>e.currentSrc||e.src||e.readyState>0||e.srcObject);
    if(!m.length)return null;
    const e=m.find(x=>!x.paused&&!x.ended)||m.slice().sort((a,b)=>(b.duration||0)-(a.duration||0))[0];
    const ms=navigator.mediaSession&&navigator.mediaSession.metadata;
    const art=ms&&ms.artwork&&ms.artwork.length?ms.artwork[ms.artwork.length-1].src:'';
    let t=ms&&ms.title||'',a=ms&&ms.artist||'';
    const yt=document.getElementById('movie_player');
    let vol=e.volume;if(yt&&yt.getVolume){try{vol=yt.getVolume()/100}catch(_){}}
    return JSON.stringify({p:!e.paused&&!e.ended,v:vol,m:e.muted,c:e.currentTime||0,d:isFinite(e.duration)?e.duration:0,t,a,i:art});
    }catch(_){return null}})()
    """#

    /// Bedient het media-element (en YouTube's eigen speler, zodat die zijn knoppen bijwerkt).
    static let helpers = #"""
    function(op,val){try{
    const m=[...document.querySelectorAll('video,audio')].filter(e=>e.currentSrc||e.src||e.readyState>0||e.srcObject);
    const e=m.find(x=>!x.paused&&!x.ended)||m.slice().sort((a,b)=>(b.duration||0)-(a.duration||0))[0];
    const yt=document.getElementById('movie_player');
    if(!e)return 0;
    if(op==='play'){e.play&&e.play().catch(()=>{});}
    else if(op==='pause'){m.forEach(x=>{try{x.pause()}catch(_){}});}
    else if(op==='mute'){e.muted=!e.muted;if(yt&&yt.isMuted){try{e.muted?yt.mute():yt.unMute()}catch(_){}}}
    else if(op==='volume'){const v=Math.max(0,Math.min(1,val));e.volume=v;e.muted=v===0;
      if(yt&&yt.setVolume){try{yt.setVolume(Math.round(v*100));v===0?yt.mute():yt.unMute()}catch(_){}}}
    else if(op==='skip'){e.currentTime=Math.max(0,(e.currentTime||0)+val);}
    }catch(_){}return 0}
    """#
}
