import SwiftUI

/// V16: audio-visualizer effect behind the tab and menu bars. WebKit does not expose the audio
/// signal of a MediaSource video to the app (tapping it would re-route audio and break PiP and
/// background playback), so this is a music-like animation that runs while a video plays and
/// settles when it pauses. Style and intensity in Settings › Appearance.
struct AudioVisualizer: View {
    let playing: Bool
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// V16.2 performance: 30 fps is visually smooth for this effect and halves the cost; nothing
    /// is drawn while paused, in the background, or in Low Power Mode.
    private var running: Bool { playing && scenePhase == .active && !lowPower }

    var body: some View {
        if theme.visualizer != .off {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { context in
                Canvas(rendersAsynchronously: true) { canvas, size in
                    guard running else { return }
                    draw(in: &canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
                }
            }
            .opacity(running ? 1 : 0)
            .animation(theme.anim(.visualizer), value: running)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let strength = theme.visualizerIntensity
        guard strength > 0.005, size.width > 0 else { return }
        let accent = theme.accent
        switch theme.visualizer {
        case .bars:
            let barWidth: CGFloat = 3, gap: CGFloat = 2
            let count = Int(size.width / (barWidth + gap))
            for i in 0..<count {
                let x = CGFloat(i) * (barWidth + gap)
                let p = Double(i) / Double(max(count, 1))
                let v = Self.energy(p, time) * strength
                let h = max(1, size.height * CGFloat(v))
                let rect = CGRect(x: x, y: size.height - h, width: barWidth, height: h)
                canvas.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(accent.opacity(0.18 + 0.32 * v)))
            }
        case .wave:
            var path = Path()
            let steps = max(Int(size.width / 4), 2)
            for s in 0...steps {
                let p = Double(s) / Double(steps)
                let y = size.height * (0.55 - 0.4 * CGFloat(Self.energy(p, time) * strength) * CGFloat(sin(p * 18 + time * 5)))
                let point = CGPoint(x: size.width * p, y: y)
                if s == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            canvas.stroke(path, with: .color(accent.opacity(0.55)), lineWidth: 1.5)
        case .glow:
            let pulse = 0.35 + 0.65 * Self.energy(0.3, time)
            let gradient = Gradient(colors: [accent.opacity(0.28 * strength * pulse), .clear])
            canvas.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(gradient, startPoint: CGPoint(x: size.width / 2, y: size.height), endPoint: CGPoint(x: size.width / 2, y: 0)))
        case .off:
            break
        }
    }

    /// Smooth pseudo-spectrum: low frequencies move slower and higher, like music.
    static func energy(_ p: Double, _ t: Double) -> Double {
        let beat = 0.5 + 0.5 * sin(t * 7.8) * sin(t * 1.9 + 0.6)
        let a = sin(p * 11 + t * 3.1) * 0.5 + 0.5
        let b = sin(p * 27 - t * 5.3) * 0.5 + 0.5
        let c = sin(p * 53 + t * 8.7) * 0.5 + 0.5
        let bass = max(0, 1 - p * 2.2) * beat
        return min(1, 0.15 + 0.35 * a * b + 0.2 * c + 0.45 * bass)
    }
}

/// Observes a tab's session so the tab-bar visualizer follows its playback.
struct SessionVisualizer: View {
    @ObservedObject var session: WebSession
    var body: some View {
        AudioVisualizer(playing: session.isPlaying && !session.isFullscreen && !session.isInPictureInPicture)
    }
}
