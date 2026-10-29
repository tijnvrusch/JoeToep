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

struct NewTabPage: View {
    @ObservedObject var session: WebSession
    @ObservedObject var settings: AppSettings
    @ObservedObject private var library = BrowserLibrary.shared
    @AppStorage("newTabPlatformV192") private var platformRaw = MediaPlatform.youtube.rawValue
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var showingDownloads = false
    @Environment(\.joeToepTheme) private var theme

    private var platform: MediaPlatform { MediaPlatform(rawValue: platformRaw) ?? .youtube }
    private var continueWatching: [LibraryItem] {
        Array(library.history.filter { NavigationPolicy.isPlaybackPage($0.url) }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 28)
                Text("JoeToep").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(theme.foreground)
                searchField
                platformPicker
                if !continueWatching.isEmpty { section("Continue watching", items: continueWatching, symbol: "play.circle") }
                if !library.bookmarks.isEmpty { section("Favourites", items: Array(library.bookmarks.prefix(8)), symbol: "bookmark") }
                if let closed = BrowserWorkspace.active?.closedTabs.prefix(4), !closed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Recently closed", systemImage: "arrow.uturn.backward").font(.headline)
                        ForEach(Array(closed.enumerated()), id: \.offset) { _, saved in
                            Button { open(saved.url) } label: {
                                Text(saved.title ?? saved.url?.host ?? "Tab").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                }
                HStack(spacing: 10) {
                    quick("Subscriptions", "person.2") { open(StartPage.subscriptions.url) }
                    quick("History", "clock") { open(StartPage.history.url) }
                    quick("Watch later", "clock.badge") { open(StartPage.watchLater.url) }
                    quick("Downloads", "arrow.down.circle") { showingDownloads = true }
                    quick("Home", "house") { dismissToPage() }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.opacity(0.98))
        .onAppear { DispatchQueue.main.async { focused = true } }
        #if os(macOS)
        .onExitCommand { dismissToPage() }
        #endif
        .sheet(isPresented: $showingDownloads) { NavigationStack { DownloadsView() } }
        .accessibilityIdentifier("newTab.page")
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.foreground.opacity(0.07)))
        .frame(maxWidth: 560)
    }

    private var platformPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MediaPlatform.allCases) { p in
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
        .frame(maxWidth: 560)
    }

    private func section(_ title: String, items: [LibraryItem], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
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
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func quick(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(title).font(.caption2)
            }
            .frame(width: 76, height: 56)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.foreground.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard let url = platform.url(for: query, webEngine: settings.searchEngine) else { return }
        open(url)
    }
    private func open(_ url: URL?) {
        guard let url else { return }
        session.showsNewTabPage = false
        session.load(url)
    }
    private func dismissToPage() { session.showsNewTabPage = false }
}
