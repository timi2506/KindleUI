import XCTest
@testable import KindleWiki

final class WikiArticleCacheTests: XCTestCase {
    private func entry(_ title: String) -> WikiArticleCache.Entry {
        WikiArticleCache.Entry(
            title: title,
            description: "d",
            rawExtract: "text of \(title)",
            leadImageURL: nil,
            links: [],
            isDisambiguation: false
        )
    }

    func testLookupIsCaseInsensitiveAndFindsRedirectsViaRequestedTitle() {
        let cache = WikiArticleCache(capacity: 3)
        cache.store(entry("Albert Einstein"), requestedTitle: "einstein")
        XCTAssertNotNil(cache.lookup("albert einstein"))
        XCTAssertNotNil(cache.lookup("  Einstein "))
        XCTAssertNil(cache.lookup("Isaac Newton"))
    }

    func testLateResultsAttachToTheSharedEntryUnderEveryKey() {
        let cache = WikiArticleCache(capacity: 3)
        cache.store(entry("Albert Einstein"), requestedTitle: "einstein")
        XCTAssertNil(cache.lookup("einstein")?.tables, "tables are unknown until their request finishes")

        // The tables arrive after the reader left; they're attached via the requested title...
        cache.peek("einstein")?.tables = [0: []]
        // ...and are visible when the article is reopened under its resolved title.
        XCTAssertNotNil(cache.lookup("Albert Einstein")?.tables)
        XCTAssertNil(cache.lookup("Albert Einstein")?.sectionImages)
    }

    func testLeastRecentlyUsedEntryIsEvicted() {
        let cache = WikiArticleCache(capacity: 2)
        cache.store(entry("A"), requestedTitle: "A")
        cache.store(entry("B"), requestedTitle: "B")
        _ = cache.lookup("A") // A is now more recent than B
        cache.store(entry("C"), requestedTitle: "C")
        XCTAssertNotNil(cache.lookup("A"))
        XCTAssertNil(cache.lookup("B"))
        XCTAssertNotNil(cache.lookup("C"))
    }

    func testPeekDoesNotChangeRecency() {
        let cache = WikiArticleCache(capacity: 2)
        cache.store(entry("A"), requestedTitle: "A")
        cache.store(entry("B"), requestedTitle: "B")
        _ = cache.peek("A")
        cache.store(entry("C"), requestedTitle: "C")
        XCTAssertNil(cache.lookup("A"), "peek must not keep A alive")
    }
}
