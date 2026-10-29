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

    private var iconSize: CGFloat { 17 * settings.toolbarDensity.scale }
    private var buttonSize: CGFloat {
        let density = settings.toolbarDensity
        #if os(macOS)
        return 32 * density.scale
        #else
        // Larger sizes keep their size; the scrolling section absorbs the extra width.
        if density.isEnlarged { return density.height - 6 }
        let extras = (settings.showNavigationControls ? 2 : 0) + (settings.showPiPButton ? 1 : 0) +
            (settings.showMoreMenu ? 1 : 0) + (settings.showBookmarkButton ? 1 : 0)
        return min(40, max(30, (availableWidth - 8) / CGFloat(8 + extras)))
        #endif
    }
    var body: some View {
        HStack(spacing: 0) {
            #if os(iOS)
            // V16: scroll only when the buttons would not fit otherwise.
            ViewThatFits(in: .horizontal) {
                leadingButtons.frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal) { leadingButtons }.scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, minHeight: buttonSize)
            #else
            ScrollView(.horizontal) { leadingButtons }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, minHeight: buttonSize)
            #endif
            #if os(iOS)
            if settings.showAirPlayButton {
                control("airplay.video", "AirPlay video", action: session.showVideoAirPlay)
                    .accessibilityIdentifier("toolbar.airplay")
            }
            #endif
            if settings.showQualityButton { qualityMenu }
            if settings.showPiPButton {
                PiPButton(session: session, size: buttonSize, iconSize: iconSize)
            }
            if settings.showMoreMenu { moreMenu }
            if settings.showSettingsButton {
                control("gearshape", "Settings", action: showSettings)
                    .accessibilityIdentifier("toolbar.settings")
            }
        }
        .padding(.horizontal, 4)
        .frame(height: settings.toolbarDensity.height)
        .background { ZStack { theme.background; AudioVisualizer(playing: session.isPlaying && !session.isFullscreen && !session.isInPictureInPicture) } }
        .animation(theme.anim(.toolbar), value: settings.toolbarDensity)
        #if os(macOS)
        .overlay(alignment: .top) { theme.style.separator.frame(height: 1).allowsHitTesting(false) }
        .overlay(alignment: .bottom) { theme.style.separator.frame(height: 1).allowsHitTesting(false) }
        #endif
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
                control("chevron.backward", "Back", enabled: session.canGoBack, action: session.goBack).accessibilityIdentifier("toolbar.back")
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
