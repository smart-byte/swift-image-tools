//
//  ThumbnailGenerator.swift
//
//
//  Created by Mario Heubach on 17.04.24.
//

import Cocoa
import QuickLookThumbnailing

public struct ThumbnailGenerator {
    public init() {}

    public func generateThumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        // Directories: use NSWorkspace so we pick up the same custom icons
        // Finder shows for Desktop, Downloads, Pictures, Music, etc. — which
        // QLThumbnailGenerator collapses to a generic folder.
        if isDirectory(url) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = size
            DispatchQueue.main.async {
                completion(icon)
            }
            return
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 1

        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size,
            scale: scale,
            representationTypes: [.thumbnail, .icon]
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            DispatchQueue.main.async {
                completion(thumbnail?.nsImage)
            }
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}
