import XCTest
@testable import KindleWiki

final class WikiReadingStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("kindlewiki-test-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func article(_ title: String) -> WikiOfflineArticle {
        WikiOfflineArticle(
            title: title,
            description: "desc",
            rawExtract: "Some text about \(title).\n== Section ==\nMore text.",
            leadImageURL: "https://x/lead.jpg",
            links: ["A", "B"],
            isDisambiguation: false,
            sectionImages: [0: [.init(url: "https://x/1.jpg", caption: "one")], 3: [.init(url: "https://x/2.jpg", caption: "")]],
            tables: [0: [WikiTableData(id: "t1", sectionTitle: "Section", title: "T", headers: ["h"], rows: [["a"], ["b"]])]]
        )
    }

    func testProgressPersistsAcrossInstancesAndIsCaseInsensitive() {
        let store = WikiReadingStore(directory: directory)
        XCTAssertNil(store.progress(for: "Albert Einstein"))
        store.setProgress(0.42, for: "Albert Einstein")
        XCTAssertEqual(store.progress(for: " albert einstein "), 0.42)

        let reopened = WikiReadingStore(directory: directory)
        XCTAssertEqual(reopened.progress(for: "Albert Einstein"), 0.42)
    }

    func testProgressIsClamped() {
        let store = WikiReadingStore(directory: directory)
        store.setProgress(7, for: "A")
        store.setProgress(-3, for: "B")
        XCTAssertEqual(store.progress(for: "A"), 1.0)
        XCTAssertEqual(store.progress(for: "B"), 0.0)
    }

    func testOfflineArticleRoundTripsIncludingFiguresAndTables() throws {
        let store = WikiReadingStore(directory: directory)
        XCTAssertFalse(store.hasOffline("Jazz"))
        let original = article("Jazz")
        store.saveOffline(original)
        XCTAssertTrue(store.hasOffline("jazz"))

        let loaded = try XCTUnwrap(store.loadOffline(title: "Jazz"))
        XCTAssertEqual(loaded, original)

        // It also survives an app restart, and converts to the in-memory cache entry without loss.
        let reopened = WikiReadingStore(directory: directory)
        XCTAssertTrue(reopened.hasOffline("Jazz"))
        let entry = try XCTUnwrap(reopened.loadOffline(title: "Jazz")).makeCacheEntry()
        XCTAssertEqual(entry.rawExtract, original.rawExtract)
        XCTAssertEqual(entry.sectionImages?[3]?.first?.url, "https://x/2.jpg")
        XCTAssertEqual(entry.tables?[0]?.first?.rows.count, 2)
    }

    func testUnknownMediaAndTablesStayNilSoTheyAreFetchedLater() throws {
        let store = WikiReadingStore(directory: directory)
        store.saveOffline(WikiOfflineArticle(title: "Haiku", description: "", rawExtract: "x", leadImageURL: nil, links: [], isDisambiguation: false))
        let entry = try XCTUnwrap(store.loadOffline(title: "Haiku")).makeCacheEntry()
        XCTAssertNil(entry.sectionImages)
        XCTAssertNil(entry.tables)
    }

    func testRemoveOfflineDeletesTheArticle() {
        let store = WikiReadingStore(directory: directory)
        store.saveOffline(article("Jazz"))
        store.removeOffline(title: "Jazz")
        XCTAssertFalse(store.hasOffline("Jazz"))
        XCTAssertNil(store.loadOffline(title: "Jazz"))
        XCTAssertFalse(WikiReadingStore(directory: directory).hasOffline("Jazz"))
    }
}
