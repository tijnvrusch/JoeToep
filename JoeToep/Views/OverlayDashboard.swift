// V22 — Aanpasbaar dashboard in de nieuwe-tab-overlay (alle apparaten).
//
// Onder het zoekveld staan blokken die je zelf kiest en in volgorde sleept: platforms, wat er
// nu speelt (met bediening), je andere apparaten (overnemen / pauzeren op afstand), Spotify,
// snelle acties, favorieten, recent bekeken en open tabs. Tik op het schuifjes-icoon in de
// overlay om te bewerken: oogje = aan/uit, sleep (of pijltjes) = volgorde.
import SwiftUI

enum OverlaySection: String, CaseIterable, Codable, Identifiable {
    case platforms, nowPlaying, devices, spotify, quickActions, favorites, recent, tabs
    var id: String { rawValue }
    var title: String {
        switch self {
        case .platforms: "Platforms"
        case .nowPlaying: "Now Playing"
        case .devices: "Other Devices"
        case .spotify: "Spotify"
        case .quickActions: "Quick Actions"
        case .favorites: "Favourites"
        case .recent: "Continue Watching"
        case .tabs: "Open Tabs"
        }
    }
    var symbol: String {
        switch self {
        case .platforms: "square.grid.2x2"
        case .nowPlaying: "play.rectangle"
        case .devices: "laptopcomputer.and.iphone"
        case .spotify: "music.note"
        case .quickActions: "bolt"
        case .favorites: "star"
        case .recent: "clock.arrow.circlepath"
        case .tabs: "square.on.square"
        }
    }
}

/// Snelle acties die je in het dashboard kunt tonen.
enum OverlayAction: String, CaseIterable, Codable, Identifiable {
    case pip, audioOnly, loop, boost, frame, privateTab, reopen, sidebar, pauseAll, sleep, copyLink, reload, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pip: "PiP"
        case .audioOnly: "Audio only"
        case .loop: "Loop"
        case .boost: "Boost"
        case .frame: "Frame"
        case .privateTab: "Private"
        case .reopen: "Reopen"
        case .sidebar: "Sidebar"
        case .pauseAll: "Pause all"
        case .sleep: "Sleep 30m"
        case .copyLink: "Copy link"
        case .reload: "Reload"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .pip: "pip"
        case .audioOnly: "waveform"
        case .loop: "repeat"
        case .boost: "speaker.plus"
        case .frame: "camera"
        case .privateTab: "eyeglasses"
        case .reopen: "arrow.uturn.backward"
        case .sidebar: "sidebar.left"
        case .pauseAll: "pause.circle"
        case .sleep: "moon.zzz"
        case .copyLink: "link"
        case .reload: "arrow.clockwise"
        case .settings: "gearshape"
        }
    }
    @MainActor func run(_ ws: BrowserWorkspace) {
        let s = ws.selected.session
        switch self {
        case .pip: s.togglePictureInPicture()
        case .audioOnly: MediaExtras.shared.toggleAudioOnly(on: s)
        case .loop: MediaExtras.shared.toggleLoop(on: s)
        case .boost: MediaExtras.shared.setBoost(MediaExtras.shared.state(for: s).boost > 1 ? 1 : 2, on: s)
        case .frame: MediaExtras.shared.captureFrame(from: s)
        case .privateTab: ws.addPrivateTab()
        case .reopen: ws.reopenClosedTab()
        case .sidebar: NotificationCenter.default.post(name: .joeToepToggleSidebar, object: nil)
        case .pauseAll: MediaHub.shared.scan(); MediaHub.shared.pauseAll()
        case .sleep: SpotifyCoordinator.shared.startSleepTimer(minutes: 30)
        case .copyLink: if let url = ws.selected.currentURL { Clipboard.copy(url) }
        case .reload: s.reload()
        case .settings: NotificationCenter.default.post(name: .joeToepOpenSettings, object: s)
        }
    }
}

struct OverlayLayout: Codable, Equatable {
    var order: [OverlaySection] = [.nowPlaying, .devices, .platforms, .spotify, .quickActions, .favorites, .recent, .tabs]
    var hidden: Set<OverlaySection> = [.tabs]
    var actions: [OverlayAction] = [.pip, .audioOnly, .loop, .boost, .reopen, .privateTab, .pauseAll, .settings]
    var favouriteCount = 8
    var recentCount = 4
    var compact = false

    /// Alle secties precies één keer (nieuwe secties uit een update komen achteraan).
    var normalizedOrder: [OverlaySection] {
        var seen = Set<OverlaySection>()
        return (order + OverlaySection.allCases).filter { seen.insert($0).inserted }
    }
}

// V22.2: soepel decoderen (in een extensie, zodat OverlayLayout() blijft bestaan). Ontbrekende
// velden krijgen hun standaardwaarde en onbekende secties/acties (uit een andere versie) worden
// overgeslagen, i.p.v. dat de hele opgeslagen indeling wegvalt. encode(to:) blijft gesynthetiseerd.
extension OverlayLayout {
    private enum LenientKeys: String, CodingKey { case order, hidden, actions, favouriteCount, recentCount, compact }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: LenientKeys.self)
        if let raw = try? c.decodeIfPresent([String].self, forKey: .order) { order = raw.compactMap(OverlaySection.init(rawValue:)) }
        if let raw = try? c.decodeIfPresent([String].self, forKey: .hidden) { hidden = Set(raw.compactMap(OverlaySection.init(rawValue:))) }
        if let raw = try? c.decodeIfPresent([String].self, forKey: .actions) { actions = raw.compactMap(OverlayAction.init(rawValue:)) }
        if let v = try? c.decodeIfPresent(Int.self, forKey: .favouriteCount) { favouriteCount = v }
        if let v = try? c.decodeIfPresent(Int.self, forKey: .recentCount) { recentCount = v }
        if let v = try? c.decodeIfPresent(Bool.self, forKey: .compact) { compact = v }
    }
}

@MainActor
final class OverlayLayoutStore: ObservableObject {
    static let shared = OverlayLayoutStore()
    private let key = "overlayLayoutV22"
    @Published var layout: OverlayLayout { didSet { save() } }
    @Published var dashboardEnabled: Bool { didSet { UserDefaults.standard.set(dashboardEnabled, forKey: "overlayDashboardV22") } }

    private init() {
        if let data = UserDefaults.standard.data(forKey: "overlayLayoutV22"),
           let decoded = try? JSONDecoder().decode(OverlayLayout.self, from: data) { layout = decoded } else { layout = OverlayLayout() }
        dashboardEnabled = UserDefaults.standard.object(forKey: "overlayDashboardV22") as? Bool ?? true
    }
    private func save() { if let data = try? JSONEncoder().encode(layout) { UserDefaults.standard.set(data, forKey: key) } }

    func isVisible(_ s: OverlaySection) -> Bool { !layout.hidden.contains(s) }
    func toggle(_ s: OverlaySection) { if layout.hidden.contains(s) { layout.hidden.remove(s) } else { layout.hidden.insert(s) } }
    func move(_ s: OverlaySection, before target: OverlaySection) {
        var order = layout.normalizedOrder
        guard s != target, let from = order.firstIndex(of: s) else { return }
        order.remove(at: from)
        let to = order.firstIndex(of: target) ?? order.count
        order.insert(s, at: to)
        layout.order = order
    }
    func step(_ s: OverlaySection, by offset: Int) {
        var order = layout.normalizedOrder
        guard let i = order.firstIndex(of: s) else { return }
        let j = min(max(i + offset, 0), order.count - 1)
        guard i != j else { return }
        order.swapAt(i, j); layout.order = order
    }
    func toggleAction(_ a: OverlayAction) {
        if let i = layout.actions.firstIndex(of: a) { layout.actions.remove(at: i) } else { layout.actions.append(a) }
    }
    func reset() { layout = OverlayLayout() }
}

struct OverlayDashboard: View {
    @ObservedObject var workspace: BrowserWorkspace
    @Binding var token: MediaPlatform?
    @Binding var editing: Bool
    let open: (URL) -> Void
    let close: () -> Void
    @ObservedObject private var store = OverlayLayoutStore.shared
    @ObservedObject private var library = BrowserLibrary.shared
    @ObservedObject private var sync = TabSyncService.shared
    @ObservedObject private var spotify = SpotifyController.shared
    @Environment(\.joeToepTheme) private var theme

    private var sections: [OverlaySection] {
        editing ? store.layout.normalizedOrder : store.layout.normalizedOrder.filter { store.isVisible($0) && hasContent($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: store.layout.compact ? 8 : 12) {
            if editing { editHeader }
            ForEach(sections) { section in
                sectionView(section)
                    .opacity(editing && !store.isVisible(section) ? 0.45 : 1)
                    .draggable(section.rawValue) { Label(section.title, systemImage: section.symbol).padding(8).background(.thinMaterial, in: Capsule()) }
                    .dropDestination(for: String.self) { items, _ in
                        guard editing, let raw = items.first, let s = OverlaySection(rawValue: raw) else { return false }
                        withAnimation(Motion.quick()) { store.move(s, before: section) }
                        return true
                    }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .animation(Motion.quick(0.2), value: store.layout)
        .onAppear { spotify.beginObserving() }
        .onDisappear { spotify.endObserving() }
    }

    private func hasContent(_ s: OverlaySection) -> Bool {
        switch s {
        case .nowPlaying: return workspace.mediaTab.session.isPlaying || NavigationPolicy.isPlaybackPage(workspace.mediaTab.currentURL)
        case .devices: return !otherDevices.isEmpty
        case .spotify: return spotify.current?.hasTrack == true
        case .favorites: return !library.bookmarks.isEmpty
        case .recent: return library.history.contains { NavigationPolicy.isPlaybackPage($0.url) }
        case .tabs: return workspace.tabs.count > 1
        case .platforms, .quickActions: return true
        }
    }

    // MARK: Bewerken

    private var editHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Customize").font(.headline)
                Spacer()
                Toggle("Compact", isOn: $store.layout.compact).toggleStyle(.switch).controlSize(.mini).fixedSize()
                Button("Reset") { store.reset() }.buttonStyle(.borderless)
                Button("Done") { withAnimation(Motion.quick()) { editing = false } }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            Text("Drag blocks to reorder, tap the eye to show or hide.").font(.caption).foregroundStyle(theme.secondary)
        }
    }

    @ViewBuilder private func header(_ s: OverlaySection) -> some View {
        HStack(spacing: 6) {
            if editing {
                Image(systemName: "line.3.horizontal").foregroundStyle(theme.secondary)
            }
            Label(s.title, systemImage: s.symbol).font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
                .textCase(.uppercase)
            Spacer()
            if editing {
                Button { store.step(s, by: -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless)
                Button { store.step(s, by: 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless)
                Button { store.toggle(s) } label: {
                    Image(systemName: store.isVisible(s) ? "eye" : "eye.slash")
                }.buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder private func sectionView(_ s: OverlaySection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(s)
            if !editing || store.isVisible(s) {
                switch s {
                case .platforms: platforms
                case .nowPlaying: nowPlaying
                case .devices: devices
                case .spotify: spotifyBlock
                case .quickActions: quickActions
                case .favorites: favourites
                case .recent: recent
                case .tabs: openTabs
                }
            }
        }
        .padding(editing ? 8 : 0)
        .background(editing ? RoundedRectangle(cornerRadius: 12).fill(theme.foreground.opacity(0.05)) : nil)
    }

    // MARK: Blokken

    private var platforms: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(MediaPlatform.allCases) { p in
                    Button { withAnimation(Motion.quick()) { token = (token == p ? nil : p) } } label: {
                        Label(p.title, systemImage: p.symbol).font(.caption.weight(.medium))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(token == p ? theme.accent.opacity(0.85) : theme.foreground.opacity(0.07)))
                            .foregroundStyle(token == p ? Color.white : theme.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var nowPlaying: some View {
        let tab = workspace.mediaTab
        let s = tab.session
        return HStack(spacing: 10) {
            thumb(tab.currentURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.fullTitle).font(.callout.weight(.medium)).lineLimit(1)
                Text(s.isPlaying ? "Playing here" : "Paused").font(.caption2).foregroundStyle(theme.secondary)
            }
            Spacer(minLength: 4)
            control("gobackward.10") { s.remoteSeek(by: -10) }
            control(s.isPlaying ? "pause.fill" : "play.fill", big: true) { s.remoteToggle() }
            control("goforward.10") { s.remoteSeek(by: 10) }
            control("pip") { s.togglePictureInPicture(); close() }
            if !workspace.otherDevices.isEmpty {
                Menu {
                    ForEach(workspace.otherDevices, id: \.id) { d in
                        Button("Continue on \(d.name)") { workspace.continuePlayback(on: d.id); close() }
                    }
                } label: { Image(systemName: "arrow.up.forward.app").frame(width: 28, height: 28) }
                .menuStyle(.button).buttonStyle(.plain).fixedSize()
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.foreground.opacity(0.06)))
    }

    private var otherDevices: [(id: String, name: String, title: String?, playing: Bool, time: Double?, url: URL?)] {
        sync.latestByDevice.filter { $0.key != sync.deviceID }.map { id, snap in
            let tab = snap.playingID.flatMap { pid in snap.tabs.first { $0.id == pid } }
                ?? snap.handoffID.flatMap { hid in snap.tabs.first { $0.id == hid } }
                ?? snap.tabs.first { $0.id == snap.selectedID }
            return (id, snap.originName, tab?.title, snap.playingID != nil && sync.devices[id] != nil, tab?.time, tab?.url)
        }.sorted { $0.name < $1.name }
    }

    private var devices: some View {
        VStack(spacing: 6) {
            ForEach(otherDevices, id: \.id) { d in
                HStack(spacing: 10) {
                    Image(systemName: WidgetBridge.kind(forName: d.name) == "mac" ? "laptopcomputer" : (WidgetBridge.kind(forName: d.name) == "ipad" ? "ipad" : "iphone"))
                        .frame(width: 22).foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.title ?? d.name).font(.callout).lineLimit(1)
                        Text(d.name + (d.playing ? " · playing" : (sync.devices[d.id] != nil ? " · paused" : " · offline")) + (d.time.map { " · " + Self.clock($0) } ?? ""))
                            .font(.caption2).foregroundStyle(theme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if sync.devices[d.id] != nil {
                        control(d.playing ? "pause.fill" : "play.fill") {
                            sync.send(SyncCommand(kind: .toggle, target: d.id, url: nil, value: nil))
                        }
                        control("goforward.10") { sync.send(SyncCommand(kind: .seek, target: d.id, url: nil, value: 10)) }
                    }
                    Button { workspace.takeOverFrom(device: d.id); close() } label: {
                        Text("Play here").font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(theme.accent.opacity(0.9))).foregroundStyle(.white)
                    }.buttonStyle(.plain)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.foreground.opacity(0.06)))
            }
        }
    }

    @ViewBuilder private var spotifyBlock: some View {
        if let sp = spotify.current {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    AsyncImage(url: sp.artworkURL) { $0.resizable().scaledToFill() } placeholder: { Color.green.opacity(0.25) }
                        .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sp.track).font(.callout.weight(.medium)).lineLimit(1)
                        Text(sp.artist + (sp.device.isEmpty ? "" : " · " + sp.device)).font(.caption2).foregroundStyle(theme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    control("shuffle", tinted: sp.shuffling) { spotify.perform(.toggleShuffle) }
                    control("backward.fill") { spotify.perform(.previous) }
                    control(sp.playing ? "pause.fill" : "play.fill", big: true) { spotify.perform(.playPause) }
                    control("forward.fill") { spotify.perform(.next) }
                    control("repeat", tinted: sp.repeating) { spotify.perform(.toggleRepeat) }
                }
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(theme.secondary)
                    Slider(value: Binding(get: { sp.volume }, set: { spotify.perform(.setVolume, value: $0) }), in: 0...100)
                        .controlSize(.mini)
                    Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(theme.secondary)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.green.opacity(0.08)))
        } else if editing {
            Text("Nothing playing in Spotify").font(.caption).foregroundStyle(theme.secondary)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            let columns = [GridItem(.adaptive(minimum: store.layout.compact ? 64 : 76), spacing: 6)]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(editing ? OverlayAction.allCases : store.layout.actions) { a in
                    let on = store.layout.actions.contains(a)
                    Button {
                        if editing { store.toggleAction(a) } else { close(); DispatchQueue.main.async { a.run(workspace) } }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: a.symbol).font(.system(size: 15, weight: .medium))
                            Text(a.title).font(.caption2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, store.layout.compact ? 6 : 9)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(editing && on ? theme.accent.opacity(0.22) : theme.foreground.opacity(0.06)))
                        .opacity(editing && !on ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var favourites: some View {
        let columns = [GridItem(.adaptive(minimum: store.layout.compact ? 70 : 84), spacing: 8)]
        return VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(library.bookmarks.prefix(store.layout.favouriteCount)) { item in
                    Button { open(item.url) } label: {
                        VStack(spacing: 4) {
                            AsyncImage(url: WidgetShared.thumbnail(for: item.url) ?? URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(item.url.host ?? "")")) {
                                $0.resizable().scaledToFill()
                            } placeholder: { theme.foreground.opacity(0.08) }
                            .frame(height: store.layout.compact ? 36 : 46).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(item.title).font(.caption2).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if editing {
                Stepper("Show \(store.layout.favouriteCount)", value: $store.layout.favouriteCount, in: 4...24, step: 4).font(.caption)
            }
        }
    }

    private var recent: some View {
        VStack(spacing: 2) {
            ForEach(library.history.filter { NavigationPolicy.isPlaybackPage($0.url) }.prefix(store.layout.recentCount)) { item in
                Button { open(item.url) } label: {
                    HStack(spacing: 10) {
                        thumb(item.url, small: true)
                        Text(item.title).font(.callout).lineLimit(1)
                        Spacer()
                        Text(item.url.host ?? "").font(.caption2).foregroundStyle(theme.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if editing {
                Stepper("Show \(store.layout.recentCount)", value: $store.layout.recentCount, in: 2...12).font(.caption)
            }
        }
    }

    private var openTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(workspace.tabs.filter { $0.id != workspace.selectedID }) { tab in
                    Button { workspace.select(tab); close() } label: {
                        Text(tab.fullTitle).font(.caption).lineLimit(1).frame(maxWidth: 160)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(theme.foreground.opacity(0.07)))
                    }.buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Hulp

    private func control(_ symbol: String, big: Bool = false, tinted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: big ? 17 : 13, weight: .semibold))
                .frame(width: big ? 34 : 28, height: big ? 34 : 28)
                .background(Circle().fill(big ? theme.accent.opacity(0.9) : (tinted ? theme.accent.opacity(0.25) : .clear)))
                .foregroundStyle(big ? Color.white : theme.foreground)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func thumb(_ url: URL?, small: Bool = false) -> some View {
        AsyncImage(url: url.flatMap { WidgetShared.thumbnail(for: $0) }) { $0.resizable().scaledToFill() } placeholder: {
            ZStack { theme.foreground.opacity(0.08); Image(systemName: "play.rectangle").foregroundStyle(theme.secondary) }
        }
        .frame(width: small ? 44 : 64, height: small ? 25 : 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    static func clock(_ t: Double) -> String {
        let s = Int(max(0, t)); return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}
