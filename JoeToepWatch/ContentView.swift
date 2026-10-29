import SwiftUI

/// Hoofdscherm: zoeken bovenaan, dan (als er iets speelt) "Now playing", dan de home-feed.
struct ContentView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var path: [Route] = []

    enum Route: Hashable { case nowPlaying, results, downloads }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                TextFieldLink(prompt: Text("Search YouTube")) {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.body.weight(.medium))
                } onSubmit: { text in
                    path.append(.results)
                    Task { await store.search(text) }
                }
                .accessibilityIdentifier("watch.search")

                NavigationLink(value: Route.downloads) {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

                if !store.nowTitle.isEmpty {
                    NavigationLink(value: Route.nowPlaying) {
                        HStack(spacing: 8) {
                            Image(systemName: store.playing ? "waveform" : "pause.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.variableColor.iterative, isActive: store.playing)
                            Text(store.nowTitle).lineLimit(1).font(.footnote)
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
            }
            .navigationTitle("JoeToep")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .nowPlaying: NowPlayingView()
                case .results: ResultsView { select($0) }
                case .downloads: DownloadsListView { item in
                    Task { await store.playDownload(item) }
                    path = [.nowPlaying]
                }
                }
            }
            .task { await store.refreshFeedIfNeeded() }
        }
        .tint(.red)
    }

    private func select(_ video: WatchVideo) {
        Task { await store.play(video) }
        path = [.nowPlaying]
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

/// Downloads op je iPhone: tik = offline afspelen op de iPhone (zonder internet).
struct DownloadsListView: View {
    @EnvironmentObject private var store: WatchStore
    let play: (WatchVideo) -> Void
    var body: some View {
        List {
            if store.downloads.isEmpty {
                Text("No downloads on your iPhone yet. Use the download button in JoeToep.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.downloads) { item in
                Button { play(item) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.channel == "Audio" ? "music.note" : "film").foregroundStyle(.red)
                        Text(item.title).font(.footnote).lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle("Downloads")
        .task { await store.refreshDownloads() }
    }
}
