import SwiftUI

/// V16 / V17.1 — audiovisualizer achter de tab- en menubalk.
///
/// Waarom "gesimuleerd"? WebKit geeft het geluid van een YouTube-video (MediaSource) niet aan de
/// app. Het kan alleen door het geluid om te leiden via Web Audio, en dan kan het geluid stilvallen
/// in PiP en op de achtergrond. Dat risico nemen we niet. Daarom tekent JoeToep een muziekachtig
/// spectrum dat beweegt zolang de video speelt en stilstaat bij pauze. Met een BPM-waarde
/// (bijv. uit Creator tools › Tap tempo) pulseert het precies op de maat van het nummer.
///
/// Performance ("geen enkele hapering"):
///  • standaard UIT (dan wordt er helemaal niets aangemaakt);
///  • maximaal 30 beelden per seconde, asynchroon getekend (niet op de hoofdthread);
///  • staat stil bij pauze, op de achtergrond, in de energiebesparingsmodus, tijdens schermvullend
///    en in PiP; dan kost hij 0 % CPU.
struct AudioVisualizer: View {
    let playing: Bool
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// Alleen tekenen als het zin heeft.
    private var running: Bool { playing && scenePhase == .active && !lowPower }

    var body: some View {
        if theme.visualizer != .off {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { context in
                Canvas(rendersAsynchronously: true) { canvas, size in
                    guard running else { return }
                    draw(in: &canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
                }
            }
            .opacity(running ? theme.visualizerConfig.opacity : 0)
            .animation(theme.anim(.visualizer), value: running)
            .allowsHitTesting(false)          // klikken gaan gewoon naar de knoppen erboven
            .accessibilityHidden(true)        // VoiceOver slaat het over (het is alleen decoratie)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    // MARK: - Tekenen

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time rawTime: Double) {
        let cfg = theme.visualizerConfig
        let strength = theme.visualizerIntensity
        guard size.width > 0, size.height > 0 else { return }
        let t = rawTime * cfg.speed                         // snelheid: tijd sneller/langzamer laten lopen
        let beat = Self.beat(t: rawTime, bpm: cfg.bpm)      // 0…1 puls op het tempo (of vrij)
        let usable = size.height * cfg.height               // hoe hoog mag het worden
        // Verticale positie: onder, midden of boven in de balk.
        let baseline: CGFloat = {
            switch cfg.placement {
            case .bottom: return size.height
            case .center: return size.height / 2 + usable / 2
            case .top: return usable
            }
        }()
        if cfg.glow { canvas.addFilter(.shadow(color: color(0.5, cfg).opacity(0.8), radius: 6)) }
        let count = max(8, min(cfg.bars, 160))
        // Waarde (0…1) voor positie p (0…1): spectrum + puls, eventueel gespiegeld en gladgestreken.
        func level(_ index: Int) -> Double {
            var p = Double(index) / Double(max(count - 1, 1))
            if cfg.mirror { p = abs(p - 0.5) * 2 }                         // spiegel rond het midden
            let raw = Self.energy(p, t) * (0.65 + 0.35 * beat)
            let smooth = Self.energy(p, t - 0.08) * (0.65 + 0.35 * beat)
            return min(1, (raw * (1 - cfg.smoothing) + smooth * cfg.smoothing) * strength * 1.35)
        }
        switch theme.visualizer {
        case .off:
            return
        case .bars, .mirror:
            let slot = size.width / CGFloat(count)
            let w = max(1, slot * 0.62)
            for i in 0..<count {
                let v = level(i)
                let h = max(1, usable * CGFloat(v))
                let x = CGFloat(i) * slot + (slot - w) / 2
                let rect: CGRect
                if theme.visualizer == .mirror {                            // groeit vanuit het midden
                    rect = CGRect(x: x, y: baseline - usable / 2 - h / 2, width: w, height: h)
                } else {
                    rect = CGRect(x: x, y: baseline - h, width: w, height: h)
                }
                let path = cfg.roundedCaps ? Path(roundedRect: rect, cornerRadius: w / 2) : Path(rect)
                canvas.fill(path, with: .color(color(Double(i) / Double(count), cfg).opacity(0.35 + 0.65 * v)))
            }
        case .blocks:
            let slot = size.width / CGFloat(count)
            let w = max(1, slot * 0.7)
            let rows = 6
            let cell = usable / CGFloat(rows)
            for i in 0..<count {
                let lit = Int((level(i) * Double(rows)).rounded())
                for r in 0..<rows {
                    let on = r < lit
                    let rect = CGRect(x: CGFloat(i) * slot, y: baseline - CGFloat(r + 1) * cell + 1, width: w, height: cell - 2)
                    canvas.fill(Path(rect), with: .color(color(Double(r) / Double(rows), cfg).opacity(on ? 0.9 : 0.08)))
                }
            }
        case .dots:
            let slot = size.width / CGFloat(count)
            let r = max(1, min(slot * 0.35, usable * 0.12))
            for i in 0..<count {
                let v = level(i)
                let y = baseline - r - (usable - 2 * r) * CGFloat(v)
                canvas.fill(Path(ellipseIn: CGRect(x: CGFloat(i) * slot + slot / 2 - r, y: y - r, width: 2 * r, height: 2 * r)),
                            with: .color(color(Double(i) / Double(count), cfg)))
            }
        case .wave, .line:
            var path = Path()
            let steps = max(count, 16)
            for s in 0...steps {
                let p = Double(s) / Double(steps)
                let v = level(Int(p * Double(count - 1)))
                let y: CGFloat = theme.visualizer == .wave
                    ? baseline - usable / 2 - usable * 0.45 * CGFloat(v) * CGFloat(sin(p * 18 + t * 5))
                    : baseline - usable * CGFloat(v)
                let point = CGPoint(x: size.width * p, y: y)
                if s == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            canvas.stroke(path, with: .linearGradient(Gradient(colors: [color(0, cfg), color(0.5, cfg), color(1, cfg)]),
                                                      startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                          style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        case .glow:
            let pulse = 0.35 + 0.65 * max(beat, Self.energy(0.3, t))
            let gradient = Gradient(colors: [color(0.5, cfg).opacity(0.5 * strength * pulse), .clear])
            canvas.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(gradient, startPoint: CGPoint(x: size.width / 2, y: baseline), endPoint: CGPoint(x: size.width / 2, y: baseline - usable)))
        case .pulse:
            let pulse = CGFloat(0.25 + 0.75 * max(beat, Self.energy(0.1, t)) * strength)
            let w = size.width * pulse
            let rect = CGRect(x: (size.width - w) / 2, y: baseline - max(2, usable * 0.12), width: w, height: max(2, usable * 0.12))
            canvas.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(color(0.5, cfg)))
        }
    }

    /// De kleur op positie p (0…1) volgens de gekozen kleurmodus.
    private func color(_ p: Double, _ cfg: VisualizerConfig) -> Color {
        switch cfg.colorMode {
        case .accent: return theme.accent
        case .white: return .white
        case .custom: return Color(hexString: cfg.colorA) ?? theme.accent
        case .rainbow: return Color(hue: p.truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1)
        case .gradient:
            // Tussen accentkleur en de tweede kleur: we mengen via doorzichtigheid (eenvoudig en snel).
            let b = Color(hexString: cfg.colorA) ?? .white
            return p < 0.5 ? theme.accent.opacity(1 - p) : b.opacity(0.5 + p / 2)
        }
    }

    /// Puls op de maat: bij BPM > 0 een korte "tik" op elke tel (snel omhoog, rustig omlaag).
    static func beat(t: Double, bpm: Double) -> Double {
        guard bpm > 0 else { return 0.5 + 0.5 * sin(t * 7.8) * sin(t * 1.9 + 0.6) }
        let phase = (t * bpm / 60).truncatingRemainder(dividingBy: 1)   // 0…1 binnen één tel
        return exp(-phase * 5)                                          // 1 op de tel, zakt dan weg
    }

    /// Vloeiend nep-spectrum: lage tonen (links) bewegen langzamer en hoger, zoals bij muziek.
    static func energy(_ p: Double, _ t: Double) -> Double {
        let beat = 0.5 + 0.5 * sin(t * 7.8) * sin(t * 1.9 + 0.6)
        let a = sin(p * 11 + t * 3.1) * 0.5 + 0.5
        let b = sin(p * 27 - t * 5.3) * 0.5 + 0.5
        let c = sin(p * 53 + t * 8.7) * 0.5 + 0.5
        let bass = max(0, 1 - p * 2.2) * beat
        return min(1, 0.15 + 0.35 * a * b + 0.2 * c + 0.45 * bass)
    }
}

/// Volgt de afspeelstatus van een tab, zodat de visualizer in de tabbalk meebeweegt.
struct SessionVisualizer: View {
    @ObservedObject var session: WebSession
    var body: some View {
        AudioVisualizer(playing: session.isPlaying && !session.isFullscreen && !session.isInPictureInPicture)
    }
}
