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
    let webView: WKWebView
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
    struct ResumePoint: Equatable { var url: URL; var time: Double; var playing: Bool }
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
    private var foregroundReturn = ForegroundReturnGate()
    private var fullscreenReturnDeadline: Date?
    private var fullscreenReturnTask: Task<Void, Never>?
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
        webView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceHorizontal = false
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
                if let time = self.restoredTime, time >= 3, NavigationPolicy.isPlaybackPage(url) {
                    self.pendingResume = (time, true)
                    self.load(Self.url(url, at: time))
                } else { self.load(url) }
            } else { self.load(self.settings.startPage.url) }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-test-notice") {
            showNotice(.information, "Test notice", "This banner expires after five seconds.")
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
        if old.pipReturnTarget != updated.pipReturnTarget || old.pipReturnKeepsPlaying != updated.pipReturnKeepsPlaying {
            configureCompatibility()
        }
        if old.videoFit != updated.videoFit || old.pinchMode != updated.pinchMode { configureBridge() }
        if old.automaticPiP != updated.automaticPiP || old.backgroundProtection != updated.backgroundProtection ||
            old.nativeFullscreen != updated.nativeFullscreen || old.pipFallbackEnabled != updated.pipFallbackEnabled {
            configureCompatibility()
            updateBackgroundProtection()
        }
        if old.quality != updated.quality { requestQuality(updated.quality, userInitiated: true) }
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
        lastRequestedURL = url; failedNavigationURL = nil; networkRetryCount = 0
        networkRetryTask?.cancel()
        navigate { [weak self] in self?.webView.load(URLRequest(url: url, timeoutInterval: 30)) }
    }
    func goHome() { load(StartPage.home.url) }
    func goBack() {
        guard canGoBack else { showNotice(.information, "No previous page", "This is the first page in this window."); return }
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
            let point = ResumePoint(url: url, time: time, playing: (info["playing"] as? Bool) ?? false)
            if self.resumePoint != point { self.resumePoint = point }
        }
    }
    private func updatePositionTracking() {
        if isPlaying {
            guard positionTask == nil else { return }
            positionTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
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


    func togglePictureInPicture() {
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
        attemptedAutomaticInEpisode = true
        requestPictureInPicture(reason: .appSwitch)
    }

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
            try? await Task.sleep(for: .milliseconds(1600))
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
            returnFromPiPTask?.cancel()
            let settle = settings.instantTransitions ? 450 : 750
            returnFromPiPTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(settle))
                guard !Task.isCancelled, let self, self.applicationActive else { return }
                let mode = (try? await self.webView.evaluateJavaScript("window.JoeToepMedia?.actualPresentation()")) as? String
                guard mode == "picture-in-picture" || JTNativePiPIsActive(self.webView) else { return }
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
        guard settings.activateMacOnPiPExit, !applicationActive, !navigatingAway else { return }
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

    private func restoreFullscreenAfterPiPIfNeeded() {
        guard applicationActive, let deadline = fullscreenReturnDeadline,
              deadline > Date(), !pip.isActive, !pip.isRequesting else { return }
        fullscreenReturnDeadline = nil
        fullscreenReturnTask?.cancel()
        let expectedDocument = documentID
        let expectedVideo = videoID
        let delay = settings.instantTransitions ? 120 : 650
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
        let delay = settings.instantTransitions ? 250 : 400
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
    func pauseForTabSwitch() {
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

    private func fulfillAutomaticFullscreen() {
        #if os(macOS)
        let keyboard = settings.macFullscreenMode == .youtube
        let serial = navigationSerial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.navigationSerial == serial, self.applicationActive,
                  self.settings.automaticFullscreen, !self.pip.isActive, !self.pip.isRequesting else { return }
            self.webView.evaluateJavaScript("window.JoeToepPreferences?.fulfillFullscreenRequest(\(keyboard))") { [weak self] result, _ in
                guard let self, result as? String == "keyboard", self.applicationActive,
                      self.navigationSerial == serial, !self.pip.isActive, !self.pip.isRequesting,
                      let window = self.webView.window else { return }
                // Use YouTube's actual F handler, with keyboard focus on its player.
                window.makeFirstResponder(self.webView)
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3) {
                    self.webView.keyDown(with: event)
                }
            }
        }
        #else
        webView.evaluateJavaScript("window.JoeToepPreferences?.fulfillFullscreenRequest()", completionHandler: nil)
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

    private func configureCompatibility() {
        webView.evaluateJavaScript("window.JoeToepMedia?.configure({protect:\(settings.backgroundProtection),automatic:\(settings.automaticPiP),nativeFullscreen:\(settings.nativeFullscreen),macFullscreen:'\(settings.macFullscreenMode.rawValue)',fallback:\(settings.pipFallbackEnabled),elementFullscreen:\(usesElementFullscreen),returnTarget:'\(settings.pipReturnTarget.rawValue)',keepPlaying:\(settings.pipReturnKeepsPlaying)})", completionHandler: nil)
        webView.evaluateJavaScript("window.JoeToepPreferences?.configure({automaticFullscreen:\(settings.automaticFullscreen),disableCaptions:\(settings.disableCaptions),disablePreviewCaptions:\(settings.disablePreviewCaptions)})", completionHandler: nil)
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
        let key = "\(enabled)|\(level.rawValue)|\(settings.hideAdCards)"
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
        applyNativeSettings()
    }
    func resetZoom() { zoomOverride = nil; applyNativeSettings() }
    var effectiveZoom: Double { zoomOverride ?? settings.pageZoom }

    #if os(iOS)
    func presentFind() { webView.findInteraction?.presentFindNavigator(showingReplace: false) }
    #endif
    /// Mac find bar (iOS uses the system find navigator).
    func find(_ text: String, backwards: Bool, completion: @escaping (Bool) -> Void) {
        guard !text.isEmpty else { completion(false); return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(text, configuration: configuration) { result in completion(result.matchFound) }
    }
    func clearFindHighlights() {
        webView.evaluateJavaScript("window.getSelection()?.removeAllRanges()", completionHandler: nil)
    }

    /// Mac: YouTube fullscreen after PiP must actually happen; verify and retry twice.
    private func verifyFullscreenRestore(document: String?, video: Int, attempt: Int) {
        #if os(macOS)
        fullscreenVerifyTask?.cancel()
        fullscreenVerifyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, self.applicationActive, !self.navigatingAway,
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

    private func installScript(_ name: String, world: WKContentWorld, time: WKUserScriptInjectionTime = .atDocumentEnd, prefix: String = "") {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            diagnostic = "Missing resource: \(name)"
            return
        }
        contentController.addUserScript(WKUserScript(source: prefix + text, injectionTime: time,
            forMainFrameOnly: true, in: world))
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
            guard applicationActive, settings.automaticFullscreen, !pip.isActive, !pip.isRequesting else { return }
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
        let wasNativePiP = pip.state == .native
        let previousVideo = videoID
        videoID = event.videoID
        isPlaying = event.playing; isBuffering = event.buffering
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
            #if os(macOS)
            restoreMacAfterPiP()
            #endif
            // A system return can precede didBecomeActive. Keep a short intent
            // window, never turn a much later app launch into fullscreen.
            fullscreenReturnDeadline = resettingPiP ? nil : Date().addingTimeInterval(2)
            restoreFullscreenAfterPiPIfNeeded()
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
                orientationTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(350))
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
            if settings.quality != .automatic {
                qualityTask?.cancel()
                qualityTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, let self else { return }
                    self.requestQuality(self.settings.quality, userInitiated: false)
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
    }
    func dismissNotice() { notice = nil }

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
            let others = suggested.filter { element in
                guard let action = element as? UIAction else { return true }
                return !action.title.localizedCaseInsensitiveContains("reading list") && !action.title.localizedCaseInsensitiveContains("copy link")
            }
            return UIMenu(children: [UIMenu(options: .displayInline, children: [open, background]),
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
