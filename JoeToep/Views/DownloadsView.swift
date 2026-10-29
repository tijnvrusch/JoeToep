// V18 — Downloads: het "opslaan voor offline"-paneel en het overzicht van alle downloads.
import SwiftUI
import AVKit

/// Paneel dat opent via de downloadknop: kies bron, formaat en (bij audio) bitrate.
struct DownloadSheet: View {
    @ObservedObject var session: WebSession
    @ObservedObject private var manager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sources: [MediaSource] = []
    @State private var searching = true
    @State private var selected: MediaSource?
    @State private var format: DownloadFormat = .videoOriginal
    @State private var bitrate: AudioBitrate = .k256
    @State private var showingLibrary = false

    private var onYouTube: Bool { session.isOnYouTube }

    var body: some View {
        NavigationStack {
            Form {
                if onYouTube {
                    Section {
                        Label("YouTube videos are protected", systemImage: "lock.fill").font(.headline)
                        Text("JoeToep doesn't bypass YouTube's protection. With YouTube Premium you can save videos for offline viewing through YouTube's own Download button.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Open YouTube Downloads") {
                            session.load(URL(string: "https://www.youtube.com/feed/downloads")!); dismiss()
                        }
                    }
                } else if searching {
                    Section { HStack { ProgressView(); Text("Looking for media on this page…").foregroundStyle(.secondary) } }
                } else if sources.isEmpty {
                    Section {
                        Label("No downloadable file found", systemImage: "questionmark.folder").font(.headline)
                        Text("This page streams its video in a protected or segmented way, or has no media. Start the video first and try again, or look for a download link on the page.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    Section("File") {
                        Picker("Source", selection: $selected) {
                            ForEach(sources) { Text("\($0.label)").tag(Optional($0)) }
                        }
                        detail("The page offers these files. Higher resolutions are larger.")
                    }
                    Section("Format") {
                        Picker("Save as", selection: $format) {
                            ForEach(DownloadFormat.allCases) { Text($0.title).tag($0) }
                        }
                        if format.isAudio {
                            Picker("Audio bitrate", selection: $bitrate) {
                                ForEach(AudioBitrate.allCases) { Text($0.title).tag($0) }
                            }
                            detail("Higher bitrate = better sound and bigger file. 256 kbit/s sounds like the original for almost everyone.")
                        } else {
                            detail(format == .videoOriginal ? "Saves the file exactly as the site offers it (fastest)." :
                                    "Re-encodes on this device to a smaller MP4. Takes a moment; works offline.")
                        }
                    }
                    Section {
                        Button {
                            guard let source = selected else { return }
                            manager.start(source: source.url, title: session.pageTitle ?? source.label, page: session.currentURL,
                                          format: format, bitrate: bitrate)
                            showingLibrary = true
                        } label: {
                            Label("Download", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected == nil)
                        .accessibilityIdentifier("download.start")
                    }
                }
                Section {
                    Button { showingLibrary = true } label: { Label("All downloads", systemImage: "tray.full") }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Download")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .navigationDestination(isPresented: $showingLibrary) { DownloadsView() }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 440)
        #endif
        .onAppear {
            guard !onYouTube else { searching = false; return }
            session.findDownloadableMedia { found in
                sources = found; selected = found.first; searching = false
                if found.first?.kind == .audio { format = .audioAAC }
            }
        }
    }
}

/// Overzicht van alle downloads: hier (afspelen, delen, verwijderen) en op je andere apparaten.
struct DownloadsView: View {
    @ObservedObject private var manager = DownloadManager.shared
    @State private var playing: DownloadItem?

    var body: some View {
        List {
            if manager.items.isEmpty && manager.remote.isEmpty {
                ContentUnavailableView("No downloads yet", systemImage: "arrow.down.circle",
                                       description: Text("Tap the download button while a video plays on a site that offers the file. Downloads work without internet."))
            }
            if !manager.items.isEmpty {
                Section {
                    ForEach(manager.items) { item in row(item) }
                } header: {
                    Text("On this device")
                } footer: {
                    Text(ByteCountFormatter.string(fromByteCount: manager.totalBytes, countStyle: .file) + " used")
                }
            }
            ForEach(manager.remote.values.sorted { $0.originName < $1.originName }, id: \.origin) { listing in
                Section("On \(listing.originName)") {
                    ForEach(listing.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).lineLimit(2)
                                Text(item.format.title).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            let here = manager.items.contains { $0.sourceURL == item.sourceURL && $0.format == item.format }
                            Button(here ? "Here" : "Get") { manager.downloadHere(item) }
                                .buttonStyle(.bordered).disabled(here)
                        }
                    }
                }
            }
        }
        .navigationTitle("Downloads")
        .sheet(item: $playing) { item in OfflinePlayer(item: item) }
    }

    @ViewBuilder private func row(_ item: DownloadItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.format.isAudio ? "music.note" : "film")
                .frame(width: 28).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).lineLimit(2)
                switch item.state {
                case .downloading, .queued:
                    ProgressView(value: item.progress).progressViewStyle(.linear)
                    Text("Downloading · \(Int(item.progress * 100))%").font(.caption).foregroundStyle(.secondary)
                case .converting:
                    ProgressView(value: item.progress).progressViewStyle(.linear)
                    Text("Converting · \(Int(item.progress * 100))%").font(.caption).foregroundStyle(.secondary)
                case .done:
                    Text("\(item.format.title) · \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                case .failed:
                    Text(item.error ?? "Failed").font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if item.state == .done {
                Button { playing = item } label: { Image(systemName: "play.circle.fill").font(.title2) }
                    .buttonStyle(.plain).accessibilityLabel("Play offline")
                if let url = manager.fileURL(for: item) {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain)
                }
            } else if item.state == .failed {
                Button { manager.retry(item) } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
        }
        .contextMenu { Button("Delete", role: .destructive) { manager.delete(item) } }
        .swipeActions { Button("Delete", role: .destructive) { manager.delete(item) } }
    }
}

/// Speelt een download af zonder internet (Apple's eigen speler: PiP en AirPlay werken ook).
struct OfflinePlayer: View {
    let item: DownloadItem
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let player { VideoPlayer(player: player) } else { ContentUnavailableView("File missing", systemImage: "exclamationmark.triangle") }
            }
            .navigationTitle(item.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { player?.pause(); dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 400)
        #endif
        .onAppear {
            if let url = DownloadManager.shared.fileURL(for: item) { player = AVPlayer(url: url); player?.play() }
        }
        .onDisappear { player?.pause() }
    }
}
