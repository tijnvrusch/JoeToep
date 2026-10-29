import Foundation
import Combine
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class WebSession: NSObject, ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var isFullscreen = false
    @Published private(set) var isVideoStage = false
    @Published private(set) var mediaResolution: String?
    @Published private(set) var currentURL: URL?
    @Published private(set) var pip = PiPStateMachine()
    @Published private(set) var qualityLevels: [PlaybackQualityPreference] = []
    @Published private(set) var qualityAPIAvailable = false
    @Published private(set) var measuredQuality = ""
    @Published private(set) var diagnostic = "Ready"
    @Published private(set) var filterStatus = "Preparing local rules"
    @Published private(set) var mediaCompatibilityStatus = "Preparing"
    @Published private(set) var experimentalFilterStatus = "No downloaded experimental rules"
    @Published private(set) var isUpdatingFilters = false
    @Published var notice: SessionNotice?

    @Published var authenticationWebView: WKWebView?
    /// V15: document title (tab titles / AI summaries) and browser state.
    @Published private(set) var pageTitle: String?
    @Published private(set) var sponsorStatus = "Idle"
    @Published private(set) var sitePresentationOverride: SitePresentation?
    @Published private(set) var zoomOverride: Double?
    let isPrivate: Bool
    /// URL, switch-to-it. Set by the workspace (context menus, target=_blank links).
    var onOpenInNewTab: ((URL, Bool) -> Void)?
    private var contextLink: (url: URL, date: Date)?
    private var titleObservation: NSKeyValueObservation?
    private var sponsorTask: Task<Void, Never>?
    private var sponsorVideoID: String?
    private var sponsorSegments: [SponsorBlockService.Segment] = []
    private var historyTask: Task<Void, Never>?
    private var lastRecordedURL: URL?
    private var installedScriptKey = ""
    private var fullscreenVerifyTask: Task<Void, Never>?
    private var onExpensiveNetwork = false
    private var forceRefreshing = false
    /// V16: quality to request right now (data saver only when enabled and on cellular/hotspot).
    var effectiveQuality: PlaybackQualityPreference {
        settings.dataSaverOnCellular && onExpensiveNetwork ? settings.cellularQuality : settings.quality
    }
    let webView: WKWebView
    #if os(macOS)
    /// V18: volgt app-wissels op andere schermen (alleen actief terwijl JoeToep op de achtergrond speelt).
    private let screenFocus = ScreenFocusMonitor()
    #endif
    let networkMonitor = NetworkMonitor()
    private let playbackSession: PlaybackSessionController
    private let contentController: WKUserContentController
    private let filters = ContentFilterController()
    private static let bridgeWorld = WKContentWorld.world(name: "JoeToepBridgeWorld")
    private var settings = SettingsSnapshot.standard
    var restoredURL: URL?
    /// V11: position to continue after relaunch (per tab), and the live resumable position.
    var restoredTime: Double?
    var restoredPlaying = false
    var focusSearchWhenReady = false
    struct ResumePoint: Equatable { var url: URL; var time: Double; var playing: Bool; var duration: Double? = nil }
    @Published private(set) var resumePoint: ResumePoint?
    private var pendingResume: (time: Double, play: Bool)?
    private var positionTask: Task<Void, Never>?
    private var reconcileTask: Task<Void, Never>?
    private var sawLandscapeWhileFullscreen = false
    private var returnFromPiPTask: Task<Void, Never>?
    private var usesElementFullscreen: Bool {
        #if os(iOS)
        settings.phoneElementFullscreen && UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
    private var hasStarted = false
    private var documentID: String?
    private var videoID = 0
    private var leavingEpisode = false
    private var attemptedAutomaticInEpisode = false
    private var applicationActive = true
    private var suppressExitPiP = false
    private var pendingPresentationReload = false
    private var floatingAfterFullscreen = false
    private var terminations: [Date] = []
    private var pipWatchdog: Task<Void, Never>?
    private var exitTask: Task<Void, Never>?
    private var qualityTask: Task<Void, Never>?
    private var orientationTask: Task<Void, Never>?
    private var fallbackToken: Int?
    private var automaticHandoffTask: Task<Void, Never>?
    private var systemFullscreenHandoff = false
    private var visibilityProtectionApplied = false
    private var navigatingAway = false
    private var navigationSerial = 0
    private var navigationTask: Task<Void, Never>?
    private var macReturnTask: Task<Void, Never>?
    private var handoffReleaseTask: Task<Void, Never>?
    private var lifecycleEvents: [String] = []
    /// UI-test probe only (published in test mode, so normal use pays nothing).
    @Published private(set) var lifecycleTail = ""
    private var foregroundReturn = ForegroundReturnGate()
    private var fullscreenReturnDeadline: Date?
    private var fullscreenReturnTask: Task<Void, Never>?
    private var pipReturnSafetyTask: Task<Void, Never>?
    /// V16.2.1 hand-over flag. While this date lies in the future, this tab's PiP window is
    /// being closed ON PURPOSE because another tab started a video. During that time the tab
    /// must stay quietly in the background: no fullscreen restore and (Mac) no bringing its
    /// window forward, which used to switch macOS to another Space ("the video disappears").
    private var pipHandoverUntil: Date?
    /// Writes a line to this tab's lifecycle log (Diagnostics, and the UI-test probe).
    func noteHandOver(_ text: String) { recordLifecycle(text) }
    /// Shared by ALL tabs (`static`): until this moment some tab is still closing its PiP window
    /// for a hand-over. The new tab's automatic fullscreen waits for it, so fullscreen always
    /// starts after the PiP window is gone (otherwise macOS could show the wrong Space).
    static var handOverClosingUntil = Date.distantPast
    /// True while a hand-over is running (see `pipHandoverUntil`).
    var isHandingOver: Bool { (pipHandoverUntil ?? .distantPast) > Date() }
    #if os(iOS)
    private var handoffTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif
    private var navObservation: NSKeyValueObservation?
    private var historyObservation: NSKeyValueObservation?
    private var networkObservation: AnyCancellable?
    private var lastRequestedURL: URL?
    private var failedNavigationURL: URL?
    private var networkRetryCount = 0
    private static let networkRetryDelays: [Double] = [0.8, 2.5, 6]
    private var networkRetryTask: Task<Void, Never>?
    #if os(macOS)
    private let floating = MacFloatingPlayerController()
    #endif
    #if os(iOS)
    /// V10: prepared native AVKit presenter for inline video (Apple HLS engine only).
    private let nativePiP = NativePiPController()
    private var nativeSyncTask: Task<Void, Never>?
    private var nativeSuspendTask: Task<Void, Never>?
    private var nativeResetTask: Task<Void, Never>?
    private var nativePiPWasFullscreen = false
    #endif
    /// Apple HLS engine: MediaSource disabled so YouTube plays URL media (video AirPlay + native PiP).
    let appleStreamingEngine: Bool
    @Published private(set) var nativePiPActive = false

    var isInPictureInPicture: Bool { pip.isActive || nativePiPActive }
    var isFloating: Bool { pip.state == .floating }
    var isPiPRequesting: Bool { pip.isRequesting }
    var isTestMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        false
        #endif
    }

    init(privateMode: Bool = false) {
        isPrivate = privateMode
        // Ordering matters: audio category precedes WebKit construction and initial playback.
        playbackSession = PlaybackSessionController()
        let controller = WKUserContentController()
        contentController = controller
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = privateMode ? .nonPersistent() : .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.ignoresViewportScaleLimits = true
        #endif
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true
        let nativeMediaEnabled = JTConfigureMedia(configuration)
        appleStreamingEngine = AppSettings.storedAppleStreamingEngine()
        #if os(iOS)
        if appleStreamingEngine { JTSetMediaSourceEnabled(configuration, false) }
        #endif
        webView = JoeToepWebView(frame: .zero, configuration: configuration)
        super.init()
        mediaCompatibilityStatus = (nativeMediaEnabled ? "Native PiP configured" : "Native PiP preference unavailable") +
            " · " + JTMediaConfigurationSummary()
        #if os(iOS)
        configureNativePiP()
        #endif
        controller.add(WeakScriptMessageHandler(delegate: self), contentWorld: Self.bridgeWorld, name: AppConstants.scriptMessageName)
        controller.add(WeakScriptMessageHandler(delegate: self), contentWorld: Self.bridgeWorld, name: AppConstants.linkMessageName)
        installUserScripts()
        playbackSession.onInterruption = { [weak self] interrupted, canResume in
            self?.webView.evaluateJavaScript("window.JoeToepMedia?.setInterrupted(\(interrupted), \(canResume))", completionHandler: nil)
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // V19.2: horizontaal vegen is nu voor scrubben in de video. Terug-vegen (pagina terug /
        // tab sluiten) staat daarom standaard UIT; de Terug-knop blijft altijd in de menubalk.
        let backSwipe = UserDefaults.standard.object(forKey: "backSwipeV192") as? Bool ?? false
        webView.allowsBackForwardNavigationGestures = backSwipe
        #if os(iOS)
        if backSwipe {
            // V17: vegen vanaf de linkerrand terwijl de tab GEEN vorige pagina heeft → tab sluiten.
            let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeSwipe(_:)))
            edge.edges = .left
            edge.delegate = self
            webView.addGestureRecognizer(edge)
        }
        #endif
        #if os(iOS)
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceHorizontal = false
        // V22: de pagina stond op de iPhone soms een stukje naar links geschoven (horizontale
        // offset bleef hangen na een veeg/scrub of een te brede pagina). Zolang de pagina niet
        // bewust ingezoomd is, blijft hij altijd precies van rand tot rand staan.
        webView.scrollView.contentInset = .zero
        webView.scrollView.showsHorizontalScrollIndicator = false
        // V22.1: ook als de pagina (per ongeluk) breder is dan het scherm of licht ingezoomd staat:
        // zolang knijpen niet voor de pagina is ingesteld, staat hij altijd op 100 % en links op 0.
        horizontalLock = webView.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.pinchMode != .page, !scroll.isZooming else { return }
                if abs(scroll.contentOffset.x) > 0.5 { scroll.contentOffset.x = 0 }
            }
        }
        zoomLock = webView.scrollView.observe(\.zoomScale, options: [.new]) { [weak self] scroll, _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.pinchMode != .page, !scroll.isZooming else { return }
                // Altijd "passend op de breedte" (ook de desktopweergave, 980 px breed).
                let fit = scroll.minimumZoomScale
                if abs(scroll.zoomScale - fit) > 0.001 { scroll.setZoomScale(fit, animated: false) }
                if abs(scroll.contentOffset.x) > 0.5 { scroll.contentOffset.x = 0 }
            }
        }
        webView.scrollView.bouncesZoom = false
        // V19.1: trekken om te verversen (iPhone/iPad), instelbaar.
        // V19.2: "trekken" = fullscreen (standaard), verversen, of uit.
        if Self.pullAction != "off" {
            let refresh = UIRefreshControl()
            refresh.addAction(UIAction { [weak self, weak refresh] _ in
                self?.performPullAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { refresh?.endRefreshing() }
            }, for: .valueChanged)
            webView.scrollView.refreshControl = refresh
        }
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.overrideUserInterfaceStyle = .dark
        #else
        webView.appearance = NSAppearance(named: .darkAqua)
        floating.onClose = { [weak self] in self?.pip.exitFloating() }
        #endif
        webView.isInspectable = true
        webView.allowsLinkPreview = true
        #if os(iOS)
        webView.isFindInteractionEnabled = true
        #endif
        #if os(macOS)
        if let custom = webView as? JoeToepWebView {
            custom.contextLink = { [weak self] in
                guard let link = self?.contextLink, Date().timeIntervalSince(link.date) < 3 else { return nil }
                return link.url
            }
            custom.openInNewTab = { [weak self] url, activate in self?.onOpenInNewTab?(url, activate) }
            custom.openInNewWindow = { url in WindowOpener.open(url) }      // V17.1
        }
        #endif
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.titleChanged() }
        }
        navObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshNavigationState() }
        }
        historyObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshNavigationState() }
        }
        networkObservation = networkMonitor.$state.removeDuplicates().sink { [weak self] state in
            guard let self else { return }
            self.objectWillChange.send()
            // V16: optional data saver on cellular / personal hotspot (e.g. "eiFoon"); off by default.
            let expensive: Bool = { if case let .online(e, c) = state { return e || c }; return false }()
            if expensive != self.onExpensiveNetwork {
                self.onExpensiveNetwork = expensive
                if self.settings.dataSaverOnCellular && self.videoID != 0 {
                    DispatchQueue.main.async { self.requestQuality(self.effectiveQuality, userInitiated: false) }
                }
            }
            // A real offline -> online transition earns a fresh retry budget.
            if state.isOnline && self.failedNavigationURL != nil {
                self.networkRetryCount = 0
                self.retryFailedNavigationIfEligible()
            }
        }
    }

    func start(with initial: SettingsSnapshot) {
        guard !hasStarted else { return }
        hasStarted = true; settings = initial
        installUserScripts()
        applyTheaterCookie()
        applyNativeSettings()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let failures = await self.filters.prepare()
            self.filters.apply(self.settings, to: self.contentController)
            self.experimentalFilterStatus = self.filters.experimentalStatus
            self.filterStatus = failures.isEmpty ? "Local rules ready" : "Unavailable: " + failures.joined(separator: ", ")
            if !failures.isEmpty {
                self.showNotice(.warning, "Some filters are unavailable", "Playback remains available. See Diagnostics for filter status.")
            }
            if self.isTestMode { self.loadTestFixture() } else if let url = self.restoredURL {
                if self.syncedStartPaused, NavigationPolicy.isPlaybackPage(url) {
                    // V18: tab van een ander apparaat → op de juiste plek klaarzetten, NIET afspelen
                    // (het andere apparaat speelt; één apparaat tegelijk).
                    self.syncedStartPaused = false
                    let time = max(self.restoredTime ?? 1, 1)
                    self.pendingResume = (time, false)
                    self.load(time >= 3 ? Self.url(url, at: time) : url)
                } else if let time = self.restoredTime, time >= 3, NavigationPolicy.isPlaybackPage(url) {
                    // V21: direct na het opstarten niet vanzelf verder spelen (instelbaar), wél bij
                    // overnemen van een ander apparaat of als je later zelf deze tab opent.
                    let play = self.forcePlayOnStart || !LaunchPrefs.isLaunchPhase || LaunchPrefs.resumeOnLaunch
                    self.forcePlayOnStart = false
                    self.pendingResume = (time, play)
                    self.load(Self.url(url, at: time))
                } else { self.load(url) }
            } else { self.load(self.settings.startPage.url) }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-test-notice") {
            // V17.1: 1.5 s na het starten tonen, zodat de UI-test de melding zeker ziet verschijnen
            // (bij een tragere eerste start was hij al weg voordat de test keek).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showNotice(.information, "Test notice", "This banner expires after five seconds.")
            }
        }
        #endif
    }

    func apply(_ updated: SettingsSnapshot) {
        let old = settings
        settings = updated
        applyNativeSettings()
        configureCompatibility()
        if old.adBlockLevel != updated.adBlockLevel || old.hideAdCards != updated.hideAdCards ||
            old.experimentalFilters != updated.experimentalFilters ||
            old.blockAds != updated.blockAds || old.blockShortsNavigation != updated.blockShortsNavigation ||
            old.blockPostsNavigation != updated.blockPostsNavigation || old.blockPremiumDestinations != updated.blockPremiumDestinations {
            filters.apply(updated, to: contentController)
            showNotice(.information, "Filters updated", "Rules apply to new page loads. Reload when ready; playback is not restarted automatically.")
        }
        if updated.experimentalFilters && !old.experimentalFilters { updateExperimentalFilters() }
        if old.adBlockLevel != updated.adBlockLevel || old.blockAds != updated.blockAds || old.hideAdCards != updated.hideAdCards {
            installUserScripts()
        }
        if old.sponsorBlock != updated.sponsorBlock {
            if old.sponsorBlock.activeCategories != updated.sponsorBlock.activeCategories ||
                old.sponsorBlock.serverURL != updated.sponsorBlock.serverURL || old.sponsorBlock.enabled != updated.sponsorBlock.enabled {
                sponsorVideoID = nil; updateSponsorBlock()
            } else { pushSponsorBlock() }
        }
        if old.pipReturnTarget != updated.pipReturnTarget || old.pipReturnKeepsPlaying != updated.pipReturnKeepsPlaying ||
            old.swipeSeekSeconds != updated.swipeSeekSeconds || old.volumeStepPercent != updated.volumeStepPercent ||
            old.showControlsWhileScrubbing != updated.showControlsWhileScrubbing || old.scrubThumbnail != updated.scrubThumbnail ||
            old.arrowKeysShowControls != updated.arrowKeysShowControls || old.exitFullscreenOnPause != updated.exitFullscreenOnPause ||
            old.fullscreenOnPlay != updated.fullscreenOnPlay || old.automaticFullscreen != updated.automaticFullscreen {
            configureCompatibility()
        }
        if old.videoFit != updated.videoFit || old.pinchMode != updated.pinchMode { configureBridge() }
        if old.automaticPiP != updated.automaticPiP || old.backgroundProtection != updated.backgroundProtection ||
            old.nativeFullscreen != updated.nativeFullscreen || old.pipFallbackEnabled != updated.pipFallbackEnabled {
            configureCompatibility()
            updateBackgroundProtection()
        }
        // V17: ruimtelijke audio aan/uit → de audiosessie van iOS meteen opnieuw instellen.
        #if os(iOS)
        if old.spatialAudio != updated.spatialAudio { playbackSession.refreshSpatialAudio() }
        #endif
        if old.quality != updated.quality || old.dataSaverOnCellular != updated.dataSaverOnCellular || old.cellularQuality != updated.cellularQuality {
            requestQuality(effectiveQuality, userInitiated: old.quality != updated.quality)
        }
        if old.theaterMode != updated.theaterMode { applyTheaterCookie() }
        if old.sitePresentation != updated.sitePresentation && hasStarted {
            if pip.isActive || pip.isRequesting || isPlaying {
                pendingPresentationReload = true
                showNotice(.information, "Applies on next page", "Site presentation is deferred to avoid interrupting playback. Reload manually when ready.")
            } else { webView.reload() }
        }
    }

    private func applyNativeSettings() {
        let zoom = zoomOverride ?? settings.pageZoom
        webView.pageZoom = zoom.isFinite ? min(max(zoom, 0.5), 3) : 1
        #if os(iOS)
        webView.scrollView.pinchGestureRecognizer?.isEnabled = settings.pinchMode == .page
        #else
        webView.allowsMagnification = settings.pinchMode == .page
        if settings.pinchMode != .page { webView.magnification = 1 }
        #endif
    }

    func load(_ input: URL) {
        var url = input
        if (sitePresentationOverride ?? settings.sitePresentation) == .desktop, input.host == "m.youtube.com",
           var parts = URLComponents(url: input, resolvingAgainstBaseURL: false) {
            parts.host = "www.youtube.com"; url = parts.url ?? input
        }
        // V17: volg-parameters (utm_, fbclid, si …) uit het adres halen vóór het laden.
        if settings.stripTrackingParameters { url = TrackingParameters.clean(url) }
        lastRequestedURL = url; failedNavigationURL = nil; networkRetryCount = 0
        networkRetryTask?.cancel()
        navigate { [weak self] in self?.webView.load(URLRequest(url: url, timeoutInterval: 30)) }
    }
    func goHome() { load(StartPage.home.url) }
    /// V17: wordt door BrowserWorkspace ingevuld. Wordt aangeroepen als je "terug" doet terwijl er
    /// geen vorige pagina is: dan sluit de werkruimte deze tab (en toont de tab waar je vandaan kwam).
    var onCannotGoBack: (() -> Void)?
    func goBack() {
        guard canGoBack else {
            // V17: geen vorige pagina → tab sluiten (instelling "Terug sluit de tab").
            if let close = onCannotGoBack { close(); return }
            showNotice(.information, "No previous page", "This is the first page in this window."); return
        }
        navigate { [weak self] in self?.webView.goBack() }
    }
    func goForward() {
        guard canGoForward else { showNotice(.information, "No next page", "There is no forward page in this window."); return }
        navigate { [weak self] in self?.webView.goForward() }
    }
    private func navigate(_ action: @escaping @MainActor () -> Void) {
        prepareNavigation()
        navigationSerial += 1
        let ticket = navigationSerial
        navigationTask?.cancel()
        let finish: @MainActor () -> Void = { [weak self] in
            guard let self, self.navigationSerial == ticket else { return }
            self.navigationSerial += 1
            self.navigationTask?.cancel()
            action()
        }
        // Allow native fullscreen/stage cleanup before replacing its document.
        // If the web process is unresponsive, navigation still proceeds once.
        navigationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            finish()
        }
        webView.evaluateJavaScript("window.JoeToepMedia?.leaveForNavigation()") { _, _ in finish() }
    }
    private func prepareNavigation() {
        networkRetryTask?.cancel(); failedNavigationURL = nil
        navigatingAway = true
        macReturnTask?.cancel()
        fullscreenReturnTask?.cancel(); fullscreenReturnDeadline = nil
        automaticHandoffTask?.cancel(); pipWatchdog?.cancel(); exitTask?.cancel(); orientationTask?.cancel()
        systemFullscreenHandoff = false; endHandoff()
        #if os(macOS)
        floating.restore()
        #endif
        pip.reset(); isPlaying = false; isFullscreen = false; isVideoStage = false
        updateBackgroundProtection()
    }
    func reload() {
        pendingPresentationReload = false
        networkRetryTask?.cancel(); networkRetryCount = 0
        if let failed = failedNavigationURL { load(failed) }
        else if currentURL == nil { load(lastRequestedURL ?? settings.startPage.url) }
        else if let url = currentURL, NavigationPolicy.isPlaybackPage(url) {
            // V11: a refresh continues the same video at the same moment.
            webView.evaluateJavaScript("window.JoeToepMedia?.sourceInfo()") { [weak self] value, _ in
                guard let self else { return }
                let info = value as? [String: Any] ?? [:]
                let time = (info["time"] as? Double) ?? self.resumePoint?.time ?? 0
                let playing = (info["playing"] as? Bool) ?? self.isPlaying
                if time >= 1 {
                    self.pendingResume = (time, playing)
                    self.load(Self.url(url, at: time))
                } else { self.navigate { [weak self] in self?.webView.reloadFromOrigin() } }
            }
        }
        else { navigate { [weak self] in self?.webView.reloadFromOrigin() } }
    }

    /// V11: new tabs accept typing immediately; also used by the '/' shortcut path.
    func focusSearch() {
        #if os(iOS)
        JTAllowProgrammaticFocus(webView, 4)
        #else
        webView.window?.makeFirstResponder(webView)
        #endif
        webView.evaluateJavaScript("window.JoeToepPreferences?.focusSearch()", completionHandler: nil)
    }

    /// V11: lock/unlock can pause PiP without user intent; let the page recover that once.
    func platformTransition(_ name: String) {
        recordLifecycle("platform: " + name)
        guard pip.isActive || isFullscreen || isPlaying else { return }
        webView.evaluateJavaScript("window.JoeToepMedia?.platformTransition()", completionHandler: nil)
    }

    #if os(iOS)
    /// V11: rotating the iPhone to landscape while a video plays opens Apple fullscreen.
    func deviceOrientationChanged() {
        let orientation = UIDevice.current.orientation
        guard UIDevice.current.userInterfaceIdiom == .phone, applicationActive else { return }
        if isFullscreen && orientation.isLandscape { sawLandscapeWhileFullscreen = true }
        // V12: back to portrait after watching fullscreen in landscape: continue inline.
        if orientation == .portrait && isFullscreen && sawLandscapeWhileFullscreen && settings.exitFullscreenOnPortrait &&
            !pip.isActive && !pip.isRequesting {
            sawLandscapeWhileFullscreen = false
            recordLifecycle("portrait: leave fullscreen, keep playing")
            suppressExitPiP = true
            webView.evaluateJavaScript("window.JoeToepMedia?.exitFullscreenKeepPlaying()", completionHandler: nil)
            return
        }
        guard settings.fullscreenOnLandscape,
              orientation.isLandscape, isPlaying, !isFullscreen,
              !pip.isActive, !pip.isRequesting, !nativePiPActive,
              isTestMode || NavigationPolicy.isPlaybackPage(currentURL) else { return }
        recordLifecycle("landscape: enter fullscreen")
        sawLandscapeWhileFullscreen = true
        webView.evaluateJavaScript("window.JoeToepMedia?.fullscreen()", completionHandler: nil)
    }
    #endif

    /// Watch URL that starts at `time` (YouTube's own t= parameter), without duplicates.
    static func url(_ url: URL, at time: Double) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = (parts.queryItems ?? []).filter { $0.name != "t" && $0.name != "start" }
        items.append(URLQueryItem(name: "t", value: "\(Int(time.rounded(.down)))s"))
        parts.queryItems = items
        return parts.url ?? url
    }

    /// V11: remember where the video is so a refresh or relaunch continues there.
    private func capturePosition() {
        guard let url = currentURL, NavigationPolicy.isPlaybackPage(url) else { return }
        webView.evaluateJavaScript("window.JoeToepMedia?.sourceInfo()") { [weak self] value, _ in
            guard let self, let info = value as? [String: Any], let time = info["time"] as? Double,
                  time.isFinite, time >= 0, (info["media"] as? Bool) == true else { return }
            let duration = (info["duration"] as? Double).flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
            let point = ResumePoint(url: url, time: time, playing: (info["playing"] as? Bool) ?? false, duration: duration)
            if self.resumePoint != point { self.resumePoint = point }
        }
    }
    private func updatePositionTracking() {
        if isPlaying {
            guard positionTask == nil else { return }
            positionTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    // V18: met verbonden apparaten elke 2 s (live positie), anders elke 5 s (zuinig).
                    let interval = TabSyncService.shared.peers.isEmpty ? 3.0 : 0.5  // V22: live positie
                    try? await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled, let self else { break }
                    self.capturePosition()
                }
            }
        } else {
            positionTask?.cancel(); positionTask = nil
            capturePosition()
        }
    }

    /// V11: a PiP button that says "active" while no system window exists is repaired from the
    /// real WebKit state; if WebKit itself is stuck, the page reloads at the same moment.
    func reconcilePictureInPicture(repairStuck: Bool) {
        #if os(iOS)
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for attempt in 0..<3 {
                let mode = (try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.actualPresentation()")) as? String
                let native = JTNativePiPIsActive(self.webView) || self.nativePiPActive
                let jsPiP = mode == "picture-in-picture"
                if native { if self.pip.state != .native && !self.nativePiPActive { self.pip.confirmNative() }; return }
                if !jsPiP {
                    if self.pip.state == .native { self.pip.exitNative(); self.recordLifecycle("reconcile: stale PiP button cleared") }
                    // V16.2: a repaired stale PiP lands inline; the user asked to come back fullscreen.
                    if attempt > 0 && self.applicationActive && self.isPlaying && !self.isFullscreen &&
                        self.settings.pipReturnTarget != .inline {
                        self.recordLifecycle("reconcile: repaired, continue fullscreen")
                        _ = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.restoreFullscreen(true)")
                    }
                    return
                }
                // Page says PiP, WebKit shows no window: ask for inline, then re-check.
                self.recordLifecycle("reconcile: stale page PiP (attempt \(attempt))")
                _ = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.resetPiP()")
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
            }
            self.pip.reset()
            guard repairStuck, self.applicationActive else { return }
            self.recordLifecycle("reconcile: WebKit presentation stuck, reload at position")
            self.reload()
        }
        #endif
    }


    /// Is de huidige pagina YouTube? (Dan regelt mediaCompatibility.js de PiP, anders webPiP.js.)
    var isOnYouTube: Bool { NavigationPolicy.isYouTubeHost((currentURL?.host ?? "").lowercased()) }
    func togglePictureInPicture() {
        // V17: andere websites → het algemene PiP-script kiest de beste video en start/stopt PiP.
        // evaluateJavaScript telt in WebKit als gebruikersactie, dus de site mag PiP starten.
        if !isOnYouTube && settings.pipOnAllSites && !isTestMode {
            recordLifecycle("web PiP toggle (non-YouTube site)")
            webView.evaluateJavaScript("window.JoeToepWebPiP && window.JoeToepWebPiP.toggle(); 0", completionHandler: nil)
            return
        }
        #if os(iOS)
        if nativePiPActive || nativePiP.isStarting { nativePiP.stop(); return }
        if nativePiP.isArmed && !isFullscreen && !pip.isActive && !pip.isRequesting {
            webView.evaluateJavaScript("window.JoeToepMedia?.sourceInfo()") { [weak self] value, _ in
                guard let self else { return }
                let info = value as? [String: Any] ?? [:]
                self.nativePiP.start(time: (info["time"] as? Double) ?? self.nativePiP.currentTime)
                self.diagnostic = "Native PiP requested (button)"
            }
            return
        }
        #endif
        if pip.state == .floating {
            #if os(macOS)
            floating.restore()
            #endif
            return
        }
        webView.evaluateJavaScript("window.JoeToepMedia?.actualPresentation()") { [weak self] value, _ in
            guard let self else { return }
            let active = (value as? String) == "picture-in-picture" || JTNativePiPIsActive(self.webView)
            if active {
                self.suppressExitPiP = true
                self.webView.evaluateJavaScript("window.JoeToepMedia?.returnToApp('origin')", completionHandler: nil)
            } else {
                self.pipWatchdog?.cancel()
                self.pip.reset()
                self.webView.evaluateJavaScript("window.JoeToepMedia?.cancelHandoff()", completionHandler: nil)
                self.requestPictureInPicture(reason: .manual)
            }
        }
    }

    private var resetPiPTask: Task<Void, Never>?
    private var resettingPiP = false
    func resetPictureInPicture() {
        #if os(iOS)
        if nativePiPActive || nativePiP.isStarting || (nativePiP.isArmed && !isFullscreen && !pip.isActive) {
            nativeResetTask?.cancel()
            let wasActive = nativePiPActive || nativePiP.isStarting
            if wasActive { nativePiP.stop() }
            nativeResetTask = Task { @MainActor [weak self] in
                // Let AVKit finish returning, then rebuild the presenter from the live web video.
                try? await Task.sleep(for: .milliseconds(wasActive ? 900 : 100))
                guard !Task.isCancelled, let self else { return }
                self.nativePiP.disarm()
                self.refreshNativeShadow { [weak self] armed in
                    guard let self, armed else { return }
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(350))
                        guard let self, !Task.isCancelled else { return }
                        self.nativePiP.start(time: self.nativePiP.currentTime)
                    }
                }
            }
            showNotice(.information, "Picture in Picture reset", "The video keeps its position.")
            return
        }
        #endif
        resetPiPTask?.cancel(); resettingPiP = true
        pipWatchdog?.cancel(); automaticHandoffTask?.cancel()
        exitTask?.cancel(); fullscreenReturnTask?.cancel(); fullscreenReturnDeadline = nil
        systemFullscreenHandoff = false; suppressExitPiP = true
        pip.reset(); endHandoff()
        resetPiPTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.resettingPiP = false }
            _ = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.resetPiP()")
            // Allow the existing AVKit presentation to finish returning before re-entry.
            for _ in 0..<8 {
                guard !Task.isCancelled else { return }
                let state = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.actualPresentation()")
                if (state as? String) != "picture-in-picture" && !JTNativePiPIsActive(self.webView) {
                    _ = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.remoteAction('play')")
                    self.pip.reset()
                    self.requestPictureInPicture(reason: .manual)
                    return
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
            // WebKit kept a PiP presentation without a window: repair from the real state.
            self.reconcilePictureInPicture(repairStuck: true)
        }
    }
    func showVideoAirPlay() {
        webView.evaluateJavaScript("window.JoeToepMedia?.showVideoAirPlay()") { [weak self] result, _ in
            guard let self else { return }
            if (result as? String) != "requested" {
                self.showNotice(.information, "Video AirPlay", "Start a video first, then choose a video-capable AirPlay receiver.")
            }
        }
    }

    private func recordLifecycle(_ event: String) {
        #if DEBUG
        NSLog("V10PiP %@", event)
        #endif
        lifecycleEvents.append("\(Int(Date().timeIntervalSince1970 * 1000)) \(event)")
        if lifecycleEvents.count > 16 { lifecycleEvents.removeFirst(lifecycleEvents.count - 16) }
        if isTestMode { lifecycleTail = lifecycleEvents.suffix(12).joined(separator: " | ") }
    }

    func applicationWillDeactivate() {
        recordLifecycle("inactive")
        capturePosition()
        applicationActive = false
        fullscreenReturnTask?.cancel()
        guard !leavingEpisode else { return }
        leavingEpisode = true
        attemptedAutomaticInEpisode = false
        exitTask?.cancel()
        orientationTask?.cancel()
        updateBackgroundProtection()
        // Lock, Control Center and transient deactivation must not restart an established
        // native session or re-arm automatic pause recovery.
        if pip.state == .native { return }
        #if os(iOS)
        if nativeOwnsAutomaticPiP() {
            // AVKit starts the prepared native presenter itself when the app reaches the
            // background. Do not ask WebKit for an inline PiP that it cannot start now.
            attemptedAutomaticInEpisode = true
            recordLifecycle("inactive: native presenter armed (possible=\(nativePiP.isPossible))")
            syncNativeShadow()
            return
        }
        #endif
        guard settings.automaticPiP,
              isFullscreen || isTestMode || NavigationPolicy.isPlaybackPage(currentURL), !pip.isActive else { return }
        #if os(macOS)
        // V18: met meerdere schermen eerst kijken WAAR de nieuwe app staat. Een tel wachten zodat
        // macOS de nieuwe app en haar venster al vooraan heeft gezet.
        if settings.smartMultiMonitorPiP && NSScreen.screens.count > 1 && !isTestMode {
            attemptedAutomaticInEpisode = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                self?.decideMultiMonitorPiP(target: ScreenFocusMonitor.screenID(of: NSWorkspace.shared.frontmostApplication))
            }
            return
        }
        #endif
        attemptedAutomaticInEpisode = true
        requestPictureInPicture(reason: .appSwitch)
    }

    #if os(macOS)
    /// V18: het scherm van JoeToep's eigen venster (nil als het venster er (nog) niet is).
    /// WebKit's element-fullscreen gebruikt een eigen venster; daarom het voorste zichtbare venster
    /// van JoeToep (dat is het fullscreen-venster als de video fullscreen speelt).
    private var ownScreenID: String? {
        let front = NSApp.orderedWindows.first { $0.isVisible && $0.screen != nil && $0.frame.width > 200 }
        return ScreenFocusMonitor.id(of: front?.screen ?? webView.window?.screen)
    }

    /// V18: start PiP alleen als de nieuwe app op JoeToep's scherm staat. Anders blijft de video
    /// fullscreen doorspelen en letten we op: komt er LATER een app op ons scherm, dán PiP.
    private func decideMultiMonitorPiP(target: String?) {
        guard !applicationActive, !pip.isActive, !pip.isRequesting else { screenFocus.stop(); return }
        let start = MultiMonitorPiPPolicy.shouldStartPiP(screenCount: NSScreen.screens.count,
                                                         joeToepScreen: ownScreenID, targetScreen: target,
                                                         enabled: settings.smartMultiMonitorPiP)
        if start {
            screenFocus.stop()
            recordLifecycle("multi-monitor: same screen -> PiP")
            requestPictureInPicture(reason: .appSwitch)
        } else {
            recordLifecycle("multi-monitor: other screen -> keep playing")
            screenFocus.start { [weak self] screen in self?.decideMultiMonitorPiP(target: screen) }
        }
    }
    #endif

    func applicationWillEnterForeground() {
        recordLifecycle("will-enter-foreground")
        foregroundReturn.willEnterForeground()
    }

    func applicationDidEnterBackground() {
        recordLifecycle("background")
        applicationActive = false
        updateBackgroundProtection()
        // Rescue a lifecycle notification arriving before the first playing snapshot.
        // Never duplicate an active/in-flight request and never start a paused video.
        #if os(iOS)
        scheduleNativeShadowSuspension()
        if nativeOwnsAutomaticPiP() || nativePiPActive { return }
        #endif
        guard settings.automaticPiP, !attemptedAutomaticInEpisode, !pip.isActive, !pip.isRequesting,
              isTestMode || NavigationPolicy.isPlaybackPage(currentURL) else { return }
        attemptedAutomaticInEpisode = true
        requestPictureInPicture(reason: .appSwitch)
    }

    func applicationDidActivate() {
        recordLifecycle("active")
        #if os(macOS)
        screenFocus.stop()
        #endif
        applicationActive = true; leavingEpisode = false
        if settings.automaticFullscreen && !pip.isActive && !pip.isRequesting {
            fulfillAutomaticFullscreen()
        }
        #if os(iOS)
        // Native presenters and Control Center also emit active notifications.
        // Only a real background -> foreground transition may dismiss PiP.
        let shouldReturn = foregroundReturn.consumeActivation()
        if !shouldReturn {
            recordLifecycle("transient activation: preserve PiP")
            updateBackgroundProtection()
            restoreFullscreenAfterPiPIfNeeded()
            return
        }
        #endif
        automaticHandoffTask?.cancel(); systemFullscreenHandoff = false
        endHandoff(); updateBackgroundProtection()
        attemptedAutomaticInEpisode = false
        #if os(iOS)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            self?.reconcilePictureInPicture(repairStuck: false)
        }
        nativeSuspendTask?.cancel()
        if nativePiPActive || nativePiP.isStarting {
            if !settings.keepPiPOnReturn { recordLifecycle("return: stop native PiP"); nativePiP.stop() }
            return
        }
        refreshNativeShadow()
        #endif
        suppressExitPiP = true
        if pip.isRequesting {
            bridge("window.JoeToepBridge?.cancelRequest(\(pip.serial))")
            pipWatchdog?.cancel(); pip.reset()
        }
        // Restore the existing video without rebuilding or reloading the web view.
        if !settings.keepPiPOnReturn {
            #if os(macOS)
            if isFloating { floating.restore() }
            webView.evaluateJavaScript("window.JoeToepMedia?.returnToApp('origin')", completionHandler: nil)
            #else
            // V12: when the PiP window's own return button was used, AVKit is already animating
            // back into fullscreen; a second request made the video jump. Only if PiP is still
            // showing after that animation (return via the app icon) do we bring it back.
            // V16.2: the system's restore animation (PiP window button) takes ~1 s and the page
            // reports PiP until it ends; stepping in during it left WebKit in a stale PiP state
            // (then inline). Watch the page: if PiP ends by itself, the system is restoring and we
            // stay out. Only if PiP is still showing after 1.2 s (return via the app icon) do we
            // bring the video back ourselves.
            returnFromPiPTask?.cancel()
            returnFromPiPTask = Task { @MainActor [weak self] in
                var waited = 0
                while waited < 1200 {
                    try? await Task.sleep(for: .milliseconds(150)); waited += 150
                    guard !Task.isCancelled, let self, self.applicationActive else { return }
                    let mode = (try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.actualPresentation()")) as? String
                    guard mode == "picture-in-picture" || JTNativePiPIsActive(self.webView) else { return }
                }
                guard !Task.isCancelled, let self, self.applicationActive else { return }
                self.recordLifecycle("return via app icon: bring video back from PiP")
                _ = try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.returnToApp('origin')")
            }
            #endif
        }
        restoreFullscreenAfterPiPIfNeeded()
        if settings.pipFallbackEnabled && pip.lastFailure != nil && videoID != 0 { showPiPFallback() }
        bridge("window.JoeToepBridge?.state()") { [weak self] result in
            guard case let .success(value) = result, var dictionary = value as? [String: Any] else { return }
            dictionary["event"] = "state"
            if let event = WebBridgeEvent(body: dictionary) { self?.handle(event) }
        }
    }

    var recentLifecycle: String { lifecycleEvents.suffix(10).map { String($0.dropFirst(8)) }.joined(separator: "\n") }
    var nativePiPDiagnostic: String {
        #if os(iOS)
        "armed=\(nativePiP.isArmed) possible=\(nativePiP.isPossible) active=\(nativePiPActive) last=\(nativePiP.lastEvent)"
        #else
        "n/a"
        #endif
    }

    #if os(iOS)
    private func configureNativePiP() {
        nativePiP.attach(to: webView)
        nativePiP.onWillStart = { [weak self] in
            guard let self else { return }
            self.nativePiPWasFullscreen = self.isFullscreen
            self.nativePiPActive = true
            self.recordLifecycle("native PiP will start")
            self.diagnostic = "Native PiP starting"
            // Exactly one audible player: silence the web video (no user-pause intent).
            self.webView.evaluateJavaScript("window.JoeToepMedia?.nativeHandoff()", completionHandler: nil)
        }
        nativePiP.onDidStart = { [weak self] in
            self?.recordLifecycle("native PiP active")
            self?.diagnostic = "System PiP active (native presenter)"
        }
        nativePiP.onStop = { [weak self] time, playing, reason in
            guard let self else { return }
            self.nativePiPActive = false
            self.recordLifecycle("native PiP stopped \(reason == .restore ? "restore" : "closed") t=\(Int(time)) playing=\(playing)")
            self.diagnostic = reason == .restore ? "Returned from native PiP" : "Native PiP closed"
            let play = playing
            let safeTime = time.isFinite ? time : -1
            self.webView.evaluateJavaScript("window.JoeToepMedia?.nativeReturn(\(safeTime), \(play), \(reason == .restore))", completionHandler: nil)
            self.refreshNativeShadow()
        }
        nativePiP.onRestoreRequested = { [weak self] time, playing in
            guard let self, self.nativePiPWasFullscreen || self.settings.automaticFullscreen else { return 0 }
            let t = time.isFinite ? time : -1
            self.recordLifecycle("native PiP restore → straight to fullscreen")
            self.webView.evaluateJavaScript("(()=>{const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(!v)return 0;try{if(\(t)>=0&&Math.abs(v.currentTime-\(t))>0.3)v.currentTime=\(t)}catch(_){}\(playing ? "v.play()?.catch(()=>{});" : "")try{if(v.webkitSetPresentationMode)v.webkitSetPresentationMode('fullscreen');else v.webkitEnterFullscreen()}catch(_){}return 1})()", completionHandler: nil)
            return 0.35
        }
        nativePiP.onFailure = { [weak self] message in
            guard let self else { return }
            self.nativePiPActive = false
            self.recordLifecycle("native PiP failure: " + message)
            self.diagnostic = String(("Native PiP: " + message).prefix(220))
            self.webView.evaluateJavaScript("window.JoeToepMedia?.setNativeOwner(false)", completionHandler: nil)
        }
    }

    /// True when the inline video is covered by the prepared native presenter.
    private func nativeOwnsAutomaticPiP() -> Bool {
        appleStreamingEngine && settings.automaticPiP && nativePiP.isArmed && nativePiP.isPossible &&
            !isFullscreen && !pip.isActive && !pip.isRequesting && isPlaying
    }

    /// Arm/disarm the native presenter from the live web video (event-driven, no polling).
    private func refreshNativeShadow(_ completion: ((Bool) -> Void)? = nil) {
        guard appleStreamingEngine, !nativePiPActive else { completion?(false); return }
        webView.evaluateJavaScript("window.JoeToepMedia?.sourceInfo()") { [weak self] value, _ in
            guard let self, !self.nativePiPActive else { completion?(false); return }
            let info = value as? [String: Any] ?? [:]
            let url = (info["url"] as? String).flatMap(URL.init(string:))
            let media = (info["media"] as? Bool) ?? false
            let wireless = (info["wireless"] as? Bool) ?? false
            let fullscreen = (info["fullscreen"] as? Bool) ?? false
            let playing = (info["playing"] as? Bool) ?? false
            let time = (info["time"] as? Double) ?? 0
            guard let url, media, !wireless else {
                if self.nativePiP.isArmed {
                    self.nativePiP.disarm(); self.nativeSyncTask?.cancel()
                    self.webView.evaluateJavaScript("window.JoeToepMedia?.setNativeOwner(false)", completionHandler: nil)
                }
                if (info["blob"] as? Bool) == true { self.diagnostic = "Native PiP unavailable: MediaSource stream" }
                self.recordLifecycle("native: not armed url=\(url != nil) media=\(media) wireless=\(wireless) blob=\((info["blob"] as? Bool) ?? false)")
                completion?(false); return
            }
            if !self.nativePiP.isArmed { self.recordLifecycle("native: arm \(url.host ?? "?") \(url.pathExtension)") }
            self.nativePiP.arm(url: url, time: time, playing: playing && self.applicationActive, userAgent: info["ua"] as? String)
            self.nativePiP.setAutomaticAllowed(self.settings.automaticPiP && !fullscreen)
            self.webView.evaluateJavaScript("window.JoeToepMedia?.setNativeOwner(\(!fullscreen))", completionHandler: nil)
            self.startNativeSync()
            completion?(true)
        }
    }

    private func syncNativeShadow() {
        webView.evaluateJavaScript("window.JoeToepMedia?.sourceInfo()") { [weak self] value, _ in
            guard let self, let info = value as? [String: Any], !self.nativePiPActive else { return }
            self.nativePiP.follow(time: (info["time"] as? Double) ?? 0, playing: (info["playing"] as? Bool) ?? false)
        }
    }

    /// Low-frequency drift correction while visible; stops when disarmed or backgrounded.
    private func startNativeSync() {
        guard nativeSyncTask == nil || nativeSyncTask?.isCancelled == true else { return }
        nativeSyncTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled, let self, self.nativePiP.isArmed else { break }
                if self.applicationActive && !self.nativePiPActive { self.syncNativeShadow() }
            }
            self?.nativeSyncTask = nil
        }
    }

    /// Locked screen / audio-only background: the silent shadow need not keep decoding.
    private func scheduleNativeShadowSuspension() {
        nativeSuspendTask?.cancel()
        guard nativePiP.isArmed else { return }
        nativeSuspendTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, !self.applicationActive,
                  !self.nativePiPActive, !self.nativePiP.isStarting else { return }
            self.nativePiP.suspendShadow()
            self.recordLifecycle("background without PiP: shadow paused")
        }
    }
    #endif

    private func requestPictureInPicture(reason: PiPStateMachine.Reason) {
        guard let token = pip.begin(reason) else { return }
        exitTask?.cancel()
        orientationTask?.cancel()
        fallbackToken = nil
        beginHandoff()
        playbackSession.prepareForPictureInPicture()
        diagnostic = "PiP request · \(reason.rawValue)"
        // Start before JS evaluation: a suspended web process may never call back.
        startPiPWatchdog(token)
        if reason != .appSwitch {
            webView.evaluateJavaScript("window.JoeToepMedia?.prepareHandoff(false)", completionHandler: nil)
        }
        updateBackgroundProtection()
        let script = reason == .appSwitch ? "window.JoeToepMedia?.beginAutomaticHandoff()" : "window.JoeToepMedia?.enterPiP()"
        webView.evaluateJavaScript(script) { [weak self] value, _ in
            guard let self, self.pip.state == .requesting(token) else { return }
            let status = (value as? [String: Any])?["status"] as? String
            self.recordLifecycle("request result: \(String(describing: value)); native=\(JTNativePiPIsActive(self.webView))")
            if status == "active" { self.confirmNativePiP(); return }
            if status == "requested" { return }
            if status == "paused" || status == "skipped" || status == "inline-background" || status == "native-owner" {
                self.pip.reset(); self.pipWatchdog?.cancel(); self.endHandoff(); self.updateBackgroundProtection(); return
            }
            if status == "system-fullscreen" {
                // Apple fullscreen owns automatic PiP (AVKit starts it when the app leaves).
                // A second page request during that transition made WebKit wait ~5 s for
                // isPictureInPicturePossible and then tear the running PiP window down.
                self.systemFullscreenHandoff = true
                self.pipWatchdog?.cancel()
                self.pip.reset()
                self.automaticHandoffTask?.cancel()
                self.automaticHandoffTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, let self else { return }
                    self.systemFullscreenHandoff = false
                    self.endHandoff()
                }
                self.recordLifecycle("system fullscreen owns automatic PiP")
                return
            }
            #if os(macOS)
            let nativeResult = JTStartNativePiP(self.webView)
            if nativeResult == 1 { self.confirmNativePiP(); return }
            if nativeResult == 2 { self.diagnostic = "Native Mac PiP requested"; return }
            #endif
            self.requestBridgePiP(token)
        }
    }

    private func requestBridgePiP(_ token: Int) {
        bridge("window.JoeToepBridge?.requestPiP(\(token))") { [weak self] result in
            guard let self, self.pip.state == .requesting(token) else { return }
            switch result {
            case let .success(value):
                let data = (value as? [String: Any]) ?? [:]
                switch data["status"] as? String {
                case "active": self.confirmNativePiP()
                case "requested", "busy": break
                default:
                    self.handlePiPFailure(token, message: (data["message"] as? String) ?? (data["status"] as? String) ?? "Bridge not ready")
                }
            case let .failure(error): self.handlePiPFailure(token, message: error.localizedDescription)
            }
        }
    }

    private func startPiPWatchdog(_ token: Int) {
        pipWatchdog?.cancel()
        pipWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, let self, self.pip.state == .requesting(token) else { return }
            if JTNativePiPIsActive(self.webView) { self.confirmNativePiP(); return }
            // Evaluate no additional JS on timeout: that callback could also be suspended.
            self.handlePiPFailure(token, message: "No native PiP confirmation")
        }
    }

    private func tryPagePiPFallback(_ token: Int) -> Bool {
        guard settings.pipFallbackEnabled, fallbackToken != token, videoID != 0 else { return false }
        fallbackToken = token
        diagnostic = "Direct video PiP fallback requested"
        startPiPWatchdog(token)
        #if os(macOS)
        // A standardized request may reject asynchronously. Do not just repeat
        // that same route after its watchdog: try the native/prefixed path instead.
        let nativeResult = JTStartNativePiP(webView)
        if nativeResult == 1 { confirmNativePiP(); return true }
        if nativeResult == 2 { return true }
        requestBridgePiP(token)
        #else
        webView.evaluateJavaScript("window.JoeToepMedia?.enterPiP()") { [weak self] value, error in
            guard let self, self.pip.state == .requesting(token) else { return }
            let status = (value as? [String: Any])?["status"] as? String
            self.recordLifecycle("request result: \(String(describing: value)); native=\(JTNativePiPIsActive(self.webView))")
            if status == "active" { self.confirmNativePiP() }
            else if status != "requested" {
                self.handlePiPFailure(token, message: error?.localizedDescription ?? status ?? "Page fallback unavailable")
            }
        }
        #endif
        return true
    }

    private func beginHandoff() {
        #if os(iOS)
        guard handoffTaskID == .invalid else { return }
        handoffTaskID = UIApplication.shared.beginBackgroundTask(withName: "PiP handoff") { [weak self] in
            Task { @MainActor [weak self] in self?.endHandoff() }
        }
        #endif
    }

    private func releaseHandoffAfterSettling() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone, !applicationActive,
              handoffTaskID != .invalid, handoffReleaseTask == nil else { return }
        handoffReleaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.endHandoff()
        }
        #endif
    }

    private func endHandoff() {
        handoffReleaseTask?.cancel(); handoffReleaseTask = nil
        #if os(iOS)
        guard handoffTaskID != .invalid else { return }
        let identifier = handoffTaskID
        handoffTaskID = .invalid
        UIApplication.shared.endBackgroundTask(identifier)
        #endif
    }

    private func confirmNativePiP() {
        pipWatchdog?.cancel(); exitTask?.cancel()
        orientationTask?.cancel()
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone && !applicationActive {
            releaseHandoffAfterSettling()
        } else { endHandoff() }
        #else
        endHandoff()
        #endif
        #if os(macOS)
        if floating.isVisible { floating.restore() }
        #endif
        pip.confirmNative()
        systemFullscreenHandoff = false
        automaticHandoffTask?.cancel()
        updateBackgroundProtection()
        diagnostic = "System PiP active"
    }

    private func handlePiPFailure(_ token: Int, message: String) {
        guard pip.state == .requesting(token) else { return }
        if JTNativePiPIsActive(webView) { confirmNativePiP(); return }
        #if os(iOS)
        // After deactivation any further page request is refused by AVKit and only disrupts.
        let futile = pip.reason == .appSwitch && !applicationActive
        if !futile && tryPagePiPFallback(token) { return }
        #else
        if tryPagePiPFallback(token) { return }
        #endif
        let reason = pip.reason
        guard pip.fail(token, message: message) else { return }
        pipWatchdog?.cancel()
        endHandoff()
        updateBackgroundProtection()
        bridge("window.JoeToepBridge?.cancelRequest(\(token))")
        webView.evaluateJavaScript("window.JoeToepMedia?.cancelHandoff()", completionHandler: nil)
        recordLifecycle("failure: " + message)
        diagnostic = String(("PiP: " + message).prefix(220))
        #if os(macOS)
        if settings.macFloatingFallback && isFullscreen && (isPlaying || videoID != 0) {
            floatingAfterFullscreen = true
            bridge("window.JoeToepBridge?.exitFullscreen()")
            return
        }
        if settings.macFloatingFallback && !isFullscreen && (isPlaying || videoID != 0) &&
            (reason == .manual || !applicationActive || reason == .fullscreenExit) &&
            floating.show(webView) {
            pip.confirmFloating()
            diagnostic = "Floating mini-player (system PiP unavailable)"
            return
        }
        #endif
        if reason == .manual {
            if settings.pipFallbackEnabled { showPiPFallback() }
            showNotice(.warning, "Use the video's direct PiP button", "The direct fallback provides a real webpage tap. Fullscreen also opens Apple's video controls.")
        }
        // Automatic failures stay in Diagnostics instead of showing repetitive pop-ups.
    }

    private func restoreMacAfterPiP() {
        #if os(macOS)
        guard settings.activateMacOnPiPExit, !applicationActive, !navigatingAway, !isHandingOver else { return }
        macReturnTask?.cancel()
        let expectedDocument = documentID
        let expectedVideo = videoID
        macReturnTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self, self.settings.activateMacOnPiPExit, !self.applicationActive, !self.navigatingAway,
                  !self.pip.isActive, !self.pip.isRequesting, self.documentID == expectedDocument,
                  self.videoID == expectedVideo, expectedVideo != 0 else { return }
            guard !JTNativePiPIsActive(self.webView), let window = self.webView.window else { return }
            // Do not wait for another JS response from a background/suspended page.
            // The preceding native-exit snapshot already confirmed the transition.
            // WebKit gives no return-vs-close reason, so this opt-out preference
            // also brings the window forward after X/close, even while paused.
            window.deminiaturize(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            self.recordLifecycle("Mac PiP return: activate existing window")
        }
        #endif
    }

    #if os(iOS)
    /// V16.2: the PiP window's return button must end in fullscreen. If the system lands the
    /// still-playing video inline (seen on iOS 27 under load), bring it to fullscreen once.
    /// Closing PiP with ✕ pauses the video, so that never qualifies; JS also checks the
    /// return target and a tab hand-over.
    private func schedulePiPReturnSafetyNet() {
        pipReturnSafetyTask?.cancel()
        let expectedVideo = videoID
        pipReturnSafetyTask = Task { @MainActor [weak self] in
            for delay in [700, 1500] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled, let self else { return }
                guard UIApplication.shared.applicationState == .active, !self.navigatingAway,
                      self.videoID == expectedVideo, expectedVideo != 0, self.isPlaying,
                      !self.isFullscreen, !self.pip.isActive, !self.pip.isRequesting,
                      !self.nativePiPActive else { continue }
                self.recordLifecycle("PiP return landed inline: fullscreen safety net")
                self.webView.evaluateJavaScript("window.JoeToepMedia?.restoreFullscreen(true)", completionHandler: nil)
                return
            }
        }
    }
    #endif

    private func restoreFullscreenAfterPiPIfNeeded() {
        guard !isHandingOver else { return }  // V16.2.1: never for a tab that is handing over
        guard applicationActive, let deadline = fullscreenReturnDeadline,
              deadline > Date(), !pip.isActive, !pip.isRequesting else { return }
        fullscreenReturnDeadline = nil
        fullscreenReturnTask?.cancel()
        let expectedDocument = documentID
        let expectedVideo = videoID
        // V17: animaties uit → meteen (0 ms); snelle overgangen → 120 ms; anders 650 ms.
        let delay = settings.animationsOff ? 0 : (settings.instantTransitions ? 120 : 650)
        fullscreenReturnTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self, self.applicationActive,
                  !self.navigatingAway, self.documentID == expectedDocument,
                  self.videoID == expectedVideo, expectedVideo != 0,
                  !self.pip.isActive, !self.pip.isRequesting, !self.isFullscreen else { return }
            self.recordLifecycle("restore fullscreen after PiP")
            self.webView.evaluateJavaScript("window.JoeToepMedia?.restoreFullscreen()", completionHandler: nil)
            self.verifyFullscreenRestore(document: expectedDocument, video: expectedVideo, attempt: 1)
        }
    }

    private func scheduleFullscreenExit() {
        guard !systemFullscreenHandoff && applicationActive else { return }
        exitTask?.cancel()
        let delay = settings.animationsOff ? 120 : (settings.instantTransitions ? 250 : 400)
        exitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self, !self.isFullscreen,
                  !self.pip.isActive, !self.pip.isRequesting else { return }
            if self.settings.pipOnFullscreenExit && !self.suppressExitPiP && self.isPlaying {
                self.requestPictureInPicture(reason: .fullscreenExit)
            } else if self.applicationActive && self.settings.returnToPortrait {
                #if os(iOS)
                OrientationCoordinator.requestPortrait()
                #endif
            }
            self.suppressExitPiP = false
        }
    }

    /// V11: a tab left while in element fullscreen stayed behind a "Click to Exit Full Screen"
    /// placeholder on Mac. Leave fullscreen before another tab becomes visible.
    func leaveFullscreenForTabSwitch() {
        guard isFullscreen || isVideoStage else { return }
        bridge("window.JoeToepBridge?.exitFullscreen()")
        webView.evaluateJavaScript("window.JoeToepStage?.exit()", completionHandler: nil)
    }
    /// V19.2: de nieuwe-tab-pagina ligt over deze tab heen (YouTube laadt erachter).
    @Published var showsNewTabPage = false

    // MARK: V18 — tab-sync
    /// true = bij de eerste keer laden de video klaarzetten maar niet starten (tab van ander apparaat).
    var syncedStartPaused = false
    #if os(iOS)
    private var horizontalLock: NSKeyValueObservation?
    private var zoomLock: NSKeyValueObservation?
    #endif
    var hasLoadedContent: Bool { hasStarted }
    /// V22: tot dit moment mag deze tab niet zelf gaan spelen (hij werd net door sync bijgewerkt).
    private(set) var syncQuietUntil = Date.distantPast
    func holdQuiet(_ seconds: Double = 15) {
        syncQuietUntil = Date().addingTimeInterval(seconds)
        webView.evaluateJavaScript("window.JoeToepMedia?.quiet(\(Int(seconds * 1000)))", completionHandler: nil)
    }
    func releaseQuiet() {
        guard syncQuietUntil > Date() else { return }
        syncQuietUntil = .distantPast
        webView.evaluateJavaScript("window.JoeToepMedia?.quiet(0)", completionHandler: nil)
    }

    /// Een ander apparaat opende hier een andere pagina: ga er ook heen, zonder af te spelen.
    func syncNavigate(to url: URL, time: Double?) {
        if !isPlaying { holdQuiet() }
        guard hasStarted else {
            restoredURL = url; restoredTime = time; restoredPlaying = false; syncedStartPaused = true
            return
        }
        guard !isPlaying else { return }   // wat hier speelt, blijft ongestoord
        if NavigationPolicy.isPlaybackPage(url) {
            let at = max(time ?? 1, 1)
            pendingResume = (at, false)
            load(at >= 3 ? Self.url(url, at: at) : url)
        } else { load(url) }
    }

    /// Het andere apparaat speelt deze video op `time`: zet de (gepauzeerde) video hier op dezelfde plek.
    func syncPosition(_ time: Double) {
        guard time.isFinite, time >= 0 else { return }
        guard hasStarted else { restoredTime = time; return }
        guard !isPlaying else { return }
        holdQuiet(8)
        let t = String(format: "%.2f", time)
        webView.evaluateJavaScript("""
        (()=>{const v=document.querySelector('video.html5-main-video')||document.querySelector('video');
        if(!v||!v.paused||Math.abs((v.currentTime||0)-\(t))<=3)return 0;
        const p=document.getElementById('movie_player');
        try{if(p&&p.seekTo){p.seekTo(\(t),true);if(!v.paused)p.pauseVideo&&p.pauseVideo();}else v.currentTime=\(t);}catch(_){}
        return 1;})()
        """, completionHandler: nil)
    }

    /// Een ander apparaat begon af te spelen: hier stoppen (PiP sluiten als die open is).
    func pauseForRemotePlayback() {
        if isInPictureInPicture { stopPiPAndPause(); return }
        if isPlaying { recordLifecycle("sync: paused for other device"); pauseForTabSwitch() }
    }

    /// V18 — afspeelsnelheid met één klik (knoppen in de menubalk, en de Watch).
    @Published private(set) var playbackRate: Double = 1
    func stepPlaybackRate(_ direction: Int) {
        webView.evaluateJavaScript("window.JoeToepControls ? window.JoeToepControls.rate(\(direction)) : 1") { [weak self] result, _ in
            Task { @MainActor in
                guard let self, let value = result as? Double else { return }
                self.playbackRate = value
                self.showRateToast(value)
            }
        }
    }
    /// V19.2 — wat "trekken" (pull) doet: "fullscreen" (standaard), "refresh" of "off".
    static var pullAction: String { UserDefaults.standard.string(forKey: "pullActionV192") ?? "fullscreen" }
    /// Trekken bovenaan: op een videopagina de inline speler naar fullscreen, anders verversen.
    func performPullAction() {
        switch Self.pullAction {
        case "refresh": reload()
        case "fullscreen":
            if NavigationPolicy.isPlaybackPage(currentURL) {
                recordLifecycle("pull: fullscreen")
                #if os(macOS)
                enterFullscreenForHandOverIgnoringPlayState()
                #else
                openFullscreenFallback()
                #endif
            } else { reload() }
        default: break
        }
    }

    /// V19.1 overdracht: exacte huidige tijd (en pauzeer). Antwoord via completion.
    func pauseAndReportTime(_ completion: @escaping (Double?) -> Void) {
        let script = "(()=>{const p=document.getElementById('movie_player');const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(!v)return -1;const t=(p&&p.getCurrentTime)?Number(p.getCurrentTime()):v.currentTime;try{if(p&&p.pauseVideo)p.pauseVideo();else v.pause();}catch(_){v.pause();}return t;})()"
        webView.evaluateJavaScript(script) { value, _ in
            Task { @MainActor in
                let time = value as? Double
                completion(time.flatMap { $0 >= 0 ? $0 : nil })
            }
        }
    }
    /// V21 — Neem het afspelen over van een ander apparaat: meteen naar `time` en spelen.
    /// Staat dezelfde video al klaar, dan zonder herladen (dus binnen ±50 ms speelt hij).
    func takeOverPlayback(url: URL, time: Double) {
        releaseQuiet()
        let t = max(0, time)
        if hasStarted, let current = currentURL, SyncDiff.sameDestination(current, url) {
            let s = String(format: "%.3f", t)
            webView.evaluateJavaScript("""
            (()=>{const p=document.getElementById('movie_player');const v=document.querySelector('video.html5-main-video')||document.querySelector('video');
            try{if(p&&p.seekTo){p.seekTo(\(s),true);p.playVideo&&p.playVideo();}else if(v){v.currentTime=\(s);v.play&&v.play().catch(()=>{});}}catch(_){}
            return 0;})()
            """, completionHandler: nil)
            recordLifecycle("takeover: seek+play \(s)")
        } else if hasStarted {
            pendingResume = (max(t, 1), true)
            load(t >= 3 ? Self.url(url, at: t) : url)
            recordLifecycle("takeover: load+play \(Int(t))")
        } else {
            restoredURL = url; restoredTime = t; restoredPlaying = true; syncedStartPaused = false; forcePlayOnStart = true
        }
    }
    /// V21: deze tab moet bij het (eerste) laden meteen spelen (overname van een ander apparaat).
    var forcePlayOnStart = false
    /// V22.1: gestart via het tab-icoon → deze keer niet automatisch fullscreen.
    var suppressAutoFullscreenOnce = false
    /// V21: kleine correctie na de overdracht — alleen spoelen als het echt verschilt (geen hapering).
    func correctPosition(_ time: Double, tolerance: Double = 0.3) {
        guard time.isFinite, time >= 0 else { return }
        let t = String(format: "%.3f", time)
        webView.evaluateJavaScript("(()=>{const p=document.getElementById('movie_player');const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(!v)return 0;const c=(p&&p.getCurrentTime)?Number(p.getCurrentTime()):v.currentTime;if(Math.abs(c-\(t))<=\(tolerance))return 0;if(p&&p.seekTo)p.seekTo(\(t),true);else v.currentTime=\(t);return 1;})()", completionHandler: nil)
    }
    /// V19.1 overdracht: spring naar precies deze tijd (zonder te pauzeren/starten).
    func seekExact(_ time: Double) {
        guard time.isFinite, time >= 0 else { return }
        let t = String(format: "%.3f", time)
        webView.evaluateJavaScript("(()=>{const p=document.getElementById('movie_player');const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(p&&p.seekTo){p.seekTo(\(t),true);}else if(v){v.currentTime=\(t);}return 0;})()", completionHandler: nil)
        recordLifecycle("handoff: seek to \(t)")
    }

    /// V19.1: exacte snelheid (knoppen klein/medium/groot, schuif, sneltoetsen).
    func setPlaybackRate(_ value: Double) {
        let clamped = min(4, max(0.1, (value * 100).rounded() / 100))
        playbackRate = clamped      // meteen tonen; de pagina bevestigt hieronder
        webView.evaluateJavaScript("window.JoeToepControls ? window.JoeToepControls.setRate(\(clamped)) : \(clamped)") { [weak self] result, _ in
            Task { @MainActor in if let value = result as? Double { self?.playbackRate = value } }
        }
    }
    /// V19.1: snelheid met een bepaalde stap aanpassen (+ sneller, − langzamer).
    func adjustPlaybackRate(by delta: Double) { setPlaybackRate(playbackRate + delta) }

    private func showRateToast(_ value: Double) {
        let text = value == floor(value) ? String(format: "%.0f×", value) : String(format: "%g×", value)
        recordLifecycle("rate \(text)")
    }
    /// Voor de Watch-afstandsbediening: spoelen en afspelen/pauzeren via dezelfde weg als de toetsen.
    func remoteSeek(by seconds: Double) {
        webView.evaluateJavaScript("window.JoeToepControls && window.JoeToepControls.seek(\(seconds)); 0", completionHandler: nil)
    }
    func remoteToggleIfPaused() {
        webView.evaluateJavaScript("(()=>{const v=document.querySelector('video');if(v&&v.paused&&window.JoeToepControls)window.JoeToepControls.toggle();return 0})()", completionHandler: nil)
    }
    func remoteToggle() {
        webView.evaluateJavaScript("window.JoeToepControls && window.JoeToepControls.toggle(); 0", completionHandler: nil)
    }

    // MARK: V18 — downloads
    /// Zoekt openlijk aangeboden media-bestanden op de pagina (video/audio met een http(s)-bron,
    /// ook <source>-varianten en <a download>-links naar mediabestanden). Geen blob:/MSE-streams.
    func findDownloadableMedia(_ completion: @escaping ([MediaSource]) -> Void) {
        let script = #"""
        (()=>{const out=[],seen=new Set();
        const add=(u,k,l)=>{try{const a=new URL(u,location.href);if(!/^https?:$/.test(a.protocol)||seen.has(a.href))return;seen.add(a.href);out.push({u:a.href,k,l});}catch(_){}};
        document.querySelectorAll('video,audio').forEach(m=>{const k=m.tagName==='AUDIO'?'audio':'video';
          const h=m.videoHeight?m.videoHeight+'p · ':'';
          if(m.currentSrc&&!m.currentSrc.startsWith('blob:'))add(m.currentSrc,k,h+(k==='audio'?'Audio':'Video'));
          m.querySelectorAll('source[src]').forEach(s=>add(s.src,k,(s.getAttribute('size')||s.getAttribute('label')||s.getAttribute('res')||'')+' '+(s.type||'').replace(/^.*\//,'').toUpperCase()));});
        document.querySelectorAll('a[href]').forEach(a=>{if(/\.(mp4|m4v|mov|webm|mp3|m4a|aac|wav|flac|ogg)(\?|$)/i.test(a.href))
          add(a.href,/\.(mp3|m4a|aac|wav|flac|ogg)(\?|$)/i.test(a.href)?'audio':'video',(a.textContent||'').trim().slice(0,40)||'File');});
        return JSON.stringify(out.slice(0,20));})()
        """#
        webView.evaluateJavaScript(script) { value, _ in
            Task { @MainActor in
                guard let text = value as? String, let data = text.data(using: .utf8),
                      let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { completion([]); return }
                completion(list.compactMap { entry in
                    guard let raw = entry["u"], let url = URL(string: raw), DownloadManager.isDownloadable(url) else { return nil }
                    let label = (entry["l"] ?? "").trimmingCharacters(in: .whitespaces)
                    return MediaSource(url: url, kind: entry["k"] == "audio" ? .audio : .video, label: label.isEmpty ? url.lastPathComponent : label)
                })
            }
        }
    }

    func pauseForTabSwitch() {
        // V17: andere sites: alle video's op die pagina pauzeren en hun PiP sluiten.
        if !isOnYouTube && settings.pipOnAllSites && !isTestMode {
            webView.evaluateJavaScript("window.JoeToepWebPiP && window.JoeToepWebPiP.pauseAll(); 0", completionHandler: nil)
            return
        }
        guard isPlaying else { return }
        webView.evaluateJavaScript("window.JoeToepMedia?.remoteAction('pause')", completionHandler: nil)
    }
    func closeTab() {
        pauseForTabSwitch()
        pipWatchdog?.cancel(); exitTask?.cancel(); automaticHandoffTask?.cancel()
        fullscreenReturnTask?.cancel(); orientationTask?.cancel(); qualityTask?.cancel()
        navigationTask?.cancel(); macReturnTask?.cancel(); resetPiPTask?.cancel(); networkRetryTask?.cancel(); endHandoff()
        #if os(iOS)
        nativeSyncTask?.cancel(); nativeSuspendTask?.cancel(); nativeResetTask?.cancel()
        nativePiP.stop(); nativePiP.disarm()
        #endif
        webView.evaluateJavaScript("window.JoeToepMedia?.leaveForNavigation()", completionHandler: nil)
        webView.stopLoading()
        #if os(macOS)
        floating.restore()
        #endif
        webView.navigationDelegate = nil; webView.uiDelegate = nil
        contentController.removeScriptMessageHandler(forName: AppConstants.scriptMessageName, contentWorld: Self.bridgeWorld)
        contentController.removeScriptMessageHandler(forName: AppConstants.linkMessageName, contentWorld: Self.bridgeWorld)
        sponsorTask?.cancel(); historyTask?.cancel(); fullscreenVerifyTask?.cancel()
        titleObservation = nil
    }
    func resetVideoZoom() { bridge("window.JoeToepBridge?.resetZoom()") }

    private func fulfillAutomaticFullscreen(extraChecks: Int = 0) {
        #if os(macOS)
        let keyboard = settings.macFullscreenMode == .youtube
        let serial = navigationSerial
        // V17: met animaties uit wacht automatisch-fullscreen 0.2 s in plaats van 0.5 s.
        let firstWait = settings.animationsOff ? 0.2 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + (extraChecks == 0 ? firstWait : 0.15)) { [weak self] in
            guard let self, self.navigationSerial == serial, self.applicationActive,
                  self.settings.automaticFullscreen || self.settings.fullscreenOnPlay, !self.pip.isActive, !self.pip.isRequesting else { return }
            // V16.2.1: another tab is still closing its PiP window for a hand-over → check again
            // in 0.15 s (max. 12 times ≈ 1.8 s), so fullscreen only starts once PiP is gone.
            if Self.handOverClosingUntil > Date() && extraChecks < 12 {
                self.fulfillAutomaticFullscreen(extraChecks: extraChecks + 1); return
            }
            self.webView.evaluateJavaScript("window.JoeToepPreferences?.fulfillFullscreenRequest(\(keyboard))") { [weak self] result, _ in
                guard let self, result as? String == "keyboard", self.applicationActive,
                      self.navigationSerial == serial, !self.pip.isActive, !self.pip.isRequesting,
                      let window = self.webView.window else { return }
                // Use YouTube's actual F handler, with keyboard focus on its player.
                // (fulfillFullscreenRequest gaf "keyboard" alleen als de pagina NIET fullscreen is.)
                window.makeFirstResponder(self.webView)
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3) {
                    self.webView.keyDown(with: event)
                }
                // V19: controle na 1,6 s — kwam fullscreen er niet (YouTube was nog bezig met
                // theatermodus of de focus sprong weg), dan één keer opnieuw. Nooit als het al
                // fullscreen is (F is een aan/uit-knop).
                // V19.1: de controle vraagt het de PAGINA (document.fullscreenElement / YouTube's
                // fullscreen-attribuut). `isFullscreen` van de app kende YouTube's eigen fullscreen
                // niet altijd — dan werd F nog eens gestuurd en schakelde fullscreen juist weer UIT
                // (terug naar theatermodus): precies de bug die je zag.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                    guard let self, self.navigationSerial == serial, self.applicationActive,
                          self.isPlaying, !self.pip.isActive, !self.pip.isRequesting else { return }
                    let probe = "!!(document.fullscreenElement||document.webkitFullscreenElement||document.querySelector('ytd-watch-flexy')?.hasAttribute('fullscreen')||document.querySelector('video')?.webkitDisplayingFullscreen||document.documentElement.hasAttribute('data-joetoep-stage'))"
                    self.webView.evaluateJavaScript(probe) { [weak self] value, _ in
                        guard let self, (value as? Bool) == false, !self.isFullscreen, let window = self.webView.window else { return }
                        // V19.3: het VENSTER is wel macOS-fullscreen maar de video niet (je zag dan
                        // de theater-weergave in een fullscreen venster). Eerst het venster terug,
                        // dan pas F — zodat de video écht in YouTube's fullscreen eindigt.
                        if window.styleMask.contains(.fullScreen) {
                            self.recordLifecycle("auto-fullscreen: window was fullscreen without video → reset")
                            window.toggleFullScreen(nil)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                                guard let self, self.isPlaying, let w = self.webView.window, !w.styleMask.contains(.fullScreen) else { return }
                                self.enterFullscreenForHandOverIgnoringPlayState()
                            }
                            return
                        }
                        self.recordLifecycle("auto-fullscreen: retry")
                        window.makeFirstResponder(self.webView)
                        if let retry = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                            context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3) {
                            self.webView.keyDown(with: retry)
                        }
                    }
                }
            }
        }
        #else
        webView.evaluateJavaScript("window.JoeToepPreferences?.fulfillFullscreenRequest()", completionHandler: nil)
        #endif
    }

    /// V16.2.1 — step 3 of a hand-over: put THIS tab's (new) video in fullscreen.
    /// On the Mac a web page may only enter fullscreen right after a user action; a request
    /// made by a script 1–2 s later can be refused. YouTube's own "F" key handler counts as
    /// such an action, so we deliver a real key press to the web view (the same trick the
    /// automatic-fullscreen feature uses). iPhone/iPad use the Apple player request.
    /// V19.2: fullscreen ook als de video (nog) niet speelt (trekken-voor-fullscreen).
    func enterFullscreenForHandOverIgnoringPlayState() {
        guard !pip.isActive, !pip.isRequesting, !isFullscreen else { return }
        enterFullscreenCore()
    }
    func enterFullscreenForHandOver() {
        guard !pip.isActive, !pip.isRequesting, !isFullscreen, isPlaying else { return }
        enterFullscreenCore()
    }
    private func enterFullscreenCore() {
        #if os(macOS)
        switch settings.macFullscreenMode {
        case .youtube:
            // V19.1: F is een aan/uit-knop. Eerst de pagina vragen of hij al fullscreen is; alleen
            // zo niet, F sturen. (Een tweede F zette fullscreen weer uit → "theatermodus-bug".)
            let probe = "!!(document.fullscreenElement||document.webkitFullscreenElement||document.querySelector('ytd-watch-flexy')?.hasAttribute('fullscreen'))"
            webView.evaluateJavaScript(probe) { [weak self] value, _ in
                guard let self, (value as? Bool) != true, let window = self.webView.window else { return }
                window.makeFirstResponder(self.webView)                // keyboard focus → player page
                // Build a keyDown event for the letter F (keyCode 3 on every Mac keyboard layout).
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3) {
                    self.webView.keyDown(with: event)                  // YouTube toggles fullscreen
                }
            }
        case .enhanced:
            openFullscreenFallback()                                   // JoeToep's own controls
        case .safe:
            openSafeFullscreen()                                       // compatibility stage
        }
        #else
        openFullscreenFallback()
        #endif
    }

    func openFullscreenFallback() {
        guard !pip.isActive && !pip.isRequesting else { return }
        webView.evaluateJavaScript("window.JoeToepMedia?.fullscreen()", completionHandler: nil)
    }

    func openSafeFullscreen() {
        guard !pip.isActive && !pip.isRequesting else { return }
        webView.evaluateJavaScript("window.JoeToepStage?.enter()", completionHandler: nil)
    }

    private func updateBackgroundProtection() {
        #if os(iOS)
        // iOS: configured once in JTConfigureMedia. A live preference change during
        // lock/Home broadcasts to the web process and caused an audible skip.
        return
        #else
        let enabled = settings.backgroundProtection && !applicationActive &&
            (NavigationPolicy.isPlaybackPage(currentURL) || isTestMode || pip.isActive || isFullscreen) &&
            (isPlaying || pip.isActive || pip.isRequesting || systemFullscreenHandoff)
        guard enabled != visibilityProtectionApplied else { return }
        visibilityProtectionApplied = enabled
        JTSetBackgroundMediaProtection(webView, enabled)
        #endif
    }

    func showPiPFallback() {
        guard settings.pipFallbackEnabled else { return }
        webView.evaluateJavaScript("window.JoeToepMedia?.showFallback()") { [weak self] value, _ in
            if (value as? Bool) != true {
                self?.showNotice(.information, "Start a video first", "The direct PiP controls appear on the video page.")
            }
        }
    }

    func updateExperimentalFilters() {
        guard !isUpdatingFilters else { return }
        isUpdatingFilters = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isUpdatingFilters = false }
            do {
                try await self.filters.refreshExperimental()
                self.experimentalFilterStatus = self.filters.experimentalStatus
                self.filters.apply(self.settings, to: self.contentController)
                self.showNotice(.success, "Experimental filters updated", "Compatible YouTube ad-card rules are ready. Reload when convenient; playback is not restarted.")
            } catch {
                self.showNotice(.warning, "Filter update failed", error.localizedDescription)
            }
        }
    }

    func copyPiPDiagnostics() {
        let base = "JoeToep \(AppConstants.version)\n\(ProcessInfo.processInfo.operatingSystemVersionString)\n" +
            "Native setup: \(mediaCompatibilityStatus)\nState: \(pip.state)\n" +
            "Playing: \(isPlaying); fullscreen: \(isFullscreen); video present: \(videoID != 0)\n" +
            "Auto PiP: \(settings.automaticPiP); protection: \(settings.backgroundProtection); fallback: \(settings.pipFallbackEnabled)\n" +
            "Last transition: \(diagnostic)\n" +
            "Engine: \(appleStreamingEngine ? "Apple HLS" : "MediaSource"); native PiP: \(nativePiPDiagnostic)\n" +
            "Lifecycle: \(lifecycleEvents.joined(separator: "; "))\n"
        webView.evaluateJavaScript("window.JoeToepMedia?.diagnostics()") { [weak self] value, _ in
            var report = base
            if let value, JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) { report += String(json.prefix(1800)) }
            #if os(iOS)
            UIPasteboard.general.string = report
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)
            #endif
            self?.showNotice(.success, "Diagnostics copied", "Contains playback state and OS version, without video URLs or account data.")
        }
    }

    func showFloatingMiniPlayer() {
        #if os(macOS)
        guard !pip.isActive && !pip.isRequesting, videoID != 0 else {
            showNotice(.information, "Start a video first", "Return from system PiP before moving the webpage to the mini-player.")
            return
        }
        if isFullscreen {
            floatingAfterFullscreen = true
            bridge("window.JoeToepBridge?.exitFullscreen()")
        } else if floating.show(webView) {
            pip.confirmFloating()
            diagnostic = "Floating mini-player active"
        }
        #endif
    }

    func refreshQuality() {
        webView.evaluateJavaScript("window.JoeToepQuality?.read()") { [weak self] value, _ in
            guard let self, let data = value as? [String: Any] else { return }
            self.updateQuality(data)
        }
    }

    private func updateQuality(_ data: [String: Any]) {
        qualityLevels = (data["levels"] as? [String] ?? []).compactMap(PlaybackQualityPreference.init(rawValue:))
        qualityAPIAvailable = (data["supported"] as? Bool) ?? false
        measuredQuality = (data["actual"] as? String).flatMap(PlaybackQualityPreference.init(rawValue:))?.title ?? ""
    }

    private func requestQuality(_ quality: PlaybackQualityPreference, userInitiated: Bool) {
        let value = quality.rawValue
        webView.evaluateJavaScript("window.JoeToepQuality?.request('\(value)')") { [weak self] result, _ in
            guard let self, let data = result as? [String: Any] else { return }
            self.updateQuality(data)
            let status = data["status"] as? String
            if status != "requested" && userInitiated {
                self.showNotice(.information, "Use YouTube's quality menu", "The current player does not expose this resolution to JoeToep. Open the video's gear menu to select an available quality.")
            }
        }
    }

    private func configureBridge() {
        bridge("window.JoeToepBridge?.configure({fit:'\(settings.videoFit.rawValue)',pinch:'\(settings.pinchMode.rawValue)'})")
        configureCompatibility()
    }

    /// V19.1: op de Mac doet GestureScrubber het vegen (native); de pagina blokkeert alleen scrollen.
    #if os(macOS)
    static var nativeWheel: Bool { UserDefaults.standard.object(forKey: "nativeGesturesV191") as? Bool ?? true }
    #else
    static let nativeWheel = false
    #endif
    private func configureCompatibility() {
        webView.evaluateJavaScript("window.JoeToepMedia?.configure({protect:\(settings.backgroundProtection),automatic:\(settings.automaticPiP),nativeFullscreen:\(settings.nativeFullscreen),macFullscreen:'\(settings.macFullscreenMode.rawValue)',fallback:\(settings.pipFallbackEnabled),elementFullscreen:\(usesElementFullscreen),returnTarget:'\(settings.pipReturnTarget.rawValue)',keepPlaying:\(settings.pipReturnKeepsPlaying)})", completionHandler: nil)
        // V19: gebaren-instellingen naar de toets/veeg-bediening.
        webView.evaluateJavaScript("window.JoeToepControls?.configure({swipeSeek:\(settings.swipeSeekSeconds),keySeek:5,volumeStep:\(settings.volumeStepPercent / 100),showControlsOnSwipe:\(settings.showControlsWhileScrubbing),scrubThumbnail:\(settings.scrubThumbnail),showControlsOnKeys:\(settings.arrowKeysShowControls),nativeWheel:\(Self.nativeWheel),exitFullscreenOnPause:\(settings.exitFullscreenOnPause),touchScrub:\(UserDefaults.standard.object(forKey: "touchScrubV192") as? Bool ?? true),touchSeekPerPx:\(UserDefaults.standard.object(forKey: "touchSeekPerPxV192") as? Double ?? 0.25),invertTouch:\(UserDefaults.standard.object(forKey: "invertTouchV192") as? Bool ?? false),seekThrottleMs:\(UserDefaults.standard.object(forKey: "seekThrottleMsV192") as? Double ?? 60)}); 0", completionHandler: nil)
        webView.evaluateJavaScript("window.JoeToepPreferences?.configure({automaticFullscreen:\(settings.automaticFullscreen),fullscreenOnPlay:\(settings.fullscreenOnPlay),disableCaptions:\(settings.disableCaptions),disablePreviewCaptions:\(settings.disablePreviewCaptions),theater:\(settings.theaterMode)})", completionHandler: nil)
    }

    private func bridge(_ script: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        webView.evaluateJavaScript(script, in: nil, in: Self.bridgeWorld) { result in completion?(result) }
    }

    // MARK: - V15 user scripts

    /// (Re)installs all user scripts. The ad-shield configuration is baked into its prefix because it
    /// must run before YouTube's own scripts; changes apply on the next page load.
    private func installUserScripts() {
        #if os(iOS)
        let mobile = "true"
        let tablet = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let mobile = "false"
        let tablet = false
        #endif
        let level = settings.adBlockLevel
        let enabled = settings.blockAds
        // V17: de sleutel bevat nu ook de privacy-instellingen, zodat een wijziging daarvan de
        // scripts opnieuw installeert (en anders niets onnodig herlaadt → sneller).
        let key = "\(enabled)|\(level.rawValue)|\(settings.hideAdCards)|\(settings.cookieBannerMode.rawValue)|\(settings.stripTrackingParameters)|\(settings.globalPrivacyControl)|\(settings.blockTrackers)|\(settings.pipOnAllSites)"
        guard key != installedScriptKey else { return }
        installedScriptKey = key
        contentController.removeAllUserScripts()
        let flags = "window.JOETOEP_NATIVE_HOST = true; window.JOETOEP_MOBILE = \(mobile); window.JOETOEP_TEST = \(isTestMode); window.JOETOEP_IPAD = \(tablet);\n"
        let shield = "window.JOETOEP_ADSHIELD = {enabled:\(enabled && level.skipsAds || enabled && settings.hideAdCards),skip:\(enabled && level.skipsAds)," +
            "fastForward:\(enabled && level.fastForwardsAds),prune:\(enabled && level.prunesPlayerAds),pruneFeed:\(enabled && level.prunesFeedAds)," +
            "dismissWarnings:\(enabled && level.dismissesWarnings),cosmetic:\(enabled && settings.hideAdCards && level.blocksMeasurement)};\n"
        installScript("adShield", world: .page, time: .atDocumentStart, prefix: flags + shield)
        installScript("mediaCompatibility", world: .page, time: .atDocumentStart, prefix: flags)
        installScript("linkBridge", world: Self.bridgeWorld, time: .atDocumentStart, prefix: flags)
        installScript("playerBridge", world: Self.bridgeWorld)
        installScript("qualityBridge", world: .page)
        installScript("siteChrome", world: .page)
        installScript("videoStage", world: .page)
        installScript("playbackControls", world: .page)
        installScript("sitePreferences", world: .page, prefix: flags)
        installScript("sponsorBlock", world: .page)
        installScript("findInPage", world: Self.bridgeWorld)
        // ── V17: scripts voor ALLE websites ──────────────────────────────────────────────
        // Privacy eerst (atDocumentStart = vóór de scripts van de site zelf draaien).
        let privacy = "window.JOETOEP_PRIVACY = {gpc:\(settings.globalPrivacyControl),strip:\(settings.stripTrackingParameters),trackers:\(settings.blockTrackers)};\n"
        installScript("privacyShield", world: .page, time: .atDocumentStart, prefix: privacy)
        // Cookiebanners: ook in iframes (sommige banners staan in een eigen frame) → allFrames.
        let cookie = "window.JOETOEP_COOKIE_MODE = \"\(settings.cookieBannerMode.rawValue)\";\n"
        installScript("cookieConsent", world: Self.bridgeWorld, prefix: cookie, allFrames: true)
        if settings.pipOnAllSites { installScript("webPiP", world: .page) }   // PiP op elke site
        installScript("creatorTools", world: .page)                          // snelheid, A-B-loop …
    }

    // MARK: - V15 titles, history

    private func titleChanged() {
        let title = webView.title
        guard title != pageTitle else { return }
        pageTitle = title
        if settings.recordHistory && !isPrivate, let url = currentURL {
            BrowserLibrary.shared.updateTitle(TabTitleSummarizer.cleanPageTitle(title, url: url), for: url)
        }
    }

    /// SPA navigations (YouTube) change the URL without a new page load; record them once settled.
    private func scheduleHistoryRecord(delay: Double = 1.5) {
        guard settings.recordHistory, !isPrivate, !isTestMode else { return }
        historyTask?.cancel()
        historyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, let url = self.currentURL, url != self.lastRecordedURL else { return }
            self.lastRecordedURL = url
            BrowserLibrary.shared.recordVisit(title: TabTitleSummarizer.cleanPageTitle(self.webView.title, url: url), url: url)
        }
    }

    // MARK: - V15 SponsorBlock

    private func updateSponsorBlock() {
        let id = SponsorBlockService.videoID(from: currentURL)
        guard id != sponsorVideoID || id == nil else { return }
        sponsorTask?.cancel()
        sponsorVideoID = id
        sponsorSegments = []
        guard let id, settings.sponsorBlock.enabled, !isTestMode else {
            sponsorStatus = settings.sponsorBlock.enabled ? "No video" : "Off"
            pushSponsorBlock(); return
        }
        sponsorStatus = "Loading…"
        let options = settings.sponsorBlock
        sponsorTask = Task { @MainActor [weak self] in
            let segments = await SponsorBlockService.shared.segments(for: id, settings: options)
            guard !Task.isCancelled, let self, self.sponsorVideoID == id else { return }
            self.sponsorSegments = segments
            self.sponsorStatus = SponsorBlockService.shared.lastStatus
            self.pushSponsorBlock()
        }
    }

    private func pushSponsorBlock() {
        let options = settings.sponsorBlock
        guard let id = sponsorVideoID, SponsorBlockService.isValid(id), options.enabled else {
            webView.evaluateJavaScript("window.JoeToepSponsorBlock?.clear()", completionHandler: nil)
            return
        }
        let payload: [String: Any] = ["segments": sponsorSegments.map(\.dictionary), "options": options.scriptOptions]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("(() => { const p = \(json); return window.JoeToepSponsorBlock?.set('\(id)', p.segments, p.options, true); })()",
                                   completionHandler: nil)
    }

    // MARK: - V15 browser features

    /// Address-bar input: a URL/domain loads directly, anything else searches.
    func loadAddress(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = Self.addressURL(text) { load(url) }
        else if let url = settings.searchEngine.url(for: text) { load(url) }
    }
    static func addressURL(_ text: String) -> URL? {
        guard !text.contains(" ") else { return nil }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil { return url }
        if text.range(of: #"^(localhost|[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,})(:\d+)?(/.*)?$"#, options: .regularExpression) != nil {
            return URL(string: "https://" + text)
        }
        return nil
    }
    var effectivePresentation: SitePresentation { sitePresentationOverride ?? settings.sitePresentation }
    /// Per-tab "Request desktop / mobile website".
    func requestSite(_ presentation: SitePresentation?) {
        sitePresentationOverride = presentation
        guard var url = currentURL else { return }
        if var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), NavigationPolicy.isYouTubeHost((url.host ?? "").lowercased()) {
            if effectivePresentation == .mobile && parts.host == "www.youtube.com" { parts.host = "m.youtube.com" }
            if effectivePresentation == .desktop && parts.host == "m.youtube.com" { parts.host = "www.youtube.com" }
            url = parts.url ?? url
        }
        if NavigationPolicy.isPlaybackPage(url), let point = resumePoint, point.time >= 3 {
            pendingResume = (point.time, point.playing); load(Self.url(url, at: point.time))
        } else { load(url) }
    }
    func zoom(by step: Double) {
        let current = zoomOverride ?? settings.pageZoom
        zoomOverride = min(max((current + step) * 100, 50), 300).rounded() / 100
        Self.storeSiteZoom(zoomOverride, host: currentURL?.host)
        applyNativeSettings()
    }
    func resetZoom() { zoomOverride = nil; Self.storeSiteZoom(nil, host: currentURL?.host); applyNativeSettings() }

    // MARK: V19.2 — browserfuncties
    /// Zoom per website: onthouden per domein en bij het openen van die site weer toepassen.
    static func siteZoom(host: String?) -> Double? {
        guard let host = host?.lowercased() else { return nil }
        return (UserDefaults.standard.dictionary(forKey: "siteZoomV192") as? [String: Double])?[host]
    }
    static func storeSiteZoom(_ value: Double?, host: String?) {
        guard let host = host?.lowercased() else { return }
        var all = UserDefaults.standard.dictionary(forKey: "siteZoomV192") as? [String: Double] ?? [:]
        all[host] = value
        UserDefaults.standard.set(all, forKey: "siteZoomV192")
    }
    private func applySiteZoom() {
        let stored = Self.siteZoom(host: currentURL?.host)
        guard stored != zoomOverride else { return }
        zoomOverride = stored
        applyNativeSettings()
    }

    /// Leesweergave: alleen de tekst van het artikel, rustig opgemaakt (Esc of de knop sluit hem).
    func toggleReaderMode() {
        let script = #"""
        (()=>{const id='joetoep-reader';const old=document.getElementById(id);if(old){old.remove();document.documentElement.style.overflow='';return 'off';}
        const cands=[...document.querySelectorAll('article, main, [role=main], .post, .article, .content, #content')];
        let best=document.body,score=0;for(const c of cands){const n=(c.innerText||'').length;if(n>score){score=n;best=c;}}
        const box=document.createElement('div');box.id=id;
        box.style.cssText='position:fixed;inset:0;z-index:2147483647;overflow:auto;background:#fbfaf7;color:#1d1d1f;font:19px/1.6 -apple-system,Georgia,serif;padding:48px 20px';
        const inner=document.createElement('div');inner.style.cssText='max-width:680px;margin:0 auto';
        const h=document.createElement('h1');h.textContent=document.title;h.style.cssText='font:700 30px/1.25 -apple-system;margin:0 0 24px';
        inner.appendChild(h);
        for(const el of best.querySelectorAll('h2,h3,p,li,blockquote,img')){
          if(el.closest('nav,footer,aside,form'))continue;
          if(el.tagName==='IMG'){if(el.naturalWidth<200)continue;const i=document.createElement('img');i.src=el.currentSrc||el.src;i.style.cssText='max-width:100%;border-radius:8px;margin:12px 0';inner.appendChild(i);continue;}
          const t=(el.innerText||'').trim();if(t.length<2)continue;const n=document.createElement(el.tagName==='LI'?'p':el.tagName.toLowerCase());n.textContent=(el.tagName==='LI'?'• ':'')+t;inner.appendChild(n);}
        const close=document.createElement('button');close.textContent='✕ Close reader';close.style.cssText='position:fixed;top:12px;right:16px;font:600 14px -apple-system;padding:8px 12px;border-radius:10px;border:0;background:#0001;cursor:pointer';
        close.onclick=()=>{box.remove();document.documentElement.style.overflow='';};
        document.addEventListener('keydown',e=>{if(e.key==='Escape'&&document.getElementById(id)){box.remove();document.documentElement.style.overflow='';}},{once:true});
        box.appendChild(inner);box.appendChild(close);document.documentElement.appendChild(box);document.documentElement.style.overflow='hidden';return 'on';})()
        """#
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    #if os(macOS)
    /// Afdrukken (ook "Bewaar als PDF" via het afdrukvenster van macOS).
    func printPage() {
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit; info.verticalPagination = .automatic
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true; operation.showsProgressPanel = true
        if let window = webView.window { operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil) }
    }
    #endif

    /// Pagina als PDF opslaan (Mac: bewaarvenster; iPhone/iPad: deelmenu).
    func exportPDF(_ completion: @escaping (URL?) -> Void) {
        webView.createPDF { result in
            Task { @MainActor in
                guard case .success(let data) = result else { completion(nil); return }
                let name = (self.pageTitle ?? "Page").replacingOccurrences(of: "/", with: "-").prefix(60)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
                do { try data.write(to: url); completion(url) } catch { completion(nil) }
            }
        }
    }
    var effectiveZoom: Double { zoomOverride ?? settings.pageZoom }

    #if os(iOS)
    func presentFind() { webView.findInteraction?.presentFindNavigator(showingReplace: false) }
    #endif
    /// V16: Chrome-style find on every platform: all matches highlighted, current one scrolled into view.
    struct FindState: Equatable { var count = 0; var index = 0 }
    func find(_ text: String, completion: @escaping (FindState) -> Void) { findCall("find(\(Self.jsString(text)))", completion) }
    func findNext(_ completion: @escaping (FindState) -> Void) { findCall("next()", completion) }
    func findPrevious(_ completion: @escaping (FindState) -> Void) { findCall("previous()", completion) }
    func clearFindHighlights() { bridge("window.JoeToepFind?.clear()") }
    private func findCall(_ call: String, _ completion: @escaping (FindState) -> Void) {
        bridge("window.JoeToepFind?.\(call)") { result in
            guard case let .success(value) = result, let d = value as? [String: Any] else { completion(FindState()); return }
            completion(FindState(count: (d["count"] as? Int) ?? 0, index: (d["index"] as? Int) ?? 0))
        }
    }
    static func jsString(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [text]), let json = String(data: data, encoding: .utf8) else { return "''" }
        return String(json.dropFirst().dropLast())
    }

    private func applyTheaterCookie() {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        if settings.theaterMode {
            guard let cookie = HTTPCookie(properties: [.domain: ".youtube.com", .path: "/", .name: "wide", .value: "1",
                                                        .secure: "TRUE", .expires: Date().addingTimeInterval(3600 * 24 * 365)]) else { return }
            store.setCookie(cookie)
        } else {
            store.getAllCookies { cookies in
                for cookie in cookies where cookie.name == "wide" && cookie.domain.hasSuffix("youtube.com") { store.delete(cookie) }
            }
        }
    }

    // MARK: - V16 PiP across tabs, force refresh

    /// Opening/switching tabs while this video plays: keep it playing in PiP.
    func enterPiPForTabSwitch() {
        // V17: op andere sites weten we "speelt er iets" alleen in de pagina zelf → daar vragen.
        if !isOnYouTube && settings.pipOnAllSites && !isTestMode {
            webView.evaluateJavaScript("window.JoeToepWebPiP && window.JoeToepWebPiP.enterIfPlaying(); 0", completionHandler: nil)
            return
        }
        guard isPlaying, !pip.isActive, !pip.isRequesting, !isFloating else { return }
        recordLifecycle("tab switch: continue in PiP")
        requestPictureInPicture(reason: .manual)
    }
    /// Another tab started a video: pause this one and close its PiP window (inline, no fullscreen).
    func stopPiPAndPause() {
        // Step 1 of the hand-over (called by BrowserWorkspace when another tab starts playing):
        // mark this tab as "handing over" for 3 seconds so every automatic "welcome back from
        // PiP" behaviour below is skipped for it.
        pipHandoverUntil = Date().addingTimeInterval(3)
        Self.handOverClosingUntil = Date().addingTimeInterval(1.5)   // worst case: 1.5 s
        recordLifecycle("hand-over: pause and close PiP (another tab plays)")
        suppressExitPiP = true            // closing PiP must not start a new PiP
        fullscreenReturnDeadline = nil    // no "return to fullscreen" window for this tab
        fullscreenReturnTask?.cancel()    // cancel a fullscreen restore that was already planned
        #if os(macOS)
        macReturnTask?.cancel()           // cancel "bring the window forward" (the Space bug)
        fullscreenVerifyTask?.cancel()    // cancel the fullscreen retry that also raised the window
        #endif
        #if os(iOS)
        pipReturnSafetyTask?.cancel()
        #endif
        webView.evaluateJavaScript("window.JoeToepMedia?.remoteAction('pause'); window.JoeToepMedia?.closePiPInline()", completionHandler: nil)
        #if os(macOS)
        floating.restore()
        #endif
    }
    /// Emergency fix (long-press / middle-click Refresh): restart the web process and PiP state,
    /// then continue the same video at the same moment. No need to force-quit the app.
    func forceRefresh() {
        recordLifecycle("force refresh")
        let point = resumePoint
        pipWatchdog?.cancel(); automaticHandoffTask?.cancel(); exitTask?.cancel(); fullscreenReturnTask?.cancel()
        returnFromPiPTask?.cancel(); resetPiPTask?.cancel(); reconcileTask?.cancel()
        systemFullscreenHandoff = false; endHandoff(); pip.reset()
        #if os(iOS)
        nativePiP.stop(); nativePiP.disarm(); nativePiPActive = false
        OrientationCoordinator.refreshSupportedOrientations()
        #else
        floating.restore()
        #endif
        if let point, point.time >= 1, NavigationPolicy.isPlaybackPage(point.url) { pendingResume = (point.time, point.playing) }
        forceRefreshing = true
        if !JTRestartWebContent(webView) {
            forceRefreshing = false
            reload()
        }
        showNotice(.information, "Force refresh", "The player was restarted.")
    }

    /// Mac: YouTube fullscreen after PiP must actually happen; verify and retry twice.
    private func verifyFullscreenRestore(document: String?, video: Int, attempt: Int) {
        #if os(macOS)
        fullscreenVerifyTask?.cancel()
        fullscreenVerifyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, self.applicationActive, !self.navigatingAway, !self.isHandingOver,
                  self.documentID == document, self.videoID == video, !self.pip.isActive, !self.pip.isRequesting else { return }
            let fullscreen = (try? await self.webView.evaluateJavaScript("Boolean(document.fullscreenElement || document.webkitFullscreenElement || document.documentElement.hasAttribute('data-joetoep-stage'))")) as? Bool
            guard fullscreen != true, attempt < 3 else { return }
            self.recordLifecycle("Mac PiP return: fullscreen retry \(attempt)")
            if let window = self.webView.window {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(self.webView)
            }
            self.webView.evaluateJavaScript("window.JoeToepMedia?.restoreFullscreen(true)", completionHandler: nil)
            self.verifyFullscreenRestore(document: document, video: video, attempt: attempt + 1)
        }
        #endif
    }

    /// Laadt een .js-bestand uit de app en voegt het toe aan elke pagina die deze tab opent.
    /// - `world`: `.page` = dezelfde wereld als de site (kan de site aanpassen); `bridgeWorld` =
    ///   een afgeschermde wereld die de site niet kan zien of verstoren.
    /// - `time`: vóór (`atDocumentStart`) of na (`atDocumentEnd`) het laden van de pagina.
    /// - `allFrames` (V17): ook in iframes (ingesloten stukjes pagina) uitvoeren.
    private func installScript(_ name: String, world: WKContentWorld, time: WKUserScriptInjectionTime = .atDocumentEnd, prefix: String = "", allFrames: Bool = false) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            diagnostic = "Missing resource: \(name)"
            return
        }
        contentController.addUserScript(WKUserScript(source: prefix + text, injectionTime: time,
            forMainFrameOnly: !allFrames, in: world))
    }

    private func handle(_ event: WebBridgeEvent) {
        #if DEBUG
        recordLifecycle("bridge \(event.name.rawValue) video=\(event.videoID) play=\(event.playing) pip=\(event.pip) fs=\(event.fullscreen)")
        #endif
        guard !navigatingAway else { return }
        if event.name == .ready {
            documentID = event.documentID
            configureBridge(); refreshQuality()
            if let resume = pendingResume {
                pendingResume = nil
                webView.evaluateJavaScript("window.JoeToepPreferences?.expectResume(\(resume.time), \(resume.play))", completionHandler: nil)
            }
            if focusSearchWhenReady { focusSearchWhenReady = false; focusSearch() }
            pushSponsorBlock()
            return
        }
        if event.name == .sponsorSkipped {
            SponsorBlockService.recordSkip(seconds: event.seconds)
            return
        }
        guard event.documentID == documentID else { return }
        if event.name == .automaticFullscreen {
            guard applicationActive, settings.automaticFullscreen || settings.fullscreenOnPlay, !pip.isActive, !pip.isRequesting else { return }
            // Native evaluation provides WebKit's gesture context for the page's
            // one-shot automatic request; an async media event alone cannot.
            fulfillAutomaticFullscreen()
            return
        }
        if event.name == .exitWindowFullscreen {
            #if os(macOS)
            if let window = webView.window, window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
            #endif
            return
        }
        if event.name == .enterWindowFullscreen {
            #if os(macOS)
            if let window = webView.window, !window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
            #endif
            return
        }
        if event.name == .windowFullscreen {
            #if os(macOS)
            webView.window?.toggleFullScreen(nil)
            #endif
            return
        }
        if event.name == .pipFailure { handlePiPFailure(event.token, message: event.message); return }
        let wasFullscreen = isFullscreen
        #if os(macOS)
        // V19.3: video verlaat fullscreen terwijl het venster nog in macOS-fullscreen staat (YouTube-
        // modus, geen JoeToep-"stage") → venster ook terug, zodat je de theater-weergave in je
        // gewone venster ziet en niet "vast" zit in een leeg fullscreen-venster.
        if wasFullscreen && !event.fullscreen && settings.macFullscreenMode == .youtube && !isVideoStage,
           let window = webView.window, window.styleMask.contains(.fullScreen) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, !self.isFullscreen, let w = self.webView.window, w.styleMask.contains(.fullScreen) else { return }
                self.recordLifecycle("fullscreen ended → leave window fullscreen")
                w.toggleFullScreen(nil)
            }
        }
        #endif
        let wasNativePiP = pip.state == .native
        let previousVideo = videoID
        let wasPlaying = isPlaying
        videoID = event.videoID
        isPlaying = event.playing; isBuffering = event.buffering
        // V21: native vangnet voor "gepauzeerd → uit fullscreen". De JavaScript-versie slaat het over
        // als de pagina zich "verborgen" voelt (Mac: fullscreen-venster terwijl JoeToep niet actief is);
        // daarom ook hier: na 0,45 s nog steeds gepauzeerd in fullscreen → fullscreen verlaten.
        if wasPlaying && !event.playing && event.fullscreen && !event.pip && !event.buffering && settings.exitFullscreenOnPause {
            let token = event.videoID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, !self.isPlaying, self.isFullscreen, !self.isBuffering, !self.isInPictureInPicture,
                      self.videoID == token else { return }
                self.recordLifecycle("paused in fullscreen → leave fullscreen (native)")
                self.webView.evaluateJavaScript("(()=>{window.__joetoepExitedByPause=true;try{if(document.fullscreenElement||document.webkitFullscreenElement){(document.exitFullscreen||document.webkitExitFullscreen).call(document);return 1}}catch(_){}const v=document.querySelector('video');try{if(v&&v.webkitDisplayingFullscreen){v.webkitExitFullscreen();return 2}}catch(_){}window.JoeToepStage&&window.JoeToepStage.exit&&window.JoeToepStage.exit();return 0})()", completionHandler: nil)
                #if os(macOS)
                if let w = self.webView.window, w.styleMask.contains(.fullScreen), self.settings.macFullscreenMode == .youtube || self.isVideoStage {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if w.styleMask.contains(.fullScreen), !self.isPlaying { w.toggleFullScreen(nil) } }
                }
                #endif
            }
        }
        updatePositionTracking()
        playbackSession.notePlayback(event.playing)
        isFullscreen = event.fullscreen
        let wasStage = isVideoStage
        isVideoStage = event.stage
        #if os(macOS)
        if wasStage && !event.stage && isFloating && !event.pip { floating.restore() }
        #endif
        updateBackgroundProtection()
        if event.pip { confirmNativePiP() }
        else if wasNativePiP {
            pip.exitNative()
            suppressExitPiP = true // Closing PiP must not immediately reopen it.
            diagnostic = "PiP ended by player/system"
            if isHandingOver {
                // V16.2.1: PiP was closed because another tab took over. Stay in the
                // background: the new tab's video is the one that goes fullscreen.
                recordLifecycle("hand-over: PiP closed, stay in background")
                // PiP is gone: the new tab may go fullscreen 0.25 s from now (close animation).
                Self.handOverClosingUntil = min(Self.handOverClosingUntil, Date().addingTimeInterval(0.25))
            } else if !event.playing && !event.buffering {
                // V22: PiP met ✕ gesloten (de video staat stil): stoppen, niets terughalen —
                // geen fullscreen, geen venster naar voren, geen vangnet.
                recordLifecycle("PiP closed with ✕: stay paused, no fullscreen")
                fullscreenReturnDeadline = nil; fullscreenReturnTask?.cancel()
                #if os(macOS)
                macReturnTask?.cancel()
                if isFloating { floating.restore() }
                #else
                pipReturnSafetyTask?.cancel(); returnFromPiPTask?.cancel()
                #endif
                webView.evaluateJavaScript("(()=>{const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(v&&!v.paused)v.pause();try{if(document.fullscreenElement||document.webkitFullscreenElement)(document.exitFullscreen||document.webkitExitFullscreen).call(document)}catch(_){}})()", completionHandler: nil)
            } else {
                #if os(macOS)
                restoreMacAfterPiP()
                #endif
                // A system return can precede didBecomeActive. Keep a short intent
                // window, never turn a much later app launch into fullscreen.
                fullscreenReturnDeadline = resettingPiP ? nil : Date().addingTimeInterval(2)
                restoreFullscreenAfterPiPIfNeeded()
                #if os(iOS)
                if !resettingPiP { schedulePiPReturnSafetyNet() }
                #endif
            }
        }
        if !wasFullscreen && event.fullscreen {
            suppressExitPiP = false
            #if os(iOS)
            sawLandscapeWhileFullscreen = UIDevice.current.orientation.isLandscape
            #endif
            exitTask?.cancel()
            #if os(iOS)
            if settings.rotateOnFullscreen && !pip.isActive && !pip.isRequesting {
                orientationTask?.cancel()
                let rotateDelay = settings.animationsOff ? 40 : (settings.instantTransitions ? 120 : 350)
                orientationTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(rotateDelay))
                    guard !Task.isCancelled, let self, self.isFullscreen, self.applicationActive,
                          !self.pip.isActive, !self.pip.isRequesting else { return }
                    OrientationCoordinator.requestLandscape()
                }
            }
            #endif
        }
        if wasFullscreen && !event.fullscreen && !wasNativePiP {
            orientationTask?.cancel()
            #if os(macOS)
            if floatingAfterFullscreen {
                floatingAfterFullscreen = false
                if !pip.isActive && floating.show(webView) {
                    pip.confirmFloating()
                    diagnostic = "Floating mini-player after fullscreen"
                }
            } else { scheduleFullscreenExit() }
            #else
            scheduleFullscreenExit()
            #endif
        }
        #if os(iOS)
        if event.name == .state && !nativePiPActive { refreshNativeShadow() }
        #endif
        let resolution = event.height > 0 ? "\(event.height)p" : nil
        if mediaResolution != resolution {
            mediaResolution = resolution
            refreshQuality()
        }
        if previousVideo != event.videoID && event.videoID != 0 {
            refreshQuality()
            // One bounded attempt on a new player; never poll or fight adaptive streaming.
            if effectiveQuality != .automatic {
                qualityTask?.cancel()
                qualityTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, let self else { return }
                    self.requestQuality(self.effectiveQuality, userInitiated: false)
                }
            }
        }
    }

    func clearWebsiteData() {
        guard !pip.isActive && !pip.isRequesting else {
            showNotice(.information, "Return from PiP first", "Website data was not deleted during active PiP playback.")
            return
        }
        webView.stopLoading()
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast) { [weak self] in
                guard let self else { return }
                self.showNotice(.success, "Website data cleared", "Cookies, cache and local website storage were removed.")
                self.goHome()
            }
    }

    func showNotice(_ kind: SessionNotice.Kind, _ title: String, _ message: String) {
        notice = SessionNotice(kind: kind, title: title, message: message)
        if isTestMode { recordLifecycle("notice shown: " + title) }   // V17.1: zichtbaar in UI-tests
    }
    func dismissNotice() {
        if isTestMode && notice != nil { recordLifecycle("notice dismissed") }
        notice = nil
    }

    private func refreshNavigationState() {
        canGoBack = webView.canGoBack; canGoForward = webView.canGoForward
        let changed = currentURL != webView.url
        currentURL = webView.url
        if changed { updateSponsorBlock(); scheduleHistoryRecord() }
    }
    private func openExternally(_ url: URL) {
        guard ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
    private func loadTestFixture() {
        #if DEBUG
        guard let url = Bundle.main.url(forResource: "offline-player", withExtension: "html", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "offline-player", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        #endif
    }
}

extension WebSession: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == AppConstants.linkMessageName {
            guard let body = message.body as? [String: Any], let raw = body["url"] as? String, raw.count < 4000,
                  let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                contextLink = nil; return
            }
            contextLink = (url, Date())
            return
        }
        guard message.frameInfo.isMainFrame else { return }
        let origin = message.frameInfo.securityOrigin.host.lowercased()
        guard NavigationPolicy.isYouTubeHost(origin) || (isTestMode && origin.isEmpty) else { return }
        guard let event = WebBridgeEvent(body: message.body) else { return }
        handle(event)
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = (sitePresentationOverride ?? settings.sitePresentation).contentMode
        guard let url = action.request.url else { decisionHandler(.cancel, preferences); return }
        if webView === authenticationWebView, NavigationPolicy.isYouTubeHost((url.host ?? "").lowercased()) {
            decisionHandler(.cancel, preferences)
            authenticationWebView = nil
            load(url)
            return
        }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow, preferences); return }
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #else
        let isPhone = false
        #endif
        if sitePresentationOverride == nil && FeedNavigation.needsDesktop(url, isPhone: isPhone) { preferences.preferredContentMode = .desktop }
        #if os(macOS)
        // Cmd-click / middle-click opens a background tab.
        if action.navigationType == .linkActivated && (action.modifierFlags.contains(.command) || action.buttonNumber == 4),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.cancel, preferences)
            onOpenInNewTab?(url, action.modifierFlags.contains(.shift))
            return
        }
        #endif
        if isTestMode && url.isFileURL { decisionHandler(.allow, preferences); return }
        // Keep the media document alive during PiP. Top-level navigation would destroy its video.
        if pip.isActive || pip.isRequesting {
            decisionHandler(.cancel, preferences)
            showNotice(.information, "Return from PiP first", "Navigation is paused while this video's document is in PiP.")
            return
        }
        switch NavigationPolicy(settings: settings).decision(for: url) {
        case .allow: decisionHandler(.allow, preferences)
        case .openExternally: decisionHandler(.cancel, preferences); openExternally(url)
        case let .block(reason):
            decisionHandler(.cancel, preferences)
            showNotice(.information, "Focus filter", "Navigation to \(reason.rawValue) is disabled in Settings.")
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        guard webView === self.webView else { return }
        isLoading = true; exitTask?.cancel(); qualityTask?.cancel()
        refreshNavigationState()
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        guard webView === self.webView else { return }
        defer { applySiteZoom() }      // V19.2: zoom per website
        navigatingAway = false
        fullscreenReturnTask?.cancel(); fullscreenReturnDeadline = nil
        automaticHandoffTask?.cancel(); systemFullscreenHandoff = false; isVideoStage = false
        endHandoff(); orientationTask?.cancel()
        documentID = nil; videoID = 0
        floatingAfterFullscreen = false
        isPlaying = false; isFullscreen = false; isBuffering = false; mediaResolution = nil
        qualityLevels = []; measuredQuality = ""; qualityAPIAvailable = false
        pipWatchdog?.cancel(); pip.reset()
        #if os(iOS)
        if !nativePiPActive { nativeSyncTask?.cancel(); nativePiP.disarm() }
        #endif
        updateBackgroundProtection()
        refreshNavigationState()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        guard webView === self.webView else { return }
        isLoading = false; failedNavigationURL = nil; networkRetryCount = 0
        refreshNavigationState(); configureCompatibility()
        scheduleHistoryRecord(delay: 0.3)
        if suppressAutoFullscreenOnce {
            suppressAutoFullscreenOnce = false
            webView.evaluateJavaScript("window.__jtSkipFSUntil=Date.now()+5000;0", completionHandler: nil)
        }
        let quietLeft = syncQuietUntil.timeIntervalSinceNow
        if quietLeft > 0 { webView.evaluateJavaScript("window.JoeToepMedia?.quiet(\(Int(quietLeft * 1000)))", completionHandler: nil) }
        MediaExtras.shared.reapply(to: self)      // V21: boost / alleen audio / herhalen blijven aan
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        guard webView === self.webView else { return }
        navigationFailed(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        guard webView === self.webView else { return }
        navigationFailed(error)
    }
    /// Transient network/DNS failures (Mac wake, Wi-Fi roaming, VPN changes) are retried
    /// silently with backoff. NWPathMonitor can lag behind the real path, so its state is
    /// not a precondition. A notice appears only when every retry failed.
    private static let transientNetworkCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
        NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed,
        NSURLErrorSecureConnectionFailed, NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed
    ]
    private func navigationFailed(_ error: Error) {
        navigatingAway = false
        isLoading = false
        let error = error as NSError
        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else { return }
        // WebKit reports policy/download/frame cancellations as 102; these are not offline errors.
        if error.domain == "WebKitErrorDomain" && error.code == 102 { return }
        if error.domain == NSURLErrorDomain && Self.transientNetworkCodes.contains(error.code) {
            failedNavigationURL = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? lastRequestedURL ?? currentURL
            if retryFailedNavigationIfEligible() { return }
        }
        let message = error.code == NSURLErrorNotConnectedToInternet
            ? "The connection is unavailable. JoeToep reloads automatically when it returns, or tap Reload."
            : "\(error.localizedDescription) Tap Reload to try again."
        showNotice(.error, "Page could not load", message)
    }
    @discardableResult
    private func retryFailedNavigationIfEligible() -> Bool {
        guard let target = failedNavigationURL, networkRetryCount < Self.networkRetryDelays.count, !isPlaying,
              applicationActive, ["https", "http"].contains(target.scheme ?? "") else { return false }
        let delay = Self.networkRetryDelays[networkRetryCount]
        networkRetryCount += 1
        networkRetryTask?.cancel()
        networkRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.failedNavigationURL == target,
                  self.applicationActive, !self.isPlaying else { return }
            self.notice = nil
            self.recordLifecycle("network retry \(self.networkRetryCount)")
            self.webView.load(URLRequest(url: target, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        }
        return true
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if forceRefreshing {
            forceRefreshing = false
            documentID = nil; videoID = 0; isPlaying = false; isFullscreen = false; pip.reset()
            let target = resumePoint.map { Self.url($0.url, at: $0.time) } ?? currentURL ?? lastRequestedURL ?? settings.startPage.url
            load(target)
            return
        }
        automaticHandoffTask?.cancel(); systemFullscreenHandoff = false; isVideoStage = false
        endHandoff(); orientationTask?.cancel()
        exitTask?.cancel(); qualityTask?.cancel(); pipWatchdog?.cancel()
        #if os(macOS)
        floating.restore()
        #endif
        pip.reset(); isPlaying = false; isBuffering = false; isFullscreen = false
        updateBackgroundProtection()
        documentID = nil; videoID = 0
        floatingAfterFullscreen = false
        let now = Date()
        terminations = terminations.filter { now.timeIntervalSince($0) < 120 }
        terminations.append(now)
        guard settings.recoverWebProcess && terminations.count <= 2 && applicationActive else {
            showNotice(.error, "Player stopped", "WebKit was closed by the system. Return to JoeToep and tap Reload.")
            return
        }
        showNotice(.warning, "Player recovered", "The web process restarted. Press Play to continue.")
        reload()
    }
}
extension WebSession: WKUIDelegate {
    func webViewDidClose(_ webView: WKWebView) {
        if webView === authenticationWebView { authenticationWebView = nil }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, let url = action.request.url {
            let host = (url.host ?? "").lowercased()
            let signIn = host == "accounts.google.com" || host.hasSuffix(".accounts.google.com") || host == "accounts.youtube.com"
            if !signIn, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
               NavigationPolicy(settings: settings).decision(for: url) == .allow {
                #if os(macOS)
                let activate = !action.modifierFlags.contains(.command) || action.modifierFlags.contains(.shift)
                #else
                let activate = true
                #endif
                onOpenInNewTab?(url, activate)
                return nil
            }
            switch NavigationPolicy(settings: settings).decision(for: url) {
            case .allow:
                let popup = WKWebView(frame: .zero, configuration: configuration)
                popup.navigationDelegate = self
                popup.uiDelegate = self
                authenticationWebView = popup
                return popup
            case .openExternally: openExternally(url)
            case let .block(reason): showNotice(.information, "Focus filter", reason.rawValue)
            }
        }
        return nil
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        showNotice(.information, "Website message", String(message.prefix(300)))
        completionHandler()
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        // No unbounded blocking website dialogs or automatically accepted destructive actions.
        showNotice(.information, "Website confirmation dismissed", String(message.prefix(240)))
        completionHandler(false)
    }
    /// V15: WebKit is about to return a PiP video to the inline player (iPad, Mac). Ask for
    /// fullscreen now, while PiP is still up, so the video goes straight to fullscreen.
    @objc(_webViewFullscreenMayReturnToInline:)
    func webViewFullscreenMayReturnToInline(_ webView: WKWebView) {
        guard webView === self.webView else { return }
        recordLifecycle("WebKit: PiP may return inline")
        guard settings.pipReturnTarget != .inline else { return }
        #if os(iOS)
        returnFromPiPTask?.cancel()
        suppressExitPiP = true
        let target = settings.pipReturnTarget == .fullscreen ? "true" : "'origin'"
        webView.evaluateJavaScript("window.JoeToepMedia?.returnToApp(\(target))", completionHandler: nil)
        #else
        fullscreenReturnDeadline = Date().addingTimeInterval(4)
        #endif
    }
    #if os(iOS)
    /// V15: long-press on a link: "Open in New Tab and Switch" (top) and "Open in New Tab".
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        guard let url = elementInfo.linkURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            completionHandler(nil); return
        }
        completionHandler(UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] suggested in
            let open = UIAction(title: "Open in New Tab and Switch", image: UIImage(systemName: "plus.square.on.square")) { _ in
                self?.onOpenInNewTab?(url, true)
            }
            let background = UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square")) { _ in
                self?.onOpenInNewTab?(url, false)
            }
            let copy = UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.url = url }
            // V17.1: op iPad (meerdere vensters mogelijk) ook "Open in nieuw venster".
            let window = UIAction(title: "Open in New Window", image: UIImage(systemName: "rectangle.badge.plus")) { _ in
                WindowOpener.open(url)
            }
            let openers: [UIMenuElement] = UIApplication.shared.supportsMultipleScenes && UIDevice.current.userInterfaceIdiom == .pad
                ? [open, background, window] : [open, background]
            let others = suggested.filter { element in
                guard let action = element as? UIAction else { return true }
                return !action.title.localizedCaseInsensitiveContains("reading list") && !action.title.localizedCaseInsensitiveContains("copy link")
            }
            return UIMenu(children: [UIMenu(options: .displayInline, children: openers),
                                     UIMenu(options: .displayInline, children: ([copy] as [UIMenuElement]) + others)])
        })
    }
    #endif
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        showNotice(.information, "Website prompt dismissed", String(prompt.prefix(240)))
        completionHandler(nil)
    }
}


#if os(iOS)
// ── V17: rand-veeg op iPhone/iPad ─────────────────────────────────────────────────────────
extension WebSession: UIGestureRecognizerDelegate {
    /// Wordt aangeroepen tijdens de veeg. Pas bij het loslaten (`.ended`) beslissen we: ver genoeg
    /// (meer dan 90 punten) naar rechts geveegd en geen vorige pagina → "terug" = tab sluiten.
    @objc func edgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, !canGoBack else { return }
        let distance = gesture.translation(in: gesture.view).x
        if distance > 90 { goBack() }     // goBack() roept onCannotGoBack aan → tab dicht
    }
    /// Laat onze veeg tegelijk met WebKit's eigen gebaren werken (anders blokkeren ze elkaar).
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    /// Alleen reageren als er echt geen vorige pagina is (anders doet WebKit het terug-vegen).
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIScreenEdgePanGestureRecognizer ? !canGoBack : true
    }
}
#endif
