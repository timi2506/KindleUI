import Foundation
import KindleUI

// MARK: - Text & MediaWiki Parsing Helpers

public func stripMediaWikiHTML(_ raw: String) -> String {
    guard !raw.isEmpty else { return "" }
    var s = raw
    if s.contains("<") {
        // Strip embedded <style>, <script>, and reference/edit-section tags before stripping markup tags
        if s.range(of: "<style", options: .caseInsensitive) != nil {
            s = s.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        if s.range(of: "<script", options: .caseInsensitive) != nil {
            s = s.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        if s.range(of: "<sup", options: .caseInsensitive) != nil {
            s = s.replacingOccurrences(of: "<sup[^>]*class=\"[^\"]*reference[^\"]*\"[^>]*>[\\s\\S]*?</sup>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        if s.range(of: "<span", options: .caseInsensitive) != nil {
            if s.contains("mw-editsection") || s.contains("noprint") || s.contains("sortkey") || s.contains("Z3988") || s.contains("bday") || s.contains("dtstart") || s.contains("dtend") {
                s = s.replacingOccurrences(of: "<span[^>]*class=\"[^\"]*(?:mw-editsection|noprint|sortkey|Z3988|bday|dtstart|dtend)[^\"]*\"[^>]*>[\\s\\S]*?</span>", with: "", options: [.regularExpression, .caseInsensitive])
            }
            if s.range(of: "display", options: .caseInsensitive) != nil {
                s = s.replacingOccurrences(of: "<span[^>]*style=\"[^\"]*display\\s*:\\s*none[^\"]*\"[^>]*>(?:<span\\b[^>]*>[\\s\\S]*?</span>|[\\s\\S])*?</span>", with: "", options: [.regularExpression, .caseInsensitive])
            }
        }

        let lineBreakTags = ["<br>", "<br/>", "<br />", "</p>", "</li>", "</div>"]
        for tag in lineBreakTags where s.contains(tag) {
            s = s.replacingOccurrences(of: tag, with: "\n")
        }
    }

    var stripped: String
    if s.contains("<") {
        stripped = String()
        stripped.reserveCapacity(s.count)
        var inTag = false
        for ch in s {
            if ch == "<" {
                inTag = true
            } else if ch == ">" {
                if inTag {
                    inTag = false
                } else {
                    stripped.append(ch)
                }
            } else if !inTag {
                stripped.append(ch)
            }
        }
    } else {
        stripped = s
    }

    if stripped.contains("&") {
        let entities: [(String, String)] = [
            ("&quot;", "\""),
            ("&#039;", "'"),
            ("&#39;", "'"),
            ("&#x27;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&#160;", " "),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&gt;", ">"),
            ("&lt;", "<"),
            ("&amp;", "&"),
            ("&#91;", "["),
            ("&#93;", "]"),
            ("&thinsp;", " "),
            ("&ensp;", " "),
            ("&emsp;", " "),
            ("&hellip;", "…"),
            ("&#8217;", "'"),
            ("&#8220;", "\""),
            ("&#8221;", "\""),
            ("&#8211;", "–"),
            ("&#8212;", "—"),
            ("&#8230;", "…")
        ]
        for (entity, rep) in entities where stripped.contains(entity) {
            stripped = stripped.replacingOccurrences(of: entity, with: rep)
        }
    }

    let unicodeSpaces = ["\u{00A0}", "\u{202F}", "\u{2009}", "\u{2002}", "\u{2003}"]
    for sp in unicodeSpaces where stripped.contains(sp) {
        stripped = stripped.replacingOccurrences(of: sp, with: " ")
    }

    // Strip bracket citations like [1], [2], [14]
    if stripped.contains("[") {
        stripped = stripped.replacingOccurrences(of: "\\[[0-9]+\\]", with: "", options: .regularExpression)
    }

    let rawLines: [String] = stripped.components(separatedBy: CharacterSet.newlines)
    var cleanLines: [String] = []
    for line in rawLines {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
        if !trimmed.isEmpty {
            cleanLines.append(trimmed)
        }
    }
    return cleanLines.joined(separator: "\n")
}

public func extractWikiLinks(from html: String) -> [String] {
    var results: [String] = []
    var seen = Set<String>()
    var searchRange = html.startIndex..<html.endIndex
    let marker = "href=\"/wiki/"
    while let found = html.range(of: marker, range: searchRange) {
        let after = found.upperBound
        guard let quoteEnd = html.range(of: "\"", range: after..<html.endIndex) else { break }
        let rawTarget = String(html[after..<quoteEnd.lowerBound])
        searchRange = quoteEnd.upperBound..<html.endIndex
        let baseTarget = rawTarget.split(separator: "#").first.map(String.init) ?? rawTarget
        guard !baseTarget.isEmpty,
              !baseTarget.contains(":"),
              !baseTarget.contains("/"),
              baseTarget.count >= 3,
              baseTarget.count <= 24 else { continue }
        let decoded = baseTarget
            .replacingOccurrences(of: "_", with: " ")
            .removingPercentEncoding ?? baseTarget
        let key = decoded.lowercased()
        if !seen.contains(key) {
            seen.insert(key)
            results.append(decoded)
            if results.count >= 5 { break }
        }
    }
    return results
}

public func encodeWikiComponent(_ text: String, underscoreSpaces: Bool = false) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = underscoreSpaces ? trimmed.replacingOccurrences(of: " ", with: "_") : trimmed
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "?&=#+/")
    return normalized.addingPercentEncoding(withAllowedCharacters: allowed) ?? normalized
}

/// Detects whether an article is a disambiguation directory linking to other Wikipedia entries.
public func isDisambiguationArticle(title: String, description: String?, extract: String) -> Bool {
    let lowerTitle = title.lowercased()
    let lowerDesc = (description ?? "").lowercased()
    let lowerExtract = extract.lowercased()
    if lowerTitle.contains("(disambiguation)") { return true }
    if lowerDesc.contains("disambiguation") || lowerDesc.contains("referred to by the same term") { return true }
    if lowerExtract.contains("may refer to:") || lowerExtract.contains("may also refer to:") { return true }
    return false
}

/// Parses a line from a disambiguation page into an interactive link item with target article title and descriptive note.
public func parseDisambiguationLine(
    _ rawLine: String,
    knownLinks: Set<String> = []
) -> (target: String, label: String, detail: String)? {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
    if line.isEmpty || line.hasPrefix("==") { return nil }

    let lower = line.lowercased()
    if lower.hasPrefix("meow is an imitative") ||
       lower.hasSuffix("may refer to:") ||
       lower.hasSuffix("may also refer to:") ||
       lower.contains("topics referred to by the same term") {
        return nil
    }

    // Check if line starts with a known linked title
    for link in knownLinks {
        if line.hasPrefix(link) {
            let remainder = line.dropFirst(link.count).trimmingCharacters(in: CharacterSet(charactersIn: " ,:–—-"))
            return (target: link, label: link, detail: remainder)
        }
    }

    // Pattern 1: "Quoted Title" ...
    if line.hasPrefix("\"") {
        if let closingQuoteIdx = line.dropFirst().firstIndex(of: "\"") {
            let title = String(line[line.index(after: line.startIndex)..<closingQuoteIdx])
            let remainder = line[line.index(after: closingQuoteIdx)...].trimmingCharacters(in: CharacterSet(charactersIn: " ,:–—-"))
            return (target: title, label: "“\(title)”", detail: remainder)
        }
    }

    // Pattern 2: Title (qualifier), detail
    if let parenOpen = line.firstIndex(of: "("),
       let parenClose = line.firstIndex(of: ")"),
       parenOpen < parenClose {
        let titleEnd = line.index(after: parenClose)
        let title = String(line[..<titleEnd]).trimmingCharacters(in: .whitespaces)
        let remainder = line[titleEnd...].trimmingCharacters(in: CharacterSet(charactersIn: " ,:–—-"))
        return (target: title, label: title, detail: remainder)
    }

    // Pattern 3: Title, detail OR Title – detail
    let separators = [", ", " – ", " — ", " - ", ": "]
    for sep in separators {
        if let range = line.range(of: sep) {
            let title = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let remainder = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if title.count >= 2 && title.count <= 50 {
                return (target: title, label: title, detail: remainder)
            }
        }
    }

    if line.count >= 2 && line.count <= 60 && !line.contains(".") {
        return (target: line, label: line, detail: "")
    }

    return nil
}

/// Finds the balanced closing `</table>` range for a `<table` starting at `tableStartRange`.
internal func findBalancedTableEnd(in lowerHTML: String, from afterOpenTag: String.Index) -> Range<String.Index>? {
    var depth = 1
    var cursor = afterOpenTag
    while cursor < lowerHTML.endIndex {
        let nextOpen = lowerHTML[cursor...].range(of: "<table")
        let nextClose = lowerHTML[cursor...].range(of: "</table>")
        guard let closeRange = nextClose else { return nil }
        if let openRange = nextOpen, openRange.lowerBound < closeRange.lowerBound {
            depth += 1
            cursor = openRange.upperBound
        } else {
            depth -= 1
            if depth == 0 {
                return closeRange
            }
            cursor = closeRange.upperBound
        }
    }
    return nil
}

/// Removes any nested `<table>...</table>` blocks inside the body of an outer `<table>`.
internal func removeNestedTables(from innerTableHTML: String) -> String {
    var current = innerTableHTML
    while true {
        let lower = current.lowercased()
        guard let openRange = lower.range(of: "<table") else { break }
        if let closeRange = findBalancedTableEnd(in: lower, from: openRange.upperBound) {
            current.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
        } else {
            current.removeSubrange(openRange.lowerBound..<current.endIndex)
            break
        }
    }
    return current
}

/// Parses HTML from MediaWiki Action API (`action=parse`) into structured tabular data blocks (both Infobox quick-fact cards and Wikitables).
public func parseMediaWikiTables(from html: String) -> [WikiTableData] {
    var tables: [WikiTableData] = []
    let lower = html.lowercased()
    var searchStart = lower.startIndex

    while let tableStartRange = lower[searchStart...].range(of: "<table") {
        guard let tableEndRange = findBalancedTableEnd(in: lower, from: tableStartRange.upperBound) else {
            break
        }
        searchStart = tableEndRange.upperBound

        let rawOuterTableHTML = String(html[tableStartRange.lowerBound..<tableEndRange.upperBound])
        guard let openTagClose = rawOuterTableHTML.firstIndex(of: ">") else { continue }
        let openTagLower = rawOuterTableHTML[..<openTagClose].lowercased()

        // Skip navigation boxes, metadata banners, Sister project boxes, and citation tables
        if openTagLower.contains("navbox") ||
           openTagLower.contains("ambox") ||
           openTagLower.contains("mbox") ||
           openTagLower.contains("sidebar") ||
           openTagLower.contains("sistersitebox") ||
           openTagLower.contains("nomobile") {
            continue
        }

        let isInfobox = openTagLower.contains("infobox")
        let isWikitable = openTagLower.contains("wikitable")

        // Strip nested tables inside the outer table so geological period bars or mini-tables don't corrupt rows
        let innerStart = rawOuterTableHTML.index(after: openTagClose)
        let innerEnd = rawOuterTableHTML.index(rawOuterTableHTML.endIndex, offsetBy: -8, limitedBy: innerStart) ?? innerStart
        let cleanInnerHTML = removeNestedTables(from: String(rawOuterTableHTML[innerStart..<innerEnd]))
        let cleanInnerLower = cleanInnerHTML.lowercased()

        guard isInfobox || isWikitable || cleanInnerLower.contains("<th") else {
            continue
        }

        var sectionTitle: String? = nil
        let prefixHTML = html[..<tableStartRange.lowerBound]
        if let lastH2Range = prefixHTML.range(of: "<h2", options: .backwards) {
            let h2Slice = prefixHTML[lastH2Range.lowerBound...]
            if let h2End = h2Slice.range(of: "</h2>") {
                let h2Text = String(h2Slice[..<h2End.upperBound])
                let cleanH2 = stripMediaWikiHTML(h2Text)
                    .replacingOccurrences(of: "[edit]", with: "")
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !cleanH2.isEmpty && cleanH2.lowercased() != "contents" {
                    sectionTitle = cleanH2
                }
            }
        }

        var caption: String? = nil
        if let capStart = cleanInnerLower.range(of: "<caption") {
            let capSlice = cleanInnerHTML[capStart.upperBound...]
            if let capCloseTag = capSlice.range(of: ">"),
               let capEnd = capSlice.range(of: "</caption>", options: .caseInsensitive) {
                let rawCap = String(capSlice[capCloseTag.upperBound..<capEnd.lowerBound])
                let clean = stripMediaWikiHTML(rawCap)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !clean.isEmpty {
                    caption = clean
                }
            }
        }

        var parsedHeaders: [String] = []
        var parsedRows: [[String]] = []

        var rowStart = cleanInnerLower.startIndex
        while let trStart = cleanInnerLower[rowStart...].range(of: "<tr") {
            guard let trEnd = cleanInnerLower[trStart.upperBound...].range(of: "</tr>") else {
                break
            }
            rowStart = trEnd.upperBound
            let trHTML = String(cleanInnerHTML[trStart.lowerBound..<trEnd.upperBound])
            let trLower = trHTML.lowercased()

            var rowThs: [String] = []
            var thScan = trLower.startIndex
            while let thStart = trLower[thScan...].range(of: "<th") {
                guard let thTagEnd = trLower[thStart.upperBound...].range(of: ">"),
                      let thEnd = trLower[thTagEnd.upperBound...].range(of: "</th>") else { break }
                thScan = thEnd.upperBound
                let thContent = String(trHTML[thTagEnd.upperBound..<thEnd.lowerBound])
                let clean = stripMediaWikiHTML(thContent)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !clean.isEmpty {
                    rowThs.append(clean)
                }
            }

            var rowTds: [String] = []
            var tdScan = trLower.startIndex
            while let tdStart = trLower[tdScan...].range(of: "<td") {
                guard let tdTagEnd = trLower[tdStart.upperBound...].range(of: ">"),
                      let tdEnd = trLower[tdTagEnd.upperBound...].range(of: "</td>") else { break }
                tdScan = tdEnd.upperBound
                let tdContent = String(trHTML[tdTagEnd.upperBound..<tdEnd.lowerBound])
                let tdLines = stripMediaWikiHTML(tdContent)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let hasListItems = tdContent.range(of: "<li", options: .caseInsensitive) != nil
                var clean = ""
                for line in tdLines {
                    if clean.isEmpty {
                        clean = line
                    } else if let lastChar = clean.last, ",;:.–—-(".contains(lastChar) {
                        clean += " " + line
                    } else if hasListItems {
                        clean += ", " + line
                    } else if isInfobox {
                        clean += " · " + line
                    } else {
                        clean += " " + line
                    }
                }
                if !clean.isEmpty {
                    rowTds.append(clean)
                }
            }

            if isInfobox {
                // In an infobox, we want clean 2-column key-value pairs (either <th>+<td> or <td>+<td>)
                if !rowThs.isEmpty && !rowTds.isEmpty {
                    let key = rowThs[0].trimmingCharacters(in: CharacterSet(charactersIn: " :"))
                    let val = rowTds.joined(separator: "; ")
                    if !key.isEmpty && !val.isEmpty && key.count <= 36 && val.count <= 110 {
                        parsedRows.append([key, val])
                    }
                } else if rowTds.count >= 2 {
                    let key = rowTds[0].trimmingCharacters(in: CharacterSet(charactersIn: " :"))
                    let val = rowTds.dropFirst().joined(separator: "; ")
                    if !key.isEmpty && !val.isEmpty && key.count <= 36 && val.count <= 110 {
                        parsedRows.append([key, val])
                    }
                } else if caption == nil && rowThs.count == 1 && parsedRows.isEmpty && rowThs[0].count <= 48 {
                    caption = rowThs[0]
                }
            } else {
                if !rowThs.isEmpty && rowTds.isEmpty {
                    if parsedHeaders.isEmpty {
                        parsedHeaders = rowThs
                    }
                } else if !rowTds.isEmpty {
                    var fullRow = rowTds
                    if !rowThs.isEmpty {
                        fullRow.insert(rowThs[0], at: 0)
                    }
                    parsedRows.append(fullRow)
                }
            }
        }

        if isInfobox {
            if !parsedRows.isEmpty {
                tables.append(
                    WikiTableData(
                        id: "infobox_\(tables.count)",
                        sectionTitle: nil,
                        title: caption ?? "Quick Facts",
                        headers: ["Fact", "Detail"],
                        rows: Array(parsedRows.prefix(8))
                    )
                )
            }
            continue
        }

        let maxRowCols = parsedRows.map(\.count).max() ?? 0
        let targetCols = min(5, max(parsedHeaders.count, maxRowCols))
        let multiCellRows = parsedRows.filter { row in
            let nonEmptyCount = row.filter { !$0.isEmpty }.count
            return targetCols <= 1 ? nonEmptyCount >= 1 : nonEmptyCount >= 2
        }

        if !multiCellRows.isEmpty && targetCols >= 2 {
            if parsedHeaders.count < targetCols {
                if parsedHeaders.count == 1 && caption == nil {
                    caption = parsedHeaders[0]
                }
                parsedHeaders = targetCols == 2
                    ? ["Property", "Value"]
                    : (1...targetCols).map { "Column \($0)" }
            } else if parsedHeaders.count > targetCols {
                parsedHeaders = Array(parsedHeaders.prefix(targetCols))
            }
            let normalizedRows = multiCellRows.map { row -> [String] in
                if row.count >= targetCols {
                    return Array(row.prefix(targetCols))
                }
                return row + Array(repeating: "", count: targetCols - row.count)
            }
            tables.append(
                WikiTableData(
                    id: "table_\(tables.count)",
                    sectionTitle: sectionTitle,
                    title: caption,
                    headers: parsedHeaders,
                    rows: normalizedRows
                )
            )
        }
    }

    return tables
}

/// Cleans raw MediaWiki plain-text extract lines, collapsing indented MathML token dumps and stripping raw `{\displaystyle ...}` LaTeX fallback lines.
public func cleanWikipediaExtractLines(_ rawExtract: String) -> [String] {
    let rawLines = rawExtract.components(separatedBy: CharacterSet.newlines)
    var outLines: [String] = []
    var i = 0
    let n = rawLines.count

    while i < n {
        let line = rawLines[i]
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)

        // Detect MediaWiki indented <math> token dump or standalone {\displaystyle ...} line
        if trimmed.hasPrefix("{\\displaystyle") || (line.hasPrefix("  ") && (trimmed.isEmpty || trimmed.count <= 6)) {
            var tokens: [String] = []
            var sawDisplayStyle = trimmed.hasPrefix("{\\displaystyle")
            var lookahead = i
            while lookahead < n {
                let l = rawLines[lookahead]
                let t = l.trimmingCharacters(in: CharacterSet.whitespaces)
                if t.hasPrefix("{\\displaystyle") {
                    sawDisplayStyle = true
                    lookahead += 1
                    continue
                }
                if l.hasPrefix("  ") {
                    let cleanTok = t
                        .replacingOccurrences(of: "\u{2061}", with: "")
                        .replacingOccurrences(of: "\u{2062}", with: "")
                    if !cleanTok.isEmpty {
                        tokens.append(cleanTok)
                    }
                    lookahead += 1
                } else {
                    break
                }
            }
            if sawDisplayStyle || tokens.count >= 2 {
                i = lookahead
                let spacedTokens = tokens.map { tok -> String in
                    if ["=", "≈", "≠", "≤", "≥", "∈", "→", "↦"].contains(tok) {
                        return " \(tok) "
                    }
                    return tok
                }
                let formula = spacedTokens.joined().replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                if !formula.isEmpty {
                    if let last = outLines.last, !last.hasPrefix("==") {
                        outLines[outLines.count - 1] = last + " " + formula
                        // If the immediately following non-empty line continues the sentence (e.g. "where ..."), merge it too
                        while i < n && rawLines[i].trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                            i += 1
                        }
                        if i < n {
                            let nextLine = rawLines[i]
                            let nextTrimmed = nextLine.trimmingCharacters(in: CharacterSet.whitespaces)
                            if !nextTrimmed.isEmpty && !nextTrimmed.hasPrefix("==") {
                                let startsLower = nextTrimmed.first?.isLowercase ?? false
                                let startsPunct = [",", ".", ";", ":", ")", "is ", "where ", "and ", "with "].contains { nextTrimmed.hasPrefix($0) }
                                if nextLine.hasPrefix(" ") || startsLower || startsPunct {
                                    let sep = [",", ".", ";", ":", ")"].contains(where: { nextTrimmed.hasPrefix($0) }) ? "" : " "
                                    outLines[outLines.count - 1] += sep + nextTrimmed
                                    i += 1
                                }
                            }
                        }
                    } else {
                        outLines.append(formula)
                    }
                }
                continue
            }
        }

        if trimmed.isEmpty {
            i += 1
            continue
        }

        let cleanedLine = trimmed.replacingOccurrences(
            of: "\\{\\\\displaystyle[^\\}]*\\}",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: "\\s*\\([\\s,;]*\\)",
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: CharacterSet.whitespaces)

        if !cleanedLine.isEmpty {
            outLines.append(cleanedLine)
        }
        i += 1
    }
    return outLines
}

/// Splits a long paragraph into sentence-aligned chunks when needed so a single block never overflows a page.
internal func splitParagraphAtSentenceBoundary(_ text: String, maxChars: Int) -> (head: String, tail: String?) {
    guard text.count > maxChars, maxChars > 80 else {
        return (text, nil)
    }
    let prefixEnd = text.index(text.startIndex, offsetBy: min(text.count, maxChars))
    var searchEnd = prefixEnd
    let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "st", "jr", "sr", "inc", "ltd",
        "co", "corp", "vs", "v", "c", "ca", "no", "vol", "fig", "gen",
        "col", "lt", "sgt", "rev", "hon", "al", "ed", "est", "dept"
    ]

    while let dotRange = text[..<searchEnd].range(of: ". ", options: .backwards),
          text.distance(from: text.startIndex, to: dotRange.upperBound) >= maxChars / 3 {
        let beforeDot = text[..<dotRange.lowerBound]
        let lastWord = beforeDot.split(whereSeparator: { $0.isWhitespace || $0 == "(" }).last.map(String.init) ?? ""
        let lowerWord = lastWord.lowercased()
        let isAbbreviation = lastWord.count == 1
            || lastWord.contains(".")
            || abbreviations.contains(lowerWord)
        if !isAbbreviation {
            let head = String(text[..<dotRange.lowerBound]) + "."
            let tail = String(text[dotRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (head, tail.isEmpty ? nil : tail)
        }
        searchEnd = dotRange.lowerBound
    }

    let searchSlice = text[..<prefixEnd]
    if let spaceRange = searchSlice.range(of: " ", options: .backwards) {
        let head = String(text[..<spaceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(text[spaceRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (head, tail.isEmpty ? nil : tail)
    }

    let head = String(text[..<prefixEnd])
    let tail = String(text[prefixEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
    return (head, tail.isEmpty ? nil : tail)
}

/// Splits a full Wikipedia plain-text extract into discrete, ghosting-free E-Ink pages and section jump targets
/// using visual line-height budgeting so text, article figures, and tables never overflow the bottom of the reader card.
public func paginateWikipediaExtract(
    _ rawExtract: String,
    charsPerPage: Int = 1800,
    fontSize: Int = 16,
    leadImageURL: String? = nil,
    leadImageCaption: String = "",
    sectionImages: [Int: [(url: String, caption: String)]] = [:],
    sectionTables: [Int: [WikiTableData]] = [:],
    linkedTitles: [String] = [],
    isDisambiguation: Bool = false
) -> (pages: [WikiArticlePage], sections: [WikiSectionJump]) {
    let skipTitles: Set<String> = ["See also", "References", "External links", "Further reading", "Notes"]
    let lines = cleanWikipediaExtractLines(rawExtract)

    var rawSections: [(sectionID: Int, title: String, items: [(kind: WikiArticleBlock.Kind, text: String)])] = []
    var currentSectionID = 0
    var currentTitle = "Overview"
    var currentItems: [(kind: WikiArticleBlock.Kind, text: String)] = []

    func flushSection() {
        let nonEmpty = currentItems.filter { !$0.text.isEmpty }
        if !nonEmpty.isEmpty && !skipTitles.contains(currentTitle) {
            rawSections.append((sectionID: currentSectionID, title: currentTitle, items: nonEmpty))
        }
        currentItems.removeAll(keepingCapacity: true)
    }

    let knownLinksSet = Set(linkedTitles)

    for rawLine in lines {
        let trimmed = rawLine.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmed.isEmpty { continue }

        if trimmed.hasPrefix("==") && trimmed.hasSuffix("==") && trimmed.count > 4 {
            var eqCount = 0
            for ch in trimmed {
                if ch == "=" { eqCount += 1 } else { break }
            }
            let heading = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
            if !heading.isEmpty {
                if eqCount == 2 {
                    flushSection()
                    currentSectionID += 1
                    currentTitle = heading
                    continue
                } else if eqCount >= 3 {
                    currentItems.append((kind: .subheading, text: heading))
                    continue
                }
            }
        }

        if isDisambiguation, let link = parseDisambiguationLine(trimmed, knownLinks: knownLinksSet) {
            currentItems.append((kind: .linkItem(targetTitle: link.target, label: link.label, detail: link.detail), text: trimmed))
        } else {
            currentItems.append((kind: .paragraph, text: trimmed))
        }
    }
    flushSection()

    let charsPerLine = max(48, 80 - (fontSize - 16) * 4)
    let sideBySideCharsPerLine = max(32, Int(Double(charsPerLine) * 0.58))
    let maxVisualLines = max(18.0, 25.0 - Double(fontSize - 16) * 1.8)
    let hasLeadInfobox = sectionTables.values.flatMap { $0 }.contains(where: { $0.id.hasPrefix("infobox_") })
    let hasLeadImage = !(sectionImages[0] ?? []).isEmpty || !(leadImageURL ?? "").isEmpty
    let hasLeadInfocard = !isDisambiguation && (hasLeadInfobox || hasLeadImage)

    var pages: [WikiArticlePage] = []
    var jumps: [WikiSectionJump] = []
    var renderedImageKeys: Set<String> = []
    var pageBlocks: [WikiArticleBlock] = []
    var usedLines: Double = 0.0
    var activePageSectionTitle = "Overview"

    func canonicalImageKey(_ url: String) -> String {
        let clean = url.components(separatedBy: "?").first ?? url
        return clean.components(separatedBy: "/").last ?? clean
    }

    func visualLineCost(for kind: WikiArticleBlock.Kind, text: String, onLeadInfocardPage: Bool = false) -> Double {
        switch kind {
        case .subheading:
            return 2.2
        case .image:
            if onLeadInfocardPage {
                return 0.0
            }
            // Inline Wikipedia figure cards float on the right alongside adjacent paragraphs,
            // so their incremental vertical cost over the paired paragraphs is small.
            return 6.0
        case .paragraph:
            if onLeadInfocardPage {
                let infocardHeightLines = 19.5
                let narrowLinesLeft = max(0.0, infocardHeightLines - usedLines)
                let narrowCharCapacity = Int(narrowLinesLeft * Double(sideBySideCharsPerLine))
                if text.count <= narrowCharCapacity {
                    let wrappedLines = max(1.0, Double((text.count + sideBySideCharsPerLine - 1) / sideBySideCharsPerLine))
                    return wrappedLines + 0.8
                } else {
                    let fullWidthChars = max(0, text.count - narrowCharCapacity)
                    let fullWidthLines = Double((fullWidthChars + charsPerLine - 1) / charsPerLine)
                    return narrowLinesLeft + fullWidthLines + 0.8
                }
            }
            let wrappedLines = max(1.0, Double((text.count + charsPerLine - 1) / charsPerLine))
            return wrappedLines + 0.8
        case .linkItem(_, _, let detail):
            let detailLines = detail.isEmpty ? 0.0 : max(1.0, Double((detail.count + charsPerLine - 1) / charsPerLine))
            return 1.6 + detailLines
        case .table(let tbl):
            return Double(tbl.rows.count) * 2.8 + 5.0
        }
    }

    func flushPage() {
        guard !pageBlocks.isEmpty else { return }
        pages.append(
            WikiArticlePage(
                id: pages.count,
                sectionTitle: activePageSectionTitle,
                blocks: pageBlocks
            )
        )
        pageBlocks.removeAll(keepingCapacity: true)
        usedLines = 0.0
    }

    for (idx, sec) in rawSections.enumerated() {
        let isLeadInfocardPage = pages.isEmpty && hasLeadInfocard
        let currentMaxLines = isLeadInfocardPage ? max(18.0, maxVisualLines + 2.0) : maxVisualLines
        // A new section may start on the current page if there's room for its heading plus a few lines of text;
        // otherwise every section end would leave up to half a page empty.
        let canFlowOnCurrent = !pageBlocks.isEmpty && !isLeadInfocardPage && (isDisambiguation || currentMaxLines - usedLines >= 9.0)

        if canFlowOnCurrent {
            pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: .subheading, text: sec.title))
            usedLines += visualLineCost(for: .subheading, text: sec.title)
        } else {
            flushPage()
            activePageSectionTitle = sec.title
        }

        let startPage = pages.count
        jumps.append(WikiSectionJump(id: "\(startPage)_\(sec.title)", title: sec.title, startPage: startPage))

        var pendingQueue = sec.items
        var rawSecImages = sectionImages[sec.sectionID] ?? []
        if idx == 0, rawSecImages.isEmpty, let leadURL = leadImageURL, !leadURL.isEmpty {
            rawSecImages.append((url: leadURL, caption: leadImageCaption))
        }

        let allNonInfoboxTables = sectionTables.values
            .flatMap { $0 }
            .filter { !$0.id.hasPrefix("infobox_") }
        let sectionTitlesLower = Set(rawSections.map { $0.title.lowercased() })
        let rawSecTables: [WikiTableData] = {
            if let explicit = sectionTables[sec.sectionID], !explicit.isEmpty, sec.sectionID != 0 {
                return explicit.filter { !$0.id.hasPrefix("infobox_") }
            }
            return allNonInfoboxTables.filter { tbl in
                if let tSec = tbl.sectionTitle?.lowercased(), !tSec.isEmpty {
                    if tSec == sec.title.lowercased() { return true }
                    if idx == 0 && !sectionTitlesLower.contains(tSec) { return true }
                    return false
                }
                return idx == 0
            }
        }()
        for tbl in rawSecTables {
            let chunkSize = 4
            let totalRows = tbl.rows.count
            var chunkStart = 0
            var partIdx = 1
            let totalParts = max(1, (totalRows + chunkSize - 1) / chunkSize)
            while chunkStart < totalRows {
                let chunkEnd = min(totalRows, chunkStart + chunkSize)
                let slice = Array(tbl.rows[chunkStart..<chunkEnd])
                let partSuffix = totalParts > 1 ? " (Part \(partIdx)/\(totalParts))" : ""
                let title = (tbl.title ?? "Data Table") + partSuffix
                let chunkTable = WikiTableData(
                    id: "\(tbl.id)_\(partIdx)",
                    sectionTitle: sec.title,
                    title: title,
                    headers: tbl.headers,
                    rows: slice
                )
                pendingQueue.append((kind: .table(chunkTable), text: ""))
                chunkStart = chunkEnd
                partIdx += 1
            }
        }

        let secImagesList = rawSecImages.filter { img in
            let key = canonicalImageKey(img.url)
            return !renderedImageKeys.contains(key)
        }

        if secImagesList.count > 1 {
            var newQueue: [(kind: WikiArticleBlock.Kind, text: String)] = []
            let firstKey = canonicalImageKey(secImagesList[0].url)
            renderedImageKeys.insert(firstKey)
            newQueue.append((kind: .image(url: secImagesList[0].url), text: secImagesList[0].caption))
            let remainingImages = Array(secImagesList.dropFirst())
            let stride = max(1, pendingQueue.count / (remainingImages.count + 1))
            var imgIdx = 0
            for (pIdx, item) in pendingQueue.enumerated() {
                newQueue.append(item)
                if imgIdx < remainingImages.count && (pIdx + 1) % stride == 0 {
                    let rKey = canonicalImageKey(remainingImages[imgIdx].url)
                    renderedImageKeys.insert(rKey)
                    newQueue.append((kind: .image(url: remainingImages[imgIdx].url), text: remainingImages[imgIdx].caption))
                    imgIdx += 1
                }
            }
            while imgIdx < remainingImages.count {
                let rKey = canonicalImageKey(remainingImages[imgIdx].url)
                renderedImageKeys.insert(rKey)
                newQueue.append((kind: .image(url: remainingImages[imgIdx].url), text: remainingImages[imgIdx].caption))
                imgIdx += 1
            }
            pendingQueue = newQueue
        } else if let singleImg = secImagesList.first {
            let key = canonicalImageKey(singleImg.url)
            renderedImageKeys.insert(key)
            pendingQueue.insert((kind: .image(url: singleImg.url), text: singleImg.caption), at: 0)
        }

        while !pendingQueue.isEmpty {
            let item = pendingQueue.removeFirst()
            let onLeadInfocardPage = pages.isEmpty && hasLeadInfocard
            let activeMaxLines = onLeadInfocardPage ? max(18.0, maxVisualLines + 2.0) : maxVisualLines
            let activeCharsPerLine = onLeadInfocardPage ? sideBySideCharsPerLine : charsPerLine
            let pageAlreadyHasImage = pageBlocks.contains {
                if case .image = $0.kind { return true }
                return false
            }

            if case .image = item.kind {
                let cost = visualLineCost(for: item.kind, text: item.text, onLeadInfocardPage: onLeadInfocardPage && !pageAlreadyHasImage)
                if !pageBlocks.isEmpty && ((onLeadInfocardPage && pageAlreadyHasImage) || (usedLines + cost > activeMaxLines)) {
                    // The figure doesn't fit in what's left of this page. If body text follows, let it fill the gap
                    // first and carry the figure to the next page, instead of leaving the gap empty.
                    if activeMaxLines - usedLines >= 4.5, pendingQueue.first?.kind == .paragraph {
                        let paragraph = pendingQueue.removeFirst()
                        pendingQueue.insert(item, at: 0)
                        pendingQueue.insert(paragraph, at: 0)
                        continue
                    }
                    flushPage()
                    activePageSectionTitle = sec.title
                }
                let finalOnLead = pages.isEmpty && hasLeadInfocard
                pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: item.kind, text: item.text))
                usedLines += visualLineCost(for: item.kind, text: item.text, onLeadInfocardPage: finalOnLead)
                continue
            }

            if case .linkItem = item.kind {
                let cost = visualLineCost(for: item.kind, text: item.text)
                if !pageBlocks.isEmpty && (usedLines + cost > activeMaxLines) {
                    flushPage()
                    activePageSectionTitle = sec.title
                }
                pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: item.kind, text: item.text))
                usedLines += cost
                continue
            }

            if case .table = item.kind {
                let cost = visualLineCost(for: item.kind, text: item.text)
                if !pageBlocks.isEmpty && (usedLines + cost > activeMaxLines) {
                    flushPage()
                    activePageSectionTitle = sec.title
                }
                pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: item.kind, text: item.text))
                usedLines += cost
                continue
            }

            if item.kind == .subheading {
                // Never leave a subheading orphaned at the bottom of a page without room for at least 3 lines of text
                if !pageBlocks.isEmpty && (usedLines + 5.0 > activeMaxLines) {
                    flushPage()
                    activePageSectionTitle = sec.title
                }
                pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: .subheading, text: item.text))
                usedLines += visualLineCost(for: .subheading, text: item.text)
                continue
            }

            let cost = visualLineCost(for: .paragraph, text: item.text, onLeadInfocardPage: onLeadInfocardPage)
            if usedLines + cost <= activeMaxLines {
                pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: .paragraph, text: item.text))
                usedLines += cost
            } else {
                let remainingLines = activeMaxLines - usedLines - 0.8
                // If there is room for at least 4 lines on the current page, split the paragraph at a sentence boundary
                if remainingLines >= 4.0 && item.text.count > activeCharsPerLine * 4 {
                    let narrowLinesLeft = onLeadInfocardPage ? max(0.0, min(remainingLines, 19.5 - usedLines)) : 0.0
                    let fullWidthLinesLeft = max(0.0, remainingLines - narrowLinesLeft)
                    let maxHeadChars = Int(narrowLinesLeft) * sideBySideCharsPerLine + Int(fullWidthLinesLeft) * charsPerLine
                    let (head, tail) = splitParagraphAtSentenceBoundary(item.text, maxChars: maxHeadChars)
                    if let tail = tail, head.count >= activeCharsPerLine * 2 {
                        pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: .paragraph, text: head))
                        flushPage()
                        activePageSectionTitle = sec.title
                        pendingQueue.insert((kind: .paragraph, text: tail), at: 0)
                        continue
                    }
                }

                // If the current page only has a trailing subheading, carry that subheading to the new page
                if pageBlocks.last?.kind == .subheading && pageBlocks.count > 1 {
                    let trailingSub = pageBlocks.removeLast()
                    flushPage()
                    activePageSectionTitle = sec.title
                    pageBlocks.append(WikiArticleBlock(id: 0, kind: .subheading, text: trailingSub.text))
                    usedLines = visualLineCost(for: .subheading, text: trailingSub.text)
                    pendingQueue.insert(item, at: 0)
                    continue
                } else if !pageBlocks.isEmpty && !(pageBlocks.count == 1 && pageBlocks[0].kind == .subheading) {
                    flushPage()
                    activePageSectionTitle = sec.title
                    pendingQueue.insert(item, at: 0)
                    continue
                } else {
                    // Single paragraph exceeds a full page on its own — split it cleanly at a sentence boundary
                    let maxFullPageChars = max(charsPerLine * 6, Int(maxVisualLines - usedLines - 1.0) * charsPerLine)
                    let (head, tail) = splitParagraphAtSentenceBoundary(item.text, maxChars: maxFullPageChars)
                    pageBlocks.append(WikiArticleBlock(id: pageBlocks.count, kind: .paragraph, text: head))
                    flushPage()
                    activePageSectionTitle = sec.title
                    if let tail = tail {
                        pendingQueue.insert((kind: .paragraph, text: tail), at: 0)
                    }
                }
            }
        }
    }
    flushPage()

    if pages.isEmpty {
        pages.append(WikiArticlePage(id: 0, sectionTitle: "Overview", body: rawExtract))
    }
    return (pages, jumps)
}

/// Calculates the default character budget per row for section jump navigation buttons based on screen width.
public func defaultChapterRowCharBudget(screenWidth: Int = KindleScreen.width) -> Int {
    if screenWidth >= 1200 {
        // Modern 300ppi Kindles (Oasis 2/3, Paperwhite 11th, Scribe: 1236-1860px)
        return 82
    } else if screenWidth >= 1000 {
        // 300ppi Voyage / Paperwhite 3/4 / Oasis 1 (1072-1080px)
        return 68
    } else if screenWidth >= 750 {
        // 212ppi Paperwhite 1/2 (758-768px)
        return 54
    } else {
        // 167ppi Kindle Touch / Basic (600-800px)
        return 44
    }
}

/// Groups section jumps into horizontal rows based on actual character width so full section names are shown without premature ellipsis.
public func groupSectionsIntoHorizontalRows(_ sections: [WikiSectionJump], maxRowCharBudget: Int = defaultChapterRowCharBudget()) -> [[WikiSectionJump]] {
    guard !sections.isEmpty else { return [] }
    var rows: [[WikiSectionJump]] = []
    var currentRow: [WikiSectionJump] = []
    var currentCost = 0

    for sec in sections {
        // Button padding (12 left + 12 right = 24px) + spacing (8px) is equivalent to ~3 characters of text width
        let itemCost = sec.displayTitle.count + 3
        if !currentRow.isEmpty && (currentCost + itemCost > maxRowCharBudget) {
            rows.append(currentRow)
            currentRow = [sec]
            currentCost = itemCost
        } else {
            currentRow.append(sec)
            currentCost += itemCost
        }
    }
    if !currentRow.isEmpty {
        rows.append(currentRow)
    }
    return rows
}

public func parseWiktionaryExtractMetadata(from rawExtract: String) -> WiktionaryExtractMetadata {
    var meta = WiktionaryExtractMetadata()
    let lines = rawExtract.components(separatedBy: CharacterSet.newlines)
    var activeSubheading = ""
    var etymLines: [String] = []
    var pronLines: [String] = []
    var synLines: [String] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmed.isEmpty { continue }

        if trimmed.hasPrefix("==") && trimmed.hasSuffix("==") && trimmed.count > 4 {
            activeSubheading = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "= ")).lowercased()
            continue
        }

        if activeSubheading.hasPrefix("etymology") {
            if etymLines.count < 6 {
                etymLines.append(trimmed)
            }
        } else if activeSubheading.hasPrefix("pronunciation") {
            if pronLines.count < 5 {
                pronLines.append(trimmed)
            }
            if meta.ipaBadge == nil {
                if let slashStart = trimmed.firstIndex(of: "/"),
                   let slashEnd = trimmed[trimmed.index(after: slashStart)...].firstIndex(of: "/") {
                    let candidate = String(trimmed[slashStart...slashEnd])
                    if candidate.count >= 3 && candidate.count <= 40 {
                        meta.ipaBadge = candidate
                    }
                }
            }
        }

        if trimmed.hasPrefix("Synonyms:") || trimmed.hasPrefix("Antonyms:") || trimmed.hasPrefix("Derived terms:") {
            if synLines.count < 5 {
                synLines.append(trimmed)
            }
        }
    }

    meta.etymology = etymLines.joined(separator: "\n\n")
    meta.pronunciation = pronLines.joined(separator: "\n")
    meta.synonymsAndRelated = synLines
    return meta
}

/// Paginates Wiktionary definitions (5 senses per page) and etymology/notes so no scrolling is needed.
public func paginateWiktionaryEntry(
    headword: String,
    entries: [WiktionaryPartOfSpeechEntry],
    metadata: WiktionaryExtractMetadata
) -> [WiktionaryReaderPage] {
    var pages: [WiktionaryReaderPage] = []
    let sensesPerPage = 4

    for entry in entries {
        var rows: [WiktionaryReaderPage.SenseRow] = []
        for (idx, def) in entry.definitions.prefix(12).enumerated() {
            let related = def.linkedWords.filter { $0.caseInsensitiveCompare(headword) != .orderedSame }
            rows.append(
                WiktionaryReaderPage.SenseRow(
                    id: idx,
                    number: idx + 1,
                    text: def.cleanDefinition,
                    examples: def.cleanExamples,
                    relatedWords: Array(related.prefix(4))
                )
            )
        }

        var start = 0
        while start < rows.count {
            let end = min(rows.count, start + sensesPerPage)
            let slice = Array(rows[start..<end])
            pages.append(
                WiktionaryReaderPage(
                    id: pages.count,
                    kind: .definitions(
                        partOfSpeech: entry.partOfSpeech,
                        language: entry.language,
                        senses: slice
                    )
                )
            )
            start = end
        }
    }

    if !metadata.etymology.isEmpty || !metadata.synonymsAndRelated.isEmpty {
        let body = metadata.etymology.isEmpty ? metadata.pronunciation : metadata.etymology
        pages.append(
            WiktionaryReaderPage(
                id: pages.count,
                kind: .notes(
                    heading: "Etymology & Linguistic Notes",
                    body: body,
                    bullets: metadata.synonymsAndRelated
                )
            )
        )
    }

    return pages
}

/// Splits any array into fixed-size pages for `KindlePager`.
public func chunkIntoPages<T>(_ items: [T], pageSize: Int) -> [[T]] {
    let size = max(1, pageSize)
    guard !items.isEmpty else { return [] }
    var out: [[T]] = []
    var idx = 0
    while idx < items.count {
        let end = min(items.count, idx + size)
        out.append(Array(items[idx..<end]))
        idx = end
    }
    return out
}

/// The "Back" trail inside the Wikipedia reader. It only records articles the reader followed a link *from*;
/// opening an article from outside the reader (home, search results, history, bookmarks) starts a fresh trail,
/// so Back then returns to where the reader was opened instead of to the article read before.
