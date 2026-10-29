import Foundation
import MultipeerConnectivity
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// V18 — Live tab-synchronisatie tussen Mac, iPad en iPhone.
///
/// Werkt zonder iCloud of server: de apparaten vinden elkaar via Bonjour (wifi) of
/// peer-to-peer wifi/Bluetooth (MultipeerConnectivity) en sturen elkaar bij elke wijziging een
/// complete snapshot. Berichten zijn klein (enkele kB) en gaan "reliable" (volgorde + aflevering
/// gegarandeerd), dus een wijziging staat binnen een fractie van een seconde op de andere apparaten.
@MainActor
final class TabSyncService: NSObject, ObservableObject {
    static let shared = TabSyncService()
    static let serviceType = "joetoep-sync"

    /// Namen van verbonden apparaten (voor Instellingen › Sync & devices en de Watch).
    @Published private(set) var peers: [String] = []
    @Published private(set) var lastSync: Date?
    /// Apparaat-id's van verbonden apparaten, met hun naam (voor "speel af op …").
    @Published private(set) var devices: [String: String] = [:]
    /// Laatste snapshot per apparaat (ook als hij niet "won"): wat speelt waar (voor de Watch).
    @Published private(set) var latestByDevice: [String: SyncSnapshot] = [:]

    let deviceID: String
    let deviceName: String
    private var ledger: SyncLedger
    private let peerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var peerDevice: [MCPeerID: String] = [:]
    private var running = false
    private var enabledObserver: AnyCancellable?

    /// Het venster dat synchroniseert (zwak: sluit je het, dan neemt het volgende het over).
    weak var owner: BrowserWorkspace?
    /// De werkruimte die snapshots toepast (de eerste/actieve vensterwerkruimte).
    /// Komt er een snapshot binnen vóórdat er een venster is (iOS start de sync al bij het
    /// opstarten), dan bewaren we hem en passen we hem toe zodra het venster er is.
    /// Tweede waarde `merge`: true bij het EERSTE contact met dat apparaat in deze sessie →
    /// samenvoegen (geen tabs weggooien die alleen hier open staan), daarna gewoon gelijk trekken.
    var onSnapshot: ((SyncSnapshot, Bool) -> Void)? {
        didSet { if let pending = pendingSnapshot, let onSnapshot { pendingSnapshot = nil; onSnapshot(pending.0, pending.1) } }
    }
    private var pendingSnapshot: (SyncSnapshot, Bool)?
    /// Apparaten waarmee we deze sessie al hebben samengevoegd.
    private var mergedOrigins: Set<String> = []

    // MARK: Status per apparaat (voor Instellingen › Sync & devices en de diagnose)
    struct PeerState: Equatable {
        var name: String
        var ackedVersion: UInt64 = 0
        var tabCount = 0
        var lastSeen = Date()
    }
    /// Per apparaat-id: bevestigde versie (ack) en aantal tabs.
    @Published private(set) var peerStates: [String: PeerState] = [:]
    /// Laatste gebeurtenissen (nieuwste bovenaan), max. 30 — voor de diagnose in Instellingen.
    @Published private(set) var log: [String] = []
    var currentVersion: UInt64 { ledger.current?.version ?? 0 }
    private func note(_ text: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        log.insert("\(stamp)  \(text)", at: 0)
        if log.count > 30 { log.removeLast() }
    }
    /// Opdracht voor DIT apparaat (bijv. "speel deze video af" vanaf de Watch).
    var onCommand: ((SyncCommand) -> Void)?

    private var isTesting: Bool { ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil }

    override init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "syncDeviceIDV18") { deviceID = saved } else {
            let fresh = UUID().uuidString; defaults.set(fresh, forKey: "syncDeviceIDV18"); deviceID = fresh
        }
        #if os(iOS)
        let model = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        deviceName = UIDevice.current.name.isEmpty ? model : UIDevice.current.name
        #else
        deviceName = Host.current().localizedName ?? "Mac"
        #endif
        ledger = SyncLedger(deviceID: deviceID)
        // MCPeerID-namen zijn max. 63 bytes; kort houden.
        peerID = MCPeerID(displayName: String(deviceName.prefix(40)))
        super.init()
    }

    /// Start/stopt volgens de instelling "Live tab sync" (standaard aan).
    func bind(to settings: AppSettings) {
        enabledObserver = settings.$tabSync.removeDuplicates().sink { [weak self] on in
            on ? self?.start() : self?.stop()
        }
    }

    func start() {
        guard !running, !isTesting || ProcessInfo.processInfo.arguments.contains("--sync-test") else { return }
        running = true
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        let info = ["id": deviceID]
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        advertiser.delegate = self; advertiser.startAdvertisingPeer()
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self; browser.startBrowsingForPeers()
        self.advertiser = advertiser; self.browser = browser
        note("sync started as \(deviceName)")
        // Vangnet: elke 4 s, als er geen enkel apparaat verbonden is, opnieuw zoeken én adverteren.
        // (MultipeerConnectivity meldt een apparaat maar één keer; na een verbroken verbinding
        //  of een app die even op de achtergrond stond, moet je zelf opnieuw beginnen.)
        scheduleReconnect()
    }

    /// Zoekt opnieuw zolang er géén apparaat verbonden is, en stopt vanzelf zodra er één is
    /// (dus geen doorlopende timer als alles werkt).
    private var reconnectTask: Task<Void, Never>?
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor [weak self] in
            for _ in 0..<180 {                           // max. ±6 minuten, daarna bij volgende activatie weer
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.running else { return }
                if !(self.session?.connectedPeers.isEmpty ?? true) { return }
                self.restartDiscovery()
            }
        }
    }

    private var lastRestart = Date.distantPast
    /// Apparaten die de browser ooit vond (blijven bekend, ook na een verbroken verbinding).
    fileprivate var foundPeers: [MCPeerID: String] = [:]
    /// Gestopte browsers/adverteerders blijven bewaard (voorkomt de "opgeruimd maar nog aangeroepen"-crash).
    private var retired: [AnyObject] = []
    /// V19.2 — Opnieuw verbinden ZONDER de Bonjour-browser te stoppen. Stoppen/vervangen van de
    /// browser liet macOS crashen (Bonjour riep nog een al opgeruimde browser aan: `_MonitorCancel`
    /// in je crashlog). De browser blijft nu de hele sessie draaien; we nodigen de apparaten die
    /// hij al kende gewoon opnieuw uit. Hooguit eens per 8 s.
    private func restartDiscovery() {
        guard running, let session, Date().timeIntervalSince(lastRestart) >= 4 else { return }
        lastRestart = Date()
        for (peer, otherID) in foundPeers where otherID != deviceID && !session.connectedPeers.contains(peer) {
            browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
        }
    }

    func stop() {
        guard running else { return }
        running = false
        reconnectTask?.cancel(); reconnectTask = nil
        advertiser?.stopAdvertisingPeer(); browser?.stopBrowsingForPeers()
        session?.disconnect()
        // Niet vrijgeven: Bonjour kan na het stoppen nog even terugroepen (crash-oorzaak in 19.1).
        if let browser { retired.append(browser) }
        if let advertiser { retired.append(advertiser) }
        advertiser = nil; browser = nil; session = nil; foundPeers = [:]
        peerDevice = [:]; refreshPeers()
    }

    /// Na terugkomst uit de achtergrond (iOS verbreekt verbindingen): opnieuw zoeken en de
    /// eigen toestand meteen opnieuw delen.
    func resume() {
        guard UserDefaults.standard.object(forKey: "tabSyncV18") as? Bool ?? true else { return }
        if !running { start(); return }
        // V22: meteen (en nog twee keer kort daarna) opnieuw uitnodigen — sneller weer verbonden.
        lastRestart = .distantPast; restartDiscovery(); scheduleReconnect()
        Task { @MainActor [weak self] in
            for delay in [600, 1500] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard let self, self.running, self.session?.connectedPeers.isEmpty ?? false else { return }
                self.lastRestart = .distantPast; self.restartDiscovery()
            }
        }
        if let current = ledger.current { broadcast(.snapshot(current)) }
    }

    // MARK: Publiceren

    /// Roep aan bij élke lokale wijziging. Stuurt alleen als de inhoud echt veranderde.
    func publish(tabs: [SyncTab], selectedID: UUID, playingID: UUID?, handoff: (id: UUID, time: Double)? = nil, force: Bool = false) {
        guard let snapshot = ledger.makeLocal(name: deviceName, tabs: tabs, selectedID: selectedID, playingID: playingID,
                                              handoff: handoff, force: force) else { return }
        lastSync = Date()
        broadcast(.snapshot(snapshot))
        WidgetBridge.shared.setNeedsUpdate()
    }

    private var lastDownloads: [DownloadItem] = []
    /// V18: laat de andere apparaten weten welke downloads hier klaarstaan.
    func publishDownloads(_ items: [DownloadItem]) {
        lastDownloads = items
        broadcast(.downloads(DownloadListing(origin: deviceID, originName: deviceName, items: items)))
    }

    /// Stuurt een opdracht naar één apparaat (of voert hem zelf uit als dat dit apparaat is).
    func send(_ command: SyncCommand) {
        if command.target == deviceID { onCommand?(command); return }
        broadcast(.command(command))
    }

    private func broadcast(_ message: SyncMessage) {
        guard let session, !session.connectedPeers.isEmpty, let data = message.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: Ontvangen

    fileprivate func handle(_ data: Data, from peer: MCPeerID) {
        guard let message = SyncMessage.decode(data) else { return }
        defer { WidgetBridge.shared.setNeedsUpdate() }
        switch message {
        case .hello(let id, let name):
            peerDevice[peer] = id; devices[id] = name
            refreshPeers()
        case .snapshot(let snapshot):
            peerDevice[peer] = snapshot.origin; devices[snapshot.origin] = snapshot.originName
            latestByDevice[snapshot.origin] = snapshot
            let accepted = ledger.receive(snapshot)
            // Altijd bevestigen (ook als hij niet won): zo ziet de afzender dat we bij zijn.
            sendAck(to: peer)
            guard let accepted else { note("ignored older v\(snapshot.version % 100000) from \(snapshot.originName)"); return }
            lastSync = Date()
            note("applied \(accepted.tabs.count) tabs from \(accepted.originName)")
            let merge = mergedOrigins.insert(accepted.origin).inserted
            if let onSnapshot { onSnapshot(accepted, merge) } else { pendingSnapshot = (accepted, merge) }
        case .ack(let id, let name, let version, let tabs):
            var state = peerStates[id] ?? PeerState(name: name)
            state.name = name; state.ackedVersion = max(state.ackedVersion, version); state.tabCount = tabs; state.lastSeen = Date()
            peerStates[id] = state; devices[id] = name
        case .command(let command):
            if command.target == deviceID { onCommand?(command) }
        case .downloads(let listing):
            devices[listing.origin] = listing.originName
            DownloadManager.shared.receive(listing)
        case .spotify(let id, let state):
            peerDevice[peer] = id
            SpotifyController.shared.receive(state, from: id)
        case .spotifyCommand(let target, let action, let value, let uri):
            if target == deviceID { SpotifyController.shared.performRemote(action, value: value, uri: uri) }
        }
    }

    private func sendAck(to peer: MCPeerID) {
        guard let session, let current = ledger.current,
              let data = SyncMessage.ack(deviceID: deviceID, name: deviceName, version: current.version, tabs: current.tabs.count).encoded()
        else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    fileprivate func connected(_ peer: MCPeerID) {
        refreshPeers()
        note("connected: \(peer.displayName)")
        guard let session, let hello = SyncMessage.hello(deviceID: deviceID, name: deviceName).encoded() else { return }
        try? session.send(hello, toPeers: [peer], with: .reliable)
        if let spotify = lastSpotify, let data = SyncMessage.spotify(deviceID: deviceID, state: spotify).encoded() {
            try? session.send(data, toPeers: [peer], with: .reliable)
        }
        // Nieuw apparaat: meteen de huidige toestand sturen, zodat het direct gelijk loopt.
        if let current = ledger.current, let data = SyncMessage.snapshot(current).encoded() {
            try? session.send(data, toPeers: [peer], with: .reliable)
        }
        let listing = DownloadListing(origin: deviceID, originName: deviceName, items: lastDownloads)
        if let data = SyncMessage.downloads(listing).encoded() { try? session.send(data, toPeers: [peer], with: .reliable) }
    }

    fileprivate func disconnected(_ peer: MCPeerID) {
        if let id = peerDevice.removeValue(forKey: peer) { devices[id] = nil; peerStates[id] = nil; SpotifyController.shared.forget(deviceID: id) }
        refreshPeers()
        note("disconnected: \(peer.displayName) — searching again")
        if running && (session?.connectedPeers.isEmpty ?? true) { scheduleReconnect() }
    }

    /// V21: overdracht-gebeurtenissen in het sync-logboek (Instellingen › Sync & devices).
    func noteHandoff(_ text: String) { note("handoff: " + text) }

    // MARK: V20 — Spotify via sync

    private var lastSpotify: SpotifyState?
    func publishSpotify(_ state: SpotifyState) {
        lastSpotify = state
        broadcast(.spotify(deviceID: deviceID, state: state))
    }
    func sendSpotify(_ action: SpotifyAction, value: Double?, uri: String?, to target: String) {
        broadcast(.spotifyCommand(target: target, action: action, value: value, uri: uri))
    }

    private func refreshPeers() {
        peers = (session?.connectedPeers ?? []).map(\.displayName).sorted()
        WidgetBridge.shared.setNeedsUpdate()
    }

    /// Voor tests: past een snapshot toe alsof hij van een ander apparaat kwam.
    func simulateReceive(_ snapshot: SyncSnapshot) {
        guard let accepted = ledger.receive(snapshot) else { return }
        onSnapshot?(accepted, false)
    }
}

// MARK: - MultipeerConnectivity-delegates (komen binnen op een achtergrondthread → hoofdthread)

extension TabSyncService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.connected(peerID)
            case .notConnected: self.disconnected(peerID)
            default: break
            }
        }
    }
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.handle(data, from: peerID) }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension TabSyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Alleen JoeToep-apparaten kunnen ons vinden (eigen servicetype); altijd accepteren.
            invitationHandler(self.session != nil, self.session)
        }
    }
}

extension TabSyncService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let otherID = info?["id"], otherID != self.deviceID else { return }
            self.foundPeers[peerID] = otherID
            guard let session = self.session, !session.connectedPeers.contains(peerID) else { return }
            // Normaal nodigt alleen de kant met de kleinste id uit (geen dubbele verbindingen).
            // Staat die kant op de achtergrond, dan nodigt de andere kant na 3 s alsnog uit.
            if self.deviceID < otherID {
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard let session = self.session, !session.connectedPeers.contains(peerID) else { return }
                    self.browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
                }
            }
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.foundPeers[peerID] = nil }
    }
}
