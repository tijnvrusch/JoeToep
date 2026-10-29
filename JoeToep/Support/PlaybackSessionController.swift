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
    private func configureCategory() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playback || session.mode != .moviePlayback || session.routeSharingPolicy != .longFormVideo || !session.categoryOptions.isEmpty else { return }
        do { try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: []) }
        catch { /* WebKit owns activation; a future user gesture can activate it. */ }
    }
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
