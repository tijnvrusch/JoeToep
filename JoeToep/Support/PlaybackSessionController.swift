#if os(iOS)
import AVFAudio
import Foundation

@MainActor
final class PlaybackSessionController {
    var onInterruption: ((Bool, Bool) -> Void)?
    private var playing = false
    private var resumeAfterInterruption = false
    private var observers: [NSObjectProtocol] = []
    init() {
        // Configure BEFORE constructing WKWebView. Do not change category on its play event.
        configureCategory()
        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in self?.interrupted(notification) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.configureCategory() }
        })
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    func notePlayback(_ isPlaying: Bool) { playing = isPlaying }
    func prepareForPictureInPicture() {
        // WebKit owns activation. Re-activating an already playing session causes a gap.
    }
    /// Stelt de "audiosessie" van iOS/iPadOS in: hoe het systeem het geluid van JoeToep behandelt.
    ///
    /// V17 — Ruimtelijke audio (spatial audio) met AirPods Pro 3:
    ///  • categorie `.playback` = geluid blijft spelen met het stilteknopje aan en op de achtergrond;
    ///  • modus `.moviePlayback` = "dit is film/video". Precies deze modus zet iOS aan om stereo
    ///    ruimtelijk te maken ("Spatialize Stereo") en hoofdbeweging te volgen (head tracking)
    ///    met AirPods Pro / Max;
    ///  • `setSupportsMultichannelContent(true)` = meerkanaals geluid (5.1 / Dolby Atmos) wordt
    ///    niet naar stereo teruggemixt maar in zijn geheel naar de AirPods gestuurd;
    ///  • `.longFormVideo` = AirPlay en "Doorgaan op ander apparaat" behandelen het als video.
    /// Met de instelling uit gebruiken we modus `.default`: gewoon stereo, zonder ruimtelijk effect.
    private func configureCategory() {
        let session = AVAudioSession.sharedInstance()
        // Leest de instelling direct uit UserDefaults (standaard aan).
        let spatial = UserDefaults.standard.object(forKey: "spatialAudioV17") as? Bool ?? true
        let mode: AVAudioSession.Mode = spatial ? .moviePlayback : .default
        // Alleen iets veranderen als het nog niet goed staat (een wijziging kost een hapering).
        if session.category != .playback || session.mode != mode || session.routeSharingPolicy != .longFormVideo || !session.categoryOptions.isEmpty {
            do { try session.setCategory(.playback, mode: mode, policy: .longFormVideo, options: []) }
            catch { /* WebKit owns activation; a future user gesture can activate it. */ }
        }
        // Meerkanaals doorgeven voor Dolby Atmos / 5.1 naar AirPods (bestaat sinds iOS 15).
        try? session.setSupportsMultichannelContent(spatial)
    }
    /// V17: opnieuw instellen nadat de gebruiker de instelling "Ruimtelijke audio" wijzigt.
    func refreshSpatialAudio() { configureCategory() }
    private func interrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            resumeAfterInterruption = playing
            onInterruption?(true, false)
        case .ended:
            let rawOptions = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let canResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            if resumeAfterInterruption && canResume {
                // Restore audio eligibility, never force a paused video to start.
                try? AVAudioSession.sharedInstance().setActive(true)
            }
            resumeAfterInterruption = false
            onInterruption?(false, canResume)
        @unknown default: resumeAfterInterruption = false
        }
    }
}
#else
import Foundation
@MainActor
final class PlaybackSessionController {
    var onInterruption: ((Bool, Bool) -> Void)?
    func notePlayback(_ isPlaying: Bool) {}
    func prepareForPictureInPicture() {}
}
#endif
