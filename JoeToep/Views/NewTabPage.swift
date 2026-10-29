// V19.2 — Nieuwe-tab-pagina: meteen typen (zoekveld heeft focus), standaard YouTube, of kies
// een ander platform. Daaronder snelkoppelingen: verder kijken, favorieten, recent gesloten en
// downloads. Achter deze pagina laadt YouTube gewoon (dus Picture in Picture bij het openen van
// een nieuwe tab werkt precies zoals voorheen). Uit te zetten in Instellingen › General.
import SwiftUI

/// Waar je zoekt.
enum MediaPlatform: String, CaseIterable, Identifiable, Sendable {
    case youtube, youtubeMusic, vimeo, twitch, soundcloud, dailymotion, spotify, web
    var id: String { rawValue }
    var title: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeMusic: "YouTube Music"
        case .vimeo: "Vimeo"
        case .twitch: "Twitch"
        case .soundcloud: "SoundCloud"
        case .dailymotion: "Dailymotion"
        case .spotify: "Spotify"
        case .web: "Web"
        }
    }
    var symbol: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .youtubeMusic: "music.note"
        case .vimeo: "v.circle.fill"
        case .twitch: "gamecontroller.fill"
        case .soundcloud: "waveform"
        case .dailymotion: "d.circle.fill"
        case .spotify: "dot.radiowaves.left.and.right"
        case .web: "globe"
        }
    }
    /// Zoek-URL voor `query`. Een webadres ("vimeo.com/123", "https://…") opent direct.
    func url(for query: String, webEngine: SearchEngine) -> URL? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        if let direct = Self.directURL(q) { return direct }
        let e = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        switch self {
        case .youtube: return URL(string: "https://www.youtube.com/results?search_query=\(e)")
        case .youtubeMusic: return URL(string: "https://music.youtube.com/search?q=\(e)")
        case .vimeo: return URL(string: "https://vimeo.com/search?q=\(e)")
        case .twitch: return URL(string: "https://www.twitch.tv/search?term=\(e)")
        case .soundcloud: return URL(string: "https://soundcloud.com/search?q=\(e)")
        case .dailymotion: return URL(string: "https://www.dailymotion.com/search/\(e)")
        case .spotify: return URL(string: "https://open.spotify.com/search/\(e)")
        case .web: return webEngine.url(for: q)
        }
    }
    /// Ziet de invoer eruit als een webadres? Dan geen zoekopdracht maar direct openen.
    static func directURL(_ text: String) -> URL? {
        if text.contains(" ") { return nil }
        if let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil { return url }
        let parts = text.split(separator: "/", maxSplits: 1)
        guard let host = parts.first, host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              host.split(separator: ".").last.map({ $0.count >= 2 && $0.allSatisfy(\.isLetter) }) == true else { return nil }
        return URL(string: "https://" + text)
    }
}

// MARK: - V20 aanpasbare nieuwe-tab-pagina

/// Eén onderdeel van de nieuwe-tab-pagina.
enum NewTabSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case greeting, search, platforms, spotify, nowPlaying, shortcuts, continueWatching, favourites,
         otherDevices, recentlyClosed, history, quickLinks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .greeting: "Clock & greeting"
        case .search: "Search field"
        case .platforms: "Platforms"
        case .spotify: "Spotify"
        case .nowPlaying: "Now playing (all tabs)"
        case .shortcuts: "My shortcuts"
        case .continueWatching: "Continue watching"
        case .favourites: "Favourites"
        case .otherDevices: "Tabs on other devices"
        case .recentlyClosed: "Recently closed"
        case .history: "Recent history"
        case .quickLinks: "Quick links"
        }
    }
    var symbol: String {
        switch self {
        case .greeting: "clock"
        case .search: "magnifyingglass"
        case .platforms: "square.grid.2x2"
        case .spotify: "music.note"
        case .nowPlaying: "waveform"
        case .shortcuts: "square.grid.3x3.fill"
        case .continueWatching: "play.circle"
        case .favourites: "bookmark"
        case .otherDevices: "laptopcomputer.and.iphone"
        case .recentlyClosed: "arrow.uturn.backward"
        case .history: "clock.arrow.circlepath"
        case .quickLinks: "link"
        }
    }
    /// Standaardvolgorde en wat standaard aan staat.
    static let defaultOrder: [NewTabSection] = [.greeting, .search, .platforms, .spotify, .nowPlaying, .shortcuts,
                                                .continueWatching, .favourites, .otherDevices, .recentlyClosed, .quickLinks, .history]
    static let defaultOff: Set<NewTabSection> = [.history, .greeting]
}

/// Een eigen snelkoppeling (tegel) op de nieuwe-tab-pagina.
struct NewTabShortcut: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
}

/// Alle keuzes van de gebruiker, als JSON in UserDefaults (één sleutel, dus in één keer te resetten).
struct NewTabLayout: Codable, Equatable {
    struct Item: Codable, Equatable { var section: NewTabSection; var enabled: Bool }
    var items: [Item] = NewTabSection.defaultOrder.map { Item(section: $0, enabled: !NewTabSection.defaultOff.contains($0)) }
    var shortcuts: [NewTabShortcut] = [
        NewTabShortcut(title: "YouTube", url: URL(string: "https://www.youtube.com")!),
        NewTabShortcut(title: "YouTube Music", url: URL(string: "https://music.youtube.com")!),
        NewTabShortcut(title: "Twitch", url: URL(string: "https://www.twitch.tv")!),
        NewTabShortcut(title: "Spotify", url: URL(string: "https://open.spotify.com")!),
        NewTabShortcut(title: "SoundCloud", url: URL(string: "https://soundcloud.com")!),
        NewTabShortcut(title: "Vimeo", url: URL(string: "https://vimeo.com")!),
    ]
    var itemsPerSection = 6
    var contentWidth: Double = 620
    var compact = false
    var alignTop = false
    var showLogo = true
    var focusSearch = true
    var tileColumns = 4
    var background: Background = .theme
    var cardStyle: CardStyle = .soft
    var spotifySearchInApp = true
    var showSleepTimer = true
    var greetingName = ""
    var visiblePlatforms: [MediaPlatform] = MediaPlatform.allCases

    enum Background: String, Codable, CaseIterable, Identifiable {
        case theme, gradient, artwork, plain
        var id: String { rawValue }
        var title: String {
            switch self {
            case .theme: "Theme"
            case .gradient: "Accent gradient"
            case .artwork: "Now-playing artwork (blurred)"
            case .plain: "Plain"
            }
        }
    }
    enum CardStyle: String, Codable, CaseIterable, Identifiable {
        case soft, outlined, none
        var id: String { rawValue }
        var title: String { switch self { case .soft: "Soft cards"; case .outlined: "Outlined"; case .none: "No cards" } }
    }

    // Nieuwe onderdelen uit een latere versie komen er automatisch bij (aan het eind).
    mutating func normalize() {
        let present = Set(items.map(\.section))
        for s in NewTabSection.defaultOrder where !present.contains(s) {
            items.append(Item(section: s, enabled: !NewTabSection.defaultOff.contains(s)))
        }
        var seen = Set<NewTabSection>(); items = items.filter { seen.insert($0.section).inserted }
        itemsPerSection = itemsPerSection.clamped(1, 20); tileColumns = tileColumns.clamped(2, 8)
        contentWidth = contentWidth.clamped(420, 1100)
        if visiblePlatforms.isEmpty { visiblePlatforms = [.youtube] }
    }

    static let key = "newTabLayoutV20"
    static func load() -> NewTabLayout {
        guard let data = UserDefaults.standard.data(forKey: key),
              var layout = try? JSONDecoder().decode(NewTabLayout.self, from: data) else { return NewTabLayout() }
        layout.normalize(); return layout
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) } }
}

extension MediaPlatform: Codable {}

/// Gedeelde, waarneembare opslag van de layout (pagina + aanpas-scherm blijven gelijk).
@MainActor
final class NewTabStore: ObservableObject {
    static let shared = NewTabStore()
    @Published var layout = NewTabLayout.load() { didSet { if layout != oldValue { layout.save() } } }
    func reset() { layout = NewTabLayout() }
    func move(_ section: NewTabSection, before target: NewTabSection) {
        guard section != target, let from = layout.items.firstIndex(where: { $0.section == section }) else { return }
        let item = layout.items.remove(at: from)
        let to = layout.items.firstIndex(where: { $0.section == target }) ?? layout.items.count
        layout.items.insert(item, at: to)
    }
    func toggle(_ section: NewTabSection) {
        if let i = layout.items.firstIndex(where: { $0.section == section }) { layout.items[i].enabled.toggle() }
    }
}

struct NewTabPage: View {
    @ObservedObject var session: WebSession
    @ObservedObject var settings: AppSettings
    @ObservedObject private var library = BrowserLibrary.shared
    @ObservedObject private var store = NewTabStore.shared
    @ObservedObject private var spotify = SpotifyController.shared
    @ObservedObject private var sync = TabSyncService.shared
    @AppStorage("newTabPlatformV192") private var platformRaw = MediaPlatform.youtube.rawValue
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var showingDownloads = false
    @State private var editing = false
    @State private var showingCustomize = false
    @State private var dragging: NewTabSection?
    @Environment(\.joeToepTheme) private var theme

    private var layout: NewTabLayout { store.layout }
    private var platform: MediaPlatform { MediaPlatform(rawValue: platformRaw) ?? .youtube }
    private var limit: Int { layout.itemsPerSection }

    var body: some View {
        ScrollView {
            VStack(spacing: layout.compact ? 14 : 22) {
                Spacer(minLength: layout.alignTop ? 12 : 28)
                if layout.showLogo {
                    Text("JoeToep").font(.system(size: layout.compact ? 24 : 30, weight: .bold, design: .rounded)).foregroundStyle(theme.foreground)
                }
                ForEach(layout.items.filter { editing || $0.enabled }, id: \.section) { item in
                    sectionContainer(item)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(backgroundView.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { editBar.padding(12) }
        .onAppear { if layout.focusSearch { DispatchQueue.main.async { focused = true } } }
        #if os(macOS)
        .onExitCommand { if editing { editing = false } else { dismissToPage() } }
        #endif
        .sheet(isPresented: $showingDownloads) { NavigationStack { DownloadsView() } }
        .sheet(isPresented: $showingCustomize) { NewTabCustomizeView() }
        .accessibilityIdentifier("newTab.page")
    }

    // MARK: Bewerken (aan/uit + slepen, direct op de pagina)

    private var editBar: some View {
        HStack(spacing: 8) {
            if editing {
                Button("Reset") { store.reset() }.buttonStyle(.bordered)
                Button { showingCustomize = true } label: { Label("More options", systemImage: "slider.horizontal.3") }.buttonStyle(.bordered)
                // V22.2: Motion.quick() → "Animaties uit" geldt ook hier.
                Button("Done") { withAnimation(Motion.quick()) { editing = false } }.buttonStyle(.borderedProminent)
            } else {
                Button { withAnimation(Motion.quick()) { editing = true } } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.bordered).help("Customize this page: turn sections on or off and drag to reorder")
                    .accessibilityLabel("Customize new tab page")
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder private func sectionContainer(_ item: NewTabLayout.Item) -> some View {
        let content = sectionView(item.section)
        if editing {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "line.3.horizontal").foregroundStyle(theme.secondary)
                    Label(item.section.title, systemImage: item.section.symbol).font(.subheadline.weight(.semibold))
                    Spacer()
                    Toggle("", isOn: Binding(get: { item.enabled }, set: { _ in store.toggle(item.section) })).labelsHidden()
                        #if os(macOS)
                        .toggleStyle(.switch).controlSize(.small)
                        #endif
                }
                if item.enabled { content.allowsHitTesting(false).opacity(0.85) }
            }
            .padding(10)
            .frame(maxWidth: layout.contentWidth)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(dragging == item.section ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .opacity(item.enabled ? 1 : 0.55)
            .contentShape(Rectangle())
            .draggable(item.section.rawValue) { Label(item.section.title, systemImage: item.section.symbol).padding(8) }
            .dropDestination(for: String.self) { values, _ in
                guard let raw = values.first, let moved = NewTabSection(rawValue: raw) else { return false }
                withAnimation(Motion.quick()) { store.move(moved, before: item.section) }
                return true
            } isTargeted: { over in if over { dragging = item.section } else if dragging == item.section { dragging = nil } }
        } else {
            content
        }
    }

    @ViewBuilder private func sectionView(_ section: NewTabSection) -> some View {
        switch section {
        case .greeting: greeting
        case .search: searchField
        case .platforms: platformPicker
        case .spotify: SpotifyWidget(showSleepTimer: layout.showSleepTimer).frame(maxWidth: layout.contentWidth)
        case .nowPlaying: NowPlayingSection(limit: limit).frame(maxWidth: layout.contentWidth)
        case .shortcuts: shortcutGrid
        case .continueWatching:
            let items = library.recentVideos(limit)
            if !items.isEmpty || editing { list("Continue watching", items: items, symbol: "play.circle") }
        case .favourites:
            if !library.bookmarks.isEmpty || editing { list("Favourites", items: Array(library.bookmarks.prefix(limit)), symbol: "bookmark") }
        case .history:
            if !library.history.isEmpty || editing { list("Recent history", items: Array(library.history.prefix(limit)), symbol: "clock.arrow.circlepath") }
        case .otherDevices: otherDevices
        case .recentlyClosed: recentlyClosed
        case .quickLinks: quickLinks
        }
    }

    // MARK: Onderdelen

    private var greeting: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 2) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: layout.compact ? 34 : 46, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(greetingText(context.date)).font(.headline).foregroundStyle(theme.secondary)
            }
            .foregroundStyle(theme.foreground)
        }
    }
    private func greetingText(_ date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        let part = h < 6 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return layout.greetingName.isEmpty ? part : "\(part), \(layout.greetingName)"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: platform.symbol).foregroundStyle(theme.accent)
            TextField("Search \(platform.title) or type a web address", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($focused)
                .onSubmit(submit)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                #endif
                .accessibilityIdentifier("newTab.search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.secondary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(card(radius: 14))
        .frame(maxWidth: layout.contentWidth)
    }

    private var platformPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(layout.visiblePlatforms) { p in
                    Button { platformRaw = p.rawValue; focused = true } label: {
                        Label(p.title, systemImage: p.symbol).font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(p == platform ? theme.accent.opacity(0.9) : theme.foreground.opacity(0.07)))
                            .foregroundStyle(p == platform ? Color.white : theme.foreground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("newTab.platform.\(p.rawValue)")
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: layout.contentWidth)
    }

    private var shortcutGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("My shortcuts", systemImage: "square.grid.3x3.fill").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: layout.tileColumns), spacing: 10) {
                ForEach(layout.shortcuts) { item in
                    Button { open(item.url) } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(theme.accent.opacity(0.15))
                                Text(String(item.title.prefix(1)).uppercased()).font(.headline).foregroundStyle(theme.accent)
                            }
                            .frame(width: 40, height: 40)
                            Text(item.title).font(.caption).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(card(radius: 12))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open in new tab") { session.onOpenInNewTab?(item.url, true) }
                        Button("Remove", role: .destructive) { store.layout.shortcuts.removeAll { $0.id == item.id } }
                    }
                }
                if let url = session.currentURL ?? session.restoredURL, !layout.shortcuts.contains(where: { $0.url == url }) {
                    Button { store.layout.shortcuts.append(NewTabShortcut(title: url.host?.replacingOccurrences(of: "www.", with: "") ?? "Link", url: url)) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.headline).frame(width: 40, height: 40)
                                .background(Circle().strokeBorder(theme.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3])))
                            Text("Add current").font(.caption).foregroundStyle(theme.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: layout.contentWidth, alignment: .leading)
    }

    @ViewBuilder private var otherDevices: some View {
        let snapshots = sync.latestByDevice.values.filter { $0.origin != sync.deviceID && sync.devices[$0.origin] != nil }
        if !snapshots.isEmpty || editing {
            VStack(alignment: .leading, spacing: 8) {
                Label("Tabs on other devices", systemImage: "laptopcomputer.and.iphone").font(.headline)
                if snapshots.isEmpty { Text("No other devices connected").font(.caption).foregroundStyle(theme.secondary) }
                ForEach(snapshots, id: \.origin) { snap in
                    Text(snap.originName).font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
                    ForEach(snap.tabs.prefix(limit)) { tab in
                        Button { open(tab.url) } label: {
                            HStack {
                                if tab.id == snap.playingID { Image(systemName: "speaker.wave.2.fill").foregroundStyle(theme.accent) }
                                Text(tab.title ?? tab.url?.host ?? "Tab").lineLimit(1)
                                Spacer()
                                Text(tab.url?.host ?? "").font(.caption).foregroundStyle(theme.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12).background(card(radius: 14))
            .frame(maxWidth: layout.contentWidth, alignment: .leading)
        }
    }

    @ViewBuilder private var recentlyClosed: some View {
        let closed = Array(BrowserWorkspace.active?.closedTabs.prefix(limit) ?? [])
        if !closed.isEmpty || editing {
            VStack(alignment: .leading, spacing: 8) {
                Label("Recently closed", systemImage: "arrow.uturn.backward").font(.headline)
                if closed.isEmpty { Text("Nothing closed yet").font(.caption).foregroundStyle(theme.secondary) }
                ForEach(Array(closed.enumerated()), id: \.offset) { _, saved in
                    Button { open(saved.url) } label: {
                        Text(saved.title ?? saved.url?.host ?? "Tab").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12).background(card(radius: 14))
            .frame(maxWidth: layout.contentWidth, alignment: .leading)
        }
    }

    private var quickLinks: some View {
        HStack(spacing: 10) {
            quick("Subscriptions", "person.2") { open(StartPage.subscriptions.url) }
            quick("History", "clock") { open(StartPage.history.url) }
            quick("Watch later", "clock.badge") { open(StartPage.watchLater.url) }
            quick("Downloads", "arrow.down.circle") { showingDownloads = true }
            quick("Home", "house") { dismissToPage() }
        }
    }

    private func list(_ title: String, items: [LibraryItem], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            if items.isEmpty { Text("Empty").font(.caption).foregroundStyle(theme.secondary) }
            ForEach(items) { item in
                Button { open(item.url) } label: {
                    HStack {
                        Text(item.title).lineLimit(1)
                        Spacer()
                        Text(item.url.host ?? "").font(.caption).foregroundStyle(theme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12).background(card(radius: 14))
        .frame(maxWidth: layout.contentWidth, alignment: .leading)
    }

    private func quick(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(title).font(.caption2)
            }
            .frame(width: 76, height: 56)
            .background(card(radius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func card(radius: CGFloat) -> some View {
        switch layout.cardStyle {
        case .soft: RoundedRectangle(cornerRadius: radius, style: .continuous).fill(theme.foreground.opacity(0.06))
        case .outlined: RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(theme.foreground.opacity(0.15))
        case .none: Color.clear
        }
    }

    @ViewBuilder private var backgroundView: some View {
        switch layout.background {
        case .theme: theme.background.opacity(0.98)
        case .plain: theme.background
        case .gradient:
            LinearGradient(colors: [theme.accent.opacity(0.35), theme.background, theme.background], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .artwork:
            ZStack {
                theme.background
                if let url = spotify.current?.artworkURL {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                        .blur(radius: 60).opacity(0.45).clipped()
                }
            }
        }
    }

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        #if os(macOS)
        // Spotify: zoeken in de desktop-app (als die er is) i.p.v. de webspeler.
        if platform == .spotify, layout.spotifySearchInApp, spotify.isInstalled, !q.isEmpty, MediaPlatform.directURL(q) == nil {
            spotify.openInSpotifyApp(uri: "spotify:search:" + (q.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? q))
            return
        }
        #endif
        guard let url = platform.url(for: q, webEngine: settings.searchEngine) else { return }
        open(url)
    }
    private func open(_ url: URL?) {
        guard let url else { return }
        session.showsNewTabPage = false
        session.load(url)
    }
    private func dismissToPage() { session.showsNewTabPage = false }
}

// MARK: - Spotify-widget

struct SpotifyWidget: View {
    var showSleepTimer = true
    @ObservedObject private var spotify = SpotifyController.shared
    @ObservedObject private var coordinator = SpotifyCoordinator.shared
    @State private var scrub: Double?
    @State private var volume: Double = 50
    @State private var volumeEditing = false
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Spotify", systemImage: "music.note").font(.headline)
                if let s = spotify.current, !spotify.isLocal { Text("on \(s.device)").font(.caption).foregroundStyle(theme.secondary) }
                Spacer()
                Button { spotify.perform(.launch) } label: { Image(systemName: "arrow.up.forward.app") }
                    .buttonStyle(.borderless).help("Open Spotify")
            }
            if let s = spotify.current, s.hasTrack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(alignment: .top, spacing: 14) {
                        AsyncImage(url: s.artworkURL) { $0.resizable().scaledToFill() } placeholder: {
                            ZStack { Color.green.opacity(0.2); Image(systemName: "music.note") }
                        }
                        .frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(s.track).font(.title3.weight(.semibold)).lineLimit(1)
                            Text("\(s.artist) — \(s.album)").font(.subheadline).foregroundStyle(theme.secondary).lineLimit(1)
                            let pos = scrub ?? s.livePosition(at: context.date)
                            Slider(value: Binding(get: { pos }, set: { scrub = $0 }), in: 0...max(1, s.duration), onEditingChanged: { editing in
                                if !editing, let v = scrub { spotify.perform(.seek, value: v); scrub = nil }
                            })
                            .tint(.green)
                            HStack {
                                Text(Self.time(pos)).font(.caption2.monospacedDigit())
                                Spacer()
                                Text("-" + Self.time(max(0, s.duration - pos))).font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(theme.secondary)
                        }
                    }
                }
                HStack(spacing: 18) {
                    Button { spotify.perform(.toggleShuffle) } label: { Image(systemName: "shuffle").foregroundStyle(s.shuffling ? Color.green : theme.secondary) }
                        .help("Shuffle")
                    Button { spotify.perform(.previous) } label: { Image(systemName: "backward.fill") }
                    Button { spotify.perform(.playPause) } label: {
                        Image(systemName: s.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 38)).foregroundStyle(.green)
                    }
                    Button { spotify.perform(.next) } label: { Image(systemName: "forward.fill") }
                    Button { spotify.perform(.toggleRepeat) } label: { Image(systemName: "repeat").foregroundStyle(s.repeating ? Color.green : theme.secondary) }
                        .help("Repeat")
                    Spacer()
                    Image(systemName: "speaker.fill").foregroundStyle(theme.secondary)
                    Slider(value: $volume, in: 0...100, onEditingChanged: { e in
                        volumeEditing = e; if !e { spotify.perform(.setVolume, value: volume.rounded()) }
                    })
                    .frame(maxWidth: 140).tint(.green)
                    .onChange(of: volume) { _, v in if volumeEditing { spotify.perform(.setVolume, value: v.rounded()) } }
                }
                .buttonStyle(.borderless)
                .font(.title3)
                .onAppear { volume = s.volume }
                .onChange(of: s.volume) { _, v in if !volumeEditing { volume = v } }
                HStack(spacing: 10) {
                    if let web = s.webURL {
                        ShareLink(item: web) { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                    if showSleepTimer { sleepTimer }
                    Spacer()
                    Menu {
                        ForEach(SpotifyCoordinator.VideoBehaviour.allCases) { b in
                            Button { coordinator.behaviourRaw = b.rawValue } label: {
                                if coordinator.behaviour == b { Label(b.title, systemImage: "checkmark") } else { Text(b.title) }
                            }
                        }
                    } label: { Label("When a video plays", systemImage: "play.rectangle.on.rectangle") }
                    .fixedSize()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            } else {
                HStack {
                    Text(spotify.current?.running == true ? "Spotify is open — nothing is playing." : spotifyHint)
                        .font(.subheadline).foregroundStyle(theme.secondary)
                    Spacer()
                    Button(spotify.current?.running == true ? "Play" : "Open Spotify") {
                        spotify.perform(spotify.current?.running == true ? .play : .launch)
                    }
                    .buttonStyle(.bordered)
                }
                if let problem = spotify.problem { Text(problem).font(.caption).foregroundStyle(.orange) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.green.opacity(0.08)))
        // V22.2: alleen waarnemen als deze tab zichtbaar is en de app actief (verborgen tabs blijven gemount).
        .modifier(ObserveWhileVisible(begin: { spotify.beginObserving() }, end: { spotify.endObserving() }))
    }

    private var spotifyHint: String {
        #if os(macOS)
        "Start Spotify to control it from here."
        #else
        "Play something in Spotify on your Mac to control it from here, or open the Spotify app."
        #endif
    }

    @ViewBuilder private var sleepTimer: some View {
        Menu {
            ForEach([15, 30, 45, 60, 90], id: \.self) { m in Button("\(m) minutes") { coordinator.startSleepTimer(minutes: m) } }
            if coordinator.sleepEnds != nil { Button("Turn off", role: .destructive) { coordinator.cancelSleepTimer() } }
        } label: {
            if let end = coordinator.sleepEnds {
                Label { Text(end, style: .timer) } icon: { Image(systemName: "moon.zzz.fill") }
            } else {
                Label("Sleep timer", systemImage: "moon.zzz")
            }
        }
        .fixedSize()
    }

    static func time(_ s: Double) -> String {
        let t = Int(max(0, s)); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Spelende en gepauzeerde tabs op de nieuwe-tab-pagina (zelfde bediening als het menubalkpaneel).
struct NowPlayingSection: View {
    var limit: Int
    @ObservedObject private var hub = MediaHub.shared
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Now playing", systemImage: "waveform").font(.headline)
                Spacer()
                if hub.playingCount > 0 { Button("Pause all") { hub.pauseAll() }.buttonStyle(.borderless).font(.caption.weight(.semibold)) }
            }
            let list = hub.sources.filter { $0.kind != .spotify }.prefix(limit)
            if list.isEmpty { Text("No tabs with video or audio").font(.caption).foregroundStyle(theme.secondary) }
            ForEach(Array(list)) { MediaSourceRow(source: $0) }
        }
        .modifier(ObserveWhileVisible(begin: { hub.beginObserving() }, end: { hub.endObserving() }))   // V22.2
    }
}

/// V22.2: is de tab waarin deze view staat de zichtbare tab? (standaard true: menubalk, instellingen.)
private struct TabIsVisibleKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var tabIsVisible: Bool {
        get { self[TabIsVisibleKey.self] }
        set { self[TabIsVisibleKey.self] = newValue }
    }
}

/// V22.2: start waarnemen (timers/scans) alleen als de tab zichtbaar is en de app actief; stopt
/// anders — en reageert op wisselen van tab of naar de achtergrond gaan.
struct ObserveWhileVisible: ViewModifier {
    let begin: () -> Void
    let end: () -> Void
    @Environment(\.tabIsVisible) private var tabIsVisible
    @Environment(\.scenePhase) private var scenePhase
    @State private var observing = false
    private var wanted: Bool {
        #if os(macOS)
        tabIsVisible && scenePhase != .background   // Mac: ook zichtbaar terwijl een andere app voorop staat
        #else
        tabIsVisible && scenePhase == .active
        #endif
    }
    func body(content: Content) -> some View {
        content
            .onAppear { setObserving(wanted) }
            .onDisappear { setObserving(false) }
            .onChange(of: wanted) { _, on in setObserving(on) }
    }
    private func setObserving(_ on: Bool) {
        guard on != observing else { return }
        observing = on
        if on { begin() } else { end() }
    }
}

// MARK: - Aanpassen (alle opties)

struct NewTabCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            NewTabCustomizeForm()
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 620)
                #endif
                .navigationTitle("Customize new tab page")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                    #endif
                }
        }
    }
}

/// Alle opties van de nieuwe-tab-pagina (ook bereikbaar via Instellingen › New tab page).
struct NewTabCustomizeForm: View {
    @ObservedObject private var store = NewTabStore.shared
    @ObservedObject private var coordinator = SpotifyCoordinator.shared
    @AppStorage("newTabPageV192") private var enabled = true
    @State private var newTitle = ""
    @State private var newURL = ""

    var body: some View {
        Form {
            Section {
                Toggle("Show the new tab page", isOn: $enabled)
            } footer: { Text("Opens when you make a new tab. Tap the pencil on the page itself to drag sections into place.") }
            Section {
                ForEach($store.layout.items, id: \.section) { $item in
                    Toggle(isOn: $item.enabled) { Label(item.section.title, systemImage: item.section.symbol) }
                }
                .onMove { store.layout.items.move(fromOffsets: $0, toOffset: $1) }
            } header: { Text("Sections — drag to reorder") } footer: {
                Text("Tip: tap the pencil on the page itself to drag sections into place.")
            }
            Section("Layout") {
                Toggle("Compact", isOn: $store.layout.compact)
                Toggle("Align to top", isOn: $store.layout.alignTop)
                Toggle("Show JoeToep logo", isOn: $store.layout.showLogo)
                Toggle("Put the cursor in the search field", isOn: $store.layout.focusSearch)
                Stepper("Items per section: \(store.layout.itemsPerSection)", value: $store.layout.itemsPerSection, in: 1...20)
                Stepper("Shortcut columns: \(store.layout.tileColumns)", value: $store.layout.tileColumns, in: 2...8)
                VStack(alignment: .leading) {
                    Text("Width: \(Int(store.layout.contentWidth)) pt")
                    Slider(value: $store.layout.contentWidth, in: 420...1100, step: 20)
                }
                Picker("Background", selection: $store.layout.background) {
                    ForEach(NewTabLayout.Background.allCases) { Text($0.title).tag($0) }
                }
                Picker("Cards", selection: $store.layout.cardStyle) {
                    ForEach(NewTabLayout.CardStyle.allCases) { Text($0.title).tag($0) }
                }
                TextField("Your name (for the greeting)", text: $store.layout.greetingName)
            }
            Section("Platforms in the picker") {
                ForEach(MediaPlatform.allCases) { p in
                    Toggle(isOn: Binding(get: { store.layout.visiblePlatforms.contains(p) }, set: { on in
                        if on { store.layout.visiblePlatforms = MediaPlatform.allCases.filter { $0 == p || store.layout.visiblePlatforms.contains($0) } }
                        else if store.layout.visiblePlatforms.count > 1 { store.layout.visiblePlatforms.removeAll { $0 == p } }
                    })) { Label(p.title, systemImage: p.symbol) }
                }
            }
            Section("My shortcuts") {
                ForEach($store.layout.shortcuts) { $s in
                    VStack(alignment: .leading) {
                        TextField("Title", text: $s.title)
                        Text(s.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .onDelete { store.layout.shortcuts.remove(atOffsets: $0) }
                .onMove { store.layout.shortcuts.move(fromOffsets: $0, toOffset: $1) }
                HStack {
                    TextField("Title", text: $newTitle)
                    TextField("Address", text: $newURL)
                        #if os(iOS)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                        #endif
                    Button("Add") {
                        guard let url = MediaPlatform.directURL(newURL.trimmingCharacters(in: .whitespaces)) else { return }
                        store.layout.shortcuts.append(NewTabShortcut(title: newTitle.isEmpty ? (url.host ?? "Link") : newTitle, url: url))
                        newTitle = ""; newURL = ""
                    }
                    .disabled(MediaPlatform.directURL(newURL.trimmingCharacters(in: .whitespaces)) == nil)
                }
            }
            Section("Spotify") {
                Toggle("Show sleep timer", isOn: $store.layout.showSleepTimer)
                #if os(macOS)
                Toggle("Search in the Spotify app (not the web player)", isOn: $store.layout.spotifySearchInApp)
                #endif
                Picker("When a video starts", selection: $coordinator.behaviourRaw) {
                    ForEach(SpotifyCoordinator.VideoBehaviour.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if coordinator.behaviour == .duck {
                    Stepper("Lowered volume: \(Int(coordinator.duckPercent))%", value: $coordinator.duckPercent, in: 0...90, step: 5)
                }
                if coordinator.behaviour == .pause {
                    Toggle("Resume Spotify after the video", isOn: $coordinator.resumeAfterVideo)
                }
            }
            Section {
                Button("Reset new tab page", role: .destructive) { store.reset() }
            }
        }
        .formStyle(.grouped)
    }
}
