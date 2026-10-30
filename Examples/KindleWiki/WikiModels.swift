import Foundation
import KindleUI

// MARK: - API Models for Wikipedia & Wiktionary

/// MediaWiki Action API Search response (`action=query&list=search`).
public struct MediaWikiSearchResponse: Codable, Sendable {
    public struct Query: Codable, Sendable {
        public struct SearchHit: Codable, Sendable, Identifiable, Equatable {
            public let title: String
            public let pageid: Int?
            public let snippet: String?
            public let wordcount: Int?

            public var id: String { title }

            public var cleanSnippet: String {
                stripMediaWikiHTML(snippet ?? "")
            }
        }
        public let search: [SearchHit]?
    }
    public let query: Query?
}

/// Wikipedia REST v1 Page Summary (`https://en.wikipedia.org/api/rest_v1/page/summary/{title}`).
public struct WikipediaSummaryResponse: Codable, Sendable {
    public let title: String
    public let displaytitle: String?
    public let description: String?
    public let extract: String?
}

/// MediaWiki Action API Plaintext Extracts (`action=query&prop=extracts|description|pageimages&explaintext=1`).
public struct MediaWikiExtractsResponse: Codable, Sendable {
    public struct Query: Codable, Sendable {
        public struct Page: Codable, Sendable {
            public struct Thumbnail: Codable, Sendable, Equatable {
                public let source: String
                public let width: Int?
                public let height: Int?
            }
            public struct LinkItem: Codable, Sendable, Equatable {
                public let ns: Int?
                public let title: String
            }
            public let pageid: Int?
            public let title: String?
            public let description: String?
            public let extract: String?
            public let thumbnail: Thumbnail?
            public let links: [LinkItem]?
        }
        public let pages: [String: Page]?
    }
    public let query: Query?
}

/// MediaWiki Action API Parse (`action=parse&prop=text`).
public struct MediaWikiParseResponse: Codable, Sendable {
    public struct ParseResult: Codable, Sendable {
        public struct TextWrapper: Codable, Sendable {
            public let html: String
            enum CodingKeys: String, CodingKey {
                case html = "*"
            }
        }
        public let title: String?
        public let text: TextWrapper?
    }
    public let parse: ParseResult?
}

/// Wikipedia REST v1 Media List (`https://en.wikipedia.org/api/rest_v1/page/media-list/{title}`).
public struct WikipediaMediaListResponse: Codable, Sendable {
    public struct MediaItem: Codable, Sendable {
        public struct Caption: Codable, Sendable {
            public let text: String?
        }
        public struct SrcSetEntry: Codable, Sendable {
            public let src: String
            public let scale: String?
        }
        public let title: String?
        public let section_id: Int?
        public let type: String?
        public let showInGallery: Bool?
        public let caption: Caption?
        public let srcset: [SrcSetEntry]?
    }
    public let items: [MediaItem]?
}

/// Wiktionary REST v1 Page Definitions (`https://en.wiktionary.org/api/rest_v1/page/definition/{word}`).
public struct WiktionaryPartOfSpeechEntry: Codable, Sendable, Equatable {
    public struct DefinitionItem: Codable, Sendable, Equatable {
        public struct ParsedExample: Codable, Sendable, Equatable {
            public let example: String?
        }
        public let definition: String
        public let examples: [String]?
        public let parsedExamples: [ParsedExample]?

        public var cleanDefinition: String {
            stripMediaWikiHTML(definition)
        }

        public var cleanExamples: [String] {
            var out: [String] = []
            if let rawList = examples {
                for ex in rawList {
                    let clean = stripMediaWikiHTML(ex)
                    if !clean.isEmpty { out.append(clean) }
                }
            }
            if out.isEmpty, let parsed = parsedExamples {
                for p in parsed {
                    if let ex = p.example {
                        let clean = stripMediaWikiHTML(ex)
                        if !clean.isEmpty { out.append(clean) }
                    }
                }
            }
            return out
        }

        public var linkedWords: [String] {
            extractWikiLinks(from: definition)
        }
    }

    public let partOfSpeech: String
    public let language: String
    public let definitions: [DefinitionItem]
}

// MARK: - Paginated Domain Models

public enum WikiAppTab: String, CaseIterable, Sendable, Equatable {
    case wikipedia = "wikipedia"
    case wiktionary = "wiktionary"
    case saved = "saved"
}

public enum SavedViewMode: String, CaseIterable, Sendable, Equatable {
    case bookmarks = "Saved Bookmarks"
    case history = "Recent History"
}

public enum ActiveReaderKind: String, Sendable, Equatable {
    case wikipedia
    case wiktionary
}

/// Structured table data parsed from a MediaWiki wikitable.
public struct WikiTableData: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let sectionTitle: String?
    public let title: String?
    public let headers: [String]
    public let rows: [[String]]

    public init(
        id: String = UUID().uuidString,
        sectionTitle: String? = nil,
        title: String? = nil,
        headers: [String],
        rows: [[String]]
    ) {
        self.id = id
        self.sectionTitle = sectionTitle
        self.title = title
        self.headers = headers
        self.rows = rows
    }
}

/// A structured typographic or figure block inside a Wikipedia reader page.
public struct WikiArticleBlock: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case subheading
        case paragraph
        case image(url: String)
        case linkItem(targetTitle: String, label: String, detail: String)
        case table(WikiTableData)
    }

    public let id: Int
    public let kind: Kind
    public let text: String

    public init(id: Int, kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// A single paginated page of a Wikipedia article.
public struct WikiArticlePage: Sendable, Equatable, Identifiable {
    public let id: Int
    public let sectionTitle: String
    public let blocks: [WikiArticleBlock]

    public var body: String {
        blocks.map(\.text).joined(separator: "\n\n")
    }

    public init(id: Int, sectionTitle: String, blocks: [WikiArticleBlock]) {
        self.id = id
        self.sectionTitle = sectionTitle
        self.blocks = blocks
    }

    public init(id: Int, sectionTitle: String, body: String) {
        self.id = id
        self.sectionTitle = sectionTitle
        self.blocks = [WikiArticleBlock(id: 0, kind: .paragraph, text: body)]
    }
}

/// A section jump entry mapping a section heading to its starting page index.
public struct WikiSectionJump: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let startPage: Int

    public var displayTitle: String {
        if title.count <= 24 { return title }
        return String(title.prefix(22)) + "…"
    }
}

/// A single paginated page of a Wiktionary word entry.
public struct WiktionaryReaderPage: Sendable, Equatable, Identifiable {
    public struct SenseRow: Sendable, Equatable, Identifiable {
        public let id: Int
        public let number: Int
        public let text: String
        public let examples: [String]
        public let relatedWords: [String]
    }

    public enum PageKind: Sendable, Equatable {
        case definitions(partOfSpeech: String, language: String, senses: [SenseRow])
        case notes(heading: String, body: String, bullets: [String])
    }

    public let id: Int
    public let kind: PageKind
}

public struct WiktionaryExtractMetadata: Sendable, Equatable {
    public var etymology: String = ""
    public var pronunciation: String = ""
    public var ipaBadge: String? = nil
    public var synonymsAndRelated: [String] = []
}

public struct WikiHistoryEntry: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case wikipedia = "Wikipedia"
        case wiktionary = "Wiktionary"
    }
    public let id: String
    public let title: String
    public let subtitle: String
    public let kind: Kind

    public init(id: String, title: String, subtitle: String, kind: Kind) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
    }
}



struct WikiReaderBackStack: Equatable {
    private(set) var titles: [String] = []

    /// Call right before opening `target`. `current` is the article shown last; `readerIsOpen` tells whether the
    /// reader is currently on screen (i.e. this is in-article navigation).
    mutating func willOpen(_ target: String, from current: String, readerIsOpen: Bool) {
        guard readerIsOpen else {
            titles.removeAll()
            return
        }
        if !current.isEmpty && current.lowercased() != target.lowercased() {
            titles.append(current)
        }
    }

    /// The article to go back to, or `nil` if Back should close the reader.
    mutating func popPrevious() -> String? {
        titles.popLast()
    }
}

/// Small in-memory LRU of loaded articles so revisiting one (back navigation, history, bookmarks)
/// doesn't hit the network again. Only touched from the main thread.
///
/// Entries are shared, mutable records: the text goes in as soon as it arrives and the figure list / tables are
/// attached whenever *their* requests finish -- even if the reader already moved on to another article.
/// `sectionImages` / `tables` stay `nil` until loaded, so a later visit only re-requests what is missing.
final class WikiArticleCache: @unchecked Sendable {
    final class Entry: @unchecked Sendable {
        var title: String
        var description: String
        var rawExtract: String
        var leadImageURL: String?
        var links: [String]
        var isDisambiguation: Bool
        var sectionImages: [Int: [(url: String, caption: String)]]?
        var tables: [Int: [WikiTableData]]?

        init(
            title: String,
            description: String,
            rawExtract: String,
            leadImageURL: String?,
            links: [String],
            isDisambiguation: Bool,
            sectionImages: [Int: [(url: String, caption: String)]]? = nil,
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
    }

    static let shared = WikiArticleCache(capacity: 6)

    internal let capacity: Int
    internal var entries: [String: Entry] = [:]
    internal var order: [String] = [] // least recently used first

    init(capacity: Int) {
        self.capacity = capacity
    }

    internal static func key(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Returns the entry for `title` and marks it as recently used.
    func lookup(_ title: String) -> Entry? {
        let k = Self.key(title)
        guard let entry = entries[k] else { return nil }
        touch(k)
        return entry
    }

    /// Returns the entry for `title` without affecting its recency (used when attaching late results).
    func peek(_ title: String) -> Entry? {
        entries[Self.key(title)]
    }

    /// Stores `entry` under its own title and under the title it was requested with (they differ for redirects).
    func store(_ entry: Entry, requestedTitle: String) {
        for k in Set([Self.key(entry.title), Self.key(requestedTitle)]) where !k.isEmpty {
            entries[k] = entry
            touch(k)
        }
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    func removeAll() {
        entries.removeAll()
        order.removeAll()
    }

    internal func touch(_ k: String) {
        order.removeAll { $0 == k }
        order.append(k)
    }
}
