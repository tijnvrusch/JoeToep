// V20 — Knop in de menubalk: alles wat speelt (of gepauzeerd staat) in één overzicht.
// Tik = paneel met alle tabs met media + Spotify; per bron play/pauze, "alleen deze",
// volume en dempen. Vasthouden = alles pauzeren.
import SwiftUI

struct MediaHubButton: View {
    var size: CGFloat
    var iconSize: CGFloat
    @ObservedObject private var hub = MediaHub.shared
    @ObservedObject private var spotify = SpotifyController.shared
    @State private var open = false
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        HoldButton(action: { open.toggle() }, hold: { hub.pauseAll() }) {
            Image(systemName: hub.playingCount > 0 || spotify.current?.playing == true ? "waveform.circle.fill" : "waveform.circle")
                .themedIcon(theme, size: iconSize, active: hub.playingCount > 0 || spotify.current?.playing == true)
                .frame(width: size, height: size).contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if hub.playingCount > 1 {
                        Text("\(hub.playingCount)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(3).background(Circle().fill(theme.accent)).offset(x: -2, y: 4)
                    }
                }
        }
        .help("Now playing · hold to pause everything")
        .accessibilityLabel("Now playing")
        .accessibilityIdentifier("toolbar.mediaHub")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            MediaHubPanel()
                #if os(iOS)
                .presentationCompactAdaptation(.popover)
                #endif
        }
    }
}

struct MediaHubPanel: View {
    @ObservedObject private var hub = MediaHub.shared
    @ObservedObject private var spotify = SpotifyController.shared
    @AppStorage("mediaHubShowPausedV20") private var showPaused = true
    @Environment(\.joeToepTheme) private var theme

    private var visible: [MediaSourceState] { showPaused ? hub.sources : hub.sources.filter(\.playing) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Now playing").font(.headline)
                Spacer()
                if hub.playingCount > 0 {
                    Button("Pause all") { hub.pauseAll() }.buttonStyle(.borderless).font(.caption.weight(.semibold))
                }
                Toggle("Paused", isOn: $showPaused).toggleStyle(.button).controlSize(.small)
                    .help("Also show paused tabs")
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            Divider()
            ScrollView {
                VStack(spacing: 6) {
                    if visible.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "speaker.slash").font(.title2).foregroundStyle(.secondary)
                            Text(hub.isScanning ? "Looking for media…" : "Nothing is playing").foregroundStyle(.secondary)
                            spotifyLaunch
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                    ForEach(visible) { source in
                        MediaSourceRow(source: source)
                    }
                    if let problem = spotify.problem {
                        Label(problem, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 440)
        }
        .frame(width: 360)
        .onAppear { hub.beginObserving() }
        .onDisappear { hub.endObserving() }
    }

    @ViewBuilder private var spotifyLaunch: some View {
        #if os(macOS)
        if spotify.current == nil && spotify.isInstalled {
            Button { spotify.perform(.launch) } label: { Label("Open Spotify", systemImage: "music.note") }
                .buttonStyle(.bordered)
        }
        #endif
    }
}

struct MediaSourceRow: View {
    let source: MediaSourceState
    @ObservedObject private var hub = MediaHub.shared
    @State private var volume: Double = 1
    @State private var editing = false
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                artwork
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text([source.subtitle, source.site].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { hub.show(source) }
                Button { hub.skip(source, forward: false) } label: {
                    Image(systemName: source.kind == .spotify ? "backward.fill" : "gobackward.10")
                }.buttonStyle(.borderless).help(source.kind == .spotify ? "Previous" : "Back 10 s")
                Button { hub.toggle(source) } label: {
                    Image(systemName: source.playing ? "pause.circle.fill" : "play.circle.fill").font(.title2)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.borderless)
                .help(source.playing ? "Pause" : "Play")
                Button { hub.skip(source, forward: true) } label: {
                    Image(systemName: source.kind == .spotify ? "forward.fill" : "goforward.10")
                }.buttonStyle(.borderless).help(source.kind == .spotify ? "Next" : "Forward 10 s")
            }
            HStack(spacing: 8) {
                Button { hub.toggleMute(source) } label: {
                    Image(systemName: source.muted || volume == 0 ? "speaker.slash.fill" : volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
                        .frame(width: 18)
                }.buttonStyle(.borderless)
                Slider(value: $volume, in: 0...1, onEditingChanged: { editing = $0; if !$0 { hub.setVolume(source, volume) } })
                    .onChange(of: volume) { _, v in if editing { hub.setVolume(source, v) } }
                Text("\(Int((volume * 100).rounded()))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
                Button { hub.solo(source) } label: { Image(systemName: "1.circle") }
                    .buttonStyle(.borderless).help("Play only this — pause everything else")
                // V21: deze video op een ander apparaat verder laten spelen.
                if case .tab(let id) = source.kind, let ws = BrowserWorkspace.registry.allObjects.first(where: { $0.tabs.contains { $0.id == id } }),
                   !ws.otherDevices.isEmpty, let tab = ws.tabs.first(where: { $0.id == id }) {
                    Menu {
                        ForEach(ws.otherDevices, id: \.id) { d in Button("Continue on \(d.name)") { ws.continuePlayback(of: tab, on: d.id) } }
                    } label: { Image(systemName: "arrow.up.forward.app") }
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                    .fixedSize().help("Continue on another device")
                }
            }
            if source.duration > 0 {
                ProgressView(value: min(source.position, source.duration), total: source.duration).tint(theme.accent)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(source.playing ? theme.accent.opacity(0.12) : Color.primary.opacity(0.05)))
        .onAppear { volume = source.muted ? 0 : source.volume }
        .onChange(of: source.volume) { _, v in if !editing { volume = v } }
    }

    @ViewBuilder private var artwork: some View {
        Group {
            if let url = source.artworkURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
            } else { placeholder }
        }
        .frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(source.kind == .spotify ? Color.green.opacity(0.25) : Color.primary.opacity(0.08))
            Image(systemName: source.kind == .spotify ? "music.note" : "play.rectangle").foregroundStyle(.secondary)
        }
    }
}
