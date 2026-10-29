import SwiftUI
import Combine
#if os(iOS)
import UIKit
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
    var lastActive: Date
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
        tabs.forEach(observe); persist()
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
        urlObservers[tab.id] = tab.session.$currentURL.dropFirst().sink { [weak self, weak tab] url in
            guard let self, let tab, let url, !tab.isPrivate else { return }
            // @Published emits before storage changes; preserve the new URL explicitly.
            tab.session.restoredURL = url
            let kept = self.tabs.filter { !$0.isPrivate }
            guard !kept.isEmpty else { return }
            self.store.save(SavedTabSession(tabs: kept.map {
                Self.saved($0, url: $0.id == tab.id ? url : nil)
            }, selectedID: kept.contains(where: { $0.id == self.selectedID }) ? self.selectedID : kept[0].id), window: self.windowID)
        }
        resumeObservers[tab.id] = tab.session.$resumePoint.dropFirst().removeDuplicates().sink { [weak self] _ in
            // @Published fires before the value is stored; persist on the next turn.
            DispatchQueue.main.async { self?.persist() }
        }
        titleObservers[tab.id] = tab.$title.dropFirst().removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persist() }
        playbackObservers[tab.id] = tab.session.$isPlaying.removeDuplicates().sink { [weak self, weak tab] playing in
            guard let self, let tab else { return }
            if playing {
                tab.lastActive = Date()
                for other in self.tabs where other.id != tab.id { other.session.pauseForTabSwitch() }
            }
            DispatchQueue.main.async { self.updateIdleTimer() }
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
        selected.session.leaveFullscreenForTabSwitch()
        if !selected.session.isInPictureInPicture { selected.session.pauseForTabSwitch() }
    }
    private var insertsNextToCurrent: Bool { UserDefaults.standard.object(forKey: "openNewTabsNextToCurrentV15") as? Bool ?? true }
    func addTab() { addTab(url: nil) }
    func addPrivateTab() { addTab(url: nil, privateMode: true) }
    /// New tab; without a URL it opens the start page with the search field focused.
    func addTab(url: URL?, privateMode: Bool = false, activate: Bool = true, after anchor: BrowserTab? = nil) {
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
        addTab(url: url, privateMode: source?.isPrivate ?? false, activate: activate, after: source ?? selected)
    }
    func select(_ tab: BrowserTab) {
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
            resetZoom: { workspace.selected.session.resetZoom() }, togglePin: { workspace.togglePin(workspace.selected) })
    }
    private func toggleBookmark() {
        let tab = workspace.selected
        library.toggleBookmark(title: tab.fullTitle, url: tab.session.currentURL)
        let saved = library.isBookmarked(tab.session.currentURL)
        tab.session.showNotice(.success, saved ? "Bookmark added" : "Bookmark removed", tab.fullTitle)
    }
    private func showFind() {
        #if os(iOS)
        workspace.selected.session.presentFind()
        #else
        findVisible = true
        #endif
    }

    var body: some View {
        let theme = settings.theme
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
                #if os(macOS)
                if findVisible {
                    FindBar(session: workspace.selected.session, visible: $findVisible)
                        .padding(.top, settings.toolbarDensity.height + 6)
                        .zIndex(5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                #endif
            }
            .animation(theme.animation, value: workspace.selectedID)
        }
        .background(theme.background)
        .environment(\.joeToepTheme, theme)
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
