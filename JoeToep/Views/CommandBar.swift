// V21 — Zwevende zoek-/adresbalk (zoals Arc): verschijnt boven de huidige pagina, die heel licht
// getint wordt. Typ een adres, een zoekterm, of de naam van een platform + Tab ("youtube ⇥")
// om daar te zoeken. Standaard zoekt hij op YouTube. Ook: naar open tabs springen, favorieten
// en geschiedenis. ⌘T = nieuwe tab, ⌘L / klik op de actieve tab = adres van deze tab wijzigen.
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CommandBarOverlay: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var settings: AppSettings
    @ObservedObject private var library = BrowserLibrary.shared
    @AppStorage("newTabPlatformV192") private var defaultPlatformRaw = MediaPlatform.youtube.rawValue
    @AppStorage("commandBarTintV21") private var tint = 0.12
    @State private var text = ""
    @State private var token: MediaPlatform?
    @State private var selection = 0
    @State private var customizing = false
    @ObservedObject private var overlayStore = OverlayLayoutStore.shared
    @FocusState private var focused: Bool
    @Environment(\.joeToepTheme) private var theme

    private var editsCurrent: Bool { workspace.commandBarEditsCurrent }
    private var platform: MediaPlatform { token ?? MediaPlatform(rawValue: defaultPlatformRaw) ?? .youtube }

    enum Suggestion: Identifiable {
        case open(URL), search(MediaPlatform, String), tab(BrowserTab), item(LibraryItem, String), command(PaletteCommand)
        var id: String {
            switch self {
            case .open(let u): "open:" + u.absoluteString
            case .search(let p, let q): "search:\(p.rawValue):\(q)"
            case .tab(let t): "tab:" + t.id.uuidString
            case .item(let i, let kind): kind + ":" + i.url.absoluteString
            case .command(let c): "cmd:" + c.title
            }
        }
    }

    private var suggestions: [Suggestion] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var list: [Suggestion] = []
        if q.isEmpty {
            if CommandBarPrefs.showTabs {
                list += workspace.tabs.filter { $0.id != workspace.selectedID }.sorted { $0.lastActive > $1.lastActive }.prefix(4).map(Suggestion.tab)
            }
            list += library.history.filter { NavigationPolicy.isPlaybackPage($0.url) }.prefix(4).map { .item($0, "history") }
            return Array(list.prefix(CommandBarPrefs.maxSuggestions))
        }
        // V21: opdrachten ("> pin", of gewoon "clear", "audio only", "sidebar" …).
        if token == nil {
            let isCommand = q.hasPrefix(">")
            let needle = (isCommand ? String(q.dropFirst()) : q).trimmingCharacters(in: .whitespaces).lowercased()
            let matches = PaletteCommand.all.filter { c in
                needle.isEmpty ? isCommand : (c.title.lowercased().contains(needle) || c.keywords.contains { $0.hasPrefix(needle) })
            }
            if isCommand { return Array(matches.prefix(CommandBarPrefs.maxSuggestions)).map(Suggestion.command) }
            if needle.count >= 3 { list += matches.prefix(2).map(Suggestion.command) }
        }
        if token == nil, let url = MediaPlatform.directURL(q) { list.append(.open(url)) }
        list.append(.search(platform, q))
        let lower = q.lowercased()
        if CommandBarPrefs.showTabs {
            list += workspace.tabs.filter { $0.fullTitle.lowercased().contains(lower) || ($0.currentURL?.absoluteString.lowercased().contains(lower) ?? false) }
                .prefix(3).map(Suggestion.tab)
        }
        if CommandBarPrefs.showHistory {
            list += library.bookmarks.filter { $0.title.lowercased().contains(lower) || $0.url.absoluteString.lowercased().contains(lower) }
                .prefix(3).map { .item($0, "bookmark") }
            list += library.history.filter { $0.title.lowercased().contains(lower) || $0.url.absoluteString.lowercased().contains(lower) }
                .prefix(4).map { .item($0, "history") }
        }
        // Dubbele adressen eruit.
        var seen = Set<String>()
        list = list.filter { seen.insert($0.id).inserted }
        return Array(list.prefix(CommandBarPrefs.maxSuggestions))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(tint).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .accessibilityLabel("Close")
            panel
                .padding(.top, topPadding)
                .padding(.horizontal, 12)
        }
        .onAppear {
            token = workspace.commandBarToken; workspace.commandBarToken = nil; selection = 0
            text = editsCurrent ? (workspace.selected.currentURL?.absoluteString ?? "") : ""
            DispatchQueue.main.async { focused = true }
        }
        #if os(macOS)
        .onExitCommand { close() }
        #endif
        .transition(.opacity)
        .accessibilityIdentifier("commandBar")
    }

    private var topPadding: CGFloat {
        #if os(macOS)
        90
        #else
        UIDevice.current.userInterfaceIdiom == .phone ? 16 : 80
        #endif
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let token {
                    Label(token.title, systemImage: token.symbol)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(theme.accent.opacity(0.9)))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture { withAnimation(.snappy) { self.token = nil } }
                } else {
                    Image(systemName: editsCurrent ? "link" : "magnifyingglass").foregroundStyle(theme.secondary)
                }
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19, weight: .regular))
                    .focused($focused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    #endif
                    .onSubmit { commit(selection) }
                    .onKeyPress(.tab) { tabToSearch() ? .handled : .ignored }
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(0, suggestions.count - 1)); return .handled }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .onKeyPress(.delete) {
                        // Backspace op een leeg veld haalt het platform-label weg.
                        if text.isEmpty, token != nil { withAnimation(.snappy) { token = nil }; return .handled }
                        return .ignored
                    }
                    .onKeyPress(.escape) { close(); return .handled }
                    .onChange(of: text) { _, _ in selection = 0 }
                    .accessibilityIdentifier("commandBar.field")
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.secondary) }
                        .buttonStyle(.plain)
                }
                if showsDashboard {
                    // V22: dashboard aanpassen (slepen, aan/uit).
                    Button { withAnimation(.snappy) { customizing.toggle() } } label: {
                        Image(systemName: customizing ? "checkmark.circle.fill" : "slider.horizontal.3")
                            .foregroundStyle(customizing ? theme.accent : theme.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Customize this overlay")
                    .accessibilityIdentifier("commandBar.customize")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            if showsDashboard {
                Divider().opacity(0.4)
                ScrollView {
                    OverlayDashboard(workspace: workspace, token: $token, editing: $customizing, open: open, close: close)
                }
                .frame(maxHeight: dashboardMaxHeight)
            } else {
            platformChips
            if !suggestions.isEmpty {
                Divider().opacity(0.4)
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, s in
                            row(s, selected: index == selection)
                                .onTapGesture { commit(index) }
                                #if os(macOS)
                                .onHover { if $0 { selection = index } }
                                #endif
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 360)
            }
            }
            hintBar
        }
        .frame(maxWidth: 680)
        .joeToepGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
        .animation(.snappy(duration: 0.2), value: token)
    }

    /// V22: leeg zoekveld bij een nieuwe tab → het aanpasbare dashboard.
    private var showsDashboard: Bool {
        overlayStore.dashboardEnabled && !editsCurrent && text.isEmpty && token == nil || customizing
    }
    private var dashboardMaxHeight: CGFloat {
        #if os(macOS)
        560
        #else
        UIDevice.current.userInterfaceIdiom == .phone ? 520 : 620
        #endif
    }

    private var placeholder: String {
        if let token { return "Search \(token.title)" }
        return editsCurrent ? "Search or enter an address" : "Search \(platform.title), type a site, or name a platform + Tab"
    }

    /// Snel een platform kiezen (ook zonder toetsenbord, bijv. op iPhone).
    private var platformChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(MediaPlatform.allCases) { p in
                    Button { withAnimation(.snappy) { token = (token == p ? nil : p) }; focused = true } label: {
                        Label(p.title, systemImage: p.symbol).font(.caption.weight(.medium))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Capsule().fill(p == platform && token != nil ? theme.accent.opacity(0.85) : theme.foreground.opacity(0.07)))
                            .foregroundStyle(p == platform && token != nil ? Color.white : theme.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var hintBar: some View {
        HStack(spacing: 14) {
            #if os(macOS)
            Label("open", systemImage: "return")
            Label("platform", systemImage: "arrow.right.to.line")
            Label("choose", systemImage: "arrow.up.arrow.down")
            Label("close", systemImage: "escape")
            #else
            Text("Tip: type a platform name and press Tab on a keyboard")
            #endif
            Spacer()
        }
        .font(.caption2).foregroundStyle(theme.secondary)
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    @ViewBuilder private func row(_ s: Suggestion, selected: Bool) -> some View {
        HStack(spacing: 10) {
            switch s {
            case .open(let url):
                icon("globe"); Text("Open \(url.host ?? url.absoluteString)").lineLimit(1); Spacer()
                Text(url.absoluteString).font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
            case .search(let p, let q):
                icon(p.symbol); Text("Search \(p.title) for “\(q)”").lineLimit(1); Spacer()
            case .tab(let tab):
                icon("square.on.square"); Text(tab.fullTitle).lineLimit(1); Spacer()
                Text("Switch to tab").font(.caption).foregroundStyle(theme.secondary)
            case .item(let item, let kind):
                icon(kind == "bookmark" ? "bookmark" : "clock.arrow.circlepath"); Text(item.title).lineLimit(1); Spacer()
                Text(item.url.host ?? "").font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
            case .command(let c):
                icon(c.symbol); Text(c.title).lineLimit(1); Spacer()
                Text("Action").font(.caption).foregroundStyle(theme.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? theme.accent.opacity(0.18) : .clear))
        .contentShape(Rectangle())
    }
    private func icon(_ name: String) -> some View {
        Image(systemName: name).frame(width: 20).foregroundStyle(theme.accent)
    }

    // MARK: Acties

    /// "youtube" + Tab → YouTube-label; wat je daarna typt is de zoekterm.
    private func tabToSearch() -> Bool {
        guard CommandBarPrefs.tabToSearch, token == nil, let p = SearchToken.platform(for: text) else { return false }
        withAnimation(.snappy) { token = p }
        text = ""
        return true
    }

    private func commit(_ index: Int) {
        let list = suggestions
        guard !list.isEmpty else { close(); return }
        switch list[min(index, list.count - 1)] {
        case .open(let url): open(url)
        case .search(let p, let q):
            #if os(macOS)
            if p == .spotify, SpotifyController.shared.isInstalled, NewTabStore.shared.layout.spotifySearchInApp {
                SpotifyController.shared.openInSpotifyApp(uri: "spotify:search:" + (q.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? q))
                close(); return
            }
            #endif
            if let url = p.url(for: q, webEngine: settings.searchEngine) { open(url) } else { close() }
        case .tab(let tab): workspace.select(tab); close()
        case .item(let item, _): open(item.url)
        case .command(let c): close(); DispatchQueue.main.async { c.run(workspace) }
        }
    }

    private func open(_ url: URL) {
        if editsCurrent { workspace.selected.session.showsNewTabPage = false; workspace.selected.session.load(url) }
        else { workspace.addTab(url: url) }
        close()
    }
    private func close() {
        withAnimation(.easeOut(duration: 0.15)) { workspace.showCommandBar = false }
    }
}


/// V21 — Acties die je in de zoekbalk kunt typen (Arc-stijl command palette).
struct PaletteCommand {
    let title: String
    let symbol: String
    let keywords: [String]
    let run: @MainActor (BrowserWorkspace) -> Void

    @MainActor static var all: [PaletteCommand] { base + platformSpecific + deviceCommands }
    /// "Verder op iPhone" / "Hier verder (van Mac)" voor elk verbonden apparaat.
    @MainActor private static var deviceCommands: [PaletteCommand] {
        let sync = TabSyncService.shared
        return sync.devices.filter { $0.key != sync.deviceID }.sorted { $0.value < $1.value }.flatMap { id, name in [
            PaletteCommand(title: "Continue on \(name)", symbol: "arrow.up.forward.app", keywords: ["continue", "send", "handoff", name.lowercased()]) {
                $0.continuePlayback(on: id) },
            PaletteCommand(title: "Take Over from \(name)", symbol: "arrow.down.backward.circle", keywords: ["take over", "here", "handoff", name.lowercased()]) {
                $0.takeOverFrom(device: id) },
        ] }
    }
    @MainActor private static var platformSpecific: [PaletteCommand] {
        #if os(macOS)
        return [PaletteCommand(title: "Print Page", symbol: "printer", keywords: ["print"]) { $0.selected.session.printPage() }]
        #else
        return [PaletteCommand(title: "Find on Page", symbol: "text.magnifyingglass", keywords: ["find", "search page"]) { $0.selected.session.presentFind() }]
        #endif
    }
    @MainActor private static let base: [PaletteCommand] = [
        PaletteCommand(title: "Pin / Unpin Tab", symbol: "pin", keywords: ["pin", "unpin"]) { $0.togglePin($0.selected) },
        PaletteCommand(title: "Duplicate Tab", symbol: "plus.square.on.square", keywords: ["duplicate", "copy tab"]) { $0.duplicate($0.selected) },
        PaletteCommand(title: "Close Tab", symbol: "xmark", keywords: ["close"]) { $0.close($0.selected) },
        PaletteCommand(title: "Clear Loose Tabs", symbol: "sparkles", keywords: ["clear", "clean", "tidy"]) { $0.clearLooseTabs() },
        PaletteCommand(title: "Reopen Closed Tab", symbol: "arrow.uturn.backward", keywords: ["reopen", "undo", "restore"]) { $0.reopenClosedTab() },
        PaletteCommand(title: "New Private Tab", symbol: "eyeglasses", keywords: ["private", "incognito"]) { $0.addPrivateTab() },
        PaletteCommand(title: "New Group with This Tab", symbol: "folder.badge.plus", keywords: ["group", "folder"]) { $0.newGroup(with: $0.selected) },
        PaletteCommand(title: "Show / Hide Sidebar", symbol: "sidebar.left", keywords: ["sidebar", "vertical"]) { _ in
            NotificationCenter.default.post(name: .joeToepToggleSidebar, object: nil) },
        PaletteCommand(title: "Picture in Picture", symbol: "pip", keywords: ["pip", "picture", "float"]) { $0.selected.session.togglePictureInPicture() },
        PaletteCommand(title: "Audio Only (hide video)", symbol: "waveform", keywords: ["audio", "hide video", "battery"]) { MediaExtras.shared.toggleAudioOnly(on: $0.selected.session) },
        PaletteCommand(title: "Loop Video", symbol: "repeat", keywords: ["loop", "repeat"]) { MediaExtras.shared.toggleLoop(on: $0.selected.session) },
        PaletteCommand(title: "Volume Boost 200%", symbol: "speaker.plus", keywords: ["boost", "louder", "volume"]) { MediaExtras.shared.setBoost(2, on: $0.selected.session) },
        PaletteCommand(title: "Volume Boost Off", symbol: "speaker", keywords: ["boost off", "normal volume"]) { MediaExtras.shared.setBoost(1, on: $0.selected.session) },
        PaletteCommand(title: "Save Current Frame", symbol: "camera", keywords: ["screenshot", "frame", "snapshot"]) { MediaExtras.shared.captureFrame(from: $0.selected.session) },
        PaletteCommand(title: "Reader Mode", symbol: "doc.plaintext", keywords: ["reader", "read"]) { $0.selected.session.toggleReaderMode() },
        PaletteCommand(title: "Reload Page", symbol: "arrow.clockwise", keywords: ["reload", "refresh"]) { $0.selected.session.reload() },
        PaletteCommand(title: "Force Refresh Player", symbol: "arrow.triangle.2.circlepath", keywords: ["force", "restart"]) { $0.selected.session.forceRefresh() },
        PaletteCommand(title: "Pause Everything", symbol: "pause.circle", keywords: ["pause all", "stop", "silence"]) { _ in MediaHub.shared.scan(); MediaHub.shared.pauseAll() },
        PaletteCommand(title: "Spotify Play / Pause", symbol: "music.note", keywords: ["spotify", "music"]) { _ in SpotifyController.shared.perform(.playPause) },
        PaletteCommand(title: "Sleep Timer 30 min", symbol: "moon.zzz", keywords: ["sleep", "timer"]) { _ in SpotifyCoordinator.shared.startSleepTimer(minutes: 30) },
        PaletteCommand(title: "Copy Link", symbol: "link", keywords: ["copy", "url", "link"]) { ws in if let url = ws.selected.currentURL { Clipboard.copy(url) } },
        PaletteCommand(title: "Settings", symbol: "gearshape", keywords: ["settings", "preferences", "options"]) { ws in
            NotificationCenter.default.post(name: .joeToepOpenSettings, object: ws.selected.session) },
    ]
}
