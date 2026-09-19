import Cocoa
import QuickLookThumbnailing

public struct ThumbnailGenerator {
    public init() {}

    /// Delivers on the main queue. Everything before that — the directory
    /// check, Quick Look, and the conversion into a display-ready bitmap —
    /// stays off the caller's thread.
    public func generateThumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        DispatchQueue.global(qos: .userInitiated).async {
            // Directories: NSWorkspace picks up the custom icons Finder shows
            // for Desktop, Downloads, Pictures, … which Quick Look collapses
            // to a generic folder. `stat` on a network mount can block, so it
            // runs here, not on the caller's thread.
            if Self.isDirectory(url) {
                DispatchQueue.main.async {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = size
                    completion(icon)
                }
                return
            }

            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: size,
                scale: scale,
                representationTypes: [.thumbnail, .icon]
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                // Still on Quick Look's queue: convert here so the main thread
                // only has to hand the finished bitmap to the view.
                let image = thumbnail.map { Self.displayReadyImage(from: $0.cgImage, scale: scale) }
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    /// Redraws into 8-bit sRGB with premultiplied alpha, the format Core
    /// Animation uploads directly. Quick Look's bitmaps arrive in other
    /// colour spaces and layouts, and CA would otherwise re-render each one on
    /// the main thread every time it is attached to a layer.
    static func displayReadyImage(from source: CGImage, scale: CGFloat) -> NSImage {
        let pointSize = NSSize(width: CGFloat(source.width) / scale, height: CGFloat(source.height) / scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: source.width,
                  height: source.height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else {
            return NSImage(cgImage: source, size: pointSize)
        }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let converted = context.makeImage() else {
            return NSImage(cgImage: source, size: pointSize)
        }
        return NSImage(cgImage: converted, size: pointSize)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}
