// V21 — JoeToep-widgets (iPhone, iPad en Mac): Now Playing (4 varianten), Alle apparaten, Zoeken,
// Bibliotheek, Verder kijken, Spotify, Tabs en Snelkoppelingen — in alle formaten die het systeem
// aanbiedt (ook vergrendelscherm op iPhone/iPad). De data komt uit de app (WidgetShared) en is
// dankzij de sync op al je apparaten hetzelfde.
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data

struct JTEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    var artwork: [URL: Data] = [:]

    var nowPlaying: WidgetDevice? { snapshot?.nowPlaying }
    func image(_ url: URL?) -> Image? {
        guard let url, let data = artwork[url] else { return nil }
        #if os(macOS)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return UIImage(data: data).map { Image(uiImage: $0) }
        #endif
    }
    static let placeholder = JTEntry(date: Date(), snapshot: .preview)
}

extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        var s = WidgetSnapshot()
        s.thisDeviceID = "me"; s.thisDeviceName = "MacBook"
        s.devices = [
            WidgetDevice(id: "me", name: "MacBook", kind: "mac", isThisDevice: true, title: "Lofi beats to relax to",
                         url: URL(string: "https://www.youtube.com/watch?v=jfKfPfyJRdk"), playing: true, time: 754, duration: 3600, updated: Date(), tabCount: 5),
            WidgetDevice(id: "phone", name: "iPhone", kind: "iphone", isThisDevice: false, title: "Tiny Desk Concert",
                         url: URL(string: "https://www.youtube.com/watch?v=abc"), playing: false, time: 120, updated: Date(), tabCount: 3),
        ]
        s.favourites = [WidgetLink(title: "Subscriptions", url: URL(string: "https://www.youtube.com/feed/subscriptions")!),
                        WidgetLink(title: "Watch later", url: URL(string: "https://www.youtube.com/playlist?list=WL")!)]
        s.continueWatching = s.favourites
        return s
    }
}

struct JTProvider: TimelineProvider {
    func placeholder(in context: Context) -> JTEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (JTEntry) -> Void) {
        let snap = WidgetShared.load()
        completion(JTEntry(date: Date(), snapshot: snap ?? (context.isPreview ? .preview : nil)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<JTEntry>) -> Void) {
        let snap = WidgetShared.load()
        Task {
            let art = await Self.loadArtwork(for: snap)
            let now = Date()
            // Elke 30 s een nieuwe regel, zodat de voortgang doorloopt; daarna vraagt WidgetKit opnieuw.
            let entries = (0..<10).map { i in JTEntry(date: now.addingTimeInterval(Double(i) * 30), snapshot: snap, artwork: art) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(300))))
        }
    }
    /// Hoezen/miniaturen vooraf ophalen (widgets kunnen zelf niets downloaden tijdens het tekenen).
    static func loadArtwork(for snap: WidgetSnapshot?) async -> [URL: Data] {
        guard let snap else { return [:] }
        var urls: [URL] = []
        for d in snap.devices { if let t = WidgetShared.thumbnail(for: d.url) { urls.append(t) } }
        if let a = snap.spotify?.artworkURL { urls.append(a) }
        for l in snap.continueWatching.prefix(4) { if let t = WidgetShared.thumbnail(for: l.url) { urls.append(t) } }
        var result: [URL: Data] = [:]
        await withTaskGroup(of: (URL, Data?).self) { group in
            for url in Set(urls).prefix(8) {
                group.addTask {
                    var req = URLRequest(url: url); req.timeoutInterval = 4
                    let data = try? await URLSession.shared.data(for: req).0
                    return (url, data)
                }
            }
            for await (url, data) in group { if let data, data.count < 400_000 { result[url] = data } }
        }
        return result
    }
}

// MARK: - Gedeelde onderdelen

private let accent = Color(red: 1, green: 0.17, blue: 0.2)

private func timeText(_ s: Double?) -> String {
    guard let s, s.isFinite else { return "" }
    let t = Int(max(0, s)); return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
}

private struct EmptyState: View {
    var text = "Open JoeToep to get started"
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "play.rectangle").font(.title2).foregroundStyle(accent)
            Text(text).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}

private struct PlayPauseButton: View {
    let device: WidgetDevice
    var size: Font = .title2
    var body: some View {
        Button(intent: MediaCommandIntent(action: .playPause, deviceID: device.isThisDevice ? nil : device.id)) {
            Image(systemName: device.playing ? "pause.circle.fill" : "play.circle.fill").font(size).foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }
}

private struct SkipButton: View {
    let device: WidgetDevice
    let forward: Bool
    var body: some View {
        Button(intent: MediaCommandIntent(action: forward ? .skipForward : .skipBack, deviceID: device.isThisDevice ? nil : device.id)) {
            Image(systemName: forward ? "goforward.10" : "gobackward.10")
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceBadge: View {
    let device: WidgetDevice
    var body: some View {
        Label(device.isThisDevice ? "This \(device.kind == "mac" ? "Mac" : device.kind == "ipad" ? "iPad" : "iPhone")" : device.name,
              systemImage: device.symbol)
            .font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
    }
}

private struct Thumb: View {
    let image: Image?
    var corner: CGFloat = 10
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Color.primary.opacity(0.08))
            if let image { image.resizable().scaledToFill() } else { Image(systemName: "play.rectangle.fill").foregroundStyle(.secondary) }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

private struct ProgressLine: View {
    let device: WidgetDevice
    let date: Date
    var body: some View {
        if let pos = device.livePosition(at: date) {
            if let d = device.duration, d > 0 {
                ProgressView(value: min(pos, d), total: d).tint(accent)
            } else {
                Text(timeText(pos)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}

/// "Hier verder kijken": neemt de video over van een ander apparaat.
private struct ContinueHereButton: View {
    let device: WidgetDevice
    var body: some View {
        if !device.isThisDevice {
            Link(destination: WidgetShared.link("takeover", ["device": device.id])) {
                Label("Continue here", systemImage: "arrow.down.right.and.arrow.up.left").font(.caption2.weight(.semibold))
            }
        }
    }
}

// MARK: - Now Playing (standaard)

struct NowPlayingView: View {
    let entry: JTEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if let d = entry.nowPlaying, d.title != nil {
                switch family {
                case .systemSmall: small(d)
                case .systemMedium: medium(d)
                #if os(iOS)
                case .accessoryCircular: circular(d)
                case .accessoryRectangular: rectangular(d)
                case .accessoryInline: Label(d.title ?? "", systemImage: d.playing ? "play.fill" : "pause.fill")
                #endif
                default: large(d)
                }
            } else { EmptyState(text: "Nothing playing yet") }
        }
        .widgetURL(entry.nowPlaying?.url.map(WidgetShared.openURL))
    }
    private func small(_ d: WidgetDevice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Thumb(image: entry.image(WidgetShared.thumbnail(for: d.url)), corner: 8).frame(height: 56)
            Text(d.title ?? "").font(.caption.weight(.semibold)).lineLimit(2)
            Spacer(minLength: 0)
            HStack { DeviceBadge(device: d); Spacer(); PlayPauseButton(device: d, size: .title3) }
        }
    }
    private func medium(_ d: WidgetDevice) -> some View {
        HStack(spacing: 12) {
            Thumb(image: entry.image(WidgetShared.thumbnail(for: d.url))).frame(width: 130)
            VStack(alignment: .leading, spacing: 6) {
                DeviceBadge(device: d)
                Text(d.title ?? "").font(.subheadline.weight(.semibold)).lineLimit(2)
                ProgressLine(device: d, date: entry.date)
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    SkipButton(device: d, forward: false); PlayPauseButton(device: d); SkipButton(device: d, forward: true)
                    Spacer(minLength: 0)
                    ContinueHereButton(device: d)
                }
            }
        }
    }
    private func large(_ d: WidgetDevice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Thumb(image: entry.image(WidgetShared.thumbnail(for: d.url)), corner: 14).frame(maxHeight: 170)
            DeviceBadge(device: d)
            Text(d.title ?? "").font(.headline).lineLimit(2)
            ProgressLine(device: d, date: entry.date)
            HStack(spacing: 22) {
                SkipButton(device: d, forward: false); PlayPauseButton(device: d, size: .largeTitle); SkipButton(device: d, forward: true)
                Spacer(); ContinueHereButton(device: d)
            }
            .font(.title3)
            let others = (entry.snapshot?.devices ?? []).filter { $0.id != d.id && $0.title != nil }
            ForEach(others.prefix(2)) { o in
                HStack { Image(systemName: o.symbol); Text(o.title ?? "").lineLimit(1); Spacer(); PlayPauseButton(device: o, size: .body) }
                    .font(.caption)
            }
        }
    }
    #if os(iOS)
    private func circular(_ d: WidgetDevice) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if let pos = d.livePosition(at: entry.date), let dur = d.duration, dur > 0 {
                Gauge(value: min(pos, dur), in: 0...dur) { Image(systemName: d.playing ? "play.fill" : "pause.fill") }.gaugeStyle(.accessoryCircularCapacity)
            } else { Image(systemName: d.playing ? "play.fill" : "pause.fill").font(.title3) }
        }
    }
    private func rectangular(_ d: WidgetDevice) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(d.name, systemImage: d.symbol).font(.caption2)
            Text(d.title ?? "").font(.headline).lineLimit(1)
            Text(d.playing ? "Playing · \(timeText(d.livePosition(at: entry.date)))" : "Paused").font(.caption2)
        }
    }
    #endif
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlaying", provider: JTProvider()) { entry in
            NowPlayingView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("What plays on any of your devices, with play/pause, skip and Continue here.")
        .supportedFamilies(Families.all)
    }
}

// MARK: - Now Playing · hoes (beeldvullend)

struct NowPlayingArtWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlayingArt", provider: JTProvider()) { entry in
            ArtView(entry: entry)
                .containerBackground(for: .widget) {
                    if let img = entry.image(WidgetShared.thumbnail(for: entry.nowPlaying?.url)) { img.resizable().scaledToFill() } else { Color.black }
                }
        }
        .configurationDisplayName("Now Playing · Artwork")
        .description("Full-bleed thumbnail of what is playing, with a glass control bar.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
    struct ArtView: View {
        let entry: JTEntry
        var body: some View {
            if let d = entry.nowPlaying, d.title != nil {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d.title ?? "").font(.caption.weight(.semibold)).lineLimit(1)
                            Text(d.name).font(.caption2).opacity(0.8)
                        }
                        Spacer(minLength: 0)
                        PlayPauseButton(device: d, size: .title3)
                    }
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .widgetURL(d.url.map(WidgetShared.openURL))
            } else { EmptyState(text: "Nothing playing").foregroundStyle(.white) }
        }
    }
}

// MARK: - Now Playing · minimaal

struct NowPlayingMinimalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowPlayingMinimal", provider: JTProvider()) { entry in
            MinimalView(entry: entry).containerBackground(.fill.quaternary, for: .widget)
        }
        .configurationDisplayName("Now Playing · Minimal")
        .description("Just the title, the device and one button.")
        .supportedFamilies(Families.smallAndAccessories)
    }
    struct MinimalView: View {
        let entry: JTEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            if let d = entry.nowPlaying, d.title != nil {
                #if os(iOS)
                if family == .accessoryCircular {
                    ZStack { AccessoryWidgetBackground(); PlayPauseButton(device: d, size: .title2) }
                } else { content(d) }
                #else
                content(d)
                #endif
            } else { EmptyState(text: "Nothing playing") }
        }
        private func content(_ d: WidgetDevice) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: d.symbol).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(d.title ?? "").font(.system(.footnote, design: .rounded).weight(.semibold)).lineLimit(3)
                HStack { Text(d.playing ? "Playing" : "Paused").font(.caption2).foregroundStyle(.secondary); Spacer(); PlayPauseButton(device: d, size: .title3) }
            }
            .widgetURL(d.url.map(WidgetShared.openURL))
        }
    }
}

// MARK: - Alle apparaten

struct DevicesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Devices", provider: JTProvider()) { entry in
            DevicesView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("All Devices")
        .description("What each of your devices is playing — control any of them from here.")
        .supportedFamilies(Families.mediumUp)
    }
    struct DevicesView: View {
        let entry: JTEntry
        var body: some View {
            let devices = entry.snapshot?.devices ?? []
            if devices.isEmpty { EmptyState() } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Devices", systemImage: "laptopcomputer.and.iphone").font(.caption.weight(.semibold))
                        Spacer()
                        let peers = entry.snapshot?.connectedPeers.count ?? 0
                        Text(peers > 0 ? "\(peers) connected" : "Not connected").font(.caption2).foregroundStyle(peers > 0 ? .green : .secondary)
                    }
                    ForEach(devices.prefix(4)) { d in
                        HStack(spacing: 10) {
                            Thumb(image: entry.image(WidgetShared.thumbnail(for: d.url)), corner: 6).frame(width: 52, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(d.isThisDevice ? "\(d.name) (this)" : d.name).font(.caption2).foregroundStyle(.secondary)
                                Text(d.title ?? "Nothing playing").font(.caption.weight(.medium)).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if d.title != nil { PlayPauseButton(device: d, size: .title3) }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Zoeken

struct SearchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Search", provider: JTProvider()) { _ in
            SearchView().containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Search")
        .description("Search YouTube, Spotify, Twitch and more — straight into JoeToep's search bar.")
        .supportedFamilies(Families.searchFamilies)
    }
    struct SearchView: View {
        @Environment(\.widgetFamily) private var family
        private let platforms: [(String, String, String)] = [("youtube", "YouTube", "play.rectangle.fill"), ("spotify", "Spotify", "dot.radiowaves.left.and.right"),
                                                             ("twitch", "Twitch", "gamecontroller.fill"), ("soundcloud", "SoundCloud", "waveform"),
                                                             ("youtubeMusic", "Music", "music.note"), ("web", "Web", "globe")]
        var body: some View {
            switch family {
            #if os(iOS)
            case .accessoryCircular:
                ZStack { AccessoryWidgetBackground(); Image(systemName: "magnifyingglass").font(.title3) }
                    .widgetURL(WidgetShared.searchURL())
            #endif
            case .systemSmall:
                VStack(alignment: .leading) {
                    Image(systemName: "magnifyingglass.circle.fill").font(.largeTitle).foregroundStyle(accent)
                    Spacer()
                    Text("Search").font(.headline)
                    Text("YouTube and more").font(.caption).foregroundStyle(.secondary)
                }
                .widgetURL(WidgetShared.searchURL())
            default:
                VStack(spacing: 10) {
                    Link(destination: WidgetShared.searchURL()) {
                        HStack { Image(systemName: "magnifyingglass"); Text("Search or type a site").foregroundStyle(.secondary); Spacer() }
                            .padding(10).background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(platforms, id: \.0) { p in
                            Link(destination: WidgetShared.searchURL(platform: p.0)) {
                                VStack(spacing: 3) { Image(systemName: p.2).foregroundStyle(accent); Text(p.1).font(.caption2) }
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Bibliotheek, verder kijken, tabs

private struct LinkList: View {
    let title: String
    let symbol: String
    let links: [WidgetLink]
    var entry: JTEntry? = nil
    var thumbnails = false
    @Environment(\.widgetFamily) private var family
    private var limit: Int { family == .systemMedium ? 3 : (family == .systemLarge ? 6 : 10) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(accent)
            if links.isEmpty { Spacer(); Text("Nothing here yet").font(.caption).foregroundStyle(.secondary); Spacer() }
            ForEach(links.prefix(limit)) { link in
                Link(destination: WidgetShared.openURL(link.url)) {
                    HStack(spacing: 8) {
                        if thumbnails { Thumb(image: entry?.image(WidgetShared.thumbnail(for: link.url)), corner: 5).frame(width: 44, height: 25) }
                        Text(link.title).font(.caption).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(link.url.host?.replacingOccurrences(of: "www.", with: "") ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct LibraryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Library", provider: JTProvider()) { entry in
            LinkList(title: "Favourites", symbol: "bookmark.fill", links: entry.snapshot?.favourites ?? [])
                .widgetURL(WidgetShared.link("library"))
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Library")
        .description("Your favourites, one tap away.")
        .supportedFamilies(Families.mediumUp)
    }
}

struct HistoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "History", provider: JTProvider()) { entry in
            LinkList(title: "Recently viewed", symbol: "clock.arrow.circlepath", links: entry.snapshot?.history ?? [])
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("History")
        .description("What you opened recently on this device.")
        .supportedFamilies(Families.mediumUp)
    }
}

struct ContinueWatchingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Continue", provider: JTProvider()) { entry in
            LinkList(title: "Continue watching", symbol: "play.circle.fill", links: entry.snapshot?.continueWatching ?? [], entry: entry, thumbnails: true)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Continue Watching")
        .description("Pick up recent videos where you left off.")
        .supportedFamilies(Families.mediumUp)
    }
}

struct TabsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Tabs", provider: JTProvider()) { entry in
            TabsView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tabs on All Devices")
        .description("The open tabs on your Mac, iPhone and iPad.")
        .supportedFamilies([.systemLarge] + Families.extraLarge)
    }
    struct TabsView: View {
        let entry: JTEntry
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach((entry.snapshot?.devices ?? []).prefix(3)) { d in
                    Label("\(d.name) · \(d.tabCount) tabs", systemImage: d.symbol).font(.caption.weight(.semibold)).foregroundStyle(accent)
                    ForEach(d.tabs.prefix(4)) { t in
                        Link(destination: WidgetShared.openURL(t.url)) { Text(t.title).font(.caption).lineLimit(1) }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Spotify

struct SpotifyHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Spotify", provider: JTProvider()) { entry in
            SpotifyView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spotify")
        .description("Spotify on your Mac: song, artwork and controls.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
    struct SpotifyView: View {
        let entry: JTEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            if let s = entry.snapshot?.spotify {
                HStack(spacing: 10) {
                    if family != .systemSmall { Thumb(image: entry.image(s.artworkURL), corner: 10).frame(width: 110) }
                    VStack(alignment: .leading, spacing: 4) {
                        Label(s.deviceName, systemImage: "music.note").font(.caption2).foregroundStyle(.green)
                        Text(s.track).font(.caption.weight(.semibold)).lineLimit(2)
                        Text(s.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 0)
                        HStack(spacing: 14) {
                            Button(intent: MediaCommandIntent(action: .spotifyPrevious, deviceID: nil)) { Image(systemName: "backward.fill") }.buttonStyle(.plain)
                            Button(intent: MediaCommandIntent(action: .spotifyPlayPause, deviceID: nil)) {
                                Image(systemName: s.playing ? "pause.circle.fill" : "play.circle.fill").font(.title2).foregroundStyle(.green)
                            }.buttonStyle(.plain)
                            Button(intent: MediaCommandIntent(action: .spotifyNext, deviceID: nil)) { Image(systemName: "forward.fill") }.buttonStyle(.plain)
                        }
                    }
                }
            } else { EmptyState(text: "Play something in Spotify on your Mac") }
        }
    }
}

// MARK: - Snelkoppelingen

struct ShortcutsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Shortcuts", provider: JTProvider()) { _ in
            ShortcutsView().containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shortcuts")
        .description("Jump straight to YouTube pages and your streaming services.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
    struct ShortcutsView: View {
        @Environment(\.widgetFamily) private var family
        private let items: [(String, String, String)] = [
            ("Home", "house.fill", "https://www.youtube.com/"), ("Subscriptions", "rectangle.stack.fill", "https://www.youtube.com/feed/subscriptions"),
            ("Watch later", "clock.fill", "https://www.youtube.com/playlist?list=WL"), ("History", "clock.arrow.circlepath", "https://www.youtube.com/feed/history"),
            ("Music", "music.note", "https://music.youtube.com/"), ("Twitch", "gamecontroller.fill", "https://www.twitch.tv/"),
            ("Spotify", "dot.radiowaves.left.and.right", "https://open.spotify.com/"), ("SoundCloud", "waveform", "https://soundcloud.com/"),
        ]
        var body: some View {
            let count = family == .systemSmall ? 4 : 8
            let columns = family == .systemSmall ? 2 : 4
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(items.prefix(count), id: \.0) { item in
                    Link(destination: WidgetShared.openURL(URL(string: item.2)!)) {
                        VStack(spacing: 3) {
                            Image(systemName: item.1).font(.title3).foregroundStyle(accent)
                            if family != .systemSmall { Text(item.0).font(.caption2).lineLimit(1) }
                        }
                        .frame(maxWidth: .infinity, minHeight: family == .systemLarge ? 70 : 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
                    }
                }
            }
        }
    }
}

// MARK: - Formaten

enum Families {
    static var extraLarge: [WidgetFamily] {
        #if os(iOS)
        return [.systemExtraLarge]
        #else
        return [.systemExtraLarge]
        #endif
    }
    static var all: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        #endif
    }
    static var smallAndAccessories: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }
    static var searchFamilies: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .accessoryCircular]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }
    static var mediumUp: [WidgetFamily] { [.systemMedium, .systemLarge] + extraLarge }
}

// MARK: - Bundel

@main
struct JoeToepWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        NowPlayingArtWidget()
        NowPlayingMinimalWidget()
        DevicesWidget()
        SearchWidget()
        LibraryWidget()
        ContinueWatchingWidget()
        HistoryWidget()
        TabsWidget()
        SpotifyHomeWidget()
        ShortcutsWidget()
    }
}
