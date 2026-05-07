//
//  DominantColor.swift
//  ImageTools
//

import AppKit
import CoreImage

/// One-pass dominant-colour helpers backed by Core Image's
/// `CIAreaAverage` filter — a single GPU-side reduce over the input
/// pixels, so the call cost is independent of resolution beyond the
/// initial upload. Useful for UI surfaces that want a representative
/// tint per image without paying a per-frame CPU walk: pinboard
/// thumbnails, mini-map dots, swatch palettes, …
///
/// The functions return either an `NSColor` (when callers want to
/// blend / further-process) or a `#RRGGBB` hex string (for storage,
/// which is the Codable / Core Data sweet spot).
public enum DominantColor {
    /// Compute the area-average colour of `image`. Returns `nil` if
    /// the image has no usable bitmap representation (e.g. a vector
    /// PDF without a TIFF rep).
    public static func averageColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage
        else { return nil }
        return averageColor(of: cg)
    }

    /// CGImage variant — skips the NSImage→CGImage hop when the
    /// caller already has a `CGImage` (drag-preview snapshots,
    /// pre-rendered thumbnails, etc.).
    public static func averageColor(of cgImage: CGImage) -> NSColor? {
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let extentVector = CIVector(
            x: extent.origin.x,
            y: extent.origin.y,
            z: extent.size.width,
            w: extent.size.height
        )
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: extentVector,
        ]),
            let outputImage = filter.outputImage
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return NSColor(
            srgbRed: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: 1.0
        )
    }

    /// Hex (`#RRGGBB`) of the area-average colour. Convenience
    /// wrapper for storage-shaped consumers (Core Data attribute,
    /// Codable settings, etc.).
    public static func averageHex(of image: NSImage) -> String? {
        guard let color = averageColor(of: image) else { return nil }
        return hex(from: color)
    }

    public static func averageHex(of cgImage: CGImage) -> String? {
        guard let color = averageColor(of: cgImage) else { return nil }
        return hex(from: color)
    }

    /// Parse a `#RRGGBB` hex string back into an NSColor. Tolerates
    /// a missing leading `#`. Returns `nil` for malformed input.
    public static func color(fromHex hex: String) -> NSColor? {
        var trimmed = hex
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6,
              let value = UInt32(trimmed, radix: 16)
        else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(value & 0x0000FF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    private static func hex(from color: NSColor) -> String {
        // Convert through sRGB so the returned hex matches what the
        // user would see on screen, regardless of which colour space
        // the source carried.
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = UInt8((srgb.redComponent * 255.0).rounded())
        let g = UInt8((srgb.greenComponent * 255.0).rounded())
        let b = UInt8((srgb.blueComponent * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
