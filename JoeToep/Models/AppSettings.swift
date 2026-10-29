// Dit bestand bevat AppSettings: de plek waar alle instellingen van de app
// worden bijgehouden en opgeslagen. Elke instelling die de gebruiker kan
// wijzigen (bijvoorbeeld in het instellingenscherm) staat hier als property.
import Foundation
import Combine
import SwiftUI
// #if os(iOS) ... #endif is een "compiler-conditie": de code ertussen wordt
// alleen meegecompileerd als de app voor iOS wordt gebouwd. Zo kan hetzelfde
// bestand zowel voor iPhone/iPad (UIKit) als voor de Mac (AppKit) werken.
#if os(iOS)
import UIKit
#endif

// @MainActor betekent: alle code in deze class draait altijd op de
// hoofdthread (de thread die de gebruikersinterface tekent). Dat is nodig
// omdat instellingen de schermen direct beïnvloeden.
// "final class" is een normale Swift-klasse die niet verder overerfd kan
// worden. AppSettings volgt het ObservableObject-protocol: dat betekent dat
// SwiftUI-schermen automatisch opnieuw tekenen zodra een @Published waarde
// hierin verandert.
@MainActor
final class AppSettings: ObservableObject {
    // @Published maakt van een gewone eigenschap (property) een eigenschap
    // die SwiftUI in de gaten houdt: verandert de waarde, dan updaten alle
    // schermen die deze property gebruiken vanzelf.
    // didSet is code die automatisch na elke wijziging van de property
    // draait. Hier wordt de nieuwe waarde meteen opgeslagen via de eigen
    // save(...)-functie (zie verderop), met een unieke sleutel/"key"-string
    // zodat UserDefaults (het kleine opslagsysteem van de app) weet onder
    // welke naam de waarde bewaard moet worden.
    @Published var automaticFullscreen: Bool { didSet { save(automaticFullscreen, "automaticFullscreenV8") } }
    /// V22: fullscreen zodra je (weer) op play drukt terwijl de video inline staat.
    @Published var fullscreenOnPlay: Bool { didSet { save(fullscreenOnPlay, "fullscreenOnPlayV22") } }
    // Simpele aan/uit-instellingen (Bool = true/false), telkens met hetzelfde
    // patroon: bij wijziging opslaan onder hun eigen sleutel.
    @Published var disableCaptions: Bool { didSet { save(disableCaptions, "disableCaptionsV8") } }
    @Published var disablePreviewCaptions: Bool { didSet { save(disablePreviewCaptions, "disablePreviewCaptionsV8") } }
    // MacFullscreenMode is een enum (een lijst van vaste, benoemde keuzes,
    // bijvoorbeeld .youtube of .native). rawValue is de tekstwaarde van die
    // keuze, en die tekst wordt opgeslagen omdat UserDefaults geen enums kent.
    @Published var macFullscreenMode: MacFullscreenMode { didSet { save(macFullscreenMode.rawValue, "macFullscreenModeV9") } }
    @Published var showHistoryButton: Bool { didSet { save(showHistoryButton, "showHistoryButtonV9") } }
    @Published var showPlaylistButton: Bool { didSet { save(showPlaylistButton, "showPlaylistButtonV9") } }
    // Een berekende (computed) property: heeft geen eigen opslagplek, maar
    // rekent bij elke opvraging een waarde uit. Hier: de standaardkwaliteit
    // hangt af van het platform (Mac krijgt 4K, telefoon/tablet 1080p).
    private var defaultQuality: PlaybackQualityPreference {
        #if os(macOS)
        .p2160
        #else
        .p1080
        #endif
    }
    // Zelfde idee: de standaard weergave van de website hangt af van het
    // apparaat. UIDevice.current.userInterfaceIdiom vertelt of het een
    // iPad (.pad) is of iets anders (bijv. iPhone).
    private var defaultPresentation: SitePresentation {
        #if os(macOS)
        .desktop
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .desktop : .mobile
        #endif
    }
    // "private" betekent dat deze eigenschap alleen binnen deze class
    // gebruikt mag worden, niet van buitenaf. Dit is de verwijzing naar
    // UserDefaults, de opslag van de app, die in init(...) wordt ingevuld.
    private let defaults: UserDefaults
    @Published var quality: PlaybackQualityPreference { didSet { save(quality.rawValue, "qualityV9") } }
    @Published var startPage: StartPage { didSet { save(startPage.rawValue, "startPage") } }
    @Published var rotateOnFullscreen: Bool { didSet { save(rotateOnFullscreen, "rotateOnFullscreen") } }
    @Published var returnToPortrait: Bool { didSet { save(returnToPortrait, "returnToPortrait") } }
    @Published var blockAds: Bool { didSet { save(blockAds, "blockAdsV2") } }
    // Deze gebruikt AdBlockLevel.storageKey (een vaste sleutel die bij de
    // enum zelf hoort) in plaats van een losse tekst hier in dit bestand.
    @Published var adBlockLevel: AdBlockLevel { didSet { save(adBlockLevel.rawValue, AdBlockLevel.storageKey) } }
    // Weer een reeks losse aan/uit-schakelaars: elk regelt één onderdeel van
    // advertentie-blokkering, Picture-in-Picture (PiP, het kleine
    // zwevende videovenstertje) of navigatiegedrag. Steeds hetzelfde
    // patroon: waarde wijzigt -> opslaan onder de eigen sleutel.
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
    // pageZoom is een Double (kommagetal), bijvoorbeeld 1.0 voor 100%.
    @Published var pageZoom: Double { didSet { save(pageZoom, "pageZoom") } }
    @Published var toolbarDensity: ToolbarDensity { didSet { save(toolbarDensity.rawValue, "toolbarDensity") } }
    @Published var showBrand: Bool { didSet { save(showBrand, "showBrandV3") } }
    @Published var showNavigationControls: Bool { didSet { save(showNavigationControls, "showNavigationControlsV5") } }
    @Published var showConnectionStatus: Bool { didSet { save(showConnectionStatus, "showConnectionStatus") } }
    @Published var glassEnabled: Bool { didSet { save(glassEnabled, "glassEnabledV3") } }
    @Published var edgeToEdge: Bool { didSet { save(edgeToEdge, "edgeToEdge") } }
    /// V10: Apple HLS engine (MediaSource off). Enables video AirPlay and the prepared native
    /// PiP presenter for inline video. Read when a tab's web view is created.
    // Deze didSet doet twee dingen na elkaar (gescheiden door een
    // puntkomma ";"): opslaan, én de schermrotatie-vergrendeling
    // bijwerken via de functie applyOrientationLock hieronder.
    @Published var fullscreenOnLandscape: Bool { didSet { save(fullscreenOnLandscape, "fullscreenOnLandscapeV11"); Self.applyOrientationLock(self) } }
    @Published var tabLifetime: TabLifetime { didSet { save(tabLifetime.rawValue, TabLifetime.storageKey) } }
    @Published var exitFullscreenOnPortrait: Bool { didSet { save(exitFullscreenOnPortrait, "exitFullscreenOnPortraitV12") } }
    @Published var phoneElementFullscreen: Bool { didSet { save(phoneElementFullscreen, "phoneElementFullscreenV12") } }
    // MARK: V15 appearance
    // Vanaf hier: instellingen voor het uiterlijk van de app (thema, kleur,
    // iconen, animaties). Allemaal enums met hun eigen keuzemogelijkheden.
    @Published var themeStyle: ThemeStyle { didSet { save(themeStyle.rawValue, "themeStyleV15") } }
    @Published var accentChoice: AccentChoice { didSet { save(accentChoice.rawValue, "accentChoiceV15") } }
    // customAccentHex is een String (tekst) met een kleurcode, bijvoorbeeld
    // "#FF3B30", voor als de gebruiker een eigen accentkleur kiest.
    @Published var customAccentHex: String { didSet { save(customAccentHex, "customAccentHexV15") } }
    @Published var iconVariant: IconVariant { didSet { save(iconVariant.rawValue, "iconVariantV15") } }
    @Published var iconWeight: IconWeightChoice { didSet { save(iconWeight.rawValue, "iconWeightV15") } }
    @Published var iconRendering: IconRendering { didSet { save(iconRendering.rawValue, "iconRenderingV15") } }
    @Published var animationStyle: AnimationStyle { didSet { save(animationStyle.rawValue, "animationStyleV15") } }
    @Published var tabShape: TabShape { didSet { save(tabShape.rawValue, "tabShapeV15") } }
    @Published var tabCloseButtons: TabCloseButtons { didSet { save(tabCloseButtons.rawValue, "tabCloseButtonsV15") } }
    @Published var tabTextSize: TabTextSize { didSet { save(tabTextSize.rawValue, "tabTextSizeV15") } }
    /// V16.2.1: size of all interface text, as a factor (1.0 = normal, 0.8 = smaller, 1.5 = larger).
    /// `didSet` runs after every change and stores the new value in UserDefaults (the app's
    /// small settings database), so it is still there after a restart.
    @Published var textScale: Double { didSet { save(textScale, "textScaleV1621") } }
    // ── V17 ───────────────────────────────────────────────────────────────────────────────
    // Elke regel hieronder is één instelling. `@Published` laat de schermen automatisch
    // verversen als de waarde verandert; `didSet { save(...) }` bewaart hem meteen.
    /// Cookiebanners: automatisch weigeren (standaard), alleen verbergen, of uit.
    @Published var cookieBannerMode: CookieBannerMode { didSet { save(cookieBannerMode.rawValue, "cookieBannerModeV17") } }
    /// Volg-parameters (utm_, fbclid, YouTube-`si` …) uit links en adressen halen.
    @Published var stripTrackingParameters: Bool { didSet { save(stripTrackingParameters, "stripTrackingV17") } }
    /// Websites het signaal "verkoop/deel mijn gegevens niet" geven (Global Privacy Control).
    @Published var globalPrivacyControl: Bool { didSet { save(globalPrivacyControl, "gpcV17") } }
    /// Bekende volg-scripts (analytics, advertentiepixels) op alle sites tegenhouden.
    @Published var blockTrackers: Bool { didSet { save(blockTrackers, "blockTrackersV17") } }
    /// Alle cookies en websitegegevens wissen als de app stopt (standaard uit: dan blijf je ingelogd).
    @Published var clearDataOnQuit: Bool { didSet { save(clearDataOnQuit, "clearDataOnQuitV17") } }
    /// Ruimtelijke audio (spatial audio) voor AirPods: filmmodus + meerkanaals geluid doorgeven.
    @Published var spatialAudio: Bool { didSet { save(spatialAudio, "spatialAudioV17") } }
    /// Terug (knop, muisknop, veeg, ⌘←) op de eerste pagina van een tab sluit die tab.
    @Published var backClosesTab: Bool { didSet { save(backClosesTab, "backClosesTabV17") } }
    /// Een link "in nieuwe tab" (middelklik / rechtsklik) opent én toont die tab meteen.
    @Published var switchToNewTabs: Bool { didSet { save(switchToNewTabs, "switchToNewTabsV17") } }
    /// Picture in Picture ook op andere websites dan YouTube (elke videospeler).
    @Published var pipOnAllSites: Bool { didSet { save(pipOnAllSites, "pipOnAllSitesV17") } }
    /// Knop "Creator tools" (snelheid, A-B-loop, BPM tikken, frame-stap) in de menubalk tonen.
    @Published var showCreatorTools: Bool { didSet { save(showCreatorTools, "showCreatorToolsV17") } }
    // MARK: V18
    /// Mac met meerdere schermen: alleen automatische PiP als de nieuwe app op JoeToep's scherm komt.
    @Published var smartMultiMonitorPiP: Bool { didSet { save(smartMultiMonitorPiP, "smartMultiMonitorPiPV18") } }
    /// Tabs live synchroniseren met je andere apparaten (zelfde wifi/Bluetooth, geen iCloud nodig).
    @Published var tabSync: Bool { didSet { save(tabSync, "tabSyncV18") } }
    /// Knoppen "langzamer / sneller" (afspeelsnelheid) in de menubalk.
    @Published var showSpeedControl: Bool { didSet { save(showSpeedControl, "showSpeedControlV18") } }
    // MARK: V19 gebaren (veeg/scroll in fullscreen, pijltjes)
    /// Seconden per veeg-stapje (horizontaal vegen / Mac Mouse Fix).
    @Published var swipeSeekSeconds: Double { didSet { save(swipeSeekSeconds, "swipeSeekSecondsV19") } }
    /// Volume per stapje, in procenten.
    @Published var volumeStepPercent: Double { didSet { save(volumeStepPercent, "volumeStepPercentV19") } }
    /// YouTube-bediening tonen tijdens vegen.
    @Published var showControlsWhileScrubbing: Bool { didSet { save(showControlsWhileScrubbing, "showControlsWhileScrubbingV19") } }
    /// Voorbeeldplaatje van de positie tonen tijdens scrubben.
    @Published var scrubThumbnail: Bool { didSet { save(scrubThumbnail, "scrubThumbnailV19") } }
    /// YouTube-bediening ook tonen bij de pijltjestoetsen (standaard onzichtbaar).
    @Published var arrowKeysShowControls: Bool { didSet { save(arrowKeysShowControls, "arrowKeysShowControlsV19") } }
    /// V19.2: gepauzeerd → uit fullscreen; verder spelen → weer fullscreen.
    @Published var exitFullscreenOnPause: Bool { didSet { save(exitFullscreenOnPause, "exitFullscreenOnPauseV22") } }
    // MARK: V19.1 snelheid
    @Published var speedStepSmall: Double { didSet { save(speedStepSmall, "speedStepSmallV191") } }
    @Published var speedStepMedium: Double { didSet { save(speedStepMedium, "speedStepMediumV191") } }
    @Published var speedStepLarge: Double { didSet { save(speedStepLarge, "speedStepLargeV191") } }
    /// Downloadknop (offline opslaan) in de menubalk.
    @Published var showDownloadButton: Bool { didSet { save(showDownloadButton, "showDownloadButtonV18") } }
    @Published var showTabIcons: Bool { didSet { save(showTabIcons, "showTabIconsV15") } }
    @Published var showMoreMenu: Bool { didSet { save(showMoreMenu, "showMoreMenuV15") } }
    @Published var showBookmarkButton: Bool { didSet { save(showBookmarkButton, "showBookmarkButtonV15") } }
    // MARK: V15 tabs
    // Deze drie instellingen sturen samen de automatische samenvatting van
    // videotitels in tabbladen aan. Daarom roept elke didSet ook
    // TabTitleSummarizer.configure(from: self) aan: die functie leest de
    // huidige AppSettings uit en stelt de samenvatter opnieuw in.
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
    // sponsorBlock is geen los getal of tekst, maar een heel "pakketje"
    // (SponsorBlockSettings) met meerdere instellingen erin. Daarom heeft
    // het geen sleutel-string hier: het pakketje weet zelf hoe het zichzelf
    // moet opslaan via zijn eigen save(defaults)-functie.
    @Published var sponsorBlock: SponsorBlockSettings { didSet { sponsorBlock.save(defaults) } }
    // MARK: V16
    @Published var theaterMode: Bool { didSet { save(theaterMode, "theaterModeV16") } }
    @Published var dataSaverOnCellular: Bool { didSet { save(dataSaverOnCellular, "dataSaverOnCellularV16") } }
    @Published var cellularQuality: PlaybackQualityPreference { didSet { save(cellularQuality.rawValue, "cellularQualityV16") } }
    @Published var pipOnTabSwitch: Bool { didSet { save(pipOnTabSwitch, "pipOnTabSwitchV16") } }
    @Published var fullscreenNewVideoFromPiP: Bool { didSet { save(fullscreenNewVideoFromPiP, "fullscreenNewVideoFromPiPV16") } }
    @Published var visualizerStyle: VisualizerStyle { didSet { save(visualizerStyle.rawValue, "visualizerStyleV171") } }
    @Published var visualizerIntensity: Double { didSet { save(visualizerIntensity, "visualizerIntensityV16") } }
    @Published var visualizerInTabBar: Bool { didSet { save(visualizerInTabBar, "visualizerInTabBarV16") } }
    /// V17.1: alle fijne visualizer-instellingen (kleur, aantal staven, tempo …), als JSON bewaard.
    @Published var visualizerConfig: VisualizerConfig { didSet {
        if let data = try? JSONEncoder().encode(visualizerConfig) { defaults.set(data, forKey: "visualizerConfigV171") } } }
    @Published var animationSpeed: Double { didSet { save(animationSpeed, "animationSpeedV16") } }
    // animationProfiles is een Dictionary (een soort naslagwerk van
    // sleutel -> waarde): per animatie-soort (de sleutel, een String) ligt
    // er een eigen AnimationProfile (stijl + snelheid) in vast. Omdat
    // UserDefaults geen dictionaries met eigen types kent, wordt het eerst
    // omgezet naar ruwe data (JSON) met JSONEncoder voor het opgeslagen wordt.
    // "try?" probeert het encoderen en geeft nil terug als het mislukt, in
    // plaats van de app te laten crashen.
    @Published var animationProfiles: [String: AnimationProfile] { didSet {
        if let data = try? JSONEncoder().encode(animationProfiles) { defaults.set(data, forKey: "animationProfilesV16") } } }
    @Published var showRefreshButton: Bool { didSet { save(showRefreshButton, "showRefreshButtonV16") } }
    @Published var showHomeButton: Bool { didSet { save(showHomeButton, "showHomeButtonV16") } }
    @Published var showSubscriptionsButton: Bool { didSet { save(showSubscriptionsButton, "showSubscriptionsButtonV16") } }
    @Published var showLibraryButton: Bool { didSet { save(showLibraryButton, "showLibraryButtonV16") } }
    @Published var showQualityButton: Bool { didSet { save(showQualityButton, "showQualityButtonV16") } }
    @Published var showAirPlayButton: Bool { didSet { save(showAirPlayButton, "showAirPlayButtonV16") } }
    @Published var showSettingsButton: Bool { didSet { save(showSettingsButton, "showSettingsButtonV16") } }
    @Published var showNewTabButton: Bool { didSet { save(showNewTabButton, "showNewTabButtonV16") } }
    // Deze gebruikt de sleutel Self.appleStreamingEngineKey hieronder, zodat
    // dezelfde sleutel-tekst ook door andere functies (storedAppleStreamingEngine)
    // hergebruikt kan worden zonder typefouten.
    @Published var appleStreamingEngine: Bool { didSet { save(appleStreamingEngine, Self.appleStreamingEngineKey) } }
    // static let: hoort bij de class zelf (AppSettings.appleStreamingEngineKey),
    // niet bij één losse instantie. Zo is de sleutel overal in de app op
    // dezelfde manier op te vragen.
    static let appleStreamingEngineKey = "appleStreamingEngineV10"
    /// Off by default (user choice 26 Sep 2026): YouTube serves only 360p without MediaSource,
    /// so the default keeps MediaSource quality (up to 1080p/4K).
    static var defaultAppleStreamingEngine: Bool { false }
    // Een static functie die, los van een AppSettings-instantie, kan
    // opzoeken wat er eerder is opgeslagen. "_ defaults: UserDefaults = .standard"
    // betekent: een parameter zonder eigen naam bij het aanroepen, met
    // UserDefaults.standard (de gewone systeemopslag) als standaardwaarde.
    static func storedAppleStreamingEngine(_ defaults: UserDefaults = .standard) -> Bool {
        #if os(iOS)
        // defaults.object(forKey:) geeft nil als er nog nooit iets is
        // opgeslagen onder die sleutel: dan gebruiken we de standaardwaarde.
        if defaults.object(forKey: appleStreamingEngineKey) == nil { return defaultAppleStreamingEngine }
        return defaults.bool(forKey: appleStreamingEngineKey)
        #else
        return false
        #endif
    }

    // init is de "initializer": de functie die draait zodra een nieuw
    // AppSettings-object wordt aangemaakt. Hier krijgen alle @Published
    // properties hierboven hun eerste (opgeslagen of standaard) waarde.
    // "defaults: UserDefaults = .standard" betekent dat je bij het
    // aanmaken normaal niets hoeft mee te geven; in tests kan een andere
    // UserDefaults worden doorgegeven.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Een lokale hulp-functie, alleen bruikbaar binnen deze init: geeft
        // de opgeslagen Bool terug, of de meegegeven standaardwaarde
        // (fallback) als er nog niets is opgeslagen onder die sleutel.
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        automaticFullscreen = flag("automaticFullscreenV8", true)
        fullscreenOnPlay = flag("fullscreenOnPlayV22", true)
        disableCaptions = flag("disableCaptionsV8", true)
        disablePreviewCaptions = flag("disablePreviewCaptionsV8", true)
        // Voor enums werkt het net iets anders dan bij flag(): eerst wordt de
        // opgeslagen tekst (String) opgehaald met defaults.string(forKey:),
        // met "" als niets is opgeslagen. Daarna probeert
        // EnumType(rawValue:) die tekst om te zetten naar een geldige
        // enum-waarde; lukt dat niet (bijv. bij de eerste start), dan zorgt
        // "?? .standaardwaarde" voor een terugvalwaarde. Ook hier is er weer
        // een verschil tussen Mac (4K) en de rest (1080p).
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
        // AdBlockLevel.stored(defaults) is een functie die bij de enum zelf
        // hoort (net als TabLifetime.stored en SponsorBlockSettings.stored
        // verderop): die regelt zelf het opzoeken en de standaardwaarde,
        // zodat die logica niet hier hoeft te staan.
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
        // "as? Double" probeert de opgeslagen waarde als Double (kommagetal)
        // te lezen; lukt dat niet (bijv. niets opgeslagen), dan is het nil
        // en gebruiken we 1 via "?? 1". isFinite sluit rare waarden als
        // oneindig uit. min/max samen knijpen het getal tussen 0.75 en 1.5,
        // zodat de zoom nooit een onbruikbare waarde krijgt.
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
        // Vanaf hier worden de uiterlijk-instellingen (thema, iconen,
        // animatie, tabvorm) op dezelfde manier ingelezen als hierboven.
        themeStyle = ThemeStyle(rawValue: defaults.string(forKey: "themeStyleV15") ?? "") ?? .youtube
        accentChoice = AccentChoice(rawValue: defaults.string(forKey: "accentChoiceV15") ?? "") ?? .youtubeRed
        customAccentHex = defaults.string(forKey: "customAccentHexV15") ?? "#FF3B30"
        iconVariant = IconVariant(rawValue: defaults.string(forKey: "iconVariantV15") ?? "") ?? .outline
        iconWeight = IconWeightChoice(rawValue: defaults.string(forKey: "iconWeightV15") ?? "") ?? .regular
        iconRendering = IconRendering(rawValue: defaults.string(forKey: "iconRenderingV15") ?? "") ?? .monochrome
        animationStyle = AnimationStyle(rawValue: defaults.string(forKey: "animationStyleV15") ?? "") ?? .smooth
        tabShape = TabShape(rawValue: defaults.string(forKey: "tabShapeV15") ?? "") ?? .rounded
        tabCloseButtons = TabCloseButtons(rawValue: defaults.string(forKey: "tabCloseButtonsV15") ?? "") ?? .hover
        tabTextSize = TabTextSize(rawValue: defaults.string(forKey: "tabTextSizeV15") ?? "") ?? .regular
        // Read the saved text size; if nothing was saved yet use 1.0. `min/max` keep it in range.
        textScale = min(max((defaults.object(forKey: "textScaleV1621") as? Double) ?? 1, 0.7), 2.0)
        // V17: lees elke instelling; staat er nog niets opgeslagen, dan geldt de standaardwaarde.
        cookieBannerMode = CookieBannerMode(rawValue: defaults.string(forKey: "cookieBannerModeV17") ?? "") ?? .rejectAll
        stripTrackingParameters = flag("stripTrackingV17", true)
        globalPrivacyControl = flag("gpcV17", true)
        blockTrackers = flag("blockTrackersV17", true)
        clearDataOnQuit = flag("clearDataOnQuitV17", false)
        spatialAudio = flag("spatialAudioV17", true)
        backClosesTab = flag("backClosesTabV17", true)
        switchToNewTabs = flag("switchToNewTabsV17", true)
        pipOnAllSites = flag("pipOnAllSitesV17", true)
        showCreatorTools = flag("showCreatorToolsV17", true)
        smartMultiMonitorPiP = flag("smartMultiMonitorPiPV18", true)
        tabSync = flag("tabSyncV18", true)
        showSpeedControl = flag("showSpeedControlV18", true)
        showDownloadButton = flag("showDownloadButtonV18", true)
        swipeSeekSeconds = min(max((defaults.object(forKey: "swipeSeekSecondsV19") as? Double) ?? 5, 1), 30)
        volumeStepPercent = min(max((defaults.object(forKey: "volumeStepPercentV19") as? Double) ?? 1, 1), 10)
        showControlsWhileScrubbing = flag("showControlsWhileScrubbingV19", true)
        scrubThumbnail = flag("scrubThumbnailV19", true)
        arrowKeysShowControls = flag("arrowKeysShowControlsV19", false)
        exitFullscreenOnPause = flag("exitFullscreenOnPauseV22", false)
        speedStepSmall = min(max((defaults.object(forKey: "speedStepSmallV191") as? Double) ?? 0.05, 0.01), 0.5)
        speedStepMedium = min(max((defaults.object(forKey: "speedStepMediumV191") as? Double) ?? 0.25, 0.05), 1)
        speedStepLarge = min(max((defaults.object(forKey: "speedStepLargeV191") as? Double) ?? 0.5, 0.1), 2)
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
        // Vanaf hier: de V16-instellingen (theatermodus, databesparing,
        // visualizer, animatiesnelheid en welke knoppen zichtbaar zijn).
        theaterMode = flag("theaterModeV16", true)
        dataSaverOnCellular = flag("dataSaverOnCellularV16", false)
        cellularQuality = PlaybackQualityPreference(rawValue: defaults.string(forKey: "cellularQualityV16") ?? "") ?? .p720
        pipOnTabSwitch = flag("pipOnTabSwitchV16", true)
        fullscreenNewVideoFromPiP = flag("fullscreenNewVideoFromPiPV16", true)
        // V17.1: nieuwe sleutel → de visualizer staat voor iedereen standaard UIT.
        visualizerStyle = VisualizerStyle(rawValue: defaults.string(forKey: "visualizerStyleV171") ?? "") ?? .off
        visualizerConfig = defaults.data(forKey: "visualizerConfigV171").flatMap { try? JSONDecoder().decode(VisualizerConfig.self, from: $0) } ?? VisualizerConfig()
        visualizerIntensity = (defaults.object(forKey: "visualizerIntensityV16") as? Double) ?? 0.6
        visualizerInTabBar = flag("visualizerInTabBarV16", true)
        animationSpeed = (defaults.object(forKey: "animationSpeedV16") as? Double) ?? 1.6
        // Het omgekeerde van het encoderen bij de animationProfiles-property
        // hierboven: eerst de ruwe data (Data) ophalen, dan proberen te
        // decoderen (terugzetten) naar het dictionary-type. flatMap voert de
        // decodeer-stap alleen uit als er ook echt data was; "?? [:]" geeft
        // een leeg dictionary terug als er niets was of het decoderen faalde.
        animationProfiles = (defaults.data(forKey: "animationProfilesV16")).flatMap { try? JSONDecoder().decode([String: AnimationProfile].self, from: $0) } ?? [:]
        showRefreshButton = flag("showRefreshButtonV16", true)
        showHomeButton = flag("showHomeButtonV16", true)
        showSubscriptionsButton = flag("showSubscriptionsButtonV16", true)
        showLibraryButton = flag("showLibraryButtonV16", true)
        showQualityButton = flag("showQualityButtonV16", true)
        showAirPlayButton = flag("showAirPlayButtonV16", true)
        showSettingsButton = flag("showSettingsButtonV16", true)
        showNewTabButton = flag("showNewTabButtonV16", true)
        // Nu alle properties een waarde hebben, worden de twee functies die
        // van andere instellingen afhangen één keer met de verse waarden
        // uitgevoerd: de rotatievergrendeling instellen en de
        // tabtitel-samenvatter configureren.
        Self.applyOrientationLock(self)
        TabTitleSummarizer.configure(from: self)
        // V19 redesign: één keer de rustige "Minimal"-menubalk en lichtere iconen toepassen.
        // Daarna blijft elke knop gewoon aan/uit te zetten (en de preset te wisselen).
        if !defaults.bool(forKey: "redesignAppliedV19") {
            defaults.set(true, forKey: "redesignAppliedV19")
            ToolbarPreset.minimal.apply(to: self)
            iconWeight = .light
        }
        // V19.2: Mac en iPad krijgen de desktop-indeling (meer knoppen direct zichtbaar) en
        // automatisch fullscreen staat overal aan. Eén keer; daarna blijft je eigen keuze staan.
        if !defaults.bool(forKey: "layoutAppliedV192") {
            defaults.set(true, forKey: "layoutAppliedV192")
            if Self.isDesktopClass { ToolbarPreset.standard.apply(to: self) }
            automaticFullscreen = true
            showNavigationControls = true
        }
    }
    /// Mac of iPad (grote schermen) → desktop-indeling.
    static var isDesktopClass: Bool {
        #if os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    // snapshot is een berekende property die alle instellingen samenvat in
    // één SettingsSnapshot-waarde (bijvoorbeeld om ze in één keer door te
    // geven aan de webpagina/JavaScript-kant van de app).
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
            // V17: animaties uit = ook de snelste overgangen, wat "instantTransitions" ook zegt.
            instantTransitions: instantTransitions || animationStyle == .off, sponsorBlock: sponsorBlock,
            theaterMode: theaterMode, dataSaverOnCellular: dataSaverOnCellular, cellularQuality: cellularQuality,
            cookieBannerMode: cookieBannerMode, stripTrackingParameters: stripTrackingParameters,
            globalPrivacyControl: globalPrivacyControl, blockTrackers: blockTrackers, spatialAudio: spatialAudio,
            pipOnAllSites: pipOnAllSites, animationsOff: animationStyle == .off,
            smartMultiMonitorPiP: smartMultiMonitorPiP,
            swipeSeekSeconds: swipeSeekSeconds, volumeStepPercent: volumeStepPercent,
            showControlsWhileScrubbing: showControlsWhileScrubbing, scrubThumbnail: scrubThumbnail,
            arrowKeysShowControls: arrowKeysShowControls, exitFullscreenOnPause: exitFullscreenOnPause, fullscreenOnPlay: fullscreenOnPlay)
    }
    // Een gewone functie (geen property): wordt aangeroepen als de
    // gebruiker de servicemelding accepteert, en zet de bijbehorende
    // instelling op true (wat door didSet meteen wordt opgeslagen).
    func acceptServiceNotice() { acceptedServiceNotice = true }
    // resetPreferences zet letterlijk elke instelling terug naar de
    // standaardwaarde van de app (gebruikt bij de knop "Reset all
    // preferences" in het instellingenscherm). Elke toekenning hier
    // triggert weer de didSet van die property, dus alles wordt ook meteen
    // opnieuw opgeslagen.
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
        themeStyle = .youtube; accentChoice = .youtubeRed; customAccentHex = "#FF3B30"
        iconVariant = .outline; iconWeight = .regular; iconRendering = .monochrome; animationStyle = .smooth
        tabShape = .rounded; tabCloseButtons = .hover; tabTextSize = .regular; showTabIcons = true
        textScale = 1
        cookieBannerMode = .rejectAll; stripTrackingParameters = true; globalPrivacyControl = true
        blockTrackers = true; clearDataOnQuit = false; spatialAudio = true; backClosesTab = true
        switchToNewTabs = true; pipOnAllSites = true; showCreatorTools = true
        smartMultiMonitorPiP = true; tabSync = true; showSpeedControl = true; showDownloadButton = true
        swipeSeekSeconds = 5; volumeStepPercent = 1; showControlsWhileScrubbing = true; scrubThumbnail = true; arrowKeysShowControls = false
        speedStepSmall = 0.05; speedStepMedium = 0.25; speedStepLarge = 0.5; exitFullscreenOnPause = false; fullscreenOnPlay = true
        showMoreMenu = true; showBookmarkButton = false
        aiTabSummary = true; tabSummaryLength = .short; useAppleIntelligence = true; openNewTabsNextToCurrent = true
        openWebLinksInApp = true; searchEngine = .youtube; recordHistory = true
        pipReturnTarget = .fullscreen; pipReturnKeepsPlaying = true; keepScreenAwake = true
        portraitLockForRotation = true; instantTransitions = true; sponsorBlock = SponsorBlockSettings()
        theaterMode = true; dataSaverOnCellular = false; cellularQuality = .p720; pipOnTabSwitch = true
        fullscreenNewVideoFromPiP = true; visualizerStyle = .off; visualizerIntensity = 0.6; visualizerInTabBar = true; visualizerConfig = VisualizerConfig()
        animationSpeed = 1.6; animationProfiles = [:]
        showRefreshButton = true; showHomeButton = true; showSubscriptionsButton = true; showLibraryButton = true
        showQualityButton = true; showAirPlayButton = true; showSettingsButton = true; showNewTabButton = true
    }
    // De hulp-functie die overal hierboven in didSet wordt gebruikt: hij
    // slaat één waarde ("value", van eender welk type dankzij "Any") op in
    // UserDefaults onder de gegeven sleutel ("key"). "private" omdat alleen
    // deze class hem nodig heeft.
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
    // Berekende property die de gekozen accentkeuze omzet naar een echte
    // SwiftUI Color, met de eigen kleurcode (customAccentHex) als de
    // gebruiker voor "aangepast" heeft gekozen.
    var accentColor: Color { accentChoice.color(custom: customAccentHex) }
    // Een korte snelkoppeling: de "algemene" animatie is gewoon de animatie
    // voor het onderdeel .tabs, opgehaald via de functie animation(_:) hieronder.
    var animation: Animation? { animation(.tabs) }
    /// V16: curve and speed for one part of the app (global style/speed unless overridden).
    func animation(_ kind: AnimationKind) -> Animation? {
        // V22.2: "Animaties uit" betekent overal uit, ook als een onderdeel een eigen profiel heeft.
        if animationStyle == .off { return nil }
        // Zoek het eigen profiel voor dit onderdeel op; is er nog geen
        // aangepast profiel, gebruik dan een leeg/standaard AnimationProfile.
        let profile = animationProfiles[kind.rawValue] ?? AnimationProfile()
        // Gebruik de eigen stijl van het profiel, of anders de algemene
        // animationStyle. De snelheid wordt vermenigvuldigd: de algemene
        // snelheid keer de relatieve snelheid van dit ene onderdeel.
        return (profile.style ?? animationStyle).animation(speed: animationSpeed * profile.speed)
    }
    /// iPhone: keep the interface in portrait so a landscape turn goes straight into fullscreen.
    static func applyOrientationLock(_ settings: AppSettings) {
        #if os(iOS)
        // Alleen vergrendelen als alle drie de voorwaarden waar zijn: de
        // gebruiker wil de instant-rotatie-truc, fullscreen-bij-landscape
        // staat aan, én het is een iPhone (geen iPad). "&&" betekent "en".
        OrientationCoordinator.portraitLocked = settings.portraitLockForRotation && settings.fullscreenOnLandscape &&
            UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }
}
