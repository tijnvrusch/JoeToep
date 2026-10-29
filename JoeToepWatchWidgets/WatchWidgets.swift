// V22 — Complicaties en Smart Stack-widgets voor de Apple Watch.
// De Watch-app bewaart de live toestand (van de iPhone) in de App Group; deze widgets tonen die:
// wat er speelt en waar (met voortgang), Spotify, je apparaten, en snelle knoppen naar de app.
// Tik = de juiste pagina in de Watch-app (bediening, apparaten, Spotify, zoeken, downloads).
import WidgetKit
import SwiftUI

struct WEntry: TimelineEntry {
    let date: Date
    let state: WatchState?
    var now: WatchDeviceState? { state?.nowPlaying }
}

struct WProvider: TimelineProvider {
    func placeholder(in context: Context) -> WEntry { WEntry(date: Date(), state: .preview) }
    func getSnapshot(in context: Context, completion: @escaping (WEntry) -> Void) {
        completion(WEntry(date: Date(), state: WatchState.loadFromGroup() ?? (context.isPreview ? .preview : nil)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WEntry>) -> Void) {
        let state = WatchState.loadFromGroup()
        let now = Date()
        // Elke minuut een regel (voortgang loopt door), 30 min vooruit; de app herlaadt bij elke wijziging.
        let entries = (0..<30).map { WEntry(date: now.addingTimeInterval(Double($0) * 60), state: state) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

extension WatchState {
    static var preview: WatchState {
        var s = WatchState()
        s.devices = [WatchDeviceState(id: "mac", name: "MacBook", kind: "mac", isPhone: false, connected: true,
                                      title: "Lofi beats to relax to", playing: true, time: 754, duration: 3600)]
        s.spotify = WatchSpotifyState(device: "MacBook", playing: true, track: "Midnight City", artist: "M83", position: 60, duration: 240,
                                      volume: 50, shuffling: false, repeating: false, updated: Date())
        return s
    }
}

private let red = Color(red: 1, green: 0.17, blue: 0.2)

// MARK: Nu aan het spelen

struct NowPlayingComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchNowPlaying", provider: WProvider()) { entry in
            NowView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("What plays on your Mac, iPhone or iPad — tap to control it.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
    struct NowView: View {
        let entry: WEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            let d = entry.now
            let pos = d?.livePosition(at: entry.date) ?? 0
            let dur = d?.duration ?? 0
            let fraction = dur > 0 ? min(1, pos / dur) : 0
            Group {
                switch family {
                case .accessoryCircular:
                    Gauge(value: fraction) { Image(systemName: d?.symbol ?? "play.rectangle") } currentValueLabel: {
                        Image(systemName: d?.playing == true ? "play.fill" : "pause.fill")
                    }
                    .gaugeStyle(.accessoryCircularCapacity).tint(red)
                case .accessoryCorner:
                    Image(systemName: d?.playing == true ? "play.fill" : "play.rectangle").font(.title3)
                        .widgetLabel { Gauge(value: fraction) { Text(d?.name ?? "JoeToep") }.tint(red) }
                case .accessoryInline:
                    Label(d?.title ?? "Nothing playing", systemImage: d?.symbol ?? "play.rectangle")
                default:
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: d?.playing == true ? "play.fill" : "pause.fill").font(.system(size: 9)).foregroundStyle(red)
                            Text(d?.name ?? "JoeToep").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(d?.title ?? "Nothing playing").font(.headline).lineLimit(2)
                        if dur > 0 {
                            Gauge(value: fraction) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(red)
                        } else if d?.time != nil {
                            Text(watchClock(pos)).font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .widgetURL(WatchLink.url("nowplaying", device: d?.id))
        }
    }
}

// MARK: Spotify

struct SpotifyComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchSpotify", provider: WProvider()) { entry in
            SpotView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spotify")
        .description("The song playing in Spotify on your Mac — tap for controls.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
    struct SpotView: View {
        let entry: WEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            let s = entry.state?.spotify
            let fraction = (s?.duration ?? 0) > 0 ? min(1, (s?.livePosition(at: entry.date) ?? 0) / (s?.duration ?? 1)) : 0
            Group {
                switch family {
                case .accessoryCircular:
                    Gauge(value: fraction) { Image(systemName: "music.note") } currentValueLabel: {
                        Image(systemName: s?.playing == true ? "pause.fill" : "play.fill")
                    }
                    .gaugeStyle(.accessoryCircularCapacity).tint(.green)
                case .accessoryCorner:
                    Image(systemName: "music.note").font(.title3)
                        .widgetLabel { Text(s?.track ?? "Spotify") }
                case .accessoryInline:
                    Label(s.map { "\($0.track) · \($0.artist)" } ?? "Spotify", systemImage: "music.note")
                default:
                    VStack(alignment: .leading, spacing: 1) {
                        Label(s?.device ?? "Spotify", systemImage: "music.note").font(.caption2).foregroundStyle(.green)
                        Text(s?.track ?? "Nothing playing").font(.headline).lineLimit(1)
                        Text(s?.artist ?? "").font(.caption2).lineLimit(1)
                        if (s?.duration ?? 0) > 0 { Gauge(value: fraction) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(.green) }
                    }
                }
            }
            .widgetURL(WatchLink.url("spotify"))
        }
    }
}

// MARK: Apparaten

struct DevicesComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchDevices", provider: WProvider()) { entry in
            DevView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Devices")
        .description("Which of your devices is playing.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
    struct DevView: View {
        let entry: WEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            let devices = entry.state?.devices ?? []
            Group {
                if family == .accessoryCircular {
                    ZStack {
                        AccessoryWidgetBackground()
                        VStack(spacing: 0) {
                            Image(systemName: devices.first { $0.playing }?.symbol ?? "laptopcomputer.and.iphone").font(.body)
                            Text("\(devices.filter(\.connected).count)").font(.caption2)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        if devices.isEmpty { Text("Open JoeToep on iPhone").font(.caption2) }
                        ForEach(devices.prefix(3)) { d in
                            HStack(spacing: 4) {
                                Image(systemName: d.playing ? "play.fill" : "pause.fill").font(.system(size: 8)).foregroundStyle(d.playing ? red : .secondary)
                                Image(systemName: d.symbol).font(.caption2)
                                Text(d.title ?? d.name).font(.caption2).lineLimit(1)
                            }
                        }
                    }
                }
            }
            .widgetURL(WatchLink.url("devices"))
        }
    }
}

// MARK: Snelle knoppen

struct LauncherComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchLauncher", provider: WProvider()) { entry in
            LaunchView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("JoeToep")
        .description("Open JoeToep: search, controls or your downloads on the Watch.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
    struct LaunchView: View {
        let entry: WEntry
        @Environment(\.widgetFamily) private var family
        var body: some View {
            Group {
                switch family {
                case .accessoryInline: Label("JoeToep", systemImage: "play.rectangle.fill")
                case .accessoryCorner:
                    Image(systemName: "play.rectangle.fill").font(.title3).foregroundStyle(red).widgetLabel("JoeToep")
                default:
                    ZStack { AccessoryWidgetBackground(); Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(red) }
                }
            }
            .widgetURL(WatchLink.url("search"))
        }
    }
}

@main
struct JoeToepWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingComplication()
        SpotifyComplication()
        DevicesComplication()
        LauncherComplication()
    }
}
