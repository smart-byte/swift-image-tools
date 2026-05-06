<div align="center">

# ImageTools

[![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-lightgrey)](https://github.com/smart-byte/swift-image-tools/releases)

</div>

A small, focused Swift package for **macOS file-browser-style thumbnail
generation and caching**. Wraps Apple's `QLThumbnailGenerator` with a
multi-size in-memory `NSCache` so repeated lookups for the same file at
the same target size are O(1) — and so a single file holds at most one
thumbnail per size bucket instead of one per pixel-perfect request.

## What it does

- **`ThumbnailGenerator`** — thin wrapper around `QLThumbnailGenerator`
  that picks up the same custom folder icons Finder shows (Desktop,
  Downloads, Pictures, Music, …) via `NSWorkspace.shared.icon`. Apple's
  generator collapses those to a generic folder icon by default.
- **`ImageCache`** — two-level `NSCache` (URL → size → `NSImage`) with
  size-threshold rounding (`32 / 64 / 128 / 256 / 512 / 1024` pt). A
  request for `200pt` resolves to the same cache slot as a request for
  `220pt` (both round up to `256pt`), so a fluid zoom slider doesn't
  trigger a fresh generation per pixel.
- API choice: `async/await`, completion-handler, and `Combine`
  publisher flavours of the same lookup, plus a synchronous
  cache-only `cachedImage(for:maxDimension:)` for hot-path renders
  where you don't want to trigger generation.

## What it doesn't do

- No remote-image loading. For URL-based image fetching consider
  [Kingfisher](https://github.com/onevcat/Kingfisher) or
  [Nuke](https://github.com/kean/Nuke).
- No persistent / disk-backed cache. The whole cache lives in
  `NSCache` and is bounded by item count and total cost — it
  dies with the process.
- No image processing / filtering. `QLThumbnailGenerator` returns
  what macOS itself produces; if you need transformations, layer
  them on top.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/smart-byte/swift-image-tools.git",
        from: "0.1.0"
    )
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the
repository URL.

## Usage

```swift
import ImageTools

let url = URL(fileURLWithPath: "/Users/me/Pictures/holiday.jpg")

// async/await
let thumbnail = await ImageCache.shared.image(for: url, maxDimension: 256)

// completion-handler
ImageCache.shared.image(for: url, maxDimension: 256) { image in
    // ...
}

// Combine
ImageCache.shared
    .imagePublisher(for: url, maxDimension: 256)
    .sink { image in /* ... */ }
    .store(in: &cancellables)

// Synchronous cache-only — returns nil on miss, no generation triggered
if let cached = ImageCache.shared.cachedImage(for: url, maxDimension: 256) {
    // hot-path render
}
```

### Multi-size pre-loading

When you know which sizes a UI will request (e.g. a zoom slider with
discrete steps), `preloadThumbnails` warms all of them up:

```swift
ImageCache.shared.preloadThumbnails(for: url)
// kicks off background generation for 32 / 64 / 128 / 256 / 512 / 1024
```

## License

Released under the [MIT License](LICENSE).

© 2026 Smart-Byte GmbH / Mario Heubach.

Originally built for [Voilà](https://github.com/smart-byte/voila), a
macOS file-browser, then extracted as a standalone library.
