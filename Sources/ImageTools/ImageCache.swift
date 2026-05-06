//
//  ImageCache.swift
//
//
//  Created by Mario Heubach on 17.04.24.
//

import Cocoa
import Combine

public class ImageCache {
    private var cache = NSCache<NSURL, NSCache<NSNumber, NSImage>>()
    private var thumbnailGenerator = ThumbnailGenerator()

    private let sizeThresholds: [CGFloat] = [32, 64, 128, 256, 512, 1024]

    public static let shared = ImageCache()

    public init() {
        cache.countLimit = 2000
        cache.totalCostLimit = 1024 * 1024 * 2000
    }

    public func image(for url: URL, maxDimension: CGFloat) async -> NSImage? {
        let cacheKey = url as NSURL
        let roundedDimension = roundedThreshold(forSize: maxDimension)

        if let sizeCache = cache.object(forKey: cacheKey),
           let cachedImage = sizeCache.object(forKey: NSNumber(value: Float(roundedDimension)))
        {
            return cachedImage
        }

        return await withCheckedContinuation { continuation in
            thumbnailGenerator.generateThumbnail(
                for: url,
                size: CGSize(
                    width: roundedDimension,
                    height: roundedDimension
                )
            ) { [weak self] image in
                guard let self, let image else {
                    continuation.resume(returning: nil)
                    return
                }
                let sizeCache = cache.object(forKey: cacheKey) ?? NSCache<NSNumber, NSImage>()
                sizeCache.setObject(image, forKey: NSNumber(value: Float(roundedDimension)))
                cache.setObject(sizeCache, forKey: cacheKey)
                continuation.resume(returning: image)
            }
        }
    }

    public func image(for url: URL, maxDimension: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = url as NSURL
        let roundedDimension = roundedThreshold(forSize: maxDimension)

        if let sizeCache = cache.object(forKey: cacheKey),
           let cachedImage = sizeCache.object(forKey: NSNumber(value: Float(roundedDimension)))
        {
            completion(cachedImage)
        } else {
            thumbnailGenerator.generateThumbnail(
                for: url,
                size: CGSize(
                    width: roundedDimension,
                    height: roundedDimension
                )
            ) { [weak self] image in
                guard let self, let image else {
                    completion(nil)
                    return
                }
                let sizeCache = cache.object(forKey: cacheKey) ?? NSCache<NSNumber, NSImage>()
                sizeCache.setObject(image, forKey: NSNumber(value: Float(roundedDimension)))
                cache.setObject(sizeCache, forKey: cacheKey)
                completion(image)
            }
        }
    }

    public func thumbnail(for url: URL, maxDimension: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = url as NSURL
        let roundedDimension = roundedThreshold(forSize: maxDimension)

        if let sizeCache = cache.object(forKey: cacheKey),
           let cachedImage = sizeCache.object(forKey: NSNumber(value: Float(roundedDimension)))
        {
            completion(cachedImage)
        } else {
            thumbnailGenerator.generateThumbnail(
                for: url,
                size: CGSize(
                    width: roundedDimension,
                    height: roundedDimension
                )
            ) { [weak self] image in
                guard let self, let image else {
                    completion(nil)
                    return
                }
                let sizeCache = cache.object(forKey: cacheKey) ?? NSCache<NSNumber, NSImage>()
                sizeCache.setObject(image, forKey: NSNumber(value: Float(roundedDimension)))
                cache.setObject(sizeCache, forKey: cacheKey)
                completion(image)
            }
        }
    }

    /// Synchronous cache-only lookup. Returns nil on cache miss (no generation triggered).
    public func cachedImage(for url: URL, maxDimension: CGFloat) -> NSImage? {
        let cacheKey = url as NSURL
        let roundedDimension = roundedThreshold(forSize: maxDimension)
        guard let sizeCache = cache.object(forKey: cacheKey) else { return nil }
        return sizeCache.object(forKey: NSNumber(value: Float(roundedDimension)))
    }

    private func roundedThreshold(forSize size: CGFloat) -> CGFloat {
        let possibleSizes = sizeThresholds.filter { $0 >= size }
        return possibleSizes.first ?? sizeThresholds.last ?? size
    }
}

public extension ImageCache {
    func preloadThumbnails(for url: URL) {
        let cacheKey = url as NSURL

        let sizeCache = cache.object(forKey: cacheKey) ?? NSCache<NSNumber, NSImage>()

        for size in sizeThresholds {
            let sizeKey = NSNumber(value: Float(size))
            if sizeCache.object(forKey: sizeKey) == nil {
                thumbnailGenerator.generateThumbnail(
                    for: url,
                    size: CGSize(
                        width: size,
                        height: size
                    )
                ) { [weak self] image in
                    guard let self, let image else { return }
                    DispatchQueue.main.async {
                        sizeCache.setObject(image, forKey: sizeKey)
                        self.cache.setObject(sizeCache, forKey: cacheKey)
                    }
                }
            }
        }
    }
}

public extension ImageCache {
    func imagePublisher(for url: URL, maxDimension: CGFloat) -> AnyPublisher<NSImage?, Never> {
        let cacheKey = url as NSURL
        let roundedDimension = roundedThreshold(forSize: maxDimension)
        let sizeKey = NSNumber(value: Float(roundedDimension))

        if let sizeCache = cache.object(forKey: cacheKey),
           let cachedImage = sizeCache.object(forKey: sizeKey)
        {
            return Just(cachedImage).eraseToAnyPublisher()
        } else {
            return Future<NSImage?, Never> { [weak self] promise in
                self?.thumbnailGenerator.generateThumbnail(
                    for: url,
                    size: CGSize(width: roundedDimension, height: roundedDimension)
                ) { image in
                    DispatchQueue.main.async {
                        guard let self, let image else {
                            promise(.success(nil))
                            return
                        }
                        let sizeCache = self.cache.object(forKey: cacheKey) ?? NSCache<NSNumber, NSImage>()
                        sizeCache.setObject(image, forKey: sizeKey)
                        self.cache.setObject(sizeCache, forKey: cacheKey)
                        promise(.success(image))
                    }
                }
            }
            .eraseToAnyPublisher()
        }
    }
}
