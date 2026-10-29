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
        lastActive = saved.lastActive ?? Date(); pinned = saved.pinned ?? false
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
    private let store: TabSessionStore
    var selected: BrowserTab { tabs.first(where: { $0.id == selectedID }) ?? tabs[0] }
    var selectedIndex: Int { tabs.firstIndex(where: { $0.id == selectedID }) ?? 0 }
    init(store suppliedStore: TabSessionStore? = nil) {
        let store = suppliedStore ?? Self.defaultStore
        self.store = store
        if let saved = store.restore(lifetime: TabLifetime.stored().seconds) {
            tabs = saved.tabs.map { BrowserTab(saved: $0) }; selectedID = saved.selectedID
        } else {
            let first = BrowserTab(); tabs = [first]; selectedID = first.id
        }
        tabs.forEach(observe)
        claimSync()
        persist()
        startExpiryChecks()
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
        for tab in expired where tabs.count > 1 { close(tab, remember: false) }
    }
    private func persist() {
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
        case .seek: mediaTab.session.remoteSeek(by: command.value ?? 10)
        case .rate: mediaTab.session.stepPlaybackRate(Int(command.value ?? 1))
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
                return SyncTab(id: tab.id, url: saved.url, title: tab.fullTitle, pinned: tab.pinned, time: saved.time)
            }
            let selection = kept.contains(where: { $0.id == self.selectedID }) ? self.selectedID : kept[0].id
            let playing = kept.first { $0.session.isPlaying }?.id
            TabSyncService.shared.publish(tabs: tabs, selectedID: selection, playingID: playing)
        }
    }

    /// Past de tabs van een ander apparaat hier toe: nieuwe tabs erbij, gesloten tabs weg,
    /// dezelfde volgorde en selectie, en de video op dezelfde plek.
    func applyRemote(_ snapshot: SyncSnapshot, merge: Bool = false) {
        applyingRemote = true
        defer {
            applyingRemote = false; persistWithoutSync()
            // Samengevoegd? Dan heeft dit apparaat nu méér dan de afzender: dat terugsturen,
            // zodat iedereen op dezelfde (volledige) lijst uitkomt.
            if merge { publishSync() }
        }
        // 1. Speelt het andere apparaat? Dan stoppen we hier (één apparaat tegelijk).
        if snapshot.playingID != nil {
            for tab in tabs where tab.session.isPlaying || tab.session.isInPictureInPicture { tab.session.pauseForRemotePlayback() }
        }
        let locals = tabs.filter { !$0.isPrivate }
        let diff = SyncDiff.plan(local: locals.map { ($0.id, $0.currentURL) }, remote: snapshot.tabs)
        // 2. Nieuwe tabs (eerst toevoegen, zodat er nooit nul tabs zijn).
        for remote in diff.add {
            let tab = BrowserTab(saved: SavedBrowserTab(id: remote.id, url: remote.url, time: remote.time, playing: false,
                                                        lastActive: Date(), pinned: remote.pinned ? true : nil, title: remote.title))
            tab.session.syncedStartPaused = true
            tabs.append(tab); observe(tab)
        }
        // 3. Andere pagina in een bestaande tab: NIET meteen laden (je kijkt nu op het andere
        //    apparaat en wilt hier geen beelden zien). Pas toepassen als je dit apparaat weer
        //    gebruikt (klik/toets/aanraking, app actief, of die tab kiezen).
        for change in diff.navigate {
            pendingNavigation[change.id] = (change.url, snapshot.tabs.first { $0.id == change.id }?.time)
        }
        // 4. Gesloten tabs (niet onthouden in "heropen": dat deed het andere apparaat al).
        for id in diff.remove where !merge {
            guard let tab = tabs.first(where: { $0.id == id }), tabs.count > 1 else { continue }
            close(tab, remember: false)
        }
        // 5. Vastpinnen + volgorde (privé-tabs blijven achteraan staan).
        for remote in snapshot.tabs { tabs.first { $0.id == remote.id }?.pinned = remote.pinned }
        let order = Dictionary(uniqueKeysWithValues: diff.order.enumerated().map { ($1, $0) })
        let sorted = tabs.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        if sorted.map(\.id) != tabs.map(\.id) { tabs = sorted }
        // 6. Afspeelpositie onthouden (ook pas toepassen bij terugkomst).
        for remote in snapshot.tabs {
            guard let time = remote.time, tabs.contains(where: { $0.id == remote.id }) else { continue }
            pendingPosition[remote.id] = time
        }
        // 7. Selectie: onthouden, toepassen zodra je hier weer verder gaat.
        if tabs.contains(where: { $0.id == snapshot.selectedID }) { pendingSelection = snapshot.selectedID }
        tabs.forEach { $0.syncPending = pendingNavigation[$0.id] != nil }
    }

    // MARK: V18 — uitgestelde toepassing ("verder waar je was" op het apparaat waar je naartoe gaat)
    private var pendingNavigation: [UUID: (url: URL, time: Double?)] = [:]
    private var pendingPosition: [UUID: Double] = [:]
    private var pendingSelection: UUID?

    /// Roep aan zodra de gebruiker dit apparaat weer gebruikt. Zet selectie, pagina en positie
    /// gelijk met het apparaat waar je vandaan komt — gepauzeerd, klaar om verder te kijken.
    func resumeFromOtherDevice() {
        guard pendingSelection != nil || !pendingNavigation.isEmpty || !pendingPosition.isEmpty else { return }
        let localPlaying = tabs.contains { $0.session.isPlaying || $0.session.isInPictureInPicture }
        if !localPlaying, let target = pendingSelection, target != selectedID, tabs.contains(where: { $0.id == target }) {
            selected.session.leaveFullscreenForTabSwitch()
            selectedID = target
            selected.lastActive = Date()
        }
        pendingSelection = nil
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
        let kept = tabs.filter { !$0.isPrivate }
        guard !kept.isEmpty else { return }
        let selection = kept.contains(where: { $0.id == selectedID }) ? selectedID : kept[0].id
        store.save(SavedTabSession(tabs: kept.map { Self.saved($0) }, selectedID: selection), window: windowID)
    }
    /// Current URL plus, when it is the same video, its last known position.
    private static func saved(_ tab: BrowserTab, url override: URL? = nil) -> SavedBrowserTab {
        let session = tab.session
        let url = override ?? session.currentURL ?? session.restoredURL
        var result = SavedBrowserTab(id: tab.id, url: url, lastActive: tab.lastActive, pinned: tab.pinned ? true : nil, title: tab.title)
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
        tab.session.onOpenInNewTab = { [weak self, weak tab] url, activate in
            self?.openInNewTab(url, activate: activate, from: tab)
        }
        // V17: "terug" terwijl er geen vorige pagina is → deze tab sluiten (als dat aan staat).
        tab.session.onCannotGoBack = { [weak self, weak tab] in
            guard let self, let tab else { return }
            self.closeFromBack(tab)
        }
        urlObservers[tab.id] = tab.session.$currentURL.dropFirst().sink { [weak self, weak tab] url in
            guard let self, let tab, let url, !tab.isPrivate else { return }
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
        resumeObservers[tab.id] = tab.session.$resumePoint.dropFirst().removeDuplicates().sink { [weak self] _ in
            // @Published fires before the value is stored; persist on the next turn.
            DispatchQueue.main.async { self?.persist() }
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
                self.handOver(to: tab)                // pause / close PiP of every other tab
            }
            // Keep the screen awake while any tab plays (iPhone/iPad setting). `async` runs it
            // a moment later, after all tabs have updated their state.
            DispatchQueue.main.async { self.updateIdleTimer(); self.publishSync() }
        }
    }
    /// V15: keep the screen on while any tab plays (setting).
    func updateIdleTimer() {
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
    private func handOver(to tab: BrowserTab) {
        var closingPiP: [BrowserTab] = []      // tabs whose PiP window we are closing
        for other in tabs where other.id != tab.id {          // every tab except the new one
            if other.session.isInPictureInPicture {
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
        if url == nil { tab.session.focusSearchWhenReady = true }
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
    func select(_ tab: BrowserTab) {
        Self.active = self
        // Eigen keuze gaat voor; de rest van wat het andere apparaat deed nu toepassen.
        pendingSelection = nil
        resumeFromOtherDevice()
        guard tab.id != selectedID else { return }
        leaveCurrent()
        selectedID = tab.id; tab.lastActive = Date(); persist()
    }
    func select(index: Int) {
        guard !tabs.isEmpty else { return }
        select(tabs[min(max(index, 0), tabs.count - 1)])
    }
    func selectNext() { select(index: (selectedIndex + 1) % max(tabs.count, 1)) }
    func selectPrevious() { select(index: (selectedIndex - 1 + tabs.count) % max(tabs.count, 1)) }
    func close(_ tab: BrowserTab) { close(tab, remember: true) }
    func close(_ tab: BrowserTab, remember: Bool) {
        guard tabs.count > 1 else {
            tab.session.goHome(); return
        }
        if remember && !tab.isPrivate {
            closedTabs.insert(Self.saved(tab), at: 0)
            if closedTabs.count > 25 { closedTabs.removeLast() }
        }
        tab.session.closeTab()
        playbackObservers[tab.id] = nil; urlObservers[tab.id] = nil; resumeObservers[tab.id] = nil; titleObservers[tab.id] = nil
        let index = tabs.firstIndex(where: { $0.id == tab.id })!
        tabs.remove(at: index)
        if selectedID == tab.id { selectedID = tabs[min(index, tabs.count - 1)].id }
        persist(); updateIdleTimer()
    }
    func closeOthers(_ keep: BrowserTab) {
        for tab in tabs where tab.id != keep.id && !tab.pinned { close(tab) }
        select(keep)
    }
    func closeToTheRight(of anchor: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == anchor.id }) else { return }
        for tab in tabs.suffix(from: index + 1) where !tab.pinned { close(tab) }
    }
    func reopenClosedTab() {
        guard !closedTabs.isEmpty else { return }
        var saved = closedTabs.removeFirst()
        saved.lastActive = Date()
        leaveCurrent()
        let tab = BrowserTab(saved: saved)
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
    @State private var showingLibrary = false
    @State private var findVisible = false
    /// V18: download die offline wordt afgespeeld (vanaf de Watch).
    @State private var offlineItem: DownloadItem?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var actions: WorkspaceActions {
        WorkspaceActions(
            newTab: workspace.addTab, closeTab: { workspace.close(workspace.selected) },
            pictureInPicture: { workspace.selected.session.togglePictureInPicture() },
            closeWindow: { dismissWindow() }, reload: { workspace.selected.session.reload() },
            openSettings: { NotificationCenter.default.post(name: .joeToepOpenSettings, object: workspace.selected.session) },
            newPrivateTab: workspace.addPrivateTab, reopenClosedTab: workspace.reopenClosedTab,
            editAddress: { editingAddress = true }, find: showFind,
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
            .sheet(item: $offlineItem) { OfflinePlayer(item: $0) }
            .onReceive(NotificationCenter.default.publisher(for: DownloadManager.playOffline)) { note in
                guard BrowserWorkspace.active === workspace || BrowserWorkspace.active == nil,
                      let id = note.object as? UUID else { return }
                workspace.mediaTab.session.pauseForRemotePlayback()
                offlineItem = DownloadManager.shared.items.first { $0.id == id }
            }
            .onAppear {
                TabSyncService.shared.bind(to: settings)
                #if os(iOS)
                WatchBridge.shared.activate(workspace: workspace)
                #endif
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                TabSyncService.shared.resume(); workspace.publishSync()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                workspace.resumeFromOtherDevice()
            }
            // Elke aanraking = "ik gebruik dit apparaat weer" → verder waar je op het andere was.
            .simultaneousGesture(TapGesture().onEnded { workspace.resumeFromOtherDevice() })
            #else
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                TabSyncService.shared.resume(); workspace.resumeFromOtherDevice()
            }
            .onAppear {
                // Mac: een klik, toets of scroll in JoeToep telt als "weer op dit apparaat".
                UserActivityMonitor.shared.install { BrowserWorkspace.active?.resumeFromOtherDevice() }
            }
            #endif
    }

    @ViewBuilder private func content(_ theme: JoeToepTheme) -> some View {
        VStack(spacing: 0) {
            TabBarView(workspace: workspace, settings: settings, editing: $editingAddress)
            ZStack(alignment: .top) {
                ForEach(workspace.tabs) { tab in
                    TabPlayerView(settings: settings, session: tab.session, selected: workspace.selectedID == tab.id,
                                  actions: actions)
                        .opacity(workspace.selectedID == tab.id ? 1 : 0)
                        .allowsHitTesting(workspace.selectedID == tab.id)
                        .accessibilityHidden(workspace.selectedID != tab.id)
                        .zIndex(workspace.selectedID == tab.id ? 1 : 0)
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
            .animation(theme.anim(.tabs), value: workspace.selectedID)
            .animation(theme.anim(.findBar), value: findVisible)
        }
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
                Button("New Tab") { workspace.addTab() }.keyboardShortcut("t", modifiers: .command)
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
