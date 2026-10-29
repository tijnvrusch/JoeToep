import SwiftUI

/// V17 — Creator tools: een paneel voor muziek, DJ en design, bovenop elke video.
///
/// Wat kun je ermee?
///  • Snelheid 0.25×–4×, met "toonhoogte behouden" aan (tijdrek) of uit (zoals een draaitafel).
///  • A-B-loop: zet A en B tijdens het afspelen; het stuk ertussen herhaalt eindeloos.
///  • Tap tempo: tik mee op de beat; JoeToep berekent de BPM (slagen per minuut) en de
///    lengte van 1 maat, zodat je een loop van precies 4/8/16 maten kunt zetten.
///  • Frame-stap: 1 beeldje terug/vooruit (voor animatie en design).
///  • Tab dempen, en een link naar het huidige tijdstip kopiëren (voor cue-punten).
/// Het paneel praat via `evaluateJavaScript` met creatorTools.js in de pagina.
struct CreatorToolsView: View {
    @ObservedObject var session: WebSession
    @Environment(\.dismiss) private var dismiss      // sluit dit paneel
    @State private var rate = 1.0                    // gekozen snelheid
    @State private var keepPitch = true              // toonhoogte behouden?
    @State private var taps: [Date] = []             // tijdstippen van de laatste tikken
    @State private var bpm: Double?                  // berekend tempo (nil = nog niet bekend)
    @State private var loopText = "No loop"          // uitleg van de huidige loop
    @State private var muted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Speed & pitch") {
                    // Schuifregelaar van 0.25 tot 4 in stapjes van 0.05.
                    Slider(value: $rate, in: 0.25...4, step: 0.05) { Text("Speed") }
                        .onChange(of: rate) { _, _ in apply() }
                    HStack {
                        Text(String(format: "%.2f×", rate)).monospacedDigit()
                        Spacer()
                        // Snelle keuzes die DJ's en muzikanten vaak gebruiken.
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                            Button(String(format: value == 1 ? "1×" : "%.2g×", value)) { rate = value }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    Toggle("Keep pitch (time-stretch)", isOn: $keepPitch).onChange(of: keepPitch) { _, _ in apply() }
                    Text("Off = speed and pitch change together, like a turntable (≈ +1 semitone per +6 %).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("A–B loop") {
                    HStack {
                        Button("Set A") { js("JoeToepCreator.setLoopPoint('a')", refresh: true) }
                        Button("Set B") { js("JoeToepCreator.setLoopPoint('b')", refresh: true) }
                        Button("Clear", role: .destructive) { js("JoeToepCreator.clearLoop()"); loopText = "No loop" }
                    }.buttonStyle(.bordered)
                    if let bpm {
                        // Een maat = 4 tellen. Tijd per maat = 4 × 60 / BPM seconden.
                        let bar = 240 / bpm
                        HStack {
                            Text("Loop from here:")
                            ForEach([1, 4, 8, 16], id: \.self) { bars in
                                Button("\(bars) bar\(bars == 1 ? "" : "s")") {
                                    js("(()=>{const s=JoeToepCreator.state();JoeToepCreator.setLoopPoint('a');JoeToepCreator.seek(s.time);return 0})()")
                                    js("(()=>{const s=JoeToepCreator.state();JoeToepCreator.seek(s.time+\(bar * Double(bars)));JoeToepCreator.setLoopPoint('b');JoeToepCreator.seek(s.time);return 0})()", refresh: true)
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                    Text(loopText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Section("Tap tempo") {
                    Button {
                        tap()
                    } label: {
                        Text(bpm.map { String(format: "%.1f BPM", $0) } ?? "Tap along with the beat")
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("t", modifiers: [])     // op een toetsenbord: tik met "T"
                    if bpm != nil { Button("Reset tempo") { taps = []; bpm = nil } }
                }
                Section("Frame & tab") {
                    HStack {
                        Button { js("JoeToepCreator.step(-1)") } label: { Label("Frame back", systemImage: "backward.frame") }
                        Button { js("JoeToepCreator.step(1)") } label: { Label("Frame forward", systemImage: "forward.frame") }
                    }.buttonStyle(.bordered)
                    Toggle("Mute this tab", isOn: $muted).onChange(of: muted) { _, on in js("JoeToepCreator.mute(\(on))") }
                    Button { copyTimestampLink() } label: { Label("Copy link at current time", systemImage: "link") }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Creator tools")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await loadState() }                    // huidige snelheid/loop inlezen
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 560)
        #endif
    }

    /// Stuurt de snelheid + toonhoogte-keuze naar de pagina.
    private func apply() { js("JoeToepCreator.setRate(\(rate), \(keepPitch))") }

    /// Voert een stukje JavaScript uit in de pagina. `refresh` = daarna de loop-tekst bijwerken.
    private func js(_ code: String, refresh: Bool = false) {
        session.webView.evaluateJavaScript("window.JoeToepCreator ? (\(code), 0) : 0") { _, _ in
            if refresh { Task { await loadState() } }
        }
    }

    /// Leest de toestand uit de pagina (snelheid, loop) en toont hem.
    private func loadState() async {
        guard let state = try? await session.webView.evaluateJavaScript("window.JoeToepCreator ? JoeToepCreator.state() : null") as? [String: Any] else { return }
        if let r = state["rate"] as? Double { rate = r }
        if let keep = state["keepPitch"] as? Bool { keepPitch = keep }
        if let m = state["muted"] as? Bool { muted = m }
        if let loop = state["loop"] as? [String: Any], let a = loop["a"] as? Double, let b = loop["b"] as? Double {
            loopText = String(format: "Looping %@ → %@ (%.2f s)", Self.clock(a), Self.clock(b), b - a)
        }
    }

    /// Tap tempo: gemiddelde tijd tussen de laatste 8 tikken → BPM. Na 2 s stilte begint het opnieuw.
    private func tap() {
        let now = Date()
        if let last = taps.last, now.timeIntervalSince(last) > 2 { taps = [] }
        taps.append(now)
        taps = Array(taps.suffix(8))
        guard taps.count >= 2, let first = taps.first, let last = taps.last else { return }
        let average = last.timeIntervalSince(first) / Double(taps.count - 1)   // seconden per tel
        bpm = 60 / average
    }

    /// Kopieert de huidige pagina-URL met `t=` (YouTube) zodat de video op dit moment start.
    private func copyTimestampLink() {
        session.webView.evaluateJavaScript("window.JoeToepCreator ? JoeToepCreator.state().time : 0") { value, _ in
            guard let url = session.currentURL else { return }
            let seconds = Int((value as? Double) ?? 0)
            Clipboard.copy(WebSession.url(url, at: Double(seconds)))
        }
    }

    /// 83.5 seconden → "1:23.5"
    private static func clock(_ t: Double) -> String { String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60)) }
}
