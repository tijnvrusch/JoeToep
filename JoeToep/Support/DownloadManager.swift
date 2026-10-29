import Foundation
import AVFoundation
import Combine

// V18 — Downloads voor offline kijken/luisteren.
//
// Wat kan wel: gewone mediabestanden die een website openlijk aanbiedt (een <video>/<audio>
// met een http(s)-bron: Vimeo-downloads, podcasts, nieuwssites, eigen video's …).
// Opslaan als video (origineel of kleiner hergecodeerd) of alleen audio (AAC, bitrate naar keuze).
// Wat bewust niet: YouTube-streams. Die zijn beveiligd; JoeToep verwijst daar naar YouTube's eigen
// Downloaden (YouTube Premium). De lijst met downloads synchroniseert tussen je apparaten; elk
// apparaat bewaart zelf de bestanden die jij daar wilt hebben.

/// Een bron die de pagina aanbiedt (gevonden door downloadProbe-JS).
struct MediaSource: Codable, Equatable, Hashable, Identifiable, Sendable {
    var url: URL
    var kind: Kind
    var label: String            // bv. "1080p · MP4" of "Audio"
    var id: URL { url }
    enum Kind: String, Codable, Sendable { case video, audio }
}

enum DownloadFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case videoOriginal, video1080, video720, video480, audioAAC
    var id: String { rawValue }
    var title: String {
        switch self {
        case .videoOriginal: "Video · original quality"
        case .video1080: "Video · 1080p (MP4)"
        case .video720: "Video · 720p (MP4, smaller)"
        case .video480: "Video · 480p (MP4, smallest)"
        case .audioAAC: "Audio only (M4A / AAC)"
        }
    }
    var isAudio: Bool { self == .audioAAC }
    var fileExtension: String { isAudio ? "m4a" : "mp4" }
    var exportPreset: String? {
        switch self {
        case .videoOriginal: nil
        case .video1080: AVAssetExportPreset1920x1080
        case .video720: AVAssetExportPreset1280x720
        case .video480: AVAssetExportPreset640x480
        case .audioAAC: nil
        }
    }
}

/// Audio-bitrates (kbit/s) om uit te kiezen.
enum AudioBitrate: Int, Codable, CaseIterable, Identifiable, Sendable {
    case k64 = 64, k96 = 96, k128 = 128, k160 = 160, k192 = 192, k256 = 256, k320 = 320
    var id: Int { rawValue }
    var title: String { "\(rawValue) kbit/s" + (self == .k256 ? " (recommended)" : "") }
}

struct DownloadItem: Codable, Equatable, Identifiable, Sendable {
    enum State: String, Codable, Sendable { case queued, downloading, converting, done, failed }
    var id: UUID = UUID()
    var title: String
    var pageURL: URL?
    var sourceURL: URL
    var format: DownloadFormat
    var bitrate: AudioBitrate = .k256
    var created: Date = Date()
    var state: State = .queued
    var progress: Double = 0
    var fileName: String?        // alleen op het apparaat dat het bestand heeft
    var bytes: Int64 = 0
    var error: String?
    /// Apparaat waar het bestand staat (naam), voor de lijst "op andere apparaten".
    var deviceName: String?
}

/// Wat andere apparaten over hun downloads melden (geen bestanden, alleen de lijst).
struct DownloadListing: Codable, Equatable, Sendable {
    var origin: String
    var originName: String
    var items: [DownloadItem]
}

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    /// Vraagt het venster een download offline af te spelen (bijv. vanaf de Apple Watch).
    static let playOffline = Notification.Name("JoeToepPlayOffline")
    /// V22: een download is klaar (object = id) — bijv. om hem automatisch naar de Watch te sturen.
    static let didComplete = Notification.Name("JoeToepDownloadCompleted")

    @Published private(set) var items: [DownloadItem] = []
    /// Downloads op andere apparaten (per apparaat-id), via de tab-sync.
    @Published private(set) var remote: [String: DownloadListing] = [:]

    private let folder: URL
    private let indexURL: URL
    private var session: URLSession!
    private var tasks: [Int: UUID] = [:]

    override init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        folder = base.appendingPathComponent("Downloads", isDirectory: true)
        indexURL = folder.appendingPathComponent("index.json")
        super.init()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Niet in iCloud-back-up (kan groot zijn).
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var f = folder; try? f.setResourceValues(values)
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        load()
    }

    func fileURL(for item: DownloadItem) -> URL? {
        guard let name = item.fileName else { return nil }
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    // MARK: Starten

    /// Is dit een bron die we mogen/kunnen downloaden? (geen YouTube-streams, geen blob:/MSE)
    static func isDownloadable(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        let host = url.host?.lowercased() ?? ""
        let blocked = ["youtube.com", "youtu.be", "ytimg.com"]
        if blocked.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return false }
        return url.pathExtension.lowercased() != "m3u8"      // HLS-streams: niet als los bestand
    }

    @discardableResult
    func start(source: URL, title: String, page: URL?, format: DownloadFormat, bitrate: AudioBitrate = .k256) -> DownloadItem? {
        guard Self.isDownloadable(source) else { return nil }
        // Nooit vanaf een YouTube-pagina (die streams zijn beveiligd; zie YouTube's eigen Downloaden).
        if let host = page?.host?.lowercased(), ["youtube.com", "youtu.be"].contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return nil }
        var item = DownloadItem(title: title.isEmpty ? source.lastPathComponent : title, pageURL: page, sourceURL: source,
                                format: format, bitrate: bitrate)
        item.state = .downloading
        item.deviceName = TabSyncService.shared.deviceName
        items.insert(item, at: 0)
        var request = URLRequest(url: source)
        if let page { request.setValue(page.absoluteString, forHTTPHeaderField: "Referer") }
        let task = session.downloadTask(with: request)
        tasks[task.taskIdentifier] = item.id
        task.resume()
        save()
        return item
    }

    /// Een download van een ander apparaat hier ook binnenhalen (zelfde bron en instellingen).
    func downloadHere(_ other: DownloadItem) {
        start(source: other.sourceURL, title: other.title, page: other.pageURL, format: other.format, bitrate: other.bitrate)
    }

    func retry(_ item: DownloadItem) {
        delete(item)
        start(source: item.sourceURL, title: item.title, page: item.pageURL, format: item.format, bitrate: item.bitrate)
    }

    func delete(_ item: DownloadItem) {
        if let url = fileURL(for: item) { try? FileManager.default.removeItem(at: url) }
        for (task, id) in tasks where id == item.id {
            session.getAllTasks { all in all.first { $0.taskIdentifier == task }?.cancel() }
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: Opslag + sync

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        // Onderbroken downloads (app gestopt) → mislukt, met "opnieuw"-knop.
        items = saved.map { item in
            var item = item
            if item.state != .done && item.state != .failed { item.state = .failed; item.error = "Interrupted" }
            if item.state == .done && fileURL(for: item) == nil { item.state = .failed; item.error = "File missing" }
            return item
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: indexURL, options: .atomic) }
        TabSyncService.shared.publishDownloads(items.filter { $0.state == .done })
    }

    func receive(_ listing: DownloadListing) {
        remote[listing.origin] = listing.items.isEmpty ? nil : listing
    }

    fileprivate func update(_ id: UUID, _ change: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    // MARK: Afronden (verplaatsen of omzetten)

    fileprivate func finished(id: UUID, temporary: URL, response: URLResponse?) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let ext = (response?.suggestedFilename as NSString?)?.pathExtension.lowercased()
        let raw = folder.appendingPathComponent(id.uuidString + "-source." + ((ext?.isEmpty == false ? ext : nil) ?? "mp4"))
        try? FileManager.default.removeItem(at: raw)
        do { try FileManager.default.moveItem(at: temporary, to: raw) } catch {
            fail(id, "Could not save the file"); return
        }
        let target = folder.appendingPathComponent(id.uuidString + "." + item.format.fileExtension)
        if item.format == .videoOriginal {
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.moveItem(at: raw, to: target)
            complete(id, file: target)
            return
        }
        update(id) { $0.state = .converting; $0.progress = 0 }
        Task { @MainActor in
            do {
                if item.format.isAudio {
                    try await MediaConverter.audio(from: raw, to: target, bitrate: item.bitrate.rawValue) { p in
                        Task { @MainActor in self.update(id) { $0.progress = p } }
                    }
                } else if let preset = item.format.exportPreset {
                    try await MediaConverter.video(from: raw, to: target, preset: preset)
                }
                try? FileManager.default.removeItem(at: raw)
                complete(id, file: target)
            } catch {
                try? FileManager.default.removeItem(at: raw)
                fail(id, "Conversion failed: \(error.localizedDescription)")
            }
        }
    }

    private func complete(_ id: UUID, file: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.int64Value ?? 0
        update(id) { $0.state = .done; $0.progress = 1; $0.fileName = file.lastPathComponent; $0.bytes = size; $0.error = nil }
        save()
        NotificationCenter.default.post(name: Self.didComplete, object: id)
    }

    fileprivate func fail(_ id: UUID, _ message: String) {
        update(id) { $0.state = .failed; $0.error = message }
        save()
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let id = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        MainActor.assumeIsolated {
            guard let item = self.tasks[id] else { return }
            self.update(item) { $0.progress = progress; $0.bytes = totalBytesWritten }
        }
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Het tijdelijke bestand verdwijnt na deze functie: meteen (synchroon) verplaatsen.
        let keep = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.moveItem(at: location, to: keep)
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        let id = downloadTask.taskIdentifier, response = downloadTask.response
        MainActor.assumeIsolated {
            guard let item = self.tasks.removeValue(forKey: id) else { return }
            guard (200..<300).contains(status) else { self.fail(item, "Server said \(status)"); return }
            self.finished(id: item, temporary: keep, response: response)
        }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = task.taskIdentifier
        MainActor.assumeIsolated {
            guard let item = self.tasks.removeValue(forKey: id) else { return }
            self.fail(item, (error as NSError).code == NSURLErrorCancelled ? "Cancelled" : error.localizedDescription)
        }
    }
}

/// Omzetten met AVFoundation (op het apparaat zelf, geen internet nodig).
enum MediaConverter {
    enum Failure: LocalizedError {
        case noAudio, exportFailed(String)
        var errorDescription: String? {
            switch self {
            case .noAudio: "This file has no audio track"
            case .exportFailed(let reason): reason
            }
        }
    }

    static func video(from source: URL, to target: URL, preset: String) async throws {
        try? FileManager.default.removeItem(at: target)
        let asset = AVURLAsset(url: source)
        guard let export = AVAssetExportSession(asset: asset, presetName: preset) else { throw Failure.exportFailed("Preset unavailable") }
        export.outputURL = target
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        await export.export()
        if export.status != .completed { throw Failure.exportFailed(export.error?.localizedDescription ?? "Export failed") }
    }

    /// Alleen de audio, als AAC in .m4a, met de gekozen bitrate.
    static func audio(from source: URL, to target: URL, bitrate: Int, progress: @escaping @Sendable (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: target)
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw Failure.noAudio }
        let duration = try await asset.load(.duration).seconds
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        reader.add(output)
        let writer = try AVAssetWriter(outputURL: target, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: bitrate * 1000])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        guard reader.startReading(), writer.startWriting() else {
            throw Failure.exportFailed(reader.error?.localizedDescription ?? writer.error?.localizedDescription ?? "Could not start")
        }
        writer.startSession(atSourceTime: .zero)
        let queue = DispatchQueue(label: "joetoep.audio-export")
        let box = ConverterBox(reader: reader, writer: writer, input: input, output: output)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: queue) {
                while box.input.isReadyForMoreMediaData {
                    if let buffer = box.output.copyNextSampleBuffer() {
                        if duration > 0 { progress(min(1, CMSampleBufferGetPresentationTimeStamp(buffer).seconds / duration)) }
                        box.input.append(buffer)
                    } else {
                        box.input.markAsFinished()
                        box.writer.finishWriting {
                            if box.writer.status == .completed { continuation.resume() }
                            else { continuation.resume(throwing: Failure.exportFailed(box.writer.error?.localizedDescription ?? "Write failed")) }
                        }
                        return
                    }
                }
            }
        }
    }
}

private final class ConverterBox: @unchecked Sendable {
    let reader: AVAssetReader, writer: AVAssetWriter, input: AVAssetWriterInput, output: AVAssetReaderTrackOutput
    init(reader: AVAssetReader, writer: AVAssetWriter, input: AVAssetWriterInput, output: AVAssetReaderTrackOutput) {
        self.reader = reader; self.writer = writer; self.input = input; self.output = output
    }
}
