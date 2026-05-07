# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-07

### Added

- `DominantColor` — one-pass dominant-colour helpers backed by Core
  Image's `CIAreaAverage` filter (single GPU-side reduce over the
  input pixels, so the cost is independent of resolution beyond the
  initial upload). Useful for UI surfaces that want a representative
  tint per image without paying a per-frame CPU walk: pinboard
  thumbnails, mini-map dots, swatch palettes, …
  - `averageColor(of:)` — `NSColor` overloads for `NSImage` and `CGImage`.
  - `averageHex(of:)` — `#RRGGBB` storage form for Core Data /
    Codable consumers.
  - `color(fromHex:)` — round-trip parser tolerant of a missing `#`.

## [0.1.0] - 2026-05-06 — Initial release

Extracted from [Voilà](https://github.com/smart-byte/voila) as a
standalone macOS Swift package.

### Added

- `ThumbnailGenerator` — thin wrapper around `QLThumbnailGenerator`
  that picks up the same custom folder icons Finder shows (Desktop,
  Downloads, Pictures, Music, …) via `NSWorkspace.shared.icon`,
  rather than the generic folder fallback Apple's generator returns.
- `ImageCache` — two-level `NSCache` (URL → size → `NSImage`) with
  size-threshold rounding (`32 / 64 / 128 / 256 / 512 / 1024` pt) so
  fluid zoom sliders don't trigger one generation per pixel-perfect
  request.
- API surface: `async/await`, completion-handler, and `Combine`
  publisher flavours of the same lookup, plus a synchronous
  cache-only `cachedImage(for:maxDimension:)` for hot-path renders.
- `preloadThumbnails(for:)` for warming all standard sizes when you
  know a UI will request multiple thumbnails of the same file.
