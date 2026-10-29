import Foundation
import Combine
import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor
final class AppSettings: ObservableObject {
    @Published var automaticFullscreen: Bool { didSet { save(automaticFullscreen, "automaticFullscreenV8") } }
    @Published var disableCaptions: Bool { didSet { save(disableCaptions, "disableCaptionsV8") } }
    @Published var disablePreviewCaptions: Bool { didSet { save(disablePreviewCaptions, "disablePreviewCaptionsV8") } }
    @Published var macFullscreenMode: MacFullscreenMode { didSet { save(macFullscreenMode.rawValue, "macFullscreenModeV9") } }
    @Published var showHistoryButton: Bool { didSet { save(showHistoryButton, "showHistoryButtonV9") } }
    @Published var showPlaylistButton: Bool { didSet { save(showPlaylistButton, "showPlaylistButtonV9") } }
    private var defaultQuality: PlaybackQualityPreference {
        #if os(macOS)
        .p2160
        #else
        .p1080
        #endif
    }
    private var defaultPresentation: SitePresentation {
        #if os(macOS)
        .desktop
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .desktop : .mobile
        #endif
    }
    private let defaults: UserDefaults
    @Published var quality: PlaybackQualityPreference { didSet { save(quality.rawValue, "qualityV9") } }
    @Published var startPage: StartPage { didSet { save(startPage.rawValue, "startPage") } }
    @Published var rotateOnFullscreen: Bool { didSet { save(rotateOnFullscreen, "rotateOnFullscreen") } }
    @Published var returnToPortrait: Bool { didSet { save(returnToPortrait, "returnToPortrait") } }
    @Published var blockAds: Bool { didSet { save(blockAds, "blockAdsV2") } }
    @Published var adBlockLevel: AdBlockLevel { didSet { save(adBlockLevel.rawValue, AdBlockLevel.storageKey) } }
    @Published var hideAdCards: Bool { didSet { save(hideAdCards, "hideAdCardsV5") } }
    @Published var experimentalFilters: Bool { didSet { save(experimentalFilters, "experimentalFiltersV5") } }
    @Published var showPiPButton: Bool { didSet { save(showPiPButton, "showPiPButtonV10") } }
    @Published var blockShortsNavigation: Bool { didSet { save(blockShortsNavigation, "blockShortsNavigationV9") } }
    @Published var blockPostsNavigation: Bool { didSet { save(blockPostsNavigation, "blockPostsNavigationV9") } }
    @Published var blockPremiumDestinations: Bool { didSet { save(blockPremiumDestinations, "blockPremiumDestinationsV9") } }
    @Published var recoverWebProcess: Bool { didSet { save(recoverWebProcess, "recoverWebProcess") } }
    @Published var acceptedServiceNotice: Bool { didSet { save(acceptedServiceNotice, "acceptedServiceNotice") } }
    @Published var automaticPiP: Bool { didSet { save(automaticPiP, "automaticPiP") } }
    @Published var pipOnFullscreenExit: Bool { didSet { save(pipOnFullscreenExit, "pipOnFullscreenExitV5") } }
    @Published var keepPiPOnReturn: Bool { didSet { save(keepPiPOnReturn, "keepPiPOnReturnV5") } }
    @Published var activateMacOnPiPExit: Bool { didSet { save(activateMacOnPiPExit, "activateMacOnPiPExitV7") } }
    @Published var macFloatingFallback: Bool { didSet { save(macFloatingFallback, "macFloatingFallbackV3") } }
    @Published var pipFallbackEnabled: Bool { didSet { save(pipFallbackEnabled, "pipFallbackV3") } }
    @Published var backgroundProtection: Bool { didSet { save(backgroundProtection, "backgroundProtectionV3") } }
    @Published var nativeFullscreen: Bool { didSet { save(nativeFullscreen, "nativeFullscreenV9") } }
    @Published var sitePresentation: SitePresentation { didSet { save(sitePresentation.rawValue, "sitePresentationV9") } }
    @Published var videoFit: VideoFit { didSet { save(videoFit.rawValue, "videoFit") } }
    @Published var pinchMode: PinchMode { didSet { save(pinchMode.rawValue, "pinchMode") } }
    @Published var pageZoom: Double { didSet { save(pageZoom, "pageZoom") } }
    @Published var toolbarDensity: ToolbarDensity { didSet { save(toolbarDensity.rawValue, "toolbarDensity") } }
    @Published var showBrand: Bool { didSet { save(showBrand, "showBrandV3") } }
    @Published var showNavigationControls: Bool { didSet { save(showNavigationControls, "showNavigationControlsV5") } }
    @Published var showConnectionStatus: Bool { didSet { save(showConnectionStatus, "showConnectionStatus") } }
    @Published var glassEnabled: Bool { didSet { save(glassEnabled, "glassEnabledV3") } }
    @Published var edgeToEdge: Bool { didSet { save(edgeToEdge, "edgeToEdge") } }
    /// V10: Apple HLS engine (MediaSource off). Enables video AirPlay and the prepared native
    /// PiP presenter for inline video. Read when a tab's web view is created.
    @Published var fullscreenOnLandscape: Bool { didSet { save(fullscreenOnLandscape, "fullscreenOnLandscapeV11"); Self.applyOrientationLock(self) } }
    @Published var tabLifetime: TabLifetime { didSet { save(tabLifetime.rawValue, TabLifetime.storageKey) } }
    @Published var exitFullscreenOnPortrait: Bool { didSet { save(exitFullscreenOnPortrait, "exitFullscreenOnPortraitV12") } }
    @Published var phoneElementFullscreen: Bool { didSet { save(phoneElementFullscreen, "phoneElementFullscreenV12") } }
    // MARK: V15 appearance
    @Published var themeStyle: ThemeStyle { didSet { save(themeStyle.rawValue, "themeStyleV15") } }
    @Published var accentChoice: AccentChoice { didSet { save(accentChoice.rawValue, "accentChoiceV15") } }
    @Published var customAccentHex: String { didSet { save(customAccentHex, "customAccentHexV15") } }
    @Published var iconVariant: IconVariant { didSet { save(iconVariant.rawValue, "iconVariantV15") } }
    @Published var iconWeight: IconWeightChoice { didSet { save(iconWeight.rawValue, "iconWeightV15") } }
    @Published var iconRendering: IconRendering { didSet { save(iconRendering.rawValue, "iconRenderingV15") } }
    @Published var animationStyle: AnimationStyle { didSet { save(animationStyle.rawValue, "animationStyleV15") } }
    @Published var tabShape: TabShape { didSet { save(tabShape.rawValue, "tabShapeV15") } }
    @Published var tabCloseButtons: TabCloseButtons { didSet { save(tabCloseButtons.rawValue, "tabCloseButtonsV15") } }
    @Published var tabTextSize: TabTextSize { didSet { save(tabTextSize.rawValue, "tabTextSizeV15") } }
    @Published var showTabIcons: Bool { didSet { save(showTabIcons, "showTabIconsV15") } }
    @Published var showMoreMenu: Bool { didSet { save(showMoreMenu, "showMoreMenuV15") } }
    @Published var showBookmarkButton: Bool { didSet { save(showBookmarkButton, "showBookmarkButtonV15") } }
    // MARK: V15 tabs
    @Published var aiTabSummary: Bool { didSet { save(aiTabSummary, "aiTabSummaryV15"); TabTitleSummarizer.configure(from: self) } }
    @Published var tabSummaryLength: TabSummaryLength { didSet { save(tabSummaryLength.rawValue, "tabSummaryLengthV15"); TabTitleSummarizer.configure(from: self) } }
    @Published var useAppleIntelligence: Bool { didSet { save(useAppleIntelligence, "useAppleIntelligenceV15"); TabTitleSummarizer.configure(from: self) } }
    @Published var openNewTabsNextToCurrent: Bool { didSet { save(openNewTabsNextToCurrent, "openNewTabsNextToCurrentV15") } }
    // MARK: V15 browser
    @Published var openWebLinksInApp: Bool { didSet { save(openWebLinksInApp, "openWebLinksInAppV15") } }
    @Published var searchEngine: SearchEngine { didSet { save(searchEngine.rawValue, "searchEngineV15") } }
    @Published var recordHistory: Bool { didSet { save(recordHistory, "recordHistoryV15") } }
    // MARK: V15 playback
    @Published var pipReturnTarget: PiPReturnTarget { didSet { save(pipReturnTarget.rawValue, "pipReturnTargetV15") } }
    @Published var pipReturnKeepsPlaying: Bool { didSet { save(pipReturnKeepsPlaying, "pipReturnKeepsPlayingV15") } }
    @Published var keepScreenAwake: Bool { didSet { save(keepScreenAwake, "keepScreenAwakeV15") } }
    @Published var portraitLockForRotation: Bool { didSet { save(portraitLockForRotation, "portraitLockForRotationV15"); Self.applyOrientationLock(self) } }
    @Published var instantTransitions: Bool { didSet { save(instantTransitions, "instantTransitionsV15") } }
    @Published var sponsorBlock: SponsorBlockSettings { didSet { sponsorBlock.save(defaults) } }
    @Published var appleStreamingEngine: Bool { didSet { save(appleStreamingEngine, Self.appleStreamingEngineKey) } }
    static let appleStreamingEngineKey = "appleStreamingEngineV10"
    /// Off by default (user choice 26 Sep 2026): YouTube serves only 360p without MediaSource,
    /// so the default keeps MediaSource quality (up to 1080p/4K).
    static var defaultAppleStreamingEngine: Bool { false }
    static func storedAppleStreamingEngine(_ defaults: UserDefaults = .standard) -> Bool {
        #if os(iOS)
        if defaults.object(forKey: appleStreamingEngineKey) == nil { return defaultAppleStreamingEngine }
        return defaults.bool(forKey: appleStreamingEngineKey)
        #else
        return false
        #endif
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        automaticFullscreen = flag("automaticFullscreenV8", true)
        disableCaptions = flag("disableCaptionsV8", true)
        disablePreviewCaptions = flag("disablePreviewCaptionsV8", true)
        #if os(macOS)
        quality = PlaybackQualityPreference(rawValue: defaults.string(forKey: "qualityV9") ?? "") ?? .p2160
        #else
        quality = PlaybackQualityPreference(rawValue: defaults.string(forKey: "qualityV9") ?? "") ?? .p1080
        #endif
        macFullscreenMode = MacFullscreenMode(rawValue: defaults.string(forKey: "macFullscreenModeV9") ?? "") ?? .youtube
        showHistoryButton = flag("showHistoryButtonV9", false)
        showPlaylistButton = flag("showPlaylistButtonV9", false)
        startPage = StartPage(rawValue: defaults.string(forKey: "startPage") ?? "") ?? .home
        rotateOnFullscreen = flag("rotateOnFullscreen", true)
        returnToPortrait = flag("returnToPortrait", true)
        blockAds = flag("blockAdsV2", true)
        adBlockLevel = AdBlockLevel.stored(defaults)
        hideAdCards = flag("hideAdCardsV5", true)
        experimentalFilters = flag("experimentalFiltersV5", false)
        showPiPButton = flag("showPiPButtonV10", true)
        blockShortsNavigation = flag("blockShortsNavigationV9", true)
        blockPostsNavigation = flag("blockPostsNavigationV9", true)
        blockPremiumDestinations = flag("blockPremiumDestinationsV9", true)
        recoverWebProcess = flag("recoverWebProcess", true)
        acceptedServiceNotice = flag("acceptedServiceNotice", false)
        automaticPiP = flag("automaticPiP", true)
        pipOnFullscreenExit = flag("pipOnFullscreenExitV5", false)
        keepPiPOnReturn = flag("keepPiPOnReturnV5", false)
        activateMacOnPiPExit = flag("activateMacOnPiPExitV7", true)
        macFloatingFallback = flag("macFloatingFallbackV3", false)
        pipFallbackEnabled = flag("pipFallbackV3", true)
        backgroundProtection = flag("backgroundProtectionV3", true)
        nativeFullscreen = flag("nativeFullscreenV9", true)
        #if os(macOS)
        sitePresentation = SitePresentation(rawValue: defaults.string(forKey: "sitePresentationV9") ?? "") ?? .desktop
        #else
        sitePresentation = SitePresentation(rawValue: defaults.string(forKey: "sitePresentationV9") ?? "") ?? (UIDevice.current.userInterfaceIdiom == .pad ? .desktop : .mobile)
        #endif
        videoFit = VideoFit(rawValue: defaults.string(forKey: "videoFit") ?? "") ?? .fit
        pinchMode = PinchMode(rawValue: defaults.string(forKey: "pinchMode") ?? "") ?? .video
        let zoom = (defaults.object(forKey: "pageZoom") as? Double) ?? 1
        pageZoom = zoom.isFinite ? min(max(zoom, 0.75), 1.5) : 1
        toolbarDensity = ToolbarDensity(rawValue: defaults.string(forKey: "toolbarDensity") ?? "") ?? .compact
        showBrand = flag("showBrandV3", false)
        showNavigationControls = flag("showNavigationControlsV5", true)
        showConnectionStatus = flag("showConnectionStatus", false)
        glassEnabled = flag("glassEnabledV3", false)
        edgeToEdge = flag("edgeToEdge", true)
        appleStreamingEngine = flag(Self.appleStreamingEngineKey, Self.defaultAppleStreamingEngine)
        fullscreenOnLandscape = flag("fullscreenOnLandscapeV11", true)
        exitFullscreenOnPortrait = flag("exitFullscreenOnPortraitV12", true)
        tabLifetime = TabLifetime.stored(defaults)
        phoneElementFullscreen = flag("phoneElementFullscreenV12", false)
        themeStyle = ThemeStyle(rawValue: defaults.string(forKey: "themeStyleV15") ?? "") ?? .youtube
        accentChoice = AccentChoice(rawValue: defaults.string(forKey: "accentChoiceV15") ?? "") ?? .red
        customAccentHex = defaults.string(forKey: "customAccentHexV15") ?? "#FF3B30"
        iconVariant = IconVariant(rawValue: defaults.string(forKey: "iconVariantV15") ?? "") ?? .outline
        iconWeight = IconWeightChoice(rawValue: defaults.string(forKey: "iconWeightV15") ?? "") ?? .regular
        iconRendering = IconRendering(rawValue: defaults.string(forKey: "iconRenderingV15") ?? "") ?? .monochrome
        animationStyle = AnimationStyle(rawValue: defaults.string(forKey: "animationStyleV15") ?? "") ?? .smooth
        tabShape = TabShape(rawValue: defaults.string(forKey: "tabShapeV15") ?? "") ?? .rounded
        tabCloseButtons = TabCloseButtons(rawValue: defaults.string(forKey: "tabCloseButtonsV15") ?? "") ?? .hover
        tabTextSize = TabTextSize(rawValue: defaults.string(forKey: "tabTextSizeV15") ?? "") ?? .regular
        showTabIcons = flag("showTabIconsV15", true)
        showMoreMenu = flag("showMoreMenuV15", true)
        showBookmarkButton = flag("showBookmarkButtonV15", false)
        aiTabSummary = flag("aiTabSummaryV15", true)
        tabSummaryLength = TabSummaryLength(rawValue: defaults.string(forKey: "tabSummaryLengthV15") ?? "") ?? .short
        useAppleIntelligence = flag("useAppleIntelligenceV15", true)
        openNewTabsNextToCurrent = flag("openNewTabsNextToCurrentV15", true)
        openWebLinksInApp = flag("openWebLinksInAppV15", true)
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: "searchEngineV15") ?? "") ?? .youtube
        recordHistory = flag("recordHistoryV15", true)
        pipReturnTarget = PiPReturnTarget(rawValue: defaults.string(forKey: "pipReturnTargetV15") ?? "") ?? .fullscreen
        pipReturnKeepsPlaying = flag("pipReturnKeepsPlayingV15", true)
        keepScreenAwake = flag("keepScreenAwakeV15", true)
        portraitLockForRotation = flag("portraitLockForRotationV15", true)
        instantTransitions = flag("instantTransitionsV15", true)
        sponsorBlock = SponsorBlockSettings.stored(defaults)
        Self.applyOrientationLock(self)
        TabTitleSummarizer.configure(from: self)
    }
    var snapshot: SettingsSnapshot {
        SettingsSnapshot(macFullscreenMode: macFullscreenMode, showHistoryButton: showHistoryButton, showPlaylistButton: showPlaylistButton, automaticFullscreen: automaticFullscreen, disableCaptions: disableCaptions, disablePreviewCaptions: disablePreviewCaptions, quality: quality, startPage: startPage,
            rotateOnFullscreen: rotateOnFullscreen, returnToPortrait: returnToPortrait,
            blockAds: blockAds,
            adBlockLevel: adBlockLevel, hideAdCards: hideAdCards, experimentalFilters: experimentalFilters, showPiPButton: showPiPButton,
            blockShortsNavigation: blockShortsNavigation, blockPostsNavigation: blockPostsNavigation,
            blockPremiumDestinations: blockPremiumDestinations, recoverWebProcess: recoverWebProcess,
            automaticPiP: automaticPiP, pipOnFullscreenExit: pipOnFullscreenExit,
            keepPiPOnReturn: keepPiPOnReturn, activateMacOnPiPExit: activateMacOnPiPExit, macFloatingFallback: macFloatingFallback,
            pipFallbackEnabled: pipFallbackEnabled, backgroundProtection: backgroundProtection,
            nativeFullscreen: nativeFullscreen,
            sitePresentation: sitePresentation, videoFit: videoFit, pinchMode: pinchMode,
            pageZoom: pageZoom, toolbarDensity: toolbarDensity, showBrand: showBrand,
            showNavigationControls: showNavigationControls, showConnectionStatus: showConnectionStatus,
            glassEnabled: glassEnabled, edgeToEdge: edgeToEdge, fullscreenOnLandscape: fullscreenOnLandscape, exitFullscreenOnPortrait: exitFullscreenOnPortrait, phoneElementFullscreen: phoneElementFullscreen,
            pipReturnTarget: pipReturnTarget, pipReturnKeepsPlaying: pipReturnKeepsPlaying,
            openWebLinksInApp: openWebLinksInApp, searchEngine: searchEngine, recordHistory: recordHistory,
            instantTransitions: instantTransitions, sponsorBlock: sponsorBlock)
    }
    func acceptServiceNotice() { acceptedServiceNotice = true }
    func resetPreferences() {
        automaticFullscreen = true
        disableCaptions = true
        disablePreviewCaptions = true
        macFullscreenMode = .youtube; showHistoryButton = false; showPlaylistButton = false
        quality = defaultQuality; startPage = .home
        rotateOnFullscreen = true; returnToPortrait = true
        blockAds = true
        adBlockLevel = .balanced; hideAdCards = true; experimentalFilters = false; showPiPButton = true
        blockShortsNavigation = true; blockPostsNavigation = true; blockPremiumDestinations = true
        recoverWebProcess = true; automaticPiP = true; pipOnFullscreenExit = false
        keepPiPOnReturn = false; activateMacOnPiPExit = true; macFloatingFallback = false
        pipFallbackEnabled = true; backgroundProtection = true; nativeFullscreen = true
        sitePresentation = defaultPresentation; videoFit = .fit; pinchMode = .video; pageZoom = 1
        toolbarDensity = .compact; showBrand = false; showNavigationControls = true
        showConnectionStatus = false; glassEnabled = false; edgeToEdge = true
        appleStreamingEngine = Self.defaultAppleStreamingEngine
        fullscreenOnLandscape = true; exitFullscreenOnPortrait = true; phoneElementFullscreen = false
        tabLifetime = .days2
        themeStyle = .youtube; accentChoice = .red; customAccentHex = "#FF3B30"
        iconVariant = .outline; iconWeight = .regular; iconRendering = .monochrome; animationStyle = .smooth
        tabShape = .rounded; tabCloseButtons = .hover; tabTextSize = .regular; showTabIcons = true
        showMoreMenu = true; showBookmarkButton = false
        aiTabSummary = true; tabSummaryLength = .short; useAppleIntelligence = true; openNewTabsNextToCurrent = true
        openWebLinksInApp = true; searchEngine = .youtube; recordHistory = true
        pipReturnTarget = .fullscreen; pipReturnKeepsPlaying = true; keepScreenAwake = true
        portraitLockForRotation = true; instantTransitions = true; sponsorBlock = SponsorBlockSettings()
    }
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
    var accentColor: Color { accentChoice.color(custom: customAccentHex) }
    var animation: Animation? { animationStyle.animation }
    /// iPhone: keep the interface in portrait so a landscape turn goes straight into fullscreen.
    static func applyOrientationLock(_ settings: AppSettings) {
        #if os(iOS)
        OrientationCoordinator.portraitLocked = settings.portraitLockForRotation && settings.fullscreenOnLandscape &&
            UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }
}
