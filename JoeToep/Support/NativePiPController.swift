#if os(iOS)
import AVFoundation
import AVKit
import UIKit

/// V10 native PiP pipeline for iPhone/iPad inline video.
///
/// WebKit only prepares an automatic-PiP ("standby") AVKit presenter while a video is in
/// fullscreen (WebFullScreenManager::setPIPStandbyElement). A small inline video therefore
/// can never start PiP when the app is left: by the time the scene deactivates, AVKit refuses
/// a non-automatic start. This controller keeps a native AVKit presenter prepared *before*
/// the user leaves, using the same Apple-HLS stream URL that the web video is already playing
/// (MediaSource is disabled for this engine, so YouTube serves a URL instead of a blob).
///
/// While armed the native player follows the web video muted and at a capped bit rate, so it
/// costs little. AVKit starts PiP automatically when the app goes to the background; only then
/// does the native player become audible and the web video is paused. On return the web video
/// resumes at the native position, so there is always exactly one audible player.
@MainActor
final class NativePiPController: NSObject {
    enum StopReason { case restore, closed }

    var onWillStart: (() -> Void)?
    var onDidStart: (() -> Void)?
    /// time, wasPlaying, reason
    var onStop: ((Double, Bool, StopReason) -> Void)?
    var onFailure: ((String) -> Void)?

    private(set) var isArmed = false
    private(set) var isActive = false
    private(set) var isStarting = false
    private(set) var sourceURL: URL?
    private(set) var lastEvent = "idle"
    private let player = AVPlayer()
    private let hostView = PlayerLayerView()
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var restoreRequested = false
    /// V22.2: close() loopt; restore-delegate en onStop mogen dan niet "terugkeren" melden.
    private var closing = false
    /// V22.2: speelt de PiP-speler zelf (niet gepauzeerd in het PiP-venster)?
    var isPlayingInPiP: Bool { player.rate != 0 }
    /// V22: vlak vóór de terugkeer uit PiP; geeft terug hoelang de animatie nog moet wachten.
    var onRestoreRequested: ((Double, Bool) -> TimeInterval)?
    private var automaticAllowed = true
    private var pendingManualStart = false
    private static let shadowBitRate: Double = 900_000

    override init() {
        super.init()
        player.isMuted = true
        player.allowsExternalPlayback = false          // AirPlay stays with the web video.
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = true
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        hostView.playerLayer.player = player
        hostView.playerLayer.videoGravity = .resizeAspect
        hostView.isUserInteractionEnabled = false
        hostView.accessibilityElementsHidden = true
        hostView.backgroundColor = .clear
        statusObservation = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, _ in
            let failed = player.currentItem?.status == .failed
            let message = player.currentItem?.error?.localizedDescription ?? "Native stream failed"
            Task { @MainActor [weak self] in
                guard let self, failed else { return }
                self.lastEvent = "item failed: " + message
                self.disarm()
                self.onFailure?(message)
            }
        }
    }

    /// Hosts the (tiny, behind-content) player layer inside the web view so it is part of
    /// the visible window hierarchy that AVKit requires for PiP eligibility.
    func attach(to webView: UIView) {
        guard hostView.superview !== webView else { return }
        hostView.removeFromSuperview()
        hostView.frame = CGRect(x: 0, y: 0, width: 4, height: 4)
        hostView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        webView.insertSubview(hostView, at: 0)
    }

    var isPossible: Bool { controller?.isPictureInPicturePossible == true }

    /// Prepare (or keep) the native presenter for `url`, positioned at `time`.
    func arm(url: URL, time: Double, playing: Bool, userAgent: String?) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            lastEvent = "PiP unsupported"; return
        }
        if sourceURL != url || player.currentItem == nil {
            var options: [String: Any] = [:]
            if let userAgent { options[AVURLAssetHTTPUserAgentKey] = userAgent }
            let asset = AVURLAsset(url: url, options: options)
            let item = AVPlayerItem(asset: asset)
            item.preferredPeakBitRate = Self.shadowBitRate
            item.preferredForwardBufferDuration = 4
            player.replaceCurrentItem(with: item)
            sourceURL = url
            lastEvent = "armed"
        }
        if controller == nil {
            let pip = AVPictureInPictureController(playerLayer: hostView.playerLayer)
            pip?.delegate = self
            pip?.canStartPictureInPictureAutomaticallyFromInline = automaticAllowed
            if #available(iOS 14.2, *) { pip?.requiresLinearPlayback = false }
            controller = pip
            possibleObservation = pip?.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] pip, _ in
                let possible = pip.isPictureInPicturePossible
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastEvent = possible ? "PiP possible" : "PiP not yet possible"
                    if possible && self.pendingManualStart { self.pendingManualStart = false; self.controller?.startPictureInPicture() }
                }
            }
        }
        isArmed = true
        follow(time: time, playing: playing)
    }

    /// Keep the muted shadow aligned with the audible web video (cheap: seeks only on drift).
    func follow(time: Double, playing: Bool) {
        guard isArmed, !isActive, !isStarting else { return }
        if time.isFinite && time >= 0 {
            let current = player.currentTime().seconds
            if !current.isFinite || abs(current - time) > 0.6 {
                player.seek(to: CMTime(seconds: time, preferredTimescale: 600),
                            toleranceBefore: .zero, toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600))
            }
        }
        if playing { if player.rate == 0 { player.play() } } else if player.rate != 0 { player.pause() }
    }

    /// Automatic start is only wanted while the web video plays inline. In Apple fullscreen
    /// WebKit's own presenter already starts PiP; two presenters must never compete.
    func setAutomaticAllowed(_ allowed: Bool) {
        automaticAllowed = allowed
        controller?.canStartPictureInPictureAutomaticallyFromInline = allowed && isArmed
    }

    /// Manual start while the app is active (PiP button).
    func start(time: Double) {
        guard isArmed, !isActive else { return }
        follow(time: time, playing: true)
        if controller?.isPictureInPicturePossible == true { controller?.startPictureInPicture() }
        else { pendingManualStart = true }
    }

    func stop() {
        pendingManualStart = false
        guard isActive || isStarting else { return }
        restoreRequested = true
        controller?.stopPictureInPicture()
    }

    /// V22.2: PiP sluiten en pauzeren (hand-over, pauzeer alles, tab-icoon): geen terugkeer naar
    /// de app of fullscreen; onStop meldt `.closed` zodat de webvideo gepauzeerd blijft.
    func close() {
        pendingManualStart = false
        guard isActive || isStarting else { return }
        closing = true
        restoreRequested = false
        player.pause()
        lastEvent = "closing"
        controller?.stopPictureInPicture()
    }

    /// Background without PiP (lock screen, audio only): stop decoding the silent shadow.
    func suspendShadow() {
        guard isArmed, !isActive, !isStarting else { return }
        player.pause()
    }

    func disarm() {
        pendingManualStart = false
        guard !isActive && !isStarting else { return }
        isArmed = false
        controller?.canStartPictureInPictureAutomaticallyFromInline = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        sourceURL = nil
        lastEvent = "disarmed"
    }

    var currentTime: Double { player.currentTime().seconds }
}

extension NativePiPController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            isStarting = true; restoreRequested = false
            // The PiP window is the audible player from now on, at full quality.
            player.currentItem?.preferredPeakBitRate = 0
            player.isMuted = false
            if player.rate == 0 { player.play() }
            lastEvent = "will start"
            onWillStart?()
        }
    }
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            isStarting = false; isActive = true
            lastEvent = "active"
            // V22.2: tijdens het starten al gesloten → nu alsnog stoppen (AVKit negeerde het eerder).
            if closing { player.pause(); controller.stopPictureInPicture() }
            onDidStart?()
        }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        MainActor.assumeIsolated {
            isStarting = false; isActive = false; closing = false
            player.isMuted = true
            player.currentItem?.preferredPeakBitRate = Self.shadowBitRate
            lastEvent = "failed: " + error.localizedDescription
            onFailure?(error.localizedDescription)
        }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
                                                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // V22: eerst de webvideo al fullscreen zetten (op het juiste tijdstip), pas daarna de
        // PiP-animatie laten eindigen → geen flits van de inline YouTube-speler ertussen.
        MainActor.assumeIsolated {
            // V22.2: sluiten via close() → geen restore/fullscreen.
            if closing { restoreRequested = false; completionHandler(true); return }
            restoreRequested = true
            guard let prepare = onRestoreRequested else { completionHandler(true); return }
            let delay = prepare(player.currentTime().seconds, player.rate != 0)
            if delay <= 0 { completionHandler(true) }
            else { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { completionHandler(true) } }
        }
    }
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {}
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            let playing = player.rate != 0
            let time = player.currentTime().seconds
            let reason: StopReason = (restoreRequested && !closing) ? .restore : .closed
            if closing { player.pause() }   // V22.2: gesloten = gepauzeerd
            isActive = false; isStarting = false; restoreRequested = false; closing = false
            // Back to a silent, low-cost shadow. The web video becomes audible again.
            player.isMuted = true
            player.currentItem?.preferredPeakBitRate = Self.shadowBitRate
            lastEvent = reason == .restore ? "stopped: restore" : "stopped: closed"
            onStop?(time, playing, reason)
        }
    }
}

private final class PlayerLayerView: UIView {
    let playerLayer = AVPlayerLayer()
    override init(frame: CGRect) { super.init(frame: frame); layer.addSublayer(playerLayer) }
    required init?(coder: NSCoder) { super.init(coder: coder); layer.addSublayer(playerLayer) }
    override func layoutSubviews() { super.layoutSubviews(); playerLayer.frame = bounds }
}
#endif
