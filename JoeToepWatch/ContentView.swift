import SwiftUI
import AVKit
import AVFoundation

/// V22 hoofdscherm: wat nu speelt (met live voortgang), je apparaten, Spotify, zoeken,
/// downloads op de Watch en op de iPhone, de home-feed en instellingen.
struct ContentView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var phase

    enum Route: Hashable { case nowPlaying, results, downloads, local, devices, spotify, settings, player(LocalDownload) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let now = store.state.nowPlaying, now.title != nil {
                    NavigationLink(value: Route.nowPlaying) { NowCard(device: now) }
                        .listRowBackground(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.red.opacity(0.22)))
                } else if !store.nowTitle.isEmpty {
                    NavigationLink(value: Route.nowPlaying) {
                        Label(store.nowTitle, systemImage: store.playing ? "waveform" : "pause.fill").font(.footnote).lineLimit(1)
                    }
                }

                TextFieldLink(prompt: Text("Search YouTube")) {
                    Label("Search", systemImage: "magnifyingglass").font(.body.weight(.medium))
                } onSubmit: { text in
                    path.append(.results)
                    Task { await store.search(text) }
                }
                .accessibilityIdentifier("watch.search")

                HStack(spacing: 6) {
                    tile("Devices", "laptopcomputer.and.iphone", badge: store.state.devices.filter(\.playing).count) { path.append(.devices) }
                    tile("Spotify", "music.note", tint: .green, badge: store.state.spotify?.playing == true ? 1 : 0) { path.append(.spotify) }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                HStack(spacing: 6) {
                    tile("On Watch", "applewatch", badge: store.local.count) { path.append(.local) }
                    tile("iPhone", "arrow.down.circle") { path.append(.downloads) }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if !store.recentSearches.isEmpty {
                    Section("Recent") {
                        ForEach(store.recentSearches.prefix(3), id: \.self) { q in
                            Button { path.append(.results); Task { await store.search(q) } } label: {
                                Label(q, systemImage: "clock.arrow.circlepath").font(.footnote).lineLimit(1)
                            }
                        }
                    }
                }

                Section {
                    if store.feed.isEmpty {
                        if store.loadingFeed { HStack { Spacer(); ProgressView(); Spacer() } }
                        else if let message = store.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    }
                    ForEach(store.feed) { video in VideoRow(video: video) { select(video) } }
                    if !store.feed.isEmpty {
                        Button { Task { await store.refreshFeed() } } label: {
                            Label("Refresh", systemImage: "arrow.clockwise").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Home") }

                NavigationLink(value: Route.settings) { Label("Settings", systemImage: "gearshape") }
            }
            .navigationTitle("JoeToep")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .nowPlaying: NowPlayingView()
                case .results: ResultsView { select($0) }
                case .downloads: DownloadsListView()
                case .local: LocalDownloadsView { path.append(.player($0)) }
                case .devices: DevicesView()
                case .spotify: SpotifyView()
                case .settings: WatchSettingsView()
                case .player(let item): LocalPlayerView(item: item)
                }
            }
            .task { await store.refreshFeedIfNeeded() }
        }
        .tint(.red)
        .onOpenURL { url in
            switch url.host {
            case "nowplaying": path = [.nowPlaying]
            case "devices": path = [.devices]
            case "spotify": path = [.spotify]
            case "search": path = []
            case "local": path = [.local]
            default: break
            }
            if let device = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "device" })?.value {
                store.target = device
            }
        }
        .onChange(of: phase) { _, now in now == .active ? store.beginLive() : store.endLive() }
        .onAppear { store.beginLive() }
    }

    private func tile(_ title: String, _ symbol: String, tint: Color = .red, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                    if badge > 0 {
                        Text("\(badge)").font(.system(size: 9, weight: .bold)).padding(3).background(Circle().fill(tint)).offset(x: 9, y: -6)
                    }
                }
                Text(title).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func select(_ video: WatchVideo) {
        Task { await store.play(video) }
        path = [.nowPlaying]
    }
}

/// Compacte kaart: titel, apparaat en live voortgang.
struct NowCard: View {
    let device: WatchDeviceState
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: device.playing ? "play.fill" : "pause.fill").font(.system(size: 9)).foregroundStyle(.red)
                    Image(systemName: device.symbol).font(.caption2)
                    Text(device.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(device.title ?? "").font(.footnote.weight(.semibold)).lineLimit(2)
                if let pos = device.livePosition(at: ctx.date) {
                    if let d = device.duration, d > 0 {
                        ProgressView(value: min(pos, d), total: d).tint(.red)
                        HStack { Text(watchClock(pos)); Spacer(); Text("-" + watchClock(max(0, d - pos))) }
                            .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                    } else {
                        Text(watchClock(pos)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Eén regel in een lijst: plaatje, titel (2 regels), kanaal · duur.
struct VideoRow: View {
    let video: WatchVideo
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                ThumbnailView(url: video.thumbnail)
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title).font(.footnote.weight(.medium)).lineLimit(2)
                    Text([video.channel, video.duration].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject private var store: WatchStore
    let select: (WatchVideo) -> Void
    var body: some View {
        List {
            if store.searching { HStack { Spacer(); ProgressView(); Spacer() } }
            else if store.results.isEmpty { Text(store.message ?? "No results").font(.footnote).foregroundStyle(.secondary) }
            ForEach(store.results) { video in VideoRow(video: video) { select(video) } }
        }
        .navigationTitle(store.query)
    }
}

// MARK: - Apparaten

struct DevicesView: View {
    @EnvironmentObject private var store: WatchStore
    var body: some View {
        List {
            if store.state.devices.isEmpty {
                Text("Open JoeToep on your iPhone. Your Mac and iPad appear here when they're nearby.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.state.devices) { d in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: d.symbol).foregroundStyle(d.playing ? .red : .secondary)
                        Text(d.name).font(.footnote.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Circle().fill(d.connected ? Color.green : Color.gray).frame(width: 6, height: 6)
                    }
                    if let title = d.title { Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                    if d.title != nil {
                        HStack(spacing: 6) {
                            small("gobackward.\(Int(store.skipSeconds))") { await store.seek(-store.skipSeconds, device: d.id) }
                            small(d.playing ? "pause.fill" : "play.fill", filled: true) { await store.toggle(d.id) }
                            small("goforward.\(Int(store.skipSeconds))") { await store.seek(store.skipSeconds, device: d.id) }
                        }
                        let others = store.state.devices.filter { $0.id != d.id && $0.connected }
                        ForEach(others) { o in
                            Button { Task { await store.move(from: d.id, to: o.id) } } label: {
                                Label("Continue on \(o.name)", systemImage: "arrow.up.forward.app").font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
                .onTapGesture { store.target = d.id }
                .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(store.target == d.id ? Color.red.opacity(0.18) : Color.white.opacity(0.06)))
            }
        }
        .navigationTitle("Devices")
    }
    private func small(_ symbol: String, filled: Bool = false, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 30)
                .background(Capsule().fill(filled ? Color.red : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spotify

struct SpotifyView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var volume: Double = 50
    var body: some View {
        ScrollView {
            if let sp = store.state.spotify {
                VStack(spacing: 8) {
                    if let art = sp.artwork.flatMap(URL.init(string:)) {
                        AsyncImage(url: art) { $0.resizable().scaledToFill() } placeholder: { Color.green.opacity(0.2) }
                            .frame(width: 70, height: 70).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text(sp.track).font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                    Text(sp.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        if sp.duration > 0 { ProgressView(value: min(sp.livePosition(at: ctx.date), sp.duration), total: sp.duration).tint(.green) }
                    }
                    HStack(spacing: 6) {
                        button("backward.fill") { await store.spotify("previous") }
                        Button { Task { await store.spotify("playPause") } } label: {
                            Image(systemName: sp.playing ? "pause.fill" : "play.fill").font(.title3)
                                .frame(width: 48, height: 48).background(Circle().fill(Color.green)).foregroundStyle(.black)
                        }.buttonStyle(.plain)
                        button("forward.fill") { await store.spotify("next") }
                    }
                    HStack(spacing: 6) {
                        button("shuffle", on: sp.shuffling) { await store.spotify("toggleShuffle") }
                        button("repeat", on: sp.repeating) { await store.spotify("toggleRepeat") }
                    }
                    HStack {
                        Image(systemName: "speaker.fill").font(.caption2)
                        Slider(value: $volume, in: 0...100, step: 10) { Text("Volume") }
                            .onChange(of: volume) { _, v in Task { await store.spotify("setVolume", value: v) } }
                        Image(systemName: "speaker.wave.3.fill").font(.caption2)
                    }
                    .onAppear { volume = sp.volume }
                    Text("on \(sp.device)").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("Play something in Spotify on your Mac to control it here.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Spotify")
    }
    private func button(_ symbol: String, on: Bool = false, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).frame(width: 40, height: 36)
                .background(Capsule().fill(on ? Color.green.opacity(0.5) : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Downloads

/// Downloads op je iPhone: tik = afspelen op de iPhone; ⤓ = op de Watch zetten.
struct DownloadsListView: View {
    @EnvironmentObject private var store: WatchStore
    var body: some View {
        List {
            Button { Task { await store.downloadCurrentPage() } } label: {
                Label("Download current iPhone page", systemImage: "square.and.arrow.down.on.square").font(.footnote)
            }
            if store.downloads.isEmpty {
                Text("No downloads on your iPhone yet. Use the download button in JoeToep (videos from other sites; YouTube can't be downloaded).")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.downloads) { item in
                HStack(spacing: 6) {
                    Button { Task { await store.playDownload(item) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.channel == "Audio" ? "music.note" : "film").foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.footnote).lineLimit(2)
                                if let size = item.duration { Text(size).font(.system(size: 10)).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    Spacer(minLength: 2)
                    Button { Task { await store.sendToWatch(item) } } label: {
                        Image(systemName: item.sentToWatch || store.local.contains { $0.id == item.id } ? "checkmark.circle.fill" : "applewatch.and.arrow.forward")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let message = store.message { Text(message).font(.caption2).foregroundStyle(.orange) }
        }
        .navigationTitle("iPhone")
        .task { await store.refreshDownloads() }
    }
}

/// Bestanden op de Watch zelf — ook zonder iPhone of internet af te spelen.
struct LocalDownloadsView: View {
    @EnvironmentObject private var store: WatchStore
    let play: (LocalDownload) -> Void
    var body: some View {
        List {
            if store.incoming > 0 { Label("Receiving \(store.incoming)…", systemImage: "arrow.down.circle.dotted").font(.footnote) }
            if store.local.isEmpty && store.incoming == 0 {
                Text("Nothing on your Watch yet. Open iPhone downloads and tap the Watch icon, or turn on Auto-sync in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.local) { item in
                Button { play(item) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.audio ? "music.note" : "play.rectangle.fill").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.footnote).lineLimit(2)
                            Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file) + (item.position > 5 ? " · " + watchClock(item.position) : ""))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions { Button(role: .destructive) { store.remove(item) } label: { Label("Delete", systemImage: "trash") } }
            }
            if !store.local.isEmpty {
                Text("Using " + ByteCountFormatter.string(fromByteCount: store.localBytes, countStyle: .file)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("On Watch")
    }
}

/// Speler voor bestanden op de Watch (video met beeld, of audio).
struct LocalPlayerView: View {
    @EnvironmentObject private var store: WatchStore
    let item: LocalDownload
    @State private var player: AVPlayer?
    var body: some View {
        Group {
            if let player {
                if item.audio {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.red)
                        Text(item.title).font(.footnote).lineLimit(2).multilineTextAlignment(.center)
                        HStack {
                            Button { player.seek(to: CMTime(seconds: max(0, player.currentTime().seconds - 15), preferredTimescale: 600)) } label: { Image(systemName: "gobackward.15") }
                            Button { player.timeControlStatus == .playing ? player.pause() : player.play() } label: { Image(systemName: "playpause.fill") }
                            Button { player.seek(to: CMTime(seconds: player.currentTime().seconds + 30, preferredTimescale: 600)) } label: { Image(systemName: "goforward.30") }
                        }
                    }
                } else {
                    VideoPlayer(player: player).ignoresSafeArea()
                }
            } else { ProgressView() }
        }
        .navigationTitle(item.title)
        .onAppear {
            let p = AVPlayer(url: store.fileURL(item))
            if item.position > 5 { p.seek(to: CMTime(seconds: item.position, preferredTimescale: 600)) }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: item.audio ? .default : .moviePlayback, policy: item.audio ? .longFormAudio : .default)
            player = p
            if item.audio {
                AVAudioSession.sharedInstance().activate(options: []) { ok, _ in if ok { DispatchQueue.main.async { p.play() } } }
            } else { p.play() }
        }
        .onDisappear {
            if let player { store.savePosition(item, player.currentTime().seconds); player.pause() }
        }
    }
}

// MARK: - Instellingen

struct WatchSettingsView: View {
    @EnvironmentObject private var store: WatchStore
    var body: some View {
        List {
            Section("Downloads to Watch") {
                Picker("Quality", selection: $store.quality) {
                    Text("Low (smallest)").tag("low")
                    Text("Medium (480p)").tag("medium")
                    Text("High (540p)").tag("high")
                    Text("Audio only").tag("audio")
                }
                Toggle("Auto-sync new downloads", isOn: $store.autoSync)
            }
            Section("Remote") {
                Toggle("Follow what's playing", isOn: $store.followPlaying)
                Picker("Skip", selection: $store.skipSeconds) {
                    Text("10 s").tag(10.0); Text("15 s").tag(15.0); Text("30 s").tag(30.0)
                }
            }
            Section {
                HStack { Text("iPhone"); Spacer(); Text(store.reachable ? "Connected" : "Not reachable").foregroundStyle(store.reachable ? .green : .secondary) }
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
    }
}
