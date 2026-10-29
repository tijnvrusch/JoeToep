import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Default controls fit on a 390pt iPhone; optional extras scroll horizontally.
struct PlayerControlBar: View {
    @ObservedObject var session: WebSession
    @ObservedObject var settings: AppSettings
    @ObservedObject private var library = BrowserLibrary.shared
    let availableWidth: CGFloat
    var actions: WorkspaceActions? = nil
    let showSettings: () -> Void
    @Environment(\.joeToepTheme) private var theme
    /// V17: is het Creator-tools-paneel open?
    @State private var showingCreatorTools = false
    /// V18: is het downloadpaneel open?
    @State private var showingDownload = false

    private var iconSize: CGFloat { min(17 * settings.toolbarDensity.scale, buttonSize * 0.55) }   // V17.1: krimpt mee
    /// V17.1: hoeveel knoppen staan er in de balk? Nodig om ze passend te maken zonder scrollen.
    private var visibleButtonCount: Int {
        var n = 0
        #if os(iOS)
        if settings.showBrand { n += 1 }
        if settings.showAirPlayButton { n += 1 }
        #endif
        if settings.showNavigationControls { n += 2 }
        if settings.showRefreshButton { n += 1 }
        n += StartPage.allCases.filter(isVisible).count        // Home, Abonnementen, Bibliotheek …
        if settings.showBookmarkButton { n += 1 }
        if settings.showConnectionStatus { n += 2 }            // de status-"pil" is ±2 knoppen breed
        if settings.showQualityButton { n += 1 }
        if settings.showPiPButton { n += 1 }
        if settings.showCreatorTools { n += 1 }
        if settings.showSpeedControl { n += 2 }
        if settings.showDownloadButton { n += 1 }
        if settings.showMoreMenu { n += 1 }
        if settings.showSettingsButton { n += 1 }
        return max(n, 1)
    }
    /// V17.1: knopgrootte. De balk scrolt nooit meer: passen niet alle knoppen op de normale maat,
    /// dan worden ze gelijkmatig iets kleiner (minimaal 24 pt), zodat ze altijd vast staan.
    private var buttonSize: CGFloat {
        let density = settings.toolbarDensity
        #if os(macOS)
        let preferred = 32 * density.scale
        #else
        let preferred: CGFloat = density.isEnlarged ? density.height - 6 : 40
        #endif
        let fits = (availableWidth - 24) / CGFloat(visibleButtonCount)
        return max(24, min(preferred, fits))
    }
    var body: some View {
        HStack(spacing: 0) {
            // V17.1: vaste knoppen, geen horizontaal scrollen meer (alle platforms).
            leadingButtons
                .frame(maxWidth: .infinity, minHeight: buttonSize, alignment: .leading)
            #if os(iOS)
            if settings.showAirPlayButton {
                control("airplay.video", "AirPlay video", action: session.showVideoAirPlay)
                    .accessibilityIdentifier("toolbar.airplay")
            }
            #endif
            if settings.showQualityButton { qualityMenu }
            // V18: afspeelsnelheid met één klik: − langzamer, + sneller; vasthouden = terug naar 1×.
            if settings.showSpeedControl { speedControl }
            // V18: offline opslaan.
            if settings.showDownloadButton {
                control("arrow.down.circle", "Download for offline", action: { showingDownload = true })
                    .accessibilityIdentifier("toolbar.download")
            }
            if settings.showPiPButton {
                PiPButton(session: session, size: buttonSize, iconSize: iconSize)
            }
            // V17: knop voor Creator tools (snelheid, A-B-loop, tap tempo, frame-stap).
            if settings.showCreatorTools {
                control("slider.horizontal.3", "Creator tools", action: { showingCreatorTools = true })
                    .accessibilityIdentifier("toolbar.creator")
            }
            if settings.showMoreMenu { moreMenu }
            if settings.showSettingsButton {
                control("gearshape", "Settings", action: showSettings)
                    .accessibilityIdentifier("toolbar.settings")
            }
        }
        // V19 redesign: meer lucht aan de zijkanten, geen harde lijn bovenaan.
        .padding(.horizontal, 10)
        .frame(height: settings.toolbarDensity.height)
        .background { ZStack { theme.background; AudioVisualizer(playing: session.isPlaying && !session.isFullscreen && !session.isInPictureInPicture) } }
        .animation(theme.anim(.toolbar), value: settings.toolbarDensity)
        // V17: het Creator-tools-paneel als "sheet" (schuift over het scherm).
        .sheet(isPresented: $showingCreatorTools) { CreatorToolsView(session: session) }
        .sheet(isPresented: $showingDownload) { DownloadSheet(session: session) }
        #if os(macOS)
        .overlay(alignment: .bottom) { theme.style.separator.opacity(0.5).frame(height: 0.5).allowsHitTesting(false) }
        #endif
    }

    /// V18: − [1×] + — de middelste tekst toont de huidige snelheid (tik = terug naar 1×).
    private var speedControl: some View {
        HStack(spacing: 0) {
            control("minus", "Slower · hold for 1×", action: { session.stepPlaybackRate(-1) },
                    secondary: { session.stepPlaybackRate(0) })
                .accessibilityIdentifier("toolbar.slower")
            Button { session.stepPlaybackRate(0) } label: {
                Text(Self.rateLabel(session.playbackRate))
                    .font(.system(size: max(10, iconSize * 0.72), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(session.playbackRate == 1 ? theme.secondary : theme.accent)
                    .frame(minWidth: buttonSize * 0.9, minHeight: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Playback speed · click for 1×")
            .accessibilityLabel("Playback speed \(Self.rateLabel(session.playbackRate))")
            .accessibilityIdentifier("toolbar.rate")
            control("plus", "Faster · hold for 1×", action: { session.stepPlaybackRate(1) },
                    secondary: { session.stepPlaybackRate(0) })
                .accessibilityIdentifier("toolbar.faster")
        }
    }
    static func rateLabel(_ rate: Double) -> String {
        rate == rate.rounded() ? String(format: "%.0f×", rate) : String(format: "%g×", rate)
    }

    @ViewBuilder
    private var leadingButtons: some View {
        HStack(spacing: 0) {
            #if os(iOS)
            if settings.showBrand {
                Button(action: session.goHome) { BrandMark(compact: true).frame(width: buttonSize, height: 44) }
                    .buttonStyle(.plain).accessibilityIdentifier("toolbar.brandHome")
            }
            #endif
            if settings.showNavigationControls {
                control("chevron.backward", "Back", enabled: session.canGoBack || settings.backClosesTab, action: session.goBack).accessibilityIdentifier("toolbar.back")
                control("chevron.forward", "Forward", enabled: session.canGoForward, action: session.goForward).accessibilityIdentifier("toolbar.forward")
            }
            if settings.showRefreshButton {
                // V16: hold / middle-click = force refresh (restarts the player when PiP or YouTube is stuck).
                control("arrow.clockwise", "Refresh · hold for force refresh", action: session.reload,
                        secondary: { session.forceRefresh() }).accessibilityIdentifier("toolbar.refresh")
            }
            ForEach(StartPage.allCases.filter(isVisible)) { page in
                // V16: hold / middle-click opens the page in a new tab.
                control(page.symbolName, page.title + " · hold for new tab", action: { session.load(page.url) },
                        secondary: { session.onOpenInNewTab?(page.url, true) })
                    .accessibilityIdentifier("toolbar." + page.rawValue)
            }
            if settings.showBookmarkButton {
                control("bookmark", library.isBookmarked(session.currentURL) ? "Remove bookmark" : "Add bookmark",
                        active: library.isBookmarked(session.currentURL)) { actions?.toggleBookmark() }
                    .accessibilityIdentifier("toolbar.bookmark")
            }
            if settings.showConnectionStatus {
                ConnectionPill(state: session.networkMonitor.state, isLoading: session.isLoading,
                               isBuffering: session.isBuffering, resolution: session.mediaResolution)
            }
        }
    }
    private func isVisible(_ page: StartPage) -> Bool {
        switch page {
        case .home: settings.showHomeButton
        case .subscriptions: settings.showSubscriptionsButton
        case .library: settings.showLibraryButton
        case .history: settings.showHistoryButton
        case .watchLater: settings.showPlaylistButton
        }
    }

    /// V15: browser menu (tabs, library, page tools).
    /// V17.1: één lijst met alle acties van het "…"-menu. Het Mac-menu en het iPhone/iPad-paneel
    /// gebruiken dezelfde lijst, zodat ze nooit uit elkaar lopen.
    private var moreActions: [MoreAction] {
        var list: [MoreAction] = [
            MoreAction("New Tab", "plus.square") { actions?.newTab() },
            MoreAction("Private Tab", "eyeglasses") { actions?.newPrivateTab() },
            MoreAction("Reopen Closed", "arrow.uturn.backward") { actions?.reopenClosedTab() },
            MoreAction("Pin Tab", "pin") { actions?.togglePin() },
            MoreAction("Duplicate", "plus.square.on.square") { actions?.duplicateTab() },
            MoreAction(library.isBookmarked(session.currentURL) ? "Unbookmark" : "Bookmark",
                       library.isBookmarked(session.currentURL) ? "bookmark.slash" : "bookmark") { actions?.toggleBookmark() },
            MoreAction("Library", "books.vertical") { actions?.showLibrary() },
            MoreAction("Address…", "character.cursor.ibeam") { actions?.editAddress() },
            MoreAction("Find", "text.magnifyingglass") { actions?.find() },
        ]
        if let url = session.currentURL {
            list.append(MoreAction("Copy Link", "link") { Clipboard.copy(url) })
            list.append(MoreAction("Safari", "safari") { openInBrowser(url) })
        }
        let desktop = session.effectivePresentation == .desktop
        list += [
            MoreAction(desktop ? "Mobile Site" : "Desktop Site", desktop ? "iphone" : "desktopcomputer") {
                session.requestSite(desktop ? .mobile : .desktop) },
            MoreAction("Zoom In", "plus.magnifyingglass") { session.zoom(by: 0.1) },
            MoreAction("Zoom Out", "minus.magnifyingglass") { session.zoom(by: -0.1) },
            MoreAction("\(Int((session.effectiveZoom * 100).rounded()))%", "1.magnifyingglass") { session.resetZoom() },
            MoreAction("Reload", "arrow.clockwise") { session.reload() },
            MoreAction("Force Refresh", "arrow.triangle.2.circlepath") { session.forceRefresh() },
            MoreAction("Creator Tools", "slider.horizontal.3") { showingCreatorTools = true },
            MoreAction("Download", "arrow.down.circle") { showingDownload = true },
            MoreAction("Settings", "gearshape") { showSettings() },
        ]
        return list
    }

    #if os(iOS)
    /// V17.1 (iPhone/iPad): het "…"-paneel toont ALLE opties meteen, zonder scrollen: een raster
    /// van 4 kolommen in een popover die als uitklapmenu onder de knop verschijnt.
    @State private var showingMore = false
    private var moreMenu: some View {
        Button { showingMore = true } label: {
            Image(systemName: "ellipsis.circle").themedIcon(theme, size: iconSize)
                .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
        .accessibilityIdentifier("toolbar.more")
        .popover(isPresented: $showingMore, arrowEdge: .bottom) {
            MoreActionsPanel(actions: moreActions, share: session.currentURL) { showingMore = false }
                .presentationCompactAdaptation(.popover)      // ook op iPhone een uitklapmenu, geen sheet
        }
    }
    #else
    private var moreMenu: some View {
        Menu {
            Section {
                Button { actions?.newTab() } label: { Label("New Tab", systemImage: "plus.square") }
                Button { actions?.newPrivateTab() } label: { Label("New Private Tab", systemImage: "eyeglasses") }
                Button { actions?.reopenClosedTab() } label: { Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward") }
                Button { actions?.togglePin() } label: { Label("Pin / Unpin Tab", systemImage: "pin") }
                Button { actions?.duplicateTab() } label: { Label("Duplicate Tab", systemImage: "plus.square.on.square") }
            }
            Section {
                Button { actions?.toggleBookmark() } label: {
                    Label(library.isBookmarked(session.currentURL) ? "Remove Bookmark" : "Add Bookmark",
                          systemImage: library.isBookmarked(session.currentURL) ? "bookmark.slash" : "bookmark")
                }
                Button { actions?.showLibrary() } label: { Label("Bookmarks & History", systemImage: "books.vertical") }
            }
            Section {
                Button { actions?.editAddress() } label: { Label("Open Address…", systemImage: "character.cursor.ibeam") }
                Button { actions?.find() } label: { Label("Find on Page", systemImage: "text.magnifyingglass") }
                if let url = session.currentURL {
                    ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
                    Button { Clipboard.copy(url) } label: { Label("Copy Link", systemImage: "link") }
                    Button { openInBrowser(url) } label: { Label("Open in Default Browser", systemImage: "safari") }
                }
            }
            Section("Page") {
                Button { session.requestSite(session.effectivePresentation == .desktop ? .mobile : .desktop) } label: {
                    Label(session.effectivePresentation == .desktop ? "Request Mobile Website" : "Request Desktop Website",
                          systemImage: session.effectivePresentation == .desktop ? "iphone" : "desktopcomputer")
                }
                if session.sitePresentationOverride != nil {
                    Button { session.requestSite(nil) } label: { Label("Use Default Website Layout", systemImage: "arrow.uturn.left") }
                }
                Button { session.zoom(by: 0.1) } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
                Button { session.zoom(by: -0.1) } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                Button { session.resetZoom() } label: { Label("Actual Size (\(Int((session.effectiveZoom * 100).rounded()))%)", systemImage: "1.magnifyingglass") }
                Button { session.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                Button { session.forceRefresh() } label: { Label("Force Refresh (restart player)", systemImage: "arrow.triangle.2.circlepath") }
            }
            Section {
                Button(action: showSettings) { Label("Settings…", systemImage: "gearshape") }
            }
        } label: {
            Image(systemName: "ellipsis.circle").themedIcon(theme, size: iconSize)
                .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        #endif
        .fixedSize()
        .tint(theme.rendering == .accent || theme.rendering == .palette ? theme.accent : theme.foreground)
        .accessibilityLabel("More")
        .accessibilityIdentifier("toolbar.more")
    }
    #endif

    private func openInBrowser(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private var qualityMenu: some View {
        Menu {
            Section("Resolution preference") {
                ForEach(PlaybackQualityPreference.allCases) { quality in
                    Button {
                        settings.quality = quality
                    } label: {
                        if settings.quality == quality { Label(quality.title, systemImage: "checkmark") }
                        else { Text(quality.title) }
                    }
                    .disabled(quality != .automatic && !session.qualityLevels.isEmpty && !session.qualityLevels.contains(quality))
                }
            }
            Section {
                Text("Measured: " + (session.mediaResolution ?? "—"))
                Text("Auto follows YouTube's adaptive quality; it is not a fixed resolution.")
                Button("Refresh available resolutions", action: session.refreshQuality)
                Button("Reset video zoom", action: session.resetVideoZoom)
                Button("Fullscreen", action: session.openFullscreenFallback)
                Button("Show direct PiP fallback", action: session.showPiPFallback)
                    .disabled(!settings.pipFallbackEnabled)
                Button("Reload page", action: session.reload)
            }
        } label: {
            Image(systemName: "4k.tv").themedIcon(theme, size: iconSize)
                .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        #endif
        .fixedSize()
        .tint(theme.rendering == .accent || theme.rendering == .palette ? theme.accent : theme.foreground)
        .accessibilityLabel("Video resolution")
        .accessibilityIdentifier("toolbar.quality")
    }

    /// Button with an optional secondary action: long-press (touch) or middle-click / long-press (Mac).
    private func control(_ symbol: String, _ title: String, enabled: Bool = true, active: Bool = false,
                         action: @escaping () -> Void, secondary: (() -> Void)? = nil) -> some View {
        Image(systemName: symbol).themedIcon(theme, size: iconSize, active: active, enabled: enabled)
            .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
            .gesture(LongPressGesture(minimumDuration: 0.45, maximumDistance: 18)
                .exclusively(before: TapGesture()).onEnded { value in
                    switch value {
                    case .first(true): if let secondary { secondary() } else { action() }
                    case .second: action()
                    default: break
                    }
                })
            .middleClick(secondary ?? action)
            .help(title)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(title)
            .accessibilityAction { action() }
    }
}


// MARK: - V17.1 "…"-acties

/// Eén actie in het "…"-menu: titel, SF-Symbol-icoon en wat er gebeurt bij een tik.
struct MoreAction: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let run: () -> Void
    init(_ title: String, _ symbol: String, run: @escaping () -> Void) { self.title = title; self.symbol = symbol; self.run = run }
}

/// Het iPhone/iPad-paneel: alle acties in een raster, in één keer zichtbaar.
struct MoreActionsPanel: View {
    let actions: [MoreAction]
    let share: URL?
    let close: () -> Void
    @Environment(\.joeToepTheme) private var theme
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(actions) { action in
                    Button {
                        close()                                   // eerst het paneel sluiten …
                        DispatchQueue.main.async { action.run() } // … dan de actie (sheets openen dan netjes)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.symbol).font(.system(size: 18)).frame(height: 22)
                            Text(action.title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(theme.style.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("more." + action.title)
                }
            }
            if let share {
                ShareLink(item: share) { Label("Share…", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .frame(width: 330)
        .tint(theme.accent)
    }
}
