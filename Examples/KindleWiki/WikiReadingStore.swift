import Foundation
import KindleUI

/// A Wikipedia article saved for offline reading (everything the reader needs except the image files themselves).
/// `sectionImages` / `tables` are `nil` while they haven't been loaded yet, mirroring `WikiArticleCache.Entry`.
public struct WikiOfflineArticle: Codable, Sendable, Equatable {
    public struct Figure: Codable, Sendable, Equatable {
        public var url: String
        public var caption: String

        public init(url: String, caption: String) {
            self.url = url
            self.caption = caption
        }
    }

    public var title: String
    public var description: String
    public var rawExtract: String
    public var leadImageURL: String?
    public var links: [String]
    public var isDisambiguation: Bool
    public var sectionImages: [Int: [Figure]]?
    public var tables: [Int: [WikiTableData]]?

    public init(
        title: String,
        description: String,
        rawExtract: String,
        leadImageURL: String?,
        links: [String],
        isDisambiguation: Bool,
        sectionImages: [Int: [Figure]]? = nil,
        tables: [Int: [WikiTableData]]? = nil
    ) {
        self.title = title
        self.description = description
        self.rawExtract = rawExtract
        self.leadImageURL = leadImageURL
        self.links = links
        self.isDisambiguation = isDisambiguation
        self.sectionImages = sectionImages
        self.tables = tables
    }

    init(_ entry: WikiArticleCache.Entry) {
        self.init(
            title: entry.title,
            description: entry.description,
            rawExtract: entry.rawExtract,
            leadImageURL: entry.leadImageURL,
            links: entry.links,
            isDisambiguation: entry.isDisambiguation,
            sectionImages: entry.sectionImages?.mapValues { $0.map { Figure(url: $0.url, caption: $0.caption) } },
            tables: entry.tables
        )
    }

    func makeCacheEntry() -> WikiArticleCache.Entry {
        WikiArticleCache.Entry(
            title: title,
            description: description,
            rawExtract: rawExtract,
            leadImageURL: leadImageURL,
            links: links,
            isDisambiguation: isDisambiguation,
            sectionImages: sectionImages?.mapValues { $0.map { (url: $0.url, caption: $0.caption) } },
            tables: tables
        )
    }
}

/// Persistent reading state of KindleWiki that must not go through `@AppStorage`: every `@AppStorage` write
/// rewrites the whole shared storage file and triggers a UI update, which is far too heavy for something that
/// changes on every page turn.
///
/// - **Reading progress**: how far (0...1) the reader got in each article, so it can be resumed.
/// - **Offline articles**: one JSON file per saved article, so bookmarks open without a network connection.
///
/// Thread-safe; file I/O is small and synchronous, so call `loadOffline`/`saveOffline` off the main thread.
public final class WikiReadingStore: @unchecked Sendable {
    public static let shared: WikiReadingStore = {
        WikiReadingStore(directory: URL(fileURLWithPath: KindleStateRegistry.appDataDirectory, isDirectory: true))
    }()

    private let directory: URL
    private let lock = NSLock()
    private var progressByKey: [String: Double] = [:]
    private var offlineFiles: Set<String> = []

    private var progressFile: URL { directory.appendingPathComponent("progress.json") }
    private var offlineDirectory: URL { directory.appendingPathComponent("offline", isDirectory: true) }

    public init(directory: URL) {
        self.directory = directory
        let fm = FileManager.default
        try? fm.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: progressFile),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            progressByKey = decoded
        }
        if let names = try? fm.contentsOfDirectory(atPath: offlineDirectory.path) {
            offlineFiles = Set(names.filter { $0.hasSuffix(".json") })
        }
    }

    // MARK: Keys

    static func key(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func fileName(for title: String) -> String {
        var hash: UInt64 = 14695981039346656037 // FNV-1a, 64 bit
        for byte in key(title).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(format: "%016llx.json", hash)
    }

    // MARK: Reading progress

    /// Fraction (0...1) of the article that was read, or `nil` if it was never opened.
    public func progress(for title: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return progressByKey[Self.key(title)]
    }

    public func setProgress(_ fraction: Double, for title: String) {
        let clamped = min(1.0, max(0.0, fraction))
        let key = Self.key(title)
        guard !key.isEmpty else { return }
        lock.lock()
        if let old = progressByKey[key], abs(old - clamped) < 0.001 {
            lock.unlock()
            return
        }
        progressByKey[key] = clamped
        let snapshot = progressByKey
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: progressFile, options: .atomic)
        }
    }

    // MARK: Offline articles

    public func hasOffline(_ title: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return offlineFiles.contains(Self.fileName(for: title))
    }

    public func saveOffline(_ article: WikiOfflineArticle) {
        guard let data = try? JSONEncoder().encode(article) else { return }
        let name = Self.fileName(for: article.title)
        do {
            try data.write(to: offlineDirectory.appendingPathComponent(name), options: .atomic)
        } catch {
            return
        }
        lock.lock()
        offlineFiles.insert(name)
        lock.unlock()
    }

    public func loadOffline(title: String) -> WikiOfflineArticle? {
        let name = Self.fileName(for: title)
        guard let data = try? Data(contentsOf: offlineDirectory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(WikiOfflineArticle.self, from: data)
    }

    public func removeOffline(title: String) {
        let name = Self.fileName(for: title)
        try? FileManager.default.removeItem(at: offlineDirectory.appendingPathComponent(name))
        lock.lock()
        offlineFiles.remove(name)
        lock.unlock()
    }
}
