import XCTest
import KindleUI
@testable import KindleWiki

final class KindleWikiTests: XCTestCase {
    func testMediaWikiHTMLStripping() {
        let raw = "<p>Quantum mechanics is a <b>fundamental</b> theory in physics.&nbsp;It describes nature at atomic scales.&#91;1&#93;&#91;2&#93;&ndash;modern era.</p>"
        let clean = stripMediaWikiHTML(raw)
        XCTAssertTrue(clean.contains("fundamental"))
        XCTAssertTrue(clean.contains("atomic scales"))
        XCTAssertFalse(clean.contains("<p>"))
        XCTAssertFalse(clean.contains("&#91;1&#93;"))
        XCTAssertFalse(clean.contains("[1]"))
        XCTAssertTrue(clean.contains("–modern"))

        let microformat = "2003<span style=\"display:none\">&#160;(<span class=\"bday dtstart published updated\">2003</span>)</span>"
        XCTAssertEqual(stripMediaWikiHTML(microformat), "2003")
        let defunct = "September 2018<span style=\"display:none\">&#160;(<span class=\"dtend\">2018-09</span>)</span>"
        XCTAssertEqual(stripMediaWikiHTML(defunct), "September 2018")
    }

    func testWikipediaPaginationLineBudgeting() {
        let sample = """
        Electronic paper or intelligent paper, is a display device that reflects ambient light, thereby mimicking the appearance of ordinary ink on paper.

        Technologies include Gyricon, electrowetting, interferometry, and plasmonics.

        == Applications ==
        Applications of e-paper include electronic shelf labels and digital signage, bus station time tables, electronic billboards, smartphone displays, and e-readers.

        == Market ==
        The market for electronic paper displays has grown significantly in recent years.
        """
        let (pages, jumps) = paginateWikipediaExtract(sample, fontSize: 16)
        XCTAssertFalse(pages.isEmpty)
        XCTAssertEqual(jumps.count, 3) // Overview, Applications, Market
        XCTAssertEqual(jumps[0].title, "Overview")
        XCTAssertEqual(jumps[1].title, "Applications")
        XCTAssertEqual(jumps[2].title, "Market")
    }

    func testWiktionaryMetadataParsing() {
        let raw = """
        == Pronunciation ==
        * /ɛˈfɛm.ə.ɹəl/
        * Audio (US)

        == Etymology ==
        From Ancient Greek ἐφήμερος (ephēmeros, "short-lived").

        == Adjective ==
        === Synonyms: ===
        * transitory, fleeting
        """
        let meta = parseWiktionaryExtractMetadata(from: raw)
        XCTAssertEqual(meta.ipaBadge, "/ɛˈfɛm.ə.ɹəl/")
        XCTAssertTrue(meta.etymology.contains("Ancient Greek"))
    }

    func testChunkIntoPages() {
        let list = Array(1...25)
        let pages = chunkIntoPages(list, pageSize: 10)
        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(pages[0].count, 10)
        XCTAssertEqual(pages[1].count, 10)
        XCTAssertEqual(pages[2].count, 5)
    }

    func testGroupSectionsIntoHorizontalRows() {
        let sections = [
            WikiSectionJump(id: "1", title: "Overview", startPage: 0),
            WikiSectionJump(id: "2", title: "Overview and fundamental concepts", startPage: 2),
            WikiSectionJump(id: "3", title: "Mathematical formulation", startPage: 5),
            WikiSectionJump(id: "4", title: "Examples", startPage: 8),
            WikiSectionJump(id: "5", title: "Applications", startPage: 10),
            WikiSectionJump(id: "6", title: "History", startPage: 12),
        ]
        let rowsSmall = groupSectionsIntoHorizontalRows(sections, maxRowCharBudget: defaultChapterRowCharBudget(screenWidth: 600))
        XCTAssertGreaterThan(rowsSmall.count, 1)
        for row in rowsSmall {
            let totalChars = row.reduce(0) { $0 + $1.displayTitle.count + 3 }
            XCTAssertLessThanOrEqual(totalChars, 48)
        }

        let rowsLarge = groupSectionsIntoHorizontalRows(sections, maxRowCharBudget: defaultChapterRowCharBudget(screenWidth: 1236))
        XCTAssertFalse(rowsLarge.isEmpty)
        // With modern Kindle width (1236px), budget is 82, so 4 buttons fit in row 0
        XCTAssertGreaterThanOrEqual(rowsLarge[0].count, 4)
    }

    func testDisambiguationParsingAndPagination() {
        let sample = """
        Meow is an imitative word for a sound made in cat communication.
        Meow or Miaow may also refer to:

        == Film and television ==
        Meow (2017 film), a 2017 Hong Kong science fantasy comedy film
        Meow (2021 film), a 2021 Indian Malayalam-language family drama film
        Meow (Dark Angel), an episode in the TV series Dark Angel

        == Music ==
        Miaow (band), an English band
        "Meow", a song from the Anamanaguchi album Endless Fantasy
        """

        let line = parseDisambiguationLine("Meow (2017 film), a 2017 Hong Kong science fantasy comedy film")
        XCTAssertNotNil(line)
        XCTAssertEqual(line?.target, "Meow (2017 film)")
        XCTAssertEqual(line?.label, "Meow (2017 film)")
        XCTAssertTrue(line?.detail.contains("Hong Kong") ?? false)

        let (pages, jumps) = paginateWikipediaExtract(
            sample,
            fontSize: 16,
            linkedTitles: ["Meow (2017 film)", "Meow (2021 film)", "Meow (Dark Angel)", "Miaow (band)"],
            isDisambiguation: true
        )
        // Disambiguation pages flow continuously on page 0 without breaking into empty pages
        XCTAssertFalse(pages.isEmpty)
        let page0 = pages[0]
        // Page 0 should contain the intro, subheadings, and link items
        let linkBlocks = page0.blocks.filter {
            if case .linkItem = $0.kind { return true }
            return false
        }
        XCTAssertGreaterThanOrEqual(linkBlocks.count, 3)
        XCTAssertEqual(jumps.count, 3) // Overview, Film and television, Music
    }

    func testMediaWikiTableParsing() {
        let sampleHTML = """
        <table class="wikitable">
            <caption>Comparison of e-readers</caption>
            <tr><th>Maker</th><th>Model</th><th>Year</th><th>Screen</th></tr>
            <tr><td>Amazon</td><td>Kindle Oasis</td><td>2016</td><td>7 inch</td></tr>
            <tr><td>Kobo</td><td>Clara 2E</td><td>2022</td><td>6 inch</td></tr>
        </table>
        """
        let tables = parseMediaWikiTables(from: sampleHTML)
        XCTAssertEqual(tables.count, 1)
        let tbl = tables[0]
        XCTAssertEqual(tbl.title, "Comparison of e-readers")
        XCTAssertEqual(tbl.headers, ["Maker", "Model", "Year", "Screen"])
        XCTAssertEqual(tbl.rows.count, 2)
        XCTAssertEqual(tbl.rows[0], ["Amazon", "Kindle Oasis", "2016", "7 inch"])
        XCTAssertEqual(tbl.rows[1], ["Kobo", "Clara 2E", "2022", "6 inch"])
    }

    func testMediaWikiInfoboxWithNestedTableParsing() {
        let honeyBeeInfoboxHTML = """
        <table class="infobox biota">
            <tr><th colspan="2">Honey bee<br/>Temporal range: Early Oligocene – Present<table><tr><td>PreꞒ</td><td>Ꞓ</td><td>O</td><td>S</td></tr></table></th></tr>
            <tr><th colspan="2">Scientific classification</th></tr>
            <tr><td>Kingdom:</td><td>Animalia</td></tr>
            <tr><td>Phylum:</td><td>Arthropoda</td></tr>
            <tr><td>Class:</td><td>Insecta</td></tr>
            <tr><td>Order:</td><td>Hymenoptera</td></tr>
            <tr><td>Family:</td><td>Apidae</td></tr>
            <tr><td>Genus:</td><td>Apis</td></tr>
        </table>
        """
        let tables = parseMediaWikiTables(from: honeyBeeInfoboxHTML)
        XCTAssertEqual(tables.count, 1)
        let infobox = tables[0]
        XCTAssertTrue(infobox.id.hasPrefix("infobox_"))
        XCTAssertEqual(infobox.rows.count, 6)
        XCTAssertEqual(infobox.rows[0], ["Kingdom", "Animalia"])
        XCTAssertEqual(infobox.rows[1], ["Phylum", "Arthropoda"])
        XCTAssertEqual(infobox.rows[5], ["Genus", "Apis"])
    }

    func testCleanWikipediaExtractMathLines() {
        let rawMathExtract = [
            "The probability of obtaining this outcome is given by",
            "  ",
            "    ",
            "      ",
            "        P",
            "        (",
            "        ",
            "          x",
            "          ",
            "            i",
            "          ",
            "        ",
            "        )",
            "        =",
            "        tr",
            "        \u{2061}",
            "        (",
            "        ",
            "          Π",
            "          ",
            "            i",
            "          ",
            "        ",
            "        ρ",
            "        )",
            "        ,",
            "      ",
            "    ",
            "    {\\displaystyle P(x_{i})=\\operatorname {tr} (\\Pi _{i}\\rho ),}",
            "  ",
            "where",
            "  ",
            "    ",
            "      ",
            "        ρ",
            "      ",
            "    ",
            "    {\\displaystyle \\rho }",
            "  ",
            "is the density operator of the ensemble."
        ]
        let cleaned = cleanWikipediaExtractLines(rawMathExtract.joined(separator: "\n"))
        XCTAssertFalse(cleaned.joined(separator: "\n").contains("\\displaystyle"))
        XCTAssertTrue(cleaned.joined(separator: " ").contains("P(xi) = tr(Πiρ),"))
        XCTAssertTrue(cleaned.joined(separator: " ").contains("where ρ is the density operator of the ensemble."))
    }
}
