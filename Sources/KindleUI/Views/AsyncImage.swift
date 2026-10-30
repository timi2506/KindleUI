import Foundation

internal final class AsyncImageCache: @unchecked Sendable {
    static let shared = AsyncImageCache()
    private let lock = NSLock()
    private var cacheDirectory: String {
        let dir = "\(KindleStateRegistry.appDataDirectory)/images"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
    private var localPaths: [String: String] = [:]
    private var inFlight: Set<String> = []
    private var failed: Set<String> = []

    private init() {
        let fm = FileManager.default

        // Clean up legacy /tmp/kindleui_img_* files that could fill the 64 MB /var tmpfs on Kindle.
        DispatchQueue.global(qos: .utility).async {
            if let entries = try? fm.contentsOfDirectory(atPath: "/tmp") {
                for entry in entries where entry.hasPrefix("kindleui_img_") {
                    try? fm.removeItem(atPath: "/tmp/\(entry)")
                }
            }
        }
    }

    private func cachePath(for url: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for b in url.utf8 {
            hash ^= UInt64(b)
            hash &*= 0x100000001b3
        }
        let hex = String(hash, radix: 16)
        let padded = String(repeating: "0", count: max(0, 16 - hex.count)) + hex
        return "\(cacheDirectory)/img_\(padded)"
    }

    func status(for url: String) -> (path: String?, isFailed: Bool) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, true) }

        lock.lock()
        defer { lock.unlock() }
        if let path = localPaths[trimmed], FileManager.default.fileExists(atPath: path) {
            return (path, false)
        }
        let deterministicDest = cachePath(for: trimmed)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: deterministicDest),
           let size = attrs[.size] as? UInt64, size > 0 {
            localPaths[trimmed] = deterministicDest
            return (deterministicDest, false)
        }
        if failed.contains(trimmed) {
            return (nil, true)
        }
        if !inFlight.contains(trimmed) {
            inFlight.insert(trimmed)
            KindleHTTP.getData(from: trimmed, timeoutSeconds: 15) { [weak self] result in
                guard let self = self else { return }
                let dest = self.cachePath(for: trimmed)
                var wrotePath: String? = nil
                if case .success(let data) = result, !data.isEmpty {
                    try? FileManager.default.createDirectory(atPath: self.cacheDirectory, withIntermediateDirectories: true)
                    if (try? data.write(to: URL(fileURLWithPath: dest), options: .atomic)) != nil,
                       FileManager.default.fileExists(atPath: dest) {
                        wrotePath = dest
                    }
                }
                self.lock.lock()
                self.inFlight.remove(trimmed)
                if let wrotePath = wrotePath {
                    self.localPaths[trimmed] = wrotePath
                    self.failed.remove(trimmed)
                } else {
                    self.failed.insert(trimmed)
                }
                self.lock.unlock()
                KindleStateRegistry.shared.notifyStateMutation()
            }
        }
        return (nil, false)
    }
}

/// A view that asynchronously loads and displays an image from a remote URL using `KindleHTTP` (`URLSession`).
public struct AsyncImage: View, _PrimitiveView {
    public typealias Body = Never
    public let url: String
    public let altText: String
    public let width: Int?
    public let height: Int?

    public init(url: String, altText: String = "Image", width: Int? = nil, height: Int? = nil) {
        self.url = url
        self.altText = altText
        self.width = width
        self.height = height
    }

    /// Pre-downloads `url` into the persistent on-disk image cache if not already present.
    public static func prefetch(url: String) {
        _ = AsyncImageCache.shared.status(for: url)
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let state = AsyncImageCache.shared.status(for: url)
        if let path = state.path {
            return Image(path, altText: altText)
                .frame(width: width, height: height)
                .buildRenderTree()
        } else if state.isFailed {
            return HStack(alignment: .center, spacing: 14) {
                Icon(.warning, size: 34)
                Text("\(altText) unavailable")
                    .font(.caption)
                    .foregroundColor(theme.mutedForeground)
            }
            .padding(14)
            .background(theme.panelBackground, cornerRadius: 14)
            .border(theme.subtleBorder, width: 1, cornerRadius: 14)
            .frame(width: width, height: height)
            .buildRenderTree()
        } else {
            return HStack(alignment: .center, spacing: 14) {
                Icon(.refresh, size: 34)
                Text("Loading \(altText)...")
                    .font(.caption)
                    .foregroundColor(theme.mutedForeground)
            }
            .padding(14)
            .background(theme.panelBackground, cornerRadius: 14)
            .border(theme.subtleBorder, width: 1, cornerRadius: 14)
            .frame(width: width, height: height)
            .buildRenderTree()
        }
    }
}
