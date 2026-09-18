//
//  ImageCacheTests.swift
//  ImageToolsTests
//

import AppKit
@testable import ImageTools
import Testing

@MainActor
struct ImageCacheTests {
    // MARK: - Helpers

    /// Writes a tiny red PNG to a temporary file. Caller is responsible for cleanup.
    private func writeTestPNG(size: CGSize = CGSize(width: 32, height: 32)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voila-imagecache-test-\(UUID()).png")

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "ImageCacheTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        try pngData.write(to: url)
        return url
    }

    // MARK: - Synchronous cache-only lookup

    @Test func freshCacheReturnsNilForUnknownURL() {
        let cache = ImageCache()
        let url = URL(fileURLWithPath: "/tmp/voila-does-not-exist-\(UUID()).png")

        #expect(cache.cachedImage(for: url, maxDimension: 128) == nil)
    }

    // MARK: - Generation + caching end-to-end

    @Test func imageIsCachedAfterLoad() async throws {
        let url = try writeTestPNG()
        defer { try? FileManager.default.removeItem(at: url) }

        let cache = ImageCache()
        let loaded = await cache.image(for: url, maxDimension: 128)
        try #require(loaded != nil)

        // Second call should come from cache and return the same instance.
        let cached = cache.cachedImage(for: url, maxDimension: 128)
        #expect(cached === loaded)
    }

    // MARK: - Size-threshold rounding

    @Test func dimensionsInSameBucketShareCacheSlot() async throws {
        let url = try writeTestPNG()
        defer { try? FileManager.default.removeItem(at: url) }

        let cache = ImageCache()
        // Thresholds are [32, 64, 128, 256, 512, 1024]; 100 and 127 both round up to 128.
        _ = await cache.image(for: url, maxDimension: 100)

        #expect(cache.cachedImage(for: url, maxDimension: 127) != nil)
        #expect(cache.cachedImage(for: url, maxDimension: 128) != nil)
    }

    @Test func dimensionsInDifferentBucketsAreIsolated() async throws {
        let url = try writeTestPNG()
        defer { try? FileManager.default.removeItem(at: url) }

        let cache = ImageCache()
        // 100 → 128 bucket.
        _ = await cache.image(for: url, maxDimension: 100)

        // 64 is its own bucket — should not be populated.
        #expect(cache.cachedImage(for: url, maxDimension: 64) == nil)
    }

    // MARK: - Display-ready bitmaps

    /// Core Animation uploads 8-bit sRGB premultiplied bitmaps as they are;
    /// anything else is re-rendered on the main thread at every attach.
    @Test func generatedThumbnailIsAnSRGBPremultipliedBitmap() async throws {
        let url = try writeTestPNG()
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try #require(await ImageCache().image(for: url, maxDimension: 64))
        var rect = CGRect(origin: .zero, size: image.size)
        let cgImage = try #require(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))

        #expect(cgImage.bitsPerComponent == 8)
        #expect(cgImage.colorSpace?.name == CGColorSpace.sRGB)
        #expect(cgImage.alphaInfo == .premultipliedFirst)
        #expect(ImageCache.cost(of: image) == cgImage.width * cgImage.height * 4)
    }
}
