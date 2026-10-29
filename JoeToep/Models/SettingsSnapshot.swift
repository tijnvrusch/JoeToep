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
    var theaterMode = true
    var dataSaverOnCellular = false
    var cellularQuality: PlaybackQualityPreference = .p720
    // V17 — dezelfde betekenis als in AppSettings; hier als "momentopname" die de web-sessie leest.
    var cookieBannerMode: CookieBannerMode = .rejectAll
    var stripTrackingParameters = true
    var globalPrivacyControl = true
    var blockTrackers = true
    var spatialAudio = true
    var pipOnAllSites = true
    /// Alle animaties uit → JoeToep gebruikt ook zijn kortst mogelijke wachttijden (snelste modus).
    var animationsOff = false
    /// V18: slimme PiP bij meerdere schermen (zie MultiMonitorPiPPolicy).
    var smartMultiMonitorPiP = true
    static let standard = SettingsSnapshot()
}
