import SwiftUI
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class BrowserTab: ObservableObject, Identifiable {
    let id: UUID
    let session: WebSession
    let isPrivate: Bool
    /// Short (AI or heuristic) title shown in the tab; `fullTitle` is the complete page title.
    @Published private(set) var title: String
    @Published private(set) var fullTitle: String
    @Published var pinned: Bool
    /// V21: in welke tabgroep deze tab zit (nil = los).
    @Published var groupID: UUID?
    /// V18: er staat een wijziging van een ander apparaat klaar (stipje in de tab).
    @Published var syncPending = false
    var lastActive: Date
    /// V17: de tab waaruit deze tab geopend is (middelklik / "open in nieuwe tab"). Sluit je deze
    /// tab met "terug", dan ga je terug naar die tab. `UUID?` = mag leeg zijn (nil).
    var openerID: UUID?
    private var titleToken = UUID()
    private var observations: Set<AnyCancellable> = []
    init(saved: SavedBrowserTab = SavedBrowserTab(), privateMode: Bool = false) {
        id = saved.id; isPrivate = privateMode
        session = WebSession(privateMode: privateMode)
        lastActive = saved.lastActive ?? Date(); pinned = saved.pinned ?? false; groupID = saved.groupID
        let initial = saved.title ?? TabTitleSummarizer.fallbackTitle(for: saved.url)
        title = initial; fullTitle = initial
        session.restoredURL = saved.url
        session.restoredTime = saved.time; session.restoredPlaying = saved.playing ?? false
        session.$pageTitle.combineLatest(session.$currentURL)
            .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .sink { [weak self] title, url in self?.refreshTitle(pageTitle: title, url: url) }
            .store(in: &observations)
        if saved.title == nil, let url = saved.url, NavigationPolicy.isPlaybackPage(url) {
            // Background tabs load only when opened; show the real video title right away.
            Task { @MainActor [weak self] in
                guard let title = await Self.oEmbedTitle(for: url), let self, self.session.pageTitle == nil else { return }
                self.refreshTitle(pageTitle: title, url: url)
            }
        }
        NotificationCenter.default.publisher(for: TabTitleSummarizer.didChange)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshTitle(pageTitle: self.session.pageTitle, url: self.session.currentURL)
            }.store(in: &observations)
    }
    private func refreshTitle(pageTitle: String?, url: URL?) {
        guard url != nil || pageTitle != nil else { return }
        let token = UUID(); titleToken = token
        fullTitle = TabTitleSummarizer.cleanPageTitle(pageTitle, url: url)
        let value = TabTitleSummarizer.displayTitle(pageTitle: pageTitle, url: url) { [weak self] smart in
            guard let self, self.titleToken == token else { return }
            self.title = smart
        }
        if title != value { title = value }
    }
    var currentURL: URL? { session.currentURL ?? session.restoredURL }
    /// YouTube's public oEmbed endpoint returns a video's title without loading the player.
    nonisolated static func oEmbedTitle(for url: URL) async -> String? {
        var parts = URLComponents(string: "https://www.youtube.com/oembed")
        parts?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString), URLQueryItem(name: "format", value: "json")]
        guard let endpoint = parts?.url,
              let result = try? await URLSession.shared.data(for: URLRequest(url: endpoint, timeoutInterval: 6)),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let title = object["title"] as? String, !title.isEmpty else { return nil }
        return title
    }
}

@MainActor
final class BrowserWorkspace: ObservableObject {
    @Published private(set) var tabs: [BrowserTab]
    @Published var selectedID: UUID
    @Published private(set) var closedTabs: [SavedBrowserTab] = []
    /// V16: most-recently-used order for Ctrl+Tab.
    private var recent: [UUID] = []
    private var playbackObservers: [UUID: AnyCancellable] = [:]
    private var urlObservers: [UUID: AnyCancellable] = [:]
    private var resumeObservers: [UUID: AnyCancellable] = [:]
    private var titleObservers: [UUID: AnyCancellable] = [:]
    static var defaultStore: TabSessionStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return TabSessionStore(defaults: UserDefaults(suiteName: "nl.tijn.joetoep.ui-tabs")!)
        }
        #endif
        return .shared
    }
    private let windowID = UUID()
    /// V22.3: dit venster wordt gesloten (niet bij afsluiten van de app): tabs van dit venster vergeten.
    func windowClosed() {
        // Even wachten: bij ⌘Q sluiten ook alle vensters, maar dan stopt het proces binnen die tijd.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            #if os(macOS)
            guard !Self.appTerminating else { return }
            #endif
            guard !isClosed else { return }
            let others = Self.registry.allObjects.filter { $0 !== self && !$0.isClosed }
            TabSyncService.shared.note("window closed: \(tabs.count) tabs, \(others.count) other window(s)")
            let wasOwner = TabSyncService.shared.owner === self
            for tab in tabs where tab.session.isPlaying || tab.session.isInPictureInPicture { tab.session.stopPiPAndPause() }
            isClosed = true
            playbackObservers = [:]; urlObservers = [:]; resumeObservers = [:]; titleObservers = [:]
            expiryTask?.cancel(); resumePersistTask?.cancel()
            Self.registry.remove(self)
            guard let next = others.first else {
                // Laatste venster: tabs blijven bewaard; een nieuw venster (Dock) mag ze opnieuw ophalen.
                store.releaseWindows()
                if wasOwner { TabSyncService.shared.owner = nil }
                return
            }
            if wasOwner {
                // Het hoofdvenster sloot: zijn tabs verhuizen naar het volgende venster (niets kwijt, ook niet
                // op je andere apparaten), en dat venster neemt de sync over.
                next.adopt(tabs.filter { !$0.isPrivate }.map { Self.saved($0) })
                store.forget(window: windowID)
                TabSyncService.shared.owner = nil
                next.reclaimSync()
            } else {
                store.forget(window: windowID)
            }
        }
    }
    private(set) var isClosed = false
    /// V22.3: tabs uit een gesloten hoofdvenster overnemen (achteraan, gepauzeerd).
    func adopt(_ saved: [SavedBrowserTab]) {
        let known = Set(tabs.map(\.id))
        for item in saved where !known.contains(item.id) {
            let tab = BrowserTab(saved: item); tabs.append(tab); observe(tab)
        }
        persist()
    }
    #if os(macOS)
    static var appTerminating = false
    #endif
    /// V22.3: het sync-venster sloot → het volgende venster neemt de sync over.
    func reclaimSync() { claimSync(); publishSync() }
    private let store: TabSessionStore
    var selected: BrowserTab { tabs.first(where: { $0.id == selectedID }) ?? tabs[0] }
    var selectedIndex: Int { tabs.firstIndex(where: { $0.id == selectedID }) ?? 0 }
    init(store suppliedStore: TabSessionStore? = nil) {
        let store = suppliedStore ?? Self.defaultStore
        self.store = store
        _ = LaunchPrefs.started
        if let saved = store.restore(lifetime: TabLifetime.stored().seconds) {
            tabs = saved.tabs.map { BrowserTab(saved: $0) }; selectedID = saved.selectedID
        } else {
            let first = BrowserTab(); tabs = [first]; selectedID = first.id
        }
        tabs.forEach(observe)
        claimSync()
        persist()
        startExpiryChecks()
        Self.registry.add(self)
    }
    private var expiryTask: Task<Void, Never>?
    /// V13: close tabs that have been inactive longer than the chosen lifetime (never pinned tabs).
    private func startExpiryChecks() {
        expiryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled, let self else { break }
                self.closeExpiredTabs()
            }
        }
    }
    func closeExpiredTabs(now: Date = Date()) {
        let lifetime = TabLifetime.stored().seconds
        selected.lastActive = now
        let expired = tabs.filter {
            $0.id != selectedID && !$0.pinned && !$0.session.isPlaying && !$0.session.isInPictureInPicture &&
                now.timeIntervalSince($0.lastActive) > lifetime
        }
        batching { for tab in expired where tabs.count > 1 { close(tab, remember: false) } }   // V22.2
    }
    private func persist() {
        guard !isClosed else { return }   // V22.3: gesloten venster schrijft zich niet terug
        // V22.2: tijdens een batch (meerdere tabs sluiten) pas aan het eind één keer opslaan.
        if batchDepth > 0 { batchNeedsPersist = true; return }
        resumePersistTask?.cancel(); resumePersistTask = nil   // V22.2: volledige opslag dekt de positie al
        let kept = tabs.filter { !$0.isPrivate }
        guard !kept.isEmpty else { return }
        let selection = kept.contains(where: { $0.id == selectedID }) ? selectedID : kept[0].id
        store.save(SavedTabSession(tabs: kept.map { Self.saved($0) }, selectedID: selection), window: windowID)
        publishSync()
    }

    // MARK: V18 — live tab-sync

    /// true terwijl een snapshot van een ander apparaat wordt toegepast (dan niets terugsturen).
    private var applyingRemote = false
    private var syncPublishQueued = false

    /// Alleen het eerste venster (werkruimte) synchroniseert; extra Mac-vensters blijven lokaal.
    private func claimSync() {
        let sync = TabSyncService.shared
        guard sync.owner == nil else { return }
        sync.owner = self
        sync.onSnapshot = { [weak self] snapshot, merge in self?.applyRemote(snapshot, merge: merge) }
        sync.onCommand = { [weak self] command in self?.perform(command) }
        sync.onPlaybackState = { [weak self] snapshot in self?.notePlayback(from: snapshot) }
        sync.onMergeOnly = { [weak self] snapshot in self?.mergeMissing(from: snapshot) }
        sync.onPeerDisconnected = { [weak self] device in self?.peerDisconnected(device) }
    }

    /// V22.2: apparaat weg → zijn LOPENDE video is niet meer over te nemen (geschatte tijd klopt niet,
    /// het pauzeert niet op ons verzoek). Een overdracht na achtergrond (gepauzeerd, exacte tijd) blijft.
    func peerDisconnected(_ device: String) {
        if let r = remotePlayback, r.device == device, !r.paused { remotePlayback = nil }
        massGuardOrigins.remove(device)
        lastRemoteSelection[device] = nil   // V22.3: eerste snapshot na herverbinden is geen tabwissel
    }
    private var massGuardOrigins: Set<String> = []
    /// V22.3: een ander apparaat hield een oudere versie van ONZE toestand met een hoger nummer vast →
    /// opnieuw (geforceerd) publiceren, zodat onze huidige toestand weer wint.
    func forceRepublish() { forceNextPublish = true; publishSync() }

    /// V19.1 — Apparaatwissel: begin je hier een video die op een ander apparaat nog speelt
    /// (of daar net stopte), dan vragen we dat apparaat om te pauzeren en zijn EXACTE tijd te
    /// sturen; die springen we dan in (±0,1 s, zoals AirPods-overdracht).
    func requestDeviceHandoff(for tab: BrowserTab) {
        guard let url = tab.currentURL, NavigationPolicy.isPlaybackPage(url) else { return }
        // V21: net zelf overgenomen? Dan loopt die aanvraag al.
        if let deadline = awaitingHandoff[url.absoluteString], deadline > Date() { return }
        let sync = TabSyncService.shared
        for (device, snapshot) in sync.latestByDevice where device != sync.deviceID {
            guard let remoteTab = snapshot.tabs.first(where: { SyncDiff.sameDestination($0.url, url) }) else { continue }
            // Alleen als die video daar NU speelt, of daar in de laatste 30 s nog speelde/stopte.
            // (Anders zou een oude pauze je terugzetten naar een tijd die je niet meer wilt.)
            let playingThere = snapshot.playingID == remoteTab.id
            guard playingThere || Date().timeIntervalSince(snapshot.sentAt) < 30 else { continue }
            sync.send(SyncCommand(kind: .handoffRequest, target: device, url: url, value: nil, from: sync.deviceID))
        }
    }

    /// Tab die "de" video heeft: de spelende, anders de geselecteerde.
    var mediaTab: BrowserTab { tabs.first { $0.session.isPlaying || $0.session.isInPictureInPicture } ?? selected }

    /// Opdracht van de Apple Watch (rechtstreeks, of via de iPhone doorgestuurd naar dit apparaat).
    func perform(_ command: SyncCommand) {
        switch command.kind {
        case .play, .open:
            guard let url = command.url else { return }
            // Staat de video al in een tab? Dan die tab tonen en afspelen; anders een nieuwe tab.
            if let existing = tabs.first(where: { SyncDiff.sameDestination($0.currentURL, url) }) {
                select(existing)
                existing.session.remoteToggleIfPaused()
            } else {
                addTab(url: url, activate: true, after: selected)
            }
        case .toggle: mediaTab.session.remoteToggle()
        case .pause: tabs.forEach { $0.session.pauseForRemotePlayback() }
        case .seek: mediaTab.session.remoteSeek(by: command.value ?? 10)
        case .rate: mediaTab.session.stepPlaybackRate(Int(command.value ?? 1))
        case .continueThere:
            // V21: het andere apparaat duwt zijn video naar ons: meteen verder spelen op die tijd.
            guard let url = command.url else { return }
            let tab = tabs.first { SyncDiff.sameDestination($0.currentURL, url) }
            let target: BrowserTab
            if let tab { target = tab } else { addTab(url: url, activate: true, after: selected); target = selected }
            if target.id != selectedID { selected.session.leaveFullscreenForTabSwitch(); select(target) }
            remotePlayback = nil
            ignoreRemoteSelectionUntil = Date().addingTimeInterval(6); pendingSelection = nil
            target.session.takeOverPlayback(url: url, time: (command.value ?? 0) + HandoffPrefs.latencyCompensation)
            TabSyncService.shared.noteHandoff("continued from \(TabSyncService.shared.devices[command.from ?? ""] ?? "device")")
        case .continueOn:
            // V22.2: Watch "verplaats naar": hier pauzeren en met de exacte tijd verder op `to`.
            guard let to = command.to, to != TabSyncService.shared.deviceID else { return }
            let tab = command.url.flatMap { url in tabs.first { SyncDiff.sameDestination($0.currentURL, url) } } ?? mediaTab
            continuePlayback(of: tab, on: to)
        case .handoffRequest:
            // Een ander apparaat neemt het over: hier pauzeren en de exacte tijd terugsturen.
            guard let from = command.from else { return }
            // V22.2: alleen de tab met DEZE video — nooit een andere video pauzeren of zijn tijd terugsturen.
            guard let tab = tabs.first(where: { SyncDiff.sameDestination($0.currentURL, command.url) && ($0.session.isPlaying || $0.session.isInPictureInPicture) })
                    ?? tabs.first(where: { SyncDiff.sameDestination($0.currentURL, command.url) }) else { return }
            let url = command.url
            tab.session.pauseAndReportTime { time in
                guard let time else { return }
                TabSyncService.shared.send(SyncCommand(kind: .handoffTime, target: from, url: url, value: time,
                                                       from: TabSyncService.shared.deviceID))
            }
            // V22.1: ook als PiP net (automatisch) aanging bij het wisselen: altijd sluiten, geen placeholder laten staan.
            tab.session.stopPiPAndPause()
        case .handoffTime:
            // Antwoord: spring naar precies waar het andere apparaat stopte.
            guard let time = command.value,
                  let tab = tabs.first(where: { SyncDiff.sameDestination($0.currentURL, command.url) }) else { return }
            if let key = command.url?.absoluteString, let deadline = awaitingHandoff[key], deadline > Date() {
                // V21: wij speelden al (overgenomen) → alleen corrigeren als het echt verschilt.
                tab.session.correctPosition(time + HandoffPrefs.latencyCompensation)
                TabSyncService.shared.noteHandoff("exact time \(String(format: "%.2f", time)) s")
            } else {
                tab.session.seekExact(time)
            }
        }
    }

    /// Stuurt de huidige tabs naar de andere apparaten (op de volgende runloop-beurt, gebundeld:
    /// tien wijzigingen in één klap = één bericht).
    func publishSync() {
        claimSync()
        guard !applyingRemote, TabSyncService.shared.owner === self, !syncPublishQueued else { return }
        syncPublishQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncPublishQueued = false
            guard !self.applyingRemote else { return }
            let kept = self.tabs.filter { !$0.isPrivate }
            guard !kept.isEmpty else { return }
            let tabs = kept.map { tab -> SyncTab in
                let saved = Self.saved(tab)
                // V22.2: nog niet toegepaste wijzigingen van een ander apparaat doorgeven als de afgesproken
                // stand (anders stuurden we de oude pagina/tijd terug met een nieuwer versienummer).
                let pending = self.pendingNavigation[tab.id]
                let position = tab.session.isPlaying ? nil : self.pendingPosition[tab.id]
                let time: Double? = pending != nil ? (pending?.time ?? position) : (position ?? saved.time)
                return SyncTab(id: tab.id, url: pending?.url ?? saved.url, title: tab.fullTitle, pinned: tab.pinned, time: time,
                              duration: tab.session.resumePoint?.duration, active: tab.lastActive.timeIntervalSince1970)
            }
            let current = kept.contains(where: { $0.id == self.selectedID }) ? self.selectedID : kept[0].id
            // V22.2: uitgestelde selectie van het andere apparaat telt ook als selectie (geen echo van de oude).
            let selection = self.pendingSelection.flatMap { id in kept.contains { $0.id == id } ? id : nil } ?? current
            let playing = kept.first { $0.session.isPlaying }?.id
            let handoff = self.localHandoff.flatMap { h in kept.contains { $0.id == h.id } ? h : nil }
            TabSyncService.shared.publish(tabs: tabs, selectedID: selection, playingID: playing, handoff: handoff,
                                          closed: SyncRules.recentTombstones(Self.closedSyncTombstones),
                                          playStamp: playing == nil ? nil : self.localPlayStamp,
                                          handoffNonce: self.localHandoffNonce,
                                          force: self.forceNextPublish)
            self.forceNextPublish = false
        }
    }

    /// V22: speelde hier iets toen dit apparaat naar de achtergrond ging? Dan geven we die tab + exacte
    /// tijd door, zodat het apparaat dat je nu pakt precies daar verder speelt (iPhone pauzeert zelf).
    private var localHandoff: (id: UUID, time: Double)?
    /// V22.2: één nonce per prepareDeviceSwitch (de twee publicaties — schatting, dan exacte tijd — horen bij elkaar).
    private var localHandoffNonce: String?
    /// V22.2: klokwaarde waarop hier de huidige video begon (voorrang bij twee apparaten die tegelijk spelen).
    private var localPlayStamp: UInt64 = 0
    /// V22.2: grafstenen met tijdstip (id → s sinds 1970) — dezelfde opslag als closedSyncIDs.
    static var closedSyncTombstones: [String: Double] {
        UserDefaults.standard.dictionary(forKey: "closedSyncIDsV22") as? [String: Double] ?? [:]
    }
    private var forceNextPublish = false
    func prepareDeviceSwitch() {
        guard let tab = tabs.first(where: { !$0.isPrivate && ($0.session.isPlaying || $0.session.isInPictureInPicture) }) else { return }
        let fallback = tab.session.resumePoint?.time ?? 0
        localHandoff = (tab.id, fallback); localHandoffNonce = UUID().uuidString
        forceNextPublish = true; publishSync()
        // Exacte tijd uit de pagina (binnen enkele ms) en meteen nog een keer versturen.
        tab.session.webView.evaluateJavaScript("(()=>{const p=document.getElementById('movie_player');const v=document.querySelector('video.html5-main-video')||document.querySelector('video');return p&&p.getCurrentTime?Number(p.getCurrentTime()):(v?v.currentTime:-1)})()") { [weak self] value, _ in
            Task { @MainActor in
                guard let self, let t = value as? Double, t >= 0, self.localHandoff?.id == tab.id else { return }
                self.localHandoff = (tab.id, t)
                self.forceNextPublish = true; self.publishSync()
            }
        }
    }
    /// Dit apparaat wordt weer gebruikt: de open overdracht vervalt.
    func clearDeviceSwitch() {
        guard localHandoff != nil else { return }
        localHandoff = nil; forceNextPublish = true; publishSync()
    }

    /// V22.2: per apparaat het laatst ontvangen tijdstip (sentAt), zodat een oud bericht de stand niet terugdraait.
    private var playbackSeenAt: [String: Date] = [:]
    /// V22.2: wat speelt het andere apparaat? Ook bijgewerkt uit snapshots die de tab-vergelijking verloren
    /// (anders bleef een pauze daar onopgemerkt en nam dit apparaat later op een verkeerde tijd over).
    func notePlayback(from snapshot: SyncSnapshot) {
        guard snapshot.origin != TabSyncService.shared.deviceID else { return }   // V22.3: nooit onze eigen oude stand
        if let seen = playbackSeenAt[snapshot.origin], snapshot.sentAt < seen { return }
        playbackSeenAt[snapshot.origin] = snapshot.sentAt
        // V21: onthoud wat het andere apparaat NU speelt (voor automatisch overnemen bij wisselen).
        if let playing = snapshot.playingID, let remote = snapshot.tabs.first(where: { $0.id == playing }), let url = remote.url {
            remotePlayback = RemotePlayback(device: snapshot.origin, tabID: playing, url: url, time: remote.time ?? 0, receivedAt: Date())
        } else if let hid = snapshot.handoffID, let remote = snapshot.tabs.first(where: { $0.id == hid }), let url = remote.url,
                  case let key = SyncRules.handoffKey(origin: snapshot.origin, tab: hid, nonce: snapshot.handoffNonce),   // V22.2: met nonce
                  !Self.consumedHandoffs.contains(key) {
            // V22: het andere apparaat ging naar de achtergrond terwijl dit speelde → hier verder, exact op die tijd.
            remotePlayback = RemotePlayback(device: snapshot.origin, tabID: hid, url: url,
                                            time: snapshot.handoffTime ?? remote.time ?? 0, receivedAt: Date(), paused: true,
                                            handoffKey: key)
        } else if remotePlayback?.device == snapshot.origin {
            remotePlayback = nil          // daar gepauzeerd/gestopt → niets over te nemen
            if sentAway?.device == snapshot.origin { sentAway = nil }
        }
    }

    /// Past de tabs van een ander apparaat hier toe: nieuwe tabs erbij, gesloten tabs weg,
    /// dezelfde volgorde en selectie, en de video op dezelfde plek.
    func applyRemote(_ snapshot: SyncSnapshot, merge: Bool = false) {
        applyingRemote = true
        // V22.2: ook terugsturen als we tabs weigerden (grafsteen) of zelf sloten, zodat de afzender ze ook kwijtraakt.
        var republish = merge
        defer {
            applyingRemote = false; persistWithoutSync()
            // Samengevoegd? Dan heeft dit apparaat nu méér dan de afzender: dat terugsturen,
            // zodat iedereen op dezelfde (volledige) lijst uitkomt.
            if republish { publishSync() }
        }
        notePlayback(from: snapshot)
        // 1. Speelt het andere apparaat? Dan stoppen we hier (één apparaat tegelijk).
        //    V22.2: alleen als het daar LATER begon dan hier (anders pauzeerde een oude stand de nieuwste keuze).
        if snapshot.playingID != nil, SyncRules.remotePlayWins(remote: snapshot.playStamp, local: localPlayStamp) {
            // V22.2: in álle vensters (extra Mac-vensters doen niet mee aan de sync, maar spelen wel geluid af).
            for workspace in Self.registry.allObjects {
                for tab in workspace.tabs where tab.session.isPlaying || tab.session.isInPictureInPicture { tab.session.pauseForRemotePlayback() }
            }
        }
        let locals = tabs.filter { !$0.isPrivate }
        let diff = SyncDiff.plan(local: locals.map { ($0.id, $0.currentURL) }, remote: snapshot.tabs)
        // 2. Nieuwe tabs (eerst toevoegen, zodat er nooit nul tabs zijn).
        // V22.2: nooit tabs terugbrengen die hier of op de afzender gesloten zijn (en daarna niet meer actief
        // waren) — ook niet bij gewoon gelijktrekken (kruisende berichten).
        let stones = SyncRules.recentTombstones(Self.closedSyncTombstones)   // V22.3: zelfde set als wat we versturen
        for remote in diff.add {
            if SyncRules.blocks(remote, local: stones, remote: snapshot.closed) { republish = true; continue }
            addSyncedTab(remote)
        }
        // V22.2: bij samenvoegen ook tabs sluiten die de afzender sloot ná hun laatste gebruik hier.
        if merge {
            for tab in locals where !tab.session.isPlaying && SyncRules.shouldClose(tab.id, lastActive: tab.lastActive, remote: snapshot.closed) {
                guard tabs.contains(where: { $0.id == tab.id }), tabs.count > 1 else { continue }
                close(tab, remember: false)
            }
        }
        // 3. Andere pagina in een bestaande tab: NIET meteen laden (je kijkt nu op het andere
        //    apparaat en wilt hier geen beelden zien). Pas toepassen als je dit apparaat weer
        //    gebruikt (klik/toets/aanraking, app actief, of die tab kiezen).
        //    V22.2: opnieuw opbouwen uit DEZE snapshot (inmiddels gelijke/vervallen wijzigingen weg).
        pendingNavigation = [:]
        for change in diff.navigate {
            pendingNavigation[change.id] = (change.url, snapshot.tabs.first { $0.id == change.id }?.time)
        }
        // 4. Gesloten tabs (niet onthouden in "heropen": dat deed het andere apparaat al).
        // V22.3: veel tabs tegelijk weg (≥ 8 én meer dan de helft)? Alleen sluiten wat de afzender ook
        // echt als gesloten meldt (grafsteen). Een snapshot zonder die bewijslast (oude/andere build,
        // leeg opgestart apparaat) kan zo nooit in één klap al je tabs wegvagen; "sluit andere tabs"
        // op een ander apparaat werkt gewoon (dat stuurt grafstenen mee).
        let massRemoval = diff.remove.count >= 8 && diff.remove.count * 2 > locals.count
        for id in diff.remove where !merge {
            guard let tab = tabs.first(where: { $0.id == id }), tabs.count > 1 else { continue }
            if massRemoval, !SyncRules.shouldClose(id, lastActive: tab.lastActive, remote: snapshot.closed) {
                // Hooguit één keer per apparaat per verbinding terugsturen (nooit een eindeloos pingpongen).
                if massGuardOrigins.insert(snapshot.origin).inserted { republish = true }
                continue
            }
            close(tab, remember: false)
        }
        if massRemoval { TabSyncService.shared.note("mass close from \(snapshot.originName): only tombstoned tabs closed") }
        // 5. Vastpinnen + volgorde (privé-tabs blijven achteraan staan).
        for remote in snapshot.tabs { tabs.first { $0.id == remote.id }?.pinned = remote.pinned }
        let order = Dictionary(uniqueKeysWithValues: diff.order.enumerated().map { ($1, $0) })
        let sorted = tabs.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        if sorted.map(\.id) != tabs.map(\.id) { tabs = sorted }
        // 6. Afspeelpositie onthouden (ook pas toepassen bij terugkomst).
        //    V22.2: opnieuw opbouwen; alleen echte verschillen, en niet voor de video die hier speelt.
        pendingPosition = [:]
        for remote in snapshot.tabs {
            guard let time = remote.time, let tab = tabs.first(where: { $0.id == remote.id }), !tab.session.isPlaying else { continue }
            if pendingNavigation[remote.id] == nil, let local = Self.saved(tab).time, abs(local - time) < 2 { continue }
            pendingPosition[remote.id] = time
        }
        // 7. Selectie: onthouden, toepassen zodra je hier weer verder gaat.
        //    V21: vlak na een overname niet (dat is de "echo" van het apparaat dat net stopte).
        //    V22.2: telkens opnieuw bepalen (een oude, inmiddels gelijke selectie vervalt).
        let wantsSelection = snapshot.selectedID != selectedID && tabs.contains(where: { $0.id == snapshot.selectedID })
        // V22.3: alleen als je op dát apparaat echt van tab wisselde. De eerste snapshot na (her)verbinden of
        // een herstart daar is geen keuze van jou — anders sprong deze Mac/iPad bij terugkomen naar de tab
        // die het andere apparaat toevallig bij het opstarten open had.
        if merge { lastRemoteSelection[snapshot.origin] = nil }
        let previousRemote = lastRemoteSelection[snapshot.origin]
        lastRemoteSelection[snapshot.origin] = snapshot.selectedID
        let remoteSwitched = previousRemote != nil && previousRemote != snapshot.selectedID
        if remoteSwitched {
            pendingSelection = wantsSelection && Date() >= ignoreRemoteSelectionUntil ? snapshot.selectedID : nil
        } else if pendingSelection != snapshot.selectedID || !wantsSelection {
            pendingSelection = nil
        }
        tabs.forEach { $0.syncPending = pendingNavigation[$0.id] != nil }
    }

    /// V22.2: tab van een ander apparaat toevoegen (gepauzeerd, laadt pas als je hem opent).
    private func addSyncedTab(_ remote: SyncTab) {
        let tab = BrowserTab(saved: SavedBrowserTab(id: remote.id, url: remote.url, time: remote.time, playing: false,
                                                    lastActive: remote.active.map { Date(timeIntervalSince1970: $0) } ?? Date(),
                                                    pinned: remote.pinned ? true : nil, title: remote.title))
        tab.session.syncedStartPaused = true
        tab.session.holdQuiet(20)
        tabs.append(tab); observe(tab)
    }

    /// V22.2: eerste snapshot na (her)verbinden verloor de versie-vergelijking (bijv. het andere apparaat
    /// sliep met een oude lijst): toch zijn unieke, niet-gesloten tabs toevoegen en daarna onze lijst delen,
    /// zodat geen van beide kanten tabs verliest. Volgorde/selectie/pagina's blijven van de nieuwste.
    func mergeMissing(from snapshot: SyncSnapshot) {
        let known = Set(tabs.map(\.id))
        let stones = SyncRules.recentTombstones(Self.closedSyncTombstones)   // V22.3: zelfde set als wat we versturen
        let extra = snapshot.tabs.filter { !known.contains($0.id) && !SyncRules.blocks($0, local: stones, remote: snapshot.closed) }
        let stale = tabs.filter { !$0.isPrivate && !$0.session.isPlaying &&
            SyncRules.shouldClose($0.id, lastActive: $0.lastActive, remote: snapshot.closed) }
        guard !extra.isEmpty || !stale.isEmpty else { return }
        applyingRemote = true
        for remote in extra { addSyncedTab(remote) }
        for tab in stale where tabs.count > 1 && tabs.contains(where: { $0.id == tab.id }) { close(tab, remember: false) }
        applyingRemote = false
        persistWithoutSync(); publishSync()
    }

    // MARK: V21 — automatisch overnemen bij wisselen van apparaat

    enum SwitchTrigger { case appActivated, interaction, tabSelection }
    struct RemotePlayback: Equatable {
        var device: String, tabID: UUID, url: URL, time: Double, receivedAt: Date
        /// V22: daar staat hij stil (overdracht na achtergrond) → exact deze tijd, niet doorrekenen.
        var paused = false
        /// V22: sleutel van de overdracht (één keer overnemen, ook niet opnieuw na een herstart).
        var handoffKey: String? = nil
        /// Geschatte positie nu: laatste bekende tijd + hoe lang geleden (de video liep door).
        func estimatedTime(at now: Date = Date()) -> Double { paused ? time : time + max(0, now.timeIntervalSince(receivedAt)) }
    }
    private(set) var remotePlayback: RemotePlayback?
    private var lastLocalInteraction = Date.distantPast
    private var waitingForPeers = false
    /// V22.2: de wacht-op-apparaat-ronde is net gedaan (de herhaalde aanroep wacht niet nog eens).
    private var peerWaitDone = false
    /// V21: na een overname even geen selectie van het andere apparaat overnemen.
    private var ignoreRemoteSelectionUntil = Date.distantPast
    /// V21: bewust naar een ander apparaat gestuurd → daar niet automatisch weer vandaan pakken.
    private var sentAway: (device: String, url: URL, until: Date)?
    /// url → deadline: wachten we op de exacte tijd van het andere apparaat?
    private var awaitingHandoff: [String: Date] = [:]

    /// V21: "Verder op <apparaat>": de video van deze tab daar laten doorspelen (exacte tijd) en hier pauzeren.
    func continuePlayback(of tab: BrowserTab? = nil, on device: String) {
        let tab = tab ?? mediaTab
        guard let url = tab.currentURL else { return }
        sentAway = (device, url, Date().addingTimeInterval(1800))
        let sync = TabSyncService.shared
        tab.session.pauseAndReportTime { time in
            sync.send(SyncCommand(kind: .continueThere, target: device, url: url, value: time ?? tab.session.resumePoint?.time ?? 0,
                                  from: sync.deviceID))
            sync.noteHandoff("sent to \(sync.devices[device] ?? "device") at \(String(format: "%.1f", time ?? 0)) s")
        }
        if tab.session.isInPictureInPicture { tab.session.stopPiPAndPause() }
        // V22.3: neemt het andere apparaat het niet binnen 8 s over (scherm op slot, app op de achtergrond,
        // verbinding weg)? Dan hier gewoon verder spelen in plaats van dat de muziek stil blijft.
        let name = sync.devices[device] ?? "The other device"
        Task { @MainActor [weak self, weak tab] in
            // Elke seconde kijken: zag het andere apparaat deze video ook maar even spelen, dan is het gelukt
            // (ook als je hem daar daarna pauzeerde).
            var tookOver = false
            for _ in 0..<8 {
                try? await Task.sleep(for: .seconds(1))
                let snap = TabSyncService.shared.latestByDevice[device]
                if snap.flatMap({ s in s.playingID.flatMap { id in s.tabs.first { $0.id == id } } })
                    .map({ SyncDiff.sameDestination($0.url, url) }) == true { tookOver = true; break }
            }
            guard !tookOver, let self, let tab, self.sentAway?.device == device else { return }
            guard !self.tabs.contains(where: { $0.session.isPlaying || $0.session.isInPictureInPicture }),
                  SyncDiff.sameDestination(tab.currentURL, url) else { return }
            self.sentAway = nil
            tab.session.remoteToggleIfPaused()
            TabSyncService.shared.noteHandoff("no answer from \(name) — continuing here")
            tab.session.showNotice(.information, "\(name) didn't take over", "The video continues here.")
        }
    }
    /// Verbonden apparaten (id, naam) — voor de "Verder op …"-menu's.
    var otherDevices: [(id: String, name: String)] {
        let sync = TabSyncService.shared
        return sync.devices.filter { $0.key != sync.deviceID }.map { (id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    /// V21: overnemen vanaf een widget of het mediacentrum (ook als het andere apparaat net pauzeerde).
    func takeOverFrom(device: String) {
        sentAway = nil
        guard let snap = TabSyncService.shared.latestByDevice[device] else { return }
        let tab = snap.playingID.flatMap { id in snap.tabs.first { $0.id == id } } ?? snap.tabs.first { $0.id == snap.selectedID }
        guard let tab, let url = tab.url else { return }
        // Speelt het daar nog: vanaf wanneer we die tijd kennen doorrekenen; anders precies die tijd.
        // V22.2: tijd én ontvangstmoment uit dezelfde bron (anders telde de verstreken tijd dubbel).
        if let known = remotePlayback, known.device == device, known.tabID == tab.id {
            takeOver(known); return
        }
        takeOver(RemotePlayback(device: device, tabID: tab.id, url: url, time: tab.time ?? 0, receivedAt: Date(),
                                paused: snap.playingID == nil))
    }

    /// Pak de video over: tab kiezen, meteen spelen op de geschatte tijd, het andere apparaat laten
    /// pauzeren en zijn exacte tijd sturen (dan corrigeren we tot op ±0,3 s).
    /// V22: overdrachten die al zijn overgenomen.
    static var consumedHandoffs: [String] {
        get { UserDefaults.standard.stringArray(forKey: "consumedHandoffsV22") ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(20)), forKey: "consumedHandoffsV22") }
    }
    /// V22.2: laatste automatische overname (tab + moment).
    private var lastTakeover: (id: UUID, at: Date)?
    private func takeOver(_ remote: RemotePlayback) {
        remotePlayback = nil
        guard remote.device != TabSyncService.shared.deviceID else { return }   // V22.3
        if let key = remote.handoffKey { Self.consumedHandoffs.append(key) }
        ignoreRemoteSelectionUntil = Date().addingTimeInterval(6)
        let tab = tabs.first(where: { $0.id == remote.tabID })
            ?? tabs.first(where: { SyncDiff.sameDestination($0.currentURL, remote.url) })
        let target: BrowserTab
        if let tab { target = tab } else {
            addTab(url: remote.url, activate: true, after: selected); target = selected
        }
        lastTakeover = (target.id, Date())
        if target.id != selectedID { selected.session.leaveFullscreenForTabSwitch(); select(target) }
        pendingNavigation[target.id] = nil; pendingPosition[target.id] = nil
        let estimate = remote.estimatedTime() + (remote.paused ? 0 : HandoffPrefs.latencyCompensation)
        target.session.takeOverPlayback(url: remote.url, time: estimate)
        awaitingHandoff[remote.url.absoluteString] = Date().addingTimeInterval(4)
        TabSyncService.shared.send(SyncCommand(kind: .handoffRequest, target: remote.device, url: remote.url, value: nil,
                                               from: TabSyncService.shared.deviceID))
        TabSyncService.shared.noteHandoff("takeover \(String(format: "%.1f", estimate)) s from \(TabSyncService.shared.devices[remote.device] ?? "device")")
        // Overige uitgestelde wijzigingen ook meteen toepassen.
        pendingSelection = nil
        for (id, change) in pendingNavigation { tabs.first { $0.id == id }?.session.syncNavigate(to: change.url, time: change.time) }
        pendingNavigation = [:]
        for (id, time) in pendingPosition { tabs.first { $0.id == id }?.session.syncPosition(time) }
        pendingPosition = [:]
        tabs.forEach { $0.syncPending = false }
    }

    // MARK: V18 — uitgestelde toepassing ("verder waar je was" op het apparaat waar je naartoe gaat)
    private var pendingNavigation: [UUID: (url: URL, time: Double?)] = [:]
    private var pendingPosition: [UUID: Double] = [:]
    private var pendingSelection: UUID?
    /// V22.3: laatst geziene selectie per apparaat (om echte tabwissels daar te herkennen).
    private var lastRemoteSelection: [String: UUID] = [:]

    /// Roep aan zodra de gebruiker dit apparaat weer gebruikt. Zet selectie, pagina en positie
    /// gelijk met het apparaat waar je vandaan komt — gepauzeerd, klaar om verder te kijken.
    func resumeFromOtherDevice(trigger: SwitchTrigger = .interaction) {
        let now = Date()
        let idle = now.timeIntervalSince(lastLocalInteraction)
        lastLocalInteraction = now
        clearDeviceSwitch()
        let localPlaying = tabs.contains { $0.session.isPlaying || $0.session.isInPictureInPicture }
        // V21: net terug uit de achtergrond en (nog) niet verbonden? Eerst even wachten op verse
        // info van het andere apparaat, anders beslissen we op verouderde gegevens.
        // V22.2: wachten op JUIST het apparaat van remotePlayback (niet zomaar een ander verbonden apparaat).
        if trigger == .appActivated, HandoffPrefs.autoResume, !localPlaying, let device = remotePlayback?.device,
           !TabSyncService.shared.isConnected(device), !waitingForPeers, !peerWaitDone {
            waitingForPeers = true
            let started = Date()
            Task { @MainActor [weak self] in
                for _ in 0..<30 {               // max 3 s, tot er een verse snapshot van dat apparaat binnen is
                    try? await Task.sleep(for: .milliseconds(100))
                    if (TabSyncService.shared.lastHeard[device] ?? .distantPast) > started { break }
                }
                guard let self else { return }
                self.waitingForPeers = false
                let heard = (TabSyncService.shared.lastHeard[device] ?? .distantPast) > started
                // Niets gehoord: een LOPENDE video daar alleen overnemen als de info heel vers is
                // (een overdracht na achtergrond staat gepauzeerd op een exacte tijd en blijft geldig).
                if !heard, let r = self.remotePlayback, r.device == device, !r.paused, Date().timeIntervalSince(r.receivedAt) > 20 {
                    self.remotePlayback = nil
                }
                self.lastLocalInteraction = .distantPast
                // V22.2: niet opnieuw gaan wachten (voorheen kon dit zichzelf herhalen).
                self.peerWaitDone = true
                self.resumeFromOtherDevice(trigger: .appActivated)
                self.peerWaitDone = false
            }
            return
        }
        // V21: het andere apparaat speelt → hier meteen verder spelen (instelbaar).
        if !localPlaying, let remote = remotePlayback, HandoffPrefs.autoResume,
           !(sentAway?.device == remote.device && SyncDiff.sameDestination(sentAway?.url, remote.url) && Date() < (sentAway?.until ?? .distantPast)),
           now.timeIntervalSince(remote.receivedAt) < HandoffPrefs.maxAge,
           trigger == .appActivated || (trigger == .interaction && idle >= HandoffPrefs.idleBeforeTakeover) {
            takeOver(remote)
            return
        }
        guard pendingSelection != nil || !pendingNavigation.isEmpty || !pendingPosition.isEmpty else { return }
        // V22.2: de tabkeuze van het andere apparaat alleen overnemen als je echt "terugkomt"
        // (app geactiveerd, of na even weg te zijn) — niet bij elke klik (dan landde je klik op een andere pagina).
        let returning = trigger == .appActivated || idle >= HandoffPrefs.idleBeforeTakeover
        if returning, !localPlaying, let target = pendingSelection, target != selectedID, tabs.contains(where: { $0.id == target }) {
            selected.session.leaveFullscreenForTabSwitch()
            selectedID = target
            selected.lastActive = Date()
        }
        if returning || trigger == .tabSelection { pendingSelection = nil }
        for (id, change) in pendingNavigation {
            guard let tab = tabs.first(where: { $0.id == id }) else { continue }
            tab.session.syncNavigate(to: change.url, time: change.time)
            pendingPosition[id] = nil
        }
        pendingNavigation = [:]
        for (id, time) in pendingPosition { tabs.first { $0.id == id }?.session.syncPosition(time) }
        pendingPosition = [:]
        tabs.forEach { $0.syncPending = false }
    }

    private func persistWithoutSync() {
        guard !isClosed else { return }
        let kept = tabs.filter { !$0.isPrivate }
        guard !kept.isEmpty else { return }
        let selection = kept.contains(where: { $0.id == selectedID }) ? selectedID : kept[0].id
        store.save(SavedTabSession(tabs: kept.map { Self.saved($0) }, selectedID: selection), window: windowID)
    }
    /// Current URL plus, when it is the same video, its last known position.
    private static func saved(_ tab: BrowserTab, url override: URL? = nil) -> SavedBrowserTab {
        let session = tab.session
        let url = override ?? session.currentURL ?? session.restoredURL
        var result = SavedBrowserTab(id: tab.id, url: url, lastActive: tab.lastActive, pinned: tab.pinned ? true : nil, title: tab.title, groupID: tab.groupID)
        if let point = session.resumePoint, let url, Self.sameVideo(point.url, url) {
            result.time = point.time; result.playing = point.playing
        } else if session.currentURL == nil, let restored = session.restoredURL, restored == url {
            result.time = session.restoredTime; result.playing = session.restoredPlaying
        }
        return result
    }
    private static func sameVideo(_ a: URL, _ b: URL) -> Bool {
        func key(_ u: URL) -> String {
            URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value ?? u.path
        }
        return key(a) == key(b)
    }
    private func observe(_ tab: BrowserTab) {
        // V22.2: een tab die terugkomt uit PiP (app weer actief) wordt eerst zichtbaar gemaakt.
        tab.session.onWantsSelection = { [weak self, weak tab] in
            guard let self, let tab, tab.id != self.selectedID else { return }
            self.selected.session.leaveFullscreenForTabSwitch()
            self.selectedID = tab.id; tab.lastActive = Date(); self.persist()
        }
        tab.session.onOpenInNewTab = { [weak self, weak tab] url, activate in
            self?.openInNewTab(url, activate: activate, from: tab)
        }
        // V17: "terug" terwijl er geen vorige pagina is → deze tab sluiten (als dat aan staat).
        tab.session.onCannotGoBack = { [weak self, weak tab] in
            guard let self, let tab else { return }
            self.closeFromBack(tab)
        }
        urlObservers[tab.id] = tab.session.$currentURL.dropFirst().sink { [weak self, weak tab] url in
            guard let self, !self.isClosed, let tab, let url, !tab.isPrivate else { return }
            // @Published emits before storage changes; preserve the new URL explicitly.
            tab.session.restoredURL = url
            let kept = self.tabs.filter { !$0.isPrivate }
            guard !kept.isEmpty else { return }
            self.store.save(SavedTabSession(tabs: kept.map {
                Self.saved($0, url: $0.id == tab.id ? url : nil)
            }, selectedID: kept.contains(where: { $0.id == self.selectedID }) ? self.selectedID : kept[0].id), window: self.windowID)
            // Op de volgende beurt staat de nieuwe URL echt opgeslagen; dan pas delen.
            DispatchQueue.main.async { self.publishSync() }
        }
        // V22.2: de positie tikt tot 2×/s. Delen (publishSync) blijft per tik zoals voorheen, maar
        // opslaan gebeurt hooguit elke 10 s — en meteen bij pauze (point.playing == false).
        resumeObservers[tab.id] = tab.session.resumePointPublisher.dropFirst().removeDuplicates().sink { [weak self] point in
            DispatchQueue.main.async {
                guard let self else { return }
                if point?.playing == true { self.publishSync(); self.schedulePositionPersist() } else { self.persist() }
            }
        }
        titleObservers[tab.id] = tab.$title.dropFirst().removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persist() }
        // ── Playback observer: "one video at a time" and the PiP hand-over ─────────────────
        // `$isPlaying` is a Combine publisher: it sends a value every time this tab's video
        // starts (true) or stops (false). `removeDuplicates()` drops repeats (true, true → true).
        // `sink { … }` is the code that runs for every new value.
        playbackObservers[tab.id] = tab.session.$isPlaying.removeDuplicates().sink { [weak self, weak tab] playing in
            // `[weak self, weak tab]`: do not keep the workspace/tab alive just because this
            // observer exists (prevents memory leaks). `guard let` unwraps them or stops.
            guard let self, let tab else { return }
            if playing {                              // this tab's video just STARTED playing
                tab.lastActive = Date()               // for "close inactive tabs" and Ctrl+Tab order
                self.localPlayStamp = TabSyncService.shared.playStamp()   // V22.2: voorrang bij gelijktijdig spelen
                self.handOver(to: tab)                // pause / close PiP of every other tab
                self.pauseOtherWindows(for: tab)      // V22.2: ook in andere vensters + vanuit een extra venster
                #if os(iOS)
                if UIApplication.shared.applicationState == .active { self.localHandoff = nil }
                #else
                self.localHandoff = nil
                #endif
                self.requestDeviceHandoff(for: tab)   // V19.1: ander apparaat speelt dezelfde video? → exacte tijd
            }
            // Keep the screen awake while any tab plays (iPhone/iPad setting). `async` runs it
            // a moment later, after all tabs have updated their state.
            DispatchQueue.main.async {
                self.updateIdleTimer(); self.publishSync()
                // V20: Spotify pauzeren/zachter als een video start, en daarna weer terug.
                let anyPlaying = BrowserWorkspace.registry.allObjects.contains { $0.tabs.contains { $0.session.isPlaying } }
                SpotifyCoordinator.shared.videoPlaybackChanged(anyPlaying: anyPlaying)
                ChromeAutoHide.shared.playbackChanged()
            }
        }
    }
    /// V22.2: opslag van de afspeelpositie samenvoegen (hooguit één keer per 10 s).
    private var resumePersistTask: Task<Void, Never>?
    private func schedulePositionPersist() {
        guard resumePersistTask == nil else { return }
        resumePersistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self else { return }
            self.resumePersistTask = nil
            self.persistWithoutSync()
        }
    }
    /// V22.2: openstaande positie-opslag nu meteen wegschrijven (achtergrond, afsluiten, venster dicht).
    func flushPendingPersist() {
        guard resumePersistTask != nil else { return }
        resumePersistTask?.cancel(); resumePersistTask = nil
        persistWithoutSync()
    }
    static func flushAllPendingPersists() { registry.allObjects.forEach { $0.flushPendingPersist() } }
    /// V15: keep the screen on while any tab plays (setting).
    func updateIdleTimer() {
        if batchDepth > 0 { batchNeedsIdleUpdate = true; return }   // V22.2
        #if os(iOS)
        let keepAwake = UserDefaults.standard.object(forKey: "keepScreenAwakeV15") as? Bool ?? true
        UIApplication.shared.isIdleTimerDisabled = keepAwake && tabs.contains { $0.session.isPlaying }
        #endif
    }
    private func leaveCurrent() {
        selected.lastActive = Date()
        recent.removeAll { $0 == selectedID }; recent.append(selectedID)
        let session = selected.session
        // V16.2: an untouched new tab must not pop up the keyboard when you come back to it later.
        session.focusSearchWhenReady = false
        // V16: a playing video continues in PiP while you open or browse another tab.
        let keepInPiP = (UserDefaults.standard.object(forKey: "pipOnTabSwitchV16") as? Bool ?? true) && session.isPlaying
        if keepInPiP && !session.isInPictureInPicture {
            session.enterPiPForTabSwitch()
            return
        }
        session.leaveFullscreenForTabSwitch()
        if !session.isInPictureInPicture { session.pauseForTabSwitch() }
    }
    /// V16.2.1 — the hand-over, in the order Tijn asked for:
    ///   1. the video in the OTHER tab (usually playing in PiP) pauses immediately,
    ///   2. its PiP window closes (without jumping back to fullscreen or raising a window),
    ///   3. only when that PiP window is really gone, the NEW tab's video goes fullscreen
    ///      (theater mode is already on for it, so it fills the window even before that).
    /// - Parameter tab: the tab whose video just started playing.
    /// V22.2: één video tegelijk, app-breed: speelt er in een ander (Mac-)venster nog iets, dan pauzeert
    /// dat. Extra vensters doen niet mee aan de sync; start je dáár een video, dan krijgen de andere
    /// apparaten die nu spelen toch een pauze-opdracht (anders speelden twee apparaten tegelijk).
    private func pauseOtherWindows(for tab: BrowserTab) {
        for workspace in Self.registry.allObjects where workspace !== self {
            for other in workspace.tabs {
                if other.session.isInPictureInPicture { other.session.stopPiPAndPause() }
                else if other.session.isPlaying { other.session.pauseForTabSwitch() }
            }
        }
        let sync = TabSyncService.shared
        guard !tab.isPrivate, let owner = sync.owner, owner !== self else { return }
        owner.localPlayStamp = localPlayStamp   // een oudere "speelt daar"-stand pauzeert dit venster dan niet
        for id in sync.devices.keys where sync.latestByDevice[id]?.playingID != nil {
            sync.send(SyncCommand(kind: .pause, target: id, url: nil, value: nil))
        }
    }

    private func handOver(to tab: BrowserTab) {
        var closingPiP: [BrowserTab] = []      // tabs whose PiP window we are closing
        for other in tabs where other.id != tab.id {          // every tab except the new one
            // V22.2: een lopend PiP-verzoek of startende native PiP telt ook als PiP.
            if other.session.isInPictureInPicture || other.session.isPiPRequesting || other.session.isNativePiPStarting {
                other.session.stopPiPAndPause()               // steps 1 + 2 for that tab
                closingPiP.append(other)
            } else {
                other.session.pauseForTabSwitch()             // plain pause if it was playing inline
            }
        }
        // Step 3 only applies when a PiP video was replaced, the new tab is the visible one,
        // and the setting "New video from PiP goes fullscreen" is on (default: on).
        let wantsFullscreen = UserDefaults.standard.object(forKey: "fullscreenNewVideoFromPiPV16") as? Bool ?? true
        guard !closingPiP.isEmpty, tab.id == selectedID, wantsFullscreen else { return }
        handOverTask?.cancel()                 // a newer hand-over replaces an older one
        handOverTask = Task { @MainActor [weak self, weak tab] in
            // Wait (max. 1.5 s, checking every 0.1 s) until every old PiP window is closed.
            // Starting fullscreen while macOS/iOS is still closing PiP made the new video
            // appear on the wrong Space or not at all.
            for _ in 0..<15 {
                if closingPiP.allSatisfy({ !$0.session.isInPictureInPicture }) { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .milliseconds(150))   // let the close animation finish
            // With "Automatic fullscreen" on, the new video starts fullscreen by itself about
            // 0.5 s after it begins. On the Mac, fullscreen is a toggle (the F key): asking a
            // second time at the same moment would switch it OFF again. So first give the
            // automatic request time, and only step in if it did not happen.
            if UserDefaults.standard.object(forKey: "automaticFullscreenV8") as? Bool ?? true {
                try? await Task.sleep(for: .milliseconds(1300))
            }
            // Try fullscreen up to twice (1.5 s apart, longer than the fullscreen animation so
            // a toggle can never undo the previous one): the first request can be refused while
            // the system is still busy with the PiP window.
            for attempt in 1...2 {
                guard !Task.isCancelled, let self, let tab, tab.id == self.selectedID,
                      tab.session.isPlaying, !tab.session.isFullscreen else { return }
                tab.session.enterFullscreenForHandOver()
                tab.session.noteHandOver("hand-over: new video fullscreen (attempt \(attempt))")
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }
    /// V16 Ctrl+Tab: back to the tab that was open before (again: forth), like app switching.
    // MARK: V19 — Ctrl+Tab door recente tabs (zoals de app-wisselaar: houd Ctrl vast, tik Tab)
    private var recentCycle: [UUID] = []
    private var recentCycleIndex = 0
    private var recentCycleFullscreen = false

    /// Eén stap: eerste Tab = vorige tab, volgende Tab (Ctrl nog vast) = die daarvoor, enz.
    /// Speelde de video fullscreen, dan gaat de nieuwe video ook fullscreen verder.
    func cycleRecent(backwards: Bool = false) {
        Self.active = self
        if recentCycle.isEmpty {
            // Volgorde: meest recent gebruikt eerst (huidige tab vooraan), daarna de rest.
            var order = recent.reversed().filter { id in tabs.contains { $0.id == id } }
            if let i = order.firstIndex(of: selectedID) { order.remove(at: i) }
            order.insert(selectedID, at: 0)
            for tab in tabs where !order.contains(tab.id) { order.append(tab.id) }
            recentCycle = order; recentCycleIndex = 0
            recentCycleFullscreen = selected.session.isFullscreen
        }
        guard recentCycle.count > 1 else { return }
        recentCycleIndex = (recentCycleIndex + (backwards ? -1 : 1) + recentCycle.count) % recentCycle.count
        guard let target = tabs.first(where: { $0.id == recentCycle[recentCycleIndex] }) else { return }
        let current = selected
        let wasPlaying = current.session.isPlaying
        if recentCycleFullscreen {
            // Fullscreen-wissel: huidige video pauzeren (geen PiP), fullscreen sluiten, doorschakelen.
            current.session.pauseForTabSwitch()
            current.session.leaveFullscreenForTabSwitch()
            current.lastActive = Date()
            selectedID = target.id; target.lastActive = Date(); target.session.userActivatedAt = Date()
            if wasPlaying || NavigationPolicy.isPlaybackPage(target.currentURL) {
                target.session.remoteToggleIfPaused()
                Task { @MainActor [weak target] in
                    try? await Task.sleep(for: .milliseconds(900))
                    target?.session.enterFullscreenForHandOver()
                }
            }
        } else {
            select(target)
        }
    }
    func endRecentCycle() {
        guard !recentCycle.isEmpty else { return }
        recentCycle = []
        recent.removeAll { $0 == selectedID }; recent.append(selectedID)
        persist()
    }

    func selectRecent() {
        guard let previous = recent.last(where: { id in id != selectedID && tabs.contains { $0.id == id } }),
              let tab = tabs.first(where: { $0.id == previous }) else { selectPrevious(); return }
        select(tab)
    }
    /// The running hand-over (see `handOver(to:)`), so a newer one can cancel it.
    private var handOverTask: Task<Void, Never>?
    private var insertsNextToCurrent: Bool { UserDefaults.standard.object(forKey: "openNewTabsNextToCurrentV15") as? Bool ?? true }
    func addTab() { addTab(url: nil) }
    func addPrivateTab() { addTab(url: nil, privateMode: true) }
    /// New tab; without a URL it opens the start page with the search field focused.
    func addTab(url: URL?, privateMode: Bool = false, activate: Bool = true, after anchor: BrowserTab? = nil) {
        Self.active = self
        let tab = BrowserTab(saved: SavedBrowserTab(url: url), privateMode: privateMode)
        tab.session.userActivatedAt = Date()   // V22.2: zelf geopend → een video mag meteen spelen
        if url == nil {
            // V19.2: nieuwe-tab-pagina (standaard aan); anders zoals voorheen YouTube's zoekveld.
            if (UserDefaults.standard.object(forKey: "newTabPageV192") as? Bool ?? true) && !privateMode {
                tab.session.showsNewTabPage = true
            } else {
                tab.session.focusSearchWhenReady = true
            }
        }
        if activate { leaveCurrent() }
        var index = tabs.count
        if let anchor, insertsNextToCurrent, let position = tabs.firstIndex(where: { $0.id == anchor.id }) {
            index = position + 1
        }
        index = max(index, tabs.filter(\.pinned).count)
        tabs.insert(tab, at: min(index, tabs.count)); observe(tab)
        if activate { selectedID = tab.id }
        persist()
    }
    func openInNewTab(_ url: URL, activate: Bool, from source: BrowserTab?) {
        // V17: met "Nieuwe tabs meteen tonen" aan (standaard) schakelt JoeToep altijd naar de
        // nieuwe tab, ook bij middelklik of rechtsklik › Open in nieuwe tab.
        let switchTo = activate || (UserDefaults.standard.object(forKey: "switchToNewTabsV17") as? Bool ?? true)
        let opener = source ?? selected
        addTab(url: url, privateMode: source?.isPrivate ?? false, activate: switchTo, after: opener)
        // De zojuist gemaakte tab staat direct rechts van de bron; onthoud waar hij vandaan komt.
        if let index = tabs.firstIndex(where: { $0.id == opener.id }), index + 1 < tabs.count {
            tabs[index + 1].openerID = opener.id
        }
    }
    /// V17: "terug" (knop, muisknop, veeg, ⌘←) op de eerste pagina van een tab.
    /// - Staat de instelling uit: een melding "geen vorige pagina".
    /// - Is dit de laatste tab: naar de startpagina in plaats van sluiten.
    /// - Anders: tab sluiten en de tab tonen waaruit hij geopend werd (of de vorige recente).
    /// V17.1: tijdstip van de laatste "terug sluit tab"; zo kan één gebaar nooit twee tabs sluiten.
    private var lastBackClose = Date.distantPast
    func closeFromBack(_ tab: BrowserTab) {
        // Alleen een tab die nog bestaat, en niet vaker dan eens per 0.7 s (een veeg of toets
        // kan soms twee meldingen geven; zonder deze rem sloot ⌘← ook de tab eronder).
        guard tabs.contains(where: { $0.id == tab.id }), Date().timeIntervalSince(lastBackClose) > 0.7 else { return }
        lastBackClose = Date()
        guard UserDefaults.standard.object(forKey: "backClosesTabV17") as? Bool ?? true else {
            tab.session.showNotice(.information, "No previous page", "This is the first page in this tab.")
            return
        }
        guard tabs.count > 1 else { tab.session.goHome(); return }
        let opener = tab.openerID.flatMap { id in tabs.first { $0.id == id } }
        close(tab)                                   // wordt onthouden: ⌘⇧T opent hem weer
        if let opener { select(opener) }
    }
    /// V17: de werkruimte (het venster) waar je het laatst mee werkte. De Mac-muisknoppen en
    /// ⌘←/⌘→ sturen hun opdracht hierheen. `weak` = houdt het venster niet kunstmatig in leven.
    static weak var active: BrowserWorkspace?
    // MARK: V21 — tabgroepen, zijbalk en de nieuwe-tab-overlay

    @Published var groups: [TabGroup] = TabGroupStore.load() { didSet { if groups != oldValue { TabGroupStore.save(groups) } } }
    /// De zwevende zoek-/adresbalk (Arc-stijl) boven de pagina.
    @Published var showCommandBar = false {
        // V22.3: de overlay lag onzichtbaar achter een fullscreen video (⌘T/⌘L deed dan schijnbaar niets).
        didSet { if showCommandBar && !oldValue { selected.session.leaveFullscreenForTabSwitch() } }
    }
    /// true = de overlay past het adres van de huidige tab aan (⌘L); false = nieuwe tab (⌘T).
    @Published var commandBarEditsCurrent = false
    /// V22: eenmalig platform voor de volgende zoekbalk (bijv. vanuit een widget).
    var commandBarToken: MediaPlatform?

    /// "+" / ⌘T: Arc-stijl overlay (standaard), of meteen een lege tab (instelbaar).
    func requestNewTab() {
        if CommandBarPrefs.overlayForNewTab { commandBarEditsCurrent = false; showCommandBar = true } else { addTab() }
    }
    func requestEditAddress() { commandBarEditsCurrent = true; showCommandBar = true }

    @discardableResult
    func newGroup(named name: String = "New group", with tab: BrowserTab? = nil) -> TabGroup {
        let colors = TabGroup.palette
        let group = TabGroup(name: name, color: colors[groups.count % colors.count])
        groups.append(group)
        if let tab { tab.groupID = group.id; tab.pinned = false; persist() }
        return group
    }
    func setGroup(_ tab: BrowserTab, to id: UUID?) {
        tab.groupID = id
        if id != nil { tab.pinned = false }
        persist()
    }
    func renameGroup(_ id: UUID, to name: String) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[i].name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Group" : name
    }
    func recolorGroup(_ id: UUID, to color: String) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[i].color = color
    }
    func toggleGroupCollapsed(_ id: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[i].collapsed.toggle()
    }
    /// Groep opheffen: tabs worden los (of gesloten).
    func removeGroup(_ id: UUID, closingTabs: Bool) {
        batching {   // V22.2: één opslag i.p.v. één per tab
            for tab in tabs where tab.groupID == id {
                if closingTabs, tabs.count > 1 { close(tab) } else { tab.groupID = nil }
            }
            groups.removeAll { $0.id == id }
            persist()
        }
    }
    /// Arc "Clear": alle losse (niet vastgezette, niet gegroepeerde) tabs sluiten.
    func clearLooseTabs() {
        let loose = tabs.filter { !$0.pinned && $0.groupID == nil && $0.id != selectedID }
        batching { for tab in loose where tabs.count > 1 { close(tab) } }   // V22.2
    }
    func tabs(in group: UUID?) -> [BrowserTab] { tabs.filter { !$0.pinned && $0.groupID == group } }
    var pinnedTabs: [BrowserTab] { tabs.filter(\.pinned) }

    /// V20: alle open vensters (zwak), voor het mediacentrum.
    static let registry = NSHashTable<BrowserWorkspace>.weakObjects()
    func select(_ tab: BrowserTab) {
        Self.active = self
        // Eigen keuze gaat voor; de rest van wat het andere apparaat deed nu toepassen.
        pendingSelection = nil
        resumeFromOtherDevice(trigger: .tabSelection)
        // V22.2: dezelfde tik startte net een automatische overname in een ándere tab, maar je kiest
        // zelf deze tab → die overname terugdraaien (anders bleef hij op de achtergrond spelen).
        if let t = lastTakeover, t.id != tab.id, Date().timeIntervalSince(t.at) < 2.5,
           let other = tabs.first(where: { $0.id == t.id }) {
            lastTakeover = nil
            other.session.cancelPendingAutoplay()
            TabSyncService.shared.noteHandoff("takeover cancelled: you picked another tab")
        }
        guard tab.id != selectedID else { return }
        tab.session.userActivatedAt = Date()   // V22.2: jouw keuze → een herstelde video mag spelen
        leaveCurrent()
        selectedID = tab.id; tab.lastActive = Date(); persist()
    }
    func select(index: Int) {
        guard !tabs.isEmpty else { return }
        select(tabs[min(max(index, 0), tabs.count - 1)])
    }
    func selectNext() { select(index: (selectedIndex + 1) % max(tabs.count, 1)) }
    func selectPrevious() { select(index: (selectedIndex - 1 + tabs.count) % max(tabs.count, 1)) }
    /// V22.2: "grafstenen" van gesloten tabs (max. 7 dagen / 300 stuks) voor de sync-samenvoeging.
    static var closedSyncIDs: Set<String> {
        let all = UserDefaults.standard.dictionary(forKey: "closedSyncIDsV22") as? [String: Double] ?? [:]
        let cutoff = Date().timeIntervalSince1970 - 7 * 86_400
        return Set(all.filter { $0.value > cutoff }.keys)
    }
    static func markClosed(_ id: UUID) { markClosed([id]) }
    /// V22.2: meerdere grafstenen in één keer lezen/sorteren/schrijven (bulk sluiten).
    static func markClosed(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        var all = UserDefaults.standard.dictionary(forKey: "closedSyncIDsV22") as? [String: Double] ?? [:]
        let now = Date().timeIntervalSince1970
        for id in ids { all[id.uuidString] = now }
        if all.count > 300 { for key in all.sorted(by: { $0.value < $1.value }).prefix(all.count - 300).map(\.key) { all[key] = nil } }
        UserDefaults.standard.set(all, forKey: "closedSyncIDsV22")
    }
    static func unmarkClosed(_ id: UUID) {
        var all = UserDefaults.standard.dictionary(forKey: "closedSyncIDsV22") as? [String: Double] ?? [:]
        all[id.uuidString] = nil
        UserDefaults.standard.set(all, forKey: "closedSyncIDsV22")
    }
    func close(_ tab: BrowserTab) { close(tab, remember: true) }
    func close(_ tab: BrowserTab, remember: Bool) {
        guard tabs.count > 1 else {
            tab.session.goHome(); return
        }
        if remember && !tab.isPrivate {
            // V22.3: "speelde hij?" = speelde hij op het moment van sluiten (niet een oude opgeslagen stand).
            var closedState = Self.saved(tab)
            closedState.playing = tab.session.isPlaying || tab.session.isInPictureInPicture
            closedTabs.insert(closedState, at: 0)
            if closedTabs.count > 25 { closedTabs.removeLast() }
        }
        if !tab.isPrivate {
            if batchDepth > 0 { batchTombstones.append(tab.id) } else { Self.markClosed(tab.id) }   // V22.2
        }
        tab.session.closeTab()
        playbackObservers[tab.id] = nil; urlObservers[tab.id] = nil; resumeObservers[tab.id] = nil; titleObservers[tab.id] = nil
        let index = tabs.firstIndex(where: { $0.id == tab.id })!
        tabs.remove(at: index)
        if selectedID == tab.id { selectedID = tabs[min(index, tabs.count - 1)].id }
        persist(); updateIdleTimer()
    }
    func closeOthers(_ keep: BrowserTab) {
        batching { for tab in tabs where tab.id != keep.id && !tab.pinned { close(tab) } }
        select(keep)
    }
    func closeToTheRight(of anchor: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == anchor.id }) else { return }
        batching { for tab in tabs.suffix(from: index + 1) where !tab.pinned { close(tab) } }
    }
    /// V22.2: bulk sluiten zonder O(n²): opslaan, schermtimer en grafstenen pas één keer aan het eind.
    private var batchDepth = 0
    private var batchNeedsPersist = false
    private var batchNeedsIdleUpdate = false
    private var batchTombstones: [UUID] = []
    func batching(_ body: () -> Void) {
        batchDepth += 1
        body()
        batchDepth -= 1
        guard batchDepth == 0 else { return }
        if !batchTombstones.isEmpty { Self.markClosed(batchTombstones); batchTombstones = [] }
        if batchNeedsPersist { batchNeedsPersist = false; persist() }
        if batchNeedsIdleUpdate { batchNeedsIdleUpdate = false; updateIdleTimer() }
    }
    func reopenClosedTab() {
        guard !closedTabs.isEmpty else { return }
        var saved = closedTabs.removeFirst()
        saved.lastActive = Date()
        Self.unmarkClosed(saved.id)
        leaveCurrent()
        let tab = BrowserTab(saved: saved)
        // V22.3: speelde hij toen je hem sloot, dan speelt hij weer; stond hij op pauze, dan blijft dat zo.
        if saved.playing == true { tab.session.userActivatedAt = Date() }
        tabs.append(tab); observe(tab); selectedID = tab.id; persist()
    }
    func duplicate(_ tab: BrowserTab) {
        var copy = Self.saved(tab); copy.id = UUID(); copy.pinned = nil
        leaveCurrent()
        let clone = BrowserTab(saved: copy, privateMode: tab.isPrivate)
        let index = (tabs.firstIndex(where: { $0.id == tab.id }) ?? tabs.count - 1) + 1
        tabs.insert(clone, at: index); observe(clone); selectedID = clone.id; persist()
    }
    func togglePin(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.pinned.toggle()
        tabs.remove(at: index)
        let pinnedCount = tabs.filter(\.pinned).count
        tabs.insert(tab, at: min(pinnedCount, tabs.count))
        persist()
    }
    /// V22.2: vastzetten/losmaken naar een vaste waarde (slepen in de zijbalk): herordent zoals
    /// togglePin (op de grens van de vastgezette tabs) en slaat op.
    func setPinned(_ tab: BrowserTab, _ pinned: Bool) {
        if pinned { tab.groupID = nil }
        guard tab.pinned != pinned else { persist(); return }
        togglePin(tab)
    }
    /// V19.1: sleep-herordenen. Zet tab `id` op de plek van `target` (pinned en gewone tabs
    /// blijven elk in hun eigen groep). Geeft false terug als het niet kon.
    @discardableResult
    func moveTab(id: UUID, before target: UUID) -> Bool {
        guard id != target, let from = tabs.firstIndex(where: { $0.id == id }),
              let to = tabs.firstIndex(where: { $0.id == target }), tabs[from].pinned == tabs[to].pinned else { return false }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
        persist()
        return true
    }
    /// V19.2: tab achteraan zetten (achter de laatste tab van zijn groep: pinned of gewoon).
    @discardableResult
    func moveTabToEnd(id: UUID) -> Bool {
        guard let from = tabs.firstIndex(where: { $0.id == id }) else { return false }
        let tab = tabs.remove(at: from)
        let end = tab.pinned ? tabs.filter(\.pinned).count : tabs.count
        tabs.insert(tab, at: end)
        persist()
        return from != end
    }
    /// V22: live herordenen tijdens het slepen (Mac): één plek naar links/rechts, binnen de eigen
    /// groep (vastgezet of gewoon). Geeft true als er echt iets verschoof.
    @discardableResult
    func stepTab(id: UUID, by offset: Int) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        let target = index + offset
        guard target >= 0, target < tabs.count, tabs[target].pinned == tabs[index].pinned else { return false }
        tabs.swapAt(index, target)
        return true
    }
    func finishTabDrag() { persist() }
    func move(_ tab: BrowserTab, by offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let target = min(max(index + offset, 0), tabs.count - 1)
        guard target != index, tabs[target].pinned == tab.pinned else { return }
        tabs.swapAt(index, target); persist()
    }
}

struct WorkspaceActions {
    var newTab: () -> Void
    var closeTab: () -> Void
    var pictureInPicture: () -> Void
    var closeWindow: () -> Void
    var reload: () -> Void
    var openSettings: () -> Void = {}
    var newPrivateTab: () -> Void = {}
    var reopenClosedTab: () -> Void = {}
    var editAddress: () -> Void = {}
    var find: () -> Void = {}
    var toggleBookmark: () -> Void = {}
    var showLibrary: () -> Void = {}
    var nextTab: () -> Void = {}
    var previousTab: () -> Void = {}
    var selectTab: (Int) -> Void = { _ in }
    var goBack: () -> Void = {}
    var goForward: () -> Void = {}
    var zoomIn: () -> Void = {}
    var zoomOut: () -> Void = {}
    var resetZoom: () -> Void = {}
    var togglePin: () -> Void = {}
    var recentTab: () -> Void = {}
    var forceRefresh: () -> Void = {}
    var duplicateTab: () -> Void = {}
    var copyLink: () -> Void = {}
}
extension Notification.Name {
    /// Object: the WebSession whose tab should present Settings (Cmd+,).
    static let joeToepOpenSettings = Notification.Name("nl.tijn.JoeToep.openSettings")
    /// V21: zijbalk in-/uitklappen (⌘S / knop).
    static let joeToepToggleSidebar = Notification.Name("nl.tijn.JoeToep.toggleSidebar")
}
struct WorkspaceActionsKey: FocusedValueKey { typealias Value = WorkspaceActions }
extension FocusedValues {
    var workspaceActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

struct PlayerShellView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var workspace = BrowserWorkspace()
    @ObservedObject private var library = BrowserLibrary.shared
    @State private var editingAddress = false
    @ObservedObject private var chrome = ChromeAutoHide.shared
    @AppStorage("autoHideAnimationV20") private var autoHideAnimated = true
    @AppStorage("autoHideRevealEdgeV20") private var autoHideRevealEdge = true
    @AppStorage("oneBarLayoutV21") private var oneBarSetting = true
    @AppStorage("sidebarTabsV21") private var sidebarSetting = false
    @AppStorage("sidebarHiddenV21") private var sidebarHidden = false
    @State private var sidebarPeek = false
    private var useSidebar: Bool { SidebarPrefs.enabled(sidebarSetting) }
    @State private var windowIsFullscreen = false
    private var oneBar: Bool { LayoutPrefs.oneBar(oneBarSetting) }
    private var oneBarInTitlebar: Bool {
        #if os(macOS)
        oneBar && !useSidebar
        #else
        false
        #endif
    }
    /// V21: zijbalk op de Mac loopt door tot bovenin (venster-knopjes staan in de zijbalk, zoals Arc).
    private var oneBarInTitlebarForSidebar: Bool {
        #if os(macOS)
        useSidebar && (!sidebarHidden || sidebarPeek)
        #else
        false
        #endif
    }
    private var sidebarTopInset: CGFloat {
        #if os(macOS)
        4
        #else
        0
        #endif
    }
    @State private var showingLibrary = false
    @State private var findVisible = false
    /// V18: download die offline wordt afgespeeld (vanaf de Watch).
    @State private var offlineItem: DownloadItem?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var actions: WorkspaceActions {
        WorkspaceActions(
            newTab: workspace.requestNewTab, closeTab: { workspace.close(workspace.selected) },
            pictureInPicture: { workspace.selected.session.togglePictureInPicture() },
            closeWindow: { dismissWindow() }, reload: { workspace.selected.session.reload() },
            openSettings: { NotificationCenter.default.post(name: .joeToepOpenSettings, object: workspace.selected.session) },
            newPrivateTab: workspace.addPrivateTab, reopenClosedTab: workspace.reopenClosedTab,
            editAddress: { if CommandBarPrefs.overlayForAddress { workspace.requestEditAddress() } else { editingAddress = true } }, find: showFind,
            toggleBookmark: toggleBookmark, showLibrary: { showingLibrary = true },
            nextTab: workspace.selectNext, previousTab: workspace.selectPrevious,
            selectTab: { index in index >= 8 ? workspace.select(index: workspace.tabs.count - 1) : workspace.select(index: index) },
            goBack: { workspace.selected.session.goBack() }, goForward: { workspace.selected.session.goForward() },
            zoomIn: { workspace.selected.session.zoom(by: 0.1) }, zoomOut: { workspace.selected.session.zoom(by: -0.1) },
            resetZoom: { workspace.selected.session.resetZoom() }, togglePin: { workspace.togglePin(workspace.selected) },
            recentTab: workspace.selectRecent, forceRefresh: { workspace.selected.session.forceRefresh() },
            duplicateTab: { workspace.duplicate(workspace.selected) },
            copyLink: { if let url = workspace.selected.currentURL { Clipboard.copy(url) } })
    }
    /// V21: linker- of rechterdeel van de knoppen, voor de ene balk.
    private func oneBarPart(_ part: PlayerControlBar.Part) -> some View {
        PlayerControlBar(session: workspace.selected.session, settings: settings, availableWidth: 600, actions: actions,
                         showSettings: actions.openSettings, part: part, fixedButtonSize: LayoutPrefs.oneBarButtonSize)
            .id(workspace.selectedID)
    }
    private func toggleBookmark() {
        let tab = workspace.selected
        library.toggleBookmark(title: tab.fullTitle, url: tab.session.currentURL)
        let saved = library.isBookmarked(tab.session.currentURL)
        tab.session.showNotice(.success, saved ? "Bookmark added" : "Bookmark removed", tab.fullTitle)
    }
    private func showFind() { findVisible = true }

    var body: some View {
        let theme = settings.theme
        content(theme)
            #if os(macOS)
            .background(WindowCloseObserver { [weak workspace] in workspace?.windowClosed() })
            #endif
            .sheet(item: $offlineItem) { OfflinePlayer(item: $0) }
            .onReceive(NotificationCenter.default.publisher(for: DownloadManager.playOffline)) { note in
                guard BrowserWorkspace.active === workspace || BrowserWorkspace.active == nil,
                      let id = note.object as? UUID else { return }
                workspace.mediaTab.session.pauseForRemotePlayback()
                offlineItem = DownloadManager.shared.items.first { $0.id == id }
            }
            .onAppear {
                TabSyncService.shared.bind(to: settings)
                ChromeAutoHide.shared.schedule()
                WidgetBridge.shared.startOnce()
                #if os(iOS)
                WatchBridge.shared.activate(workspace: workspace)
                #endif
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                TabSyncService.shared.resume(); workspace.publishSync()
            }
            // V22: vlak vóór de achtergrond de exacte positie doorgeven (de verbinding valt daarna weg).
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                workspace.prepareDeviceSwitch()
                workspace.flushPendingPersist()   // V22.2
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                workspace.resumeFromOtherDevice(trigger: .appActivated)
            }
            // Elke aanraking = "ik gebruik dit apparaat weer" → verder waar je op het andere was.
            .simultaneousGesture(TapGesture().onEnded { workspace.resumeFromOtherDevice() })
            #else
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                TabSyncService.shared.resume(); workspace.resumeFromOtherDevice(trigger: .appActivated)
            }
            .onAppear {
                // Mac: een klik, toets of scroll in JoeToep telt als "weer op dit apparaat".
                UserActivityMonitor.shared.install { BrowserWorkspace.active?.resumeFromOtherDevice() }
            }
            #endif
    }

    @ViewBuilder private func content(_ theme: JoeToepTheme) -> some View {
        HStack(spacing: 0) {
        // V21: verticale tabs in een zijbalk (Arc/Dia), Mac en iPad.
        if useSidebar && (!sidebarHidden || sidebarPeek) && !chrome.tabsHidden {
            SidebarView(workspace: workspace, settings: settings, actions: actions, topInset: sidebarTopInset,
                        leadingInset: oneBarInTitlebarForSidebar && !windowIsFullscreen ? 70 : 0)
                .transition(.move(edge: .leading).combined(with: .opacity))
                #if os(macOS)
                .onHover { inside in if !inside && sidebarHidden { withAnimation(Motion.quick()) { sidebarPeek = false } } }
                #endif
            Rectangle().fill(theme.style.separator.opacity(0.4)).frame(width: 0.5)
        }
        VStack(spacing: 0) {
            // V20: tabbalk kan automatisch verbergen (Instellingen › Top bar auto-hide).
            if !useSidebar && (!chrome.tabsHidden || editingAddress) {
                TabBarView(workspace: workspace, settings: settings, editing: $editingAddress,
                           leading: oneBar && !chrome.buttonsHidden ? AnyView(oneBarPart(.leading)) : nil,
                           trailing: oneBar && !chrome.buttonsHidden ? AnyView(oneBarPart(.trailing)) : nil,
                           leadingInset: oneBarInTitlebar && !windowIsFullscreen ? 70 : 0)
                    // V22: een te brede balk mag nooit de hele layout breder dan het scherm maken
                    // (dan schoof de pagina op de iPhone naar links en viel de linkerrand weg).
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading).clipped()
                    #if os(macOS)
                    .onHover { chrome.setHovering($0) }
                    #endif
                    .simultaneousGesture(TapGesture().onEnded { chrome.reveal() })
                    .transition(autoHideAnimated ? .move(edge: .top).combined(with: .opacity) : .identity)
            }
            ZStack(alignment: .top) {
                ForEach(workspace.tabs) { tab in
                    TabPlayerView(settings: settings, session: tab.session, selected: workspace.selectedID == tab.id,
                                  actions: actions)
                        .opacity(workspace.selectedID == tab.id ? 1 : 0)
                        .allowsHitTesting(workspace.selectedID == tab.id)
                        .accessibilityHidden(workspace.selectedID != tab.id)
                        .zIndex(workspace.selectedID == tab.id ? 1 : 0)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                if editingAddress {
                    // V16: tapping/clicking anywhere else closes the address bar.
                    Color.black.opacity(0.001).contentShape(Rectangle())
                        .onTapGesture { editingAddress = false }
                        .zIndex(4)
                }
                if findVisible {
                    FindBar(session: workspace.selected.session, visible: $findVisible)
                        #if os(macOS)
                        .padding(.top, settings.toolbarDensity.height + 6)
                        #else
                        .padding(.top, 6)
                        #endif
                        .zIndex(5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity).clipped()
            .animation(theme.anim(.tabs), value: workspace.selectedID)
            .animation(theme.anim(.findBar), value: findVisible)
            .overlay(alignment: .top) {
                if chrome.hidden && autoHideRevealEdge { AutoHideRevealZone(height: 8) }
            }
            .overlay(alignment: .leading) {
                // V21: zijbalk verborgen → muis naar de linkerrand laat hem tijdelijk verschijnen (Arc).
                if useSidebar && sidebarHidden && !sidebarPeek {
                    Color.black.opacity(0.001).frame(width: 6).contentShape(Rectangle())
                        #if os(macOS)
                        .onHover { if $0 { withAnimation(Motion.quick()) { sidebarPeek = true } } }
                        #endif
                        .onTapGesture { withAnimation(Motion.quick()) { sidebarPeek = true } }
                }
            }
        }
        }
        .animation(Motion.quick(0.22), value: sidebarHidden)
        .animation(Motion.quick(0.18), value: sidebarPeek)
        .onReceive(NotificationCenter.default.publisher(for: .joeToepToggleSidebar)) { _ in
            guard BrowserWorkspace.active === workspace || BrowserWorkspace.active == nil else { return }
            sidebarPeek = false; sidebarHidden.toggle()
        }
        // V22.2: via Motion → respecteert "Animaties uit" en de snelheid.
        .animation(autoHideAnimated ? Motion.fade(0.25) : nil, value: chrome.hidden)
        // V21: zwevende zoekbalk (Arc-stijl) boven de pagina.
        .overlay {
            if workspace.showCommandBar {
                CommandBarOverlay(workspace: workspace, settings: settings).zIndex(20)
            }
        }
        .animation(Motion.fade(0.15), value: workspace.showCommandBar)
        // V21 (Mac): de ene balk staat helemaal bovenin, naast de venster-knopjes (zoals Safari).
        .ignoresSafeArea(.container, edges: (oneBarInTitlebar || oneBarInTitlebarForSidebar) && !chrome.tabsHidden ? .top : [])
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in windowIsFullscreen = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in windowIsFullscreen = false }
        #endif
        .onChange(of: editingAddress) { _, editing in if editing { chrome.reveal() } }
        .background(theme.background)
        .environment(\.joeToepTheme, theme)
        .joeToepTextScale(theme.textScale)        // V16.2.1: Settings › Appearance › Text size
        .preferredColorScheme(theme.style.colorScheme)
        .tint(theme.accent)
        .sheet(isPresented: $showingLibrary) {
            LibraryView(library: library, workspace: workspace)
                .environment(\.joeToepTheme, theme)
                .preferredColorScheme(theme.style.colorScheme)
                #if os(macOS)
                .frame(minWidth: 520, idealWidth: 640, minHeight: 480, idealHeight: 620)
                #endif
        }
        .focusedSceneValue(\.workspaceActions, actions)
        // V17: dit venster wordt "actief" zodra het verschijnt; op de Mac starten we dan ook de
        // monitors voor muis-zijknoppen, ⌘←/⌘→ en trackpad-vegen (één keer voor de hele app).
        // V17.1: een link van buitenaf (JoeToep als standaardbrowser, of "Open met") → nieuwe tab.
        .onOpenURL { url in
            // V21: links uit widgets: joetoep://search?p=…, joetoep://open?url=…, joetoep://newtab, joetoep://takeover?device=…
            if url.scheme?.lowercased() == WidgetShared.urlScheme, let host = url.host?.lowercased(),
               ["search", "newtab", "open", "takeover", "library", "nowplaying"].contains(host) {
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                func value(_ n: String) -> String? { items.first { $0.name == n }?.value }
                switch host {
                case "search":
                    // V22: platform alleen voor deze zoekopdracht (je standaard blijft YouTube).
                    workspace.commandBarToken = value("p").flatMap(MediaPlatform.init(rawValue:))
                    workspace.commandBarEditsCurrent = false; workspace.showCommandBar = true
                case "newtab": workspace.requestNewTab()
                case "library": showingLibrary = true
                case "nowplaying": workspace.select(workspace.mediaTab)
                case "takeover": if let d = value("device") { workspace.takeOverFrom(device: d) }
                default:
                    if let raw = value("url"), let target = URL(string: raw) {
                        if let existing = workspace.tabs.first(where: { SyncDiff.sameDestination($0.currentURL, target) }) { workspace.select(existing) }
                        else { workspace.addTab(url: target) }
                    }
                }
                return
            }
            // V18: joetoep://… (Opdrachten/deelmenu-omweg op iPhone/iPad) → gewone webpagina.
            if let web = DefaultBrowser.webURL(fromCustom: url) { workspace.addTab(url: web); return }
            guard ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") else { return }
            workspace.addTab(url: url)
        }
        // V17.1: "Open in nieuw venster" — alleen het actieve venster opent het nieuwe venster.
        .onReceive(NotificationCenter.default.publisher(for: WindowOpener.notification)) { _ in
            guard BrowserWorkspace.active === workspace else { return }
            openWindow(id: "main")
        }
        .onAppear {
            // Een nieuw venster dat voor een link is geopend: die link meteen tonen.
            if let url = WindowOpener.takePending() { workspace.addTab(url: url) }
            BrowserWorkspace.active = workspace
            #if os(macOS)
            MacNavigationMonitor.shared.install()
            #endif
        }
        .onChange(of: workspace.selectedID) { _, _ in editingAddress = false; findVisible = false }
        .onChange(of: settings.keepScreenAwake) { _, _ in workspace.updateIdleTimer() }
        #if os(iOS)
        .background {
            // Hardware-keyboard shortcuts on iPad (and iPhone with a keyboard).
            VStack {
                Button("New Tab") { workspace.requestNewTab() }.keyboardShortcut("t", modifiers: .command)
                Button("New Private Tab") { workspace.addPrivateTab() }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Reopen Closed Tab") { workspace.reopenClosedTab() }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Reload") { workspace.selected.session.reload() }.keyboardShortcut("r", modifiers: .command)
                Button("New window") { openWindow(id: "main") }.keyboardShortcut("n", modifiers: .command)
                Button("Close tab") { workspace.close(workspace.selected) }.keyboardShortcut("w", modifiers: .command)
                Button("Close window") { dismissWindow() }.keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Picture in Picture") { workspace.selected.session.togglePictureInPicture() }.keyboardShortcut("z", modifiers: .option)
                Button("Settings") { actions.openSettings() }.keyboardShortcut(",", modifiers: .command)
                Button("Address") { editingAddress = true }.keyboardShortcut("l", modifiers: .command)
                Button("Find") { showFind() }.keyboardShortcut("f", modifiers: .command)
                Button("Bookmark") { toggleBookmark() }.keyboardShortcut("d", modifiers: .command)
                Button("Library") { showingLibrary = true }.keyboardShortcut("y", modifiers: .command)
                // V17: Option (⌥) + Tab wisselt naar de vorige (recentste) tab, zoals ⌘+Tab bij apps.
                Button("Recent tab") { workspace.selectRecent() }.keyboardShortcut(.tab, modifiers: .option)
                Button("Recent tab (Ctrl)") { workspace.cycleRecent(); workspace.endRecentCycle() }.keyboardShortcut(.tab, modifiers: .control)
                Button("Force refresh") { workspace.selected.session.forceRefresh() }.keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Next tab") { workspace.selectNext() }.keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous tab") { workspace.selectPrevious() }.keyboardShortcut("[", modifiers: [.command, .shift])
                Button("Back") { workspace.selected.session.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button("Forward") { workspace.selected.session.goForward() }.keyboardShortcut("]", modifiers: .command)
                ForEach(1..<10) { number in
                    Button("Tab \(number)") { actions.selectTab(number - 1) }
                        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }
            }.frame(width: 0, height: 0).clipped().accessibilityHidden(true)
        }
        #endif
    }
}

#if os(macOS)
/// V22.3: meldt wanneer het venster van deze werkruimte echt sluit (rode knop of ⇧⌘W).
struct WindowCloseObserver: NSViewRepresentable {
    let onClose: () -> Void
    func makeNSView(context: Context) -> NSView { Probe(onClose: onClose) }
    func updateNSView(_ view: NSView, context: Context) {}
    final class Probe: NSView {
        let onClose: () -> Void
        private var token: NSObjectProtocol?
        init(onClose: @escaping () -> Void) { self.onClose = onClose; super.init(frame: .zero) }
        required init?(coder: NSCoder) { return nil }
        private weak var lastWindow: NSWindow?
        private var fired = false
        private func fire() { guard !fired else { return }; fired = true; onClose() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token); self.token = nil }
            guard let window else {
                // SwiftUI haalt de inhoud soms al uit het venster vóór "willClose": kijk even later of het
                // venster echt weg is (niet zichtbaar / niet meer in de app).
                let previous = lastWindow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    if let previous { if !previous.isVisible || !NSApp.windows.contains(previous) { self.fire() } }
                    else { self.fire() }
                }
                return
            }
            lastWindow = window
            token = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fire() }
            }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}
#endif
