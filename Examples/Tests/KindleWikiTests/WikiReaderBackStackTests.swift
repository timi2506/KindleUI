import XCTest
@testable import KindleWiki

final class WikiReaderBackStackTests: XCTestCase {
    func testBackFromAnArticleOpenedOnHomeClosesTheReader() {
        var stack = WikiReaderBackStack()
        // Read "Einstein" (opened from home), go back home, then open "Jazz" from home.
        stack.willOpen("Einstein", from: "", readerIsOpen: false)
        stack.willOpen("Jazz", from: "Einstein", readerIsOpen: false)
        XCTAssertNil(stack.popPrevious(), "Back must leave the reader, not return to Einstein")
    }

    func testFollowingLinksInsideTheReaderBuildsABackTrail() {
        var stack = WikiReaderBackStack()
        stack.willOpen("Einstein", from: "", readerIsOpen: false)
        stack.willOpen("Physics", from: "Einstein", readerIsOpen: true)
        stack.willOpen("Energy", from: "Physics", readerIsOpen: true)
        XCTAssertEqual(stack.popPrevious(), "Physics")
        XCTAssertEqual(stack.popPrevious(), "Einstein")
        XCTAssertNil(stack.popPrevious())
    }

    func testOpeningFromOutsideDiscardsAnOldTrail() {
        var stack = WikiReaderBackStack()
        stack.willOpen("Physics", from: "Einstein", readerIsOpen: true)
        // Reader was closed some other way; a later open from home must not resurrect the trail.
        stack.willOpen("Jazz", from: "Physics", readerIsOpen: false)
        XCTAssertNil(stack.popPrevious())
    }

    func testReopeningTheSameArticleDoesNotAddATrailEntry() {
        var stack = WikiReaderBackStack()
        stack.willOpen("Einstein", from: "einstein", readerIsOpen: true)
        XCTAssertNil(stack.popPrevious())
    }
}
