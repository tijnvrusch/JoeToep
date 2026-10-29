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
            ScrollView(.horizontal) {
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
                    control("arrow.clockwise", "Refresh", action: session.reload).accessibilityIdentifier("toolbar.refresh")
                    ForEach(StartPage.allCases.filter { ($0 != .history || settings.showHistoryButton) && ($0 != .watchLater || settings.showPlaylistButton) }) { page in
                        control(page.symbolName, page.title) {
                            session.load(page.url)
                        }
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
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, minHeight: buttonSize)
            #if os(iOS)
            control("airplay.video", "AirPlay video", action: session.showVideoAirPlay)
                .accessibilityIdentifier("toolbar.airplay")
            #endif
            qualityMenu
            if settings.showPiPButton {
                PiPButton(session: session, size: buttonSize, iconSize: iconSize)
            }
            if settings.showMoreMenu { moreMenu }
            control("gearshape", "Settings", action: showSettings)
                .accessibilityIdentifier("toolbar.settings")
        }
        .padding(.horizontal, 4)
        .frame(height: settings.toolbarDensity.height)
        .background(theme.background)
        .animation(theme.animation, value: settings.toolbarDensity)
        #if os(macOS)
        .overlay(alignment: .top) { theme.style.separator.frame(height: 1).allowsHitTesting(false) }
        .overlay(alignment: .bottom) { theme.style.separator.frame(height: 1).allowsHitTesting(false) }
        #endif
    }

    /// V15: browser menu (tabs, library, page tools).
    private var moreMenu: some View {
        Menu {
            Section {
                Button { actions?.newTab() } label: { Label("New Tab", systemImage: "plus.square") }
                Button { actions?.newPrivateTab() } label: { Label("New Private Tab", systemImage: "eyeglasses") }
                Button { actions?.reopenClosedTab() } label: { Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward") }
                Button { actions?.togglePin() } label: { Label("Pin / Unpin Tab", systemImage: "pin") }
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

    private func control(_ symbol: String, _ title: String, enabled: Bool = true, active: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).themedIcon(theme, size: iconSize, active: active, enabled: enabled)
                .frame(width: buttonSize, height: buttonSize).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}
