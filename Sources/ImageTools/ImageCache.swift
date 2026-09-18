import Cocoa
import Combine

/// Thumbnails by URL and size bucket. Entries carry their pixel cost so the
/// memory limit actually bounds the cache.
public class ImageCache {
    private let cache = NSCache<NSString, NSImage>()
    private var thumbnailGenerator = ThumbnailGenerator()

    private let sizeThresholds: [CGFloat] = [32, 64, 128, 256, 512, 1024]

    public static let shared = ImageCache()

    public init() {
        cache.countLimit = 4000
        cache.totalCostLimit = 300 * 1024 * 1024
    }

    public func image(for url: URL, maxDimension: CGFloat) async -> NSImage? {
        await withCheckedContinuation { continuation in
            image(for: url, maxDimension: maxDimension) { image in
                continuation.resume(returning: image)
            }
        }
    }

    public func image(for url: URL, maxDimension: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let dimension = roundedThreshold(forSize: maxDimension)
        if let cached = cache.object(forKey: Self.key(url, dimension)) {
            completion(cached)
            return
        }
        thumbnailGenerator.generateThumbnail(
            for: url,
            size: CGSize(width: dimension, height: dimension)
        ) { [weak self] image in
            guard let self, let image else {
                completion(nil)
                return
            }
            store(image, for: url, dimension: dimension)
            completion(image)
        }
    }

    public func thumbnail(for url: URL, maxDimension: CGFloat, completion: @escaping (NSImage?) -> Void) {
        image(for: url, maxDimension: maxDimension, completion: completion)
    }

    /// Synchronous cache-only lookup. Returns nil on cache miss (no generation triggered).
    public func cachedImage(for url: URL, maxDimension: CGFloat) -> NSImage? {
        cache.object(forKey: Self.key(url, roundedThreshold(forSize: maxDimension)))
    }

    private func store(_ image: NSImage, for url: URL, dimension: CGFloat) {
        cache.setObject(image, forKey: Self.key(url, dimension), cost: Self.cost(of: image))
    }

    private static func key(_ url: URL, _ dimension: CGFloat) -> NSString {
        "\(url.path)|\(Int(dimension))" as NSString
    }

    /// Bytes of the largest representation; the point size would under-count Retina bitmaps.
    static func cost(of image: NSImage) -> Int {
        let pixels = image.representations.map { $0.pixelsWide * $0.pixelsHigh }.max() ?? 0
        return max(pixels, Int(image.size.width * image.size.height)) * 4
    }

    private func roundedThreshold(forSize size: CGFloat) -> CGFloat {
        let possibleSizes = sizeThresholds.filter { $0 >= size }
        return possibleSizes.first ?? sizeThresholds.last ?? size
    }
}

public extension ImageCache {
    func preloadThumbnails(for url: URL) {
        for dimension in sizeThresholds where cache.object(forKey: Self.key(url, dimension)) == nil {
            thumbnailGenerator.generateThumbnail(
                for: url,
                size: CGSize(width: dimension, height: dimension)
            ) { [weak self] image in
                guard let self, let image else { return }
                store(image, for: url, dimension: dimension)
            }
        }
    }
}
