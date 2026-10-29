import Foundation

struct SettingsSnapshot: Equatable, Sendable {
    var macFullscreenMode: MacFullscreenMode = .youtube
    var showHistoryButton = false
    var showPlaylistButton = false
    var automaticFullscreen = true
    var disableCaptions = true
    var disablePreviewCaptions = true
    #if os(macOS)
    var quality: PlaybackQualityPreference = .p2160
    #else
    var quality: PlaybackQualityPreference = .p1080
    #endif
    var startPage: StartPage = .home
    var rotateOnFullscreen = true
    var returnToPortrait = true
    var blockAds = true
    var adBlockLevel: AdBlockLevel = .balanced
    var hideAdCards = true
    var experimentalFilters = false
    var showPiPButton = true
    var blockShortsNavigation = true
    var blockPostsNavigation = true
    var blockPremiumDestinations = true
    var recoverWebProcess = true
    var automaticPiP = true
    var pipOnFullscreenExit = false
    var keepPiPOnReturn = false
    var activateMacOnPiPExit = true
    var macFloatingFallback = false
    var pipFallbackEnabled = true
    var backgroundProtection = true
    var nativeFullscreen = true
    #if os(macOS)
    var sitePresentation: SitePresentation = .desktop
    #else
    var sitePresentation: SitePresentation = .mobile
    #endif
    var videoFit: VideoFit = .fit
    var pinchMode: PinchMode = .video
    var pageZoom = 1.0
    var toolbarDensity: ToolbarDensity = .compact
    var showBrand = false
    var showNavigationControls = true
    var showConnectionStatus = false
    var glassEnabled = false
    var edgeToEdge = true
    var fullscreenOnLandscape = true
    var exitFullscreenOnPortrait = true
    var phoneElementFullscreen = false
    var pipReturnTarget: PiPReturnTarget = .fullscreen
    var pipReturnKeepsPlaying = true
    var openWebLinksInApp = true
    var searchEngine: SearchEngine = .youtube
    var recordHistory = true
    var instantTransitions = true
    var sponsorBlock = SponsorBlockSettings()
    static let standard = SettingsSnapshot()
}
