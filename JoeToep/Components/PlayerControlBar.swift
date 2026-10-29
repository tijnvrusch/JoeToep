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
    /// V21: hele balk, of alleen het linker- of rechterdeel (voor de Safari-achtige ene balk).
    enum Part { case full, leading, trailing }
    var part: Part = .full
    /// V21: vaste knopgrootte in de ene balk (anders passend gemaakt op de breedte).
    var fixedButtonSize: CGFloat? = nil
    @Environment(\.joeToepTheme) private var theme
    /// V17: is het Creator-tools-paneel open?
    @State fileprivate var showingCreatorTools = false
    /// V18: is het downloadpaneel open?
    @State fileprivate var showingDownload = false
    @State fileprivate var showingDownloadsList = false
    @AppStorage("showMediaHubV20") private var showMediaHub = true
    /// V19.1: snelheidspaneel.
    @State private var showingSpeedPanel = false
    /// V19.2: tabs doorzoeken.
    @State fileprivate var showingTabSearch = false

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
        if showMediaHub { n += 1 }
        if settings.showMoreMenu { n += 1 }
        if settings.showSettingsButton { n += 1 }
        return max(n, 1)
    }
    /// V17.1: knopgrootte. De balk scrolt nooit meer: passen niet alle knoppen op de normale maat,
    /// dan worden ze gelijkmatig iets kleiner (minimaal 24 pt), zodat ze altijd vast staan.
    private var buttonSize: CGFloat {
        if let fixedButtonSize { return fixedButtonSize }
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
        switch part {
        case .full: fullBar
        case .leading: leadingButtons.modifier(PanelSheets(bar: self))
        case .trailing: HStack(spacing: 0) { trailingButtons }.modifier(PanelSheets(bar: self))
        }
    }

    @ViewBuilder private var trailingButtons: some View {
            #if os(iOS)
            if settings.showAirPlayButton {
                control("airplay.video", "AirPlay video · hold for fullscreen", action: session.showVideoAirPlay, secondary: session.openFullscreenFallback)
                    .accessibilityIdentifier("toolbar.airplay")
            }
            #endif
            if settings.showQualityButton { qualityMenu }
            // V18: afspeelsnelheid met één klik: − langzamer, + sneller; vasthouden = terug naar 1×.
            if settings.showSpeedControl { speedControl }
            // V20: mediacentrum (alle spelende/gepauzeerde tabs + Spotify).
            if showMediaHub { MediaHubButton(size: buttonSize, iconSize: iconSize) }
            // V18: offline opslaan.
            if settings.showDownloadButton {
                control("arrow.down.circle", "Download for offline · hold for downloads", action: { showingDownload = true }, secondary: { showingDownloadsList = true })
                    .accessibilityIdentifier("toolbar.download")
            }
            if settings.showPiPButton {
                PiPButton(session: session, size: buttonSize, iconSize: iconSize)
            }
            // V17: knop voor Creator tools (snelheid, A-B-loop, tap tempo, frame-stap).
            if settings.showCreatorTools {
                control("slider.horizontal.3", "Creator tools · hold for speed panel", action: { showingCreatorTools = true }, secondary: { showingSpeedPanel = true })
                    .accessibilityIdentifier("toolbar.creator")
            }
            if settings.showMoreMenu { moreMenu }
            if settings.showSettingsButton {
                control("gearshape", "Settings · hold to search tabs", action: showSettings, secondary: { showingTabSearch = true })
                    .accessibilityIdentifier("toolbar.settings")
            }
    }

    private var fullBar: some View {
        HStack(spacing: 0) {
            // V17.1: vaste knoppen, geen horizontaal scrollen meer (alle platforms).
            leadingButtons
                .frame(maxWidth: .infinity, minHeight: buttonSize, alignment: .leading)
            trailingButtons
        }
        // V19 redesign: meer lucht aan de zijkanten, geen harde lijn bovenaan.
        .padding(.horizontal, 10)
        .frame(height: settings.toolbarDensity.height)
        .background { ZStack { theme.background; AudioVisualizer(playing: session.isPlaying && !session.isFullscreen && !session.isInPictureInPicture) } }
        .animation(theme.anim(.toolbar), value: settings.toolbarDensity)
        .modifier(PanelSheets(bar: self))
        #if os(macOS)
        .overlay(alignment: .bottom) { theme.style.separator.opacity(0.5).frame(height: 0.5).allowsHitTesting(false) }
        #endif
    }

    /// V19.1: − [1.00×] + — kleine stapjes met − en +; tik op de snelheid voor het paneel met
    /// klein/medium/groot, een schuif en vaste waarden. Vasthouden van − of + = terug naar 1×.
    private var speedControl: some View {
        HStack(spacing: 0) {
            control("minus", "Slower (−\(Self.rateLabel(settings.speedStepSmall))) · hold for 1×",
                    action: { session.adjustPlaybackRate(by: -settings.speedStepSmall) },
                    secondary: { session.setPlaybackRate(1) })
                .accessibilityIdentifier("toolbar.slower")
            Button { showingSpeedPanel = true } label: {
                Text(Self.rateLabel(session.playbackRate))
                    .font(.system(size: max(10, iconSize * 0.72), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(session.playbackRate == 1 ? theme.secondary : theme.accent)
                    .frame(minWidth: buttonSize * 1.1, minHeight: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Playback speed · click for fine control")
            .accessibilityLabel("Playback speed \(Self.rateLabel(session.playbackRate))")
            .accessibilityIdentifier("toolbar.rate")
            .popover(isPresented: $showingSpeedPanel, arrowEdge: .bottom) {
                SpeedPanel(session: session, settings: settings)
                    #if os(iOS)
                    .presentationCompactAdaptation(.popover)
                    #endif
            }
            control("plus", "Faster (+\(Self.rateLabel(settings.speedStepSmall))) · hold for 1×",
                    action: { session.adjustPlaybackRate(by: settings.speedStepSmall) },
                    secondary: { session.setPlaybackRate(1) })
                .accessibilityIdentifier("toolbar.faster")
        }
    }
    /// V19.2: pagina als PDF bewaren (Mac: bewaarvenster; iPhone/iPad: deelmenu).
    private func savePDF() {
        session.exportPDF { url in
            guard let url else { return }
            #if os(macOS)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.allowedContentTypes = [.pdf]
            if panel.runModal() == .OK, let target = panel.url {
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.copyItem(at: url, to: target)
            }
            #else
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
            var top = root; while let next = top?.presentedViewController { top = next }
            sheet.popoverPresentationController?.sourceView = top?.view
            top?.present(sheet, animated: true)
            #endif
        }
    }

    static func rateLabel(_ rate: Double) -> String {
        rate == rate.rounded() ? String(format: "%.0f×", rate) : String(format: "%.2f×", rate).replacingOccurrences(of: "0×", with: "×")
    }

    @ViewBuilder
    private var leadingButtons: some View {
        HStack(spacing: 0) {
            #if os(iOS)
            if settings.showBrand {
                HoldButton(action: session.goHome, hold: { actions?.newTab() }) { BrandMark(compact: true).frame(width: buttonSize, height: 44) }.accessibilityIdentifier("toolbar.brandHome")
            }
            #endif
            if settings.showNavigationControls {
                control("chevron.backward", "Back · hold for home", enabled: session.canGoBack || settings.backClosesTab, action: session.goBack, secondary: session.goHome).accessibilityIdentifier("toolbar.back")
                control("chevron.forward", "Forward · hold to reopen closed tab", enabled: session.canGoForward || actions != nil, action: session.goForward, secondary: { actions?.reopenClosedTab() }).accessibilityIdentifier("toolbar.forward")
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
                        active: library.isBookmarked(session.currentURL), action: { actions?.toggleBookmark() }, secondary: { actions?.showLibrary() })
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
            // V19.2: extra browserfuncties.
            MoreAction("Reader", "doc.plaintext") { session.toggleReaderMode() },
            // V21: media-extra's.
            MoreAction(MediaExtras.shared.state(for: session).audioOnly ? "Show Video" : "Audio Only", "waveform") { MediaExtras.shared.toggleAudioOnly(on: session) },
            MoreAction(MediaExtras.shared.state(for: session).loop ? "Loop Off" : "Loop", "repeat") { MediaExtras.shared.toggleLoop(on: session) },
            MoreAction("Boost \(Int(MediaExtras.shared.state(for: session).boost * 100))%", "speaker.plus") {
                let b = MediaExtras.shared.state(for: session).boost
                MediaExtras.shared.setBoost(b >= 2.99 ? 1 : b + 0.5, on: session) },
            MoreAction("Save Frame", "camera") { MediaExtras.shared.captureFrame(from: session) },
            MoreAction("Save as PDF", "doc.richtext") { savePDF() },
            MoreAction("Search Tabs", "rectangle.and.text.magnifyingglass") { showingTabSearch = true },
        ]
        // V26: Arc/Dia-functies (alleen wat aan staat; Split View niet op de iPhone).
        #if os(iOS)
        if V26Prefs.splitEnabled() && UIDevice.current.userInterfaceIdiom != .phone {
            list.append(MoreAction("Split View", "rectangle.split.2x1") { actions?.toggleSplit() })
        }
        #endif
        if V26Prefs.assistantEnabled() { list.append(MoreAction("Assistant", "sparkles") { actions?.toggleAssistant() }) }
        if V26Prefs.boostsEnabled() && session.boostSite != nil {
            list.append(MoreAction("Boost", "paintbrush.pointed") { actions?.editBoost() })
            list.append(MoreAction("Zap", "bolt") { actions?.zap() })
        }
        if V26Prefs.spacesEnabled() { list.append(MoreAction("New Space", "plus.square.on.square") { actions?.newSpace() }) }
        list.append(MoreAction("Settings", "gearshape") { showSettings() })
        #if os(macOS)
        list.insert(MoreAction("Print…", "printer") { session.printPage() }, at: max(0, list.count - 1))
        #endif
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
            Section("Media") {
                let extras = MediaExtras.shared.state(for: session)
                Button { MediaExtras.shared.toggleAudioOnly(on: session) } label: {
                    Label(extras.audioOnly ? "Show Video" : "Audio Only (hide video)", systemImage: extras.audioOnly ? "play.rectangle" : "waveform") }
                Button { MediaExtras.shared.toggleLoop(on: session) } label: {
                    Label(extras.loop ? "Stop Looping" : "Loop Video", systemImage: "repeat") }
                Menu("Volume Boost (\(Int(extras.boost * 100))%)") {
                    ForEach([1.0, 1.5, 2.0, 2.5, 3.0], id: \.self) { b in
                        Button { MediaExtras.shared.setBoost(b, on: session) } label: {
                            if abs(extras.boost - b) < 0.01 { Label("\(Int(b * 100))%", systemImage: "checkmark") } else { Text("\(Int(b * 100))%") }
                        }
                    }
                }
                Button { MediaExtras.shared.captureFrame(from: session) } label: { Label("Save Current Frame…", systemImage: "camera") }
            }
            // V26: Arc/Dia-functies.
            Section("Spaces, Split View & Boosts") {
                if V26Prefs.splitEnabled() {
                    Button { actions?.toggleSplit() } label: { Label("Split View", systemImage: "rectangle.split.2x1") }
                }
                if V26Prefs.assistantEnabled() {
                    Button { actions?.toggleAssistant() } label: { Label("Page Assistant", systemImage: "sparkles") }
                }
                if V26Prefs.boostsEnabled() && session.boostSite != nil {
                    Button { actions?.editBoost() } label: { Label("Boost This Site…", systemImage: "paintbrush.pointed") }
                    Button { actions?.zap() } label: { Label(session.isZapping ? "Stop Zapping" : "Zap Elements", systemImage: "bolt") }
                }
                if V26Prefs.spacesEnabled() {
                    Button { actions?.newSpace() } label: { Label("New Space", systemImage: "plus.square.on.square") }
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

    /// V19.3: echte knop — één tik werkt direct (ook iPad/iPhone); vasthouden = passende extra functie.
    private func control(_ symbol: String, _ title: String, enabled: Bool = true, active: Bool = false,
                         action: @escaping () -> Void, secondary: (() -> Void)? = nil) -> some View {
        HoldButton(action: action, hold: secondary) {
            Image(systemName: symbol).themedIcon(theme, size: iconSize, active: active, enabled: enabled)
                .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
        }
        .middleClick(secondary ?? action)
        .help(title)
        .accessibilityLabel(title)
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


/// V19.1 — Nauwkeurige afspeelsnelheid: klein/medium/groot omlaag en omhoog, een schuif
/// (0,25–4×, stapjes van 0,01) en snelle vaste waarden.
struct SpeedPanel: View {
    @ObservedObject var session: WebSession
    @ObservedObject var settings: AppSettings
    @State private var slider: Double = 1
    var body: some View {
        VStack(spacing: 14) {
            Text(PlayerControlBar.rateLabel(session.playbackRate))
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                .accessibilityIdentifier("speed.value")
            HStack(spacing: 8) {
                step(-settings.speedStepLarge, "chevron.backward.2")
                step(-settings.speedStepMedium, "chevron.backward")
                step(-settings.speedStepSmall, "minus")
                step(settings.speedStepSmall, "plus")
                step(settings.speedStepMedium, "chevron.forward")
                step(settings.speedStepLarge, "chevron.forward.2")
            }
            Slider(value: $slider, in: 0.25...4, step: 0.01) { editing in
                if !editing { session.setPlaybackRate(slider) }
            }
            .onChange(of: slider) { _, value in session.setPlaybackRate(value) }
            .accessibilityIdentifier("speed.slider")
            HStack(spacing: 6) {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                    Button(PlayerControlBar.rateLabel(value)) { session.setPlaybackRate(value); slider = value }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(abs(session.playbackRate - value) < 0.001 ? .accentColor : .secondary)
                }
            }
            #if os(macOS)
            Text("⌥, / ⌥.  small   ·   ⌥⇧, / ⌥⇧.  medium   ·   ⌃⌥, / ⌃⌥.  large   ·   ⌥0  1×")
                .font(.caption2).foregroundStyle(.secondary)
            #endif
        }
        .padding(18)
        .frame(width: 340)
        .onAppear { slider = session.playbackRate }
        .onChange(of: session.playbackRate) { _, value in if abs(value - slider) > 0.004 { slider = value } }
    }
    private func step(_ delta: Double, _ symbol: String) -> some View {
        Button { session.adjustPlaybackRate(by: delta) } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                Text((delta > 0 ? "+" : "−") + String(format: "%g", abs(delta))).font(.caption2).monospacedDigit()
            }
            .frame(width: 44, height: 40)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel((delta > 0 ? "Faster by " : "Slower by ") + String(format: "%g", abs(delta)))
    }
}


/// V19.2 — Zoeken in je open tabs (titel en adres); tik om ernaartoe te gaan.
struct TabSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                let tabs = BrowserWorkspace.active?.tabs ?? []
                let q = query.lowercased()
                ForEach(tabs.filter { q.isEmpty || $0.fullTitle.lowercased().contains(q) || ($0.currentURL?.absoluteString.lowercased().contains(q) ?? false) }) { tab in
                    Button {
                        BrowserWorkspace.active?.select(tab); dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tab.fullTitle).lineLimit(1)
                            Text(tab.currentURL?.host ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search open tabs")
            .navigationTitle("Tabs")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }
}


/// V19.3 — Knop met directe tik en een aparte "ingedrukt houden"-actie. De tik gaat via een
/// gewone Button (dus nooit wachten tot een lang-indrukken mislukt); het vasthouden loopt er
/// gelijktijdig naast en onderdrukt dan de tik die bij het loslaten volgt.
struct HoldButton<Label: View>: View {
    let action: () -> Void
    var hold: (() -> Void)?
    var holdDuration: Double = 0.5
    @ViewBuilder var label: () -> Label
    @State private var suppressTap = false

    var body: some View {
        Button {
            if suppressTap { suppressTap = false; return }
            action()
        } label: { label() }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: holdDuration, maximumDistance: 20).onEnded { _ in
            guard let hold else { return }
            suppressTap = true
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            hold()
            // Als het systeem na een lange druk géén tik meer stuurt, niet de vólgende tik opslokken.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { suppressTap = false }
        })
        .accessibilityAction(named: "Hold action") { hold?() }
    }
}


/// V21: de panelen (Creator tools, downloads, tabs zoeken) — gedeeld door de hele balk en de delen.
private struct PanelSheets: ViewModifier {
    let bar: PlayerControlBar
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: bar.$showingCreatorTools) { CreatorToolsView(session: bar.session) }
            .sheet(isPresented: bar.$showingDownload) { DownloadSheet(session: bar.session) }
            .sheet(isPresented: bar.$showingDownloadsList) { NavigationStack { DownloadsView() } }
            .sheet(isPresented: bar.$showingTabSearch) { TabSearchView() }
    }
}
