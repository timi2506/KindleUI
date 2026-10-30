import XCTest
@testable import KindleWiki

final class WikiPaginationTests: XCTestCase {
    private func sentence(_ n: Int) -> String { "Sentence number \(n) says something quite ordinary about the subject at hand." }

    private func paragraph(chars: Int, seed: Int = 0) -> String {
        var s = ""
        var i = seed
        while s.count < chars { s += sentence(i) + " "; i += 1 }
        return String(s.prefix(chars)).trimmingCharacters(in: .whitespaces)
    }

    func testNewSectionFlowsOntoCurrentPageWhenThereIsRoom() {
        // ~16 estimated lines used by the overview leaves >= 9 free, so the short next section shares the page.
        let text = paragraph(chars: 1200) + "\n== Second ==\n" + paragraph(chars: 200, seed: 100)
        let (pages, jumps) = paginateWikipediaExtract(text, fontSize: 16)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(jumps.map(\.startPage), [0, 0])
    }

    func testNewSectionStartsNewPageWhenPageIsNearlyFull() {
        let text = paragraph(chars: 1800) + "\n== Second ==\n" + paragraph(chars: 200, seed: 100)
        let (pages, jumps) = paginateWikipediaExtract(text, fontSize: 16)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(jumps.map(\.startPage), [0, 1])
    }

    func testFiguresAreNeverDroppedOrDuplicatedAndNoTextIsLost() {
        var sections: [String] = [paragraph(chars: 900, seed: 1), paragraph(chars: 1300, seed: 20), paragraph(chars: 700, seed: 40)]
        sections += ["== Two ==", paragraph(chars: 1500, seed: 60), paragraph(chars: 500, seed: 80)]
        let text = sections.joined(separator: "\n")
        let images = [
            (url: "https://x/1.jpg", caption: "First figure caption."),
            (url: "https://x/2.jpg", caption: ""),
            (url: "https://x/3.jpg", caption: "Third."),
        ]
        for fontSize in [13, 16, 20, 24] {
            let (pages, _) = paginateWikipediaExtract(
                text,
                fontSize: fontSize,
                leadImageURL: nil,
                sectionImages: [0: images, 1: [(url: "https://x/4.jpg", caption: "Four.")]]
            )
            XCTAssertFalse(pages.contains { $0.blocks.isEmpty }, "font \(fontSize): empty page")

            let imageURLs = pages.flatMap { $0.blocks }.compactMap { block -> String? in
                if case .image(let url) = block.kind { return url }
                return nil
            }
            XCTAssertEqual(Set(imageURLs), ["https://x/1.jpg", "https://x/2.jpg", "https://x/3.jpg", "https://x/4.jpg"], "font \(fontSize)")
            XCTAssertEqual(imageURLs.count, 4, "font \(fontSize): a figure was duplicated")

            let kept = pages.flatMap { $0.blocks }.filter { $0.kind == .paragraph }.map { $0.text.filter { !$0.isWhitespace }.count }.reduce(0, +)
            let expected = [900, 1300, 700, 1500, 500].reduce(0) { $0 + paragraph(chars: $1).filter { !$0.isWhitespace }.count }
            XCTAssertGreaterThanOrEqual(kept, Int(Double(expected) * 0.98), "font \(fontSize): text lost")
            XCTAssertLessThanOrEqual(kept, Int(Double(expected) * 1.02) + 50, "font \(fontSize): text duplicated")
        }
    }
}
