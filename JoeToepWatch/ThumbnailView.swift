import SwiftUI
import ImageIO

/// Klein, gecachet plaatje (120×90 van YouTube, ±4 kB). Eigen cache: AsyncImage zou bij elk
/// scrollen opnieuw downloaden — dat hapert op de Watch.
struct ThumbnailView: View {
    let url: URL
    @State private var image: CGImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08))
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .transition(.opacity)
            }
        }
        .frame(width: 52, height: 30)
        .clipped()
        .task(id: url) { image = await ThumbnailCache.shared.image(for: url) }
    }
}

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [URL: CGImage] = [:]
    private var order: [URL] = []

    func image(for url: URL) async -> CGImage? {
        if let hit = cache[url] { return hit }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Direct verkleind decoderen: minder geheugen, soepeler scrollen.
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 104,
                                        kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        cache[url] = image; order.append(url)
        if order.count > 80 { cache[order.removeFirst()] = nil }
        return image
    }
}
