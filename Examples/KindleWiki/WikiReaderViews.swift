import Foundation
import KindleUI

extension KindleWikiRootView {
    // MARK: - Dedicated E-Ink Loading Display

    internal enum WikiReaderDisplayRow: Identifiable {
        case single(WikiArticleBlock)
        case sideBySide(
            id: String,
            paragraphs: [String],
            imageURL: String?,
            imageCaption: String,
            infobox: WikiTableData?
        )

        var id: String {
            switch self {
            case .single(let b): return "single_\(b.id)"
            case .sideBySide(let id, _, _, _, _): return id
            }
        }
    }

    internal func buildReaderDisplayRows(for page: WikiArticlePage, pageIndex: Int) -> [WikiReaderDisplayRow] {
        let infobox: WikiTableData? = (pageIndex == 0)
            ? activeArticleTables.values.flatMap({ $0 }).first(where: { $0.id.hasPrefix("infobox_") })
            : nil

        var rows: [WikiReaderDisplayRow] = []
        var usedInfobox = false
        var i = 0
        let blocks = page.blocks
        let isLeadPage = (pageIndex == 0)
        let infoboxLineCount: Int = {
            guard let infobox = infobox else { return 0 }
            let rows = displayedInfoboxRows(infobox, hasImage: true)
            return rows.reduce(0) { acc, r in
                let kLines = max(1, (r[0].count + 13) / 14)
                let vLines = min(3, max(1, ((r.count > 1 ? r[1].count : 0) + 23) / 24))
                return acc + max(kLines, vLines)
            }
        }()
        let maxPairedChars = isLeadPage ? max(780, min(980, 580 + infoboxLineCount * 32)) : 680

        while i < blocks.count {
            let block = blocks[i]
            if case .image(let url) = block.kind {
                let caption = block.text
                var pairedParagraphs: [String] = []
                var remainderParagraph: String? = nil
                var charCount = 0
                var j = i + 1

                while j < blocks.count, pairedParagraphs.count < 3, charCount < maxPairedChars {
                    if case .paragraph = blocks[j].kind {
                        let pText = blocks[j].text
                        if charCount + pText.count <= maxPairedChars + 80 {
                            pairedParagraphs.append(pText)
                            charCount += pText.count
                            j += 1
                        } else if maxPairedChars - charCount >= 140 {
                            let (head, tail) = splitParagraphAtSentenceBoundary(pText, maxChars: max(200, maxPairedChars + 60 - charCount))
                            pairedParagraphs.append(head)
                            remainderParagraph = tail
                            charCount += head.count
                            j += 1
                            break
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }

                // If no paragraphs followed the image on this page, pair with the preceding paragraph if available
                if pairedParagraphs.isEmpty,
                   let lastRow = rows.last,
                   case .single(let prevBlock) = lastRow,
                   case .paragraph = prevBlock.kind {
                    rows.removeLast()
                    pairedParagraphs.append(prevBlock.text)
                }

                let attachedInfobox: WikiTableData? = (!usedInfobox && pageIndex == 0) ? infobox : nil
                if attachedInfobox != nil { usedInfobox = true }

                rows.append(
                    .sideBySide(
                        id: "sbs_\(page.id)_\(block.id)",
                        paragraphs: pairedParagraphs,
                        imageURL: url,
                        imageCaption: caption,
                        infobox: attachedInfobox
                    )
                )
                if let rem = remainderParagraph, !rem.isEmpty {
                    rows.append(.single(WikiArticleBlock(id: block.id * 1000 + 999, kind: .paragraph, text: rem)))
                }
                i = j
                continue
            }

            rows.append(.single(block))
            i += 1
        }

        // If Page 0 has an infobox but had no image block on Page 0, pair the infobox with all paragraphs on Page 0
        if pageIndex == 0, !usedInfobox, let infobox = infobox {
            var paired: [String] = []
            var remainingRows: [WikiReaderDisplayRow] = []
            for r in rows {
                if case .single(let b) = r, case .paragraph = b.kind {
                    paired.append(b.text)
                } else {
                    remainingRows.append(r)
                }
            }
            if !paired.isEmpty {
                remainingRows.insert(
                    .sideBySide(
                        id: "sbs_infobox_\(page.id)",
                        paragraphs: paired,
                        imageURL: nil,
                        imageCaption: "",
                        infobox: infobox
                    ),
                    at: 0
                )
                rows = remainingRows
            }
        }

        return rows
    }

    internal func displayedInfoboxRows(_ infobox: WikiTableData, hasImage: Bool) -> [[String]] {
        let maxRows = hasImage ? 5 : 6
        let maxVisualLines = hasImage ? 11 : 16
        var result: [[String]] = []
        var usedLines = 0
        for row in infobox.rows {
            guard !row.isEmpty else { continue }
            if result.count >= maxRows { break }
            let key = row[0]
            let val = compactPreview(row.count > 1 ? row[1] : "", maxChars: 88)
            let keyLines = max(1, (key.count + 13) / 14)
            let valLines = min(3, max(1, (val.count + 23) / 24))
            let rowLines = max(keyLines, valLines)
            if !result.isEmpty && (usedLines + rowLines > maxVisualLines) {
                break
            }
            result.append([key, val])
            usedLines += rowLines
        }
        return result
    }

    @ViewBuilder
    internal func renderWikipediaInfocard(
        imageURL: String?,
        imageCaption: String,
        infobox: WikiTableData?,
        theme: KindleTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let infobox = infobox {
                HStack(alignment: .center, spacing: 8) {
                    Icon(.book, size: 18)
                        .foregroundColor(theme.foreground)
                    Text(infobox.title ?? activeArticleTitle)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)
                        .lineLimit(1)
                    Spacer()
                }
                Divider(thickness: 1, color: theme.subtleBorder)
            }

            if let url = imageURL {
                VStack(alignment: .center, spacing: 8) {
                    AsyncImage(
                        url: url,
                        altText: imageCaption.isEmpty ? activeArticleTitle : imageCaption,
                        width: 400,
                        height: infobox != nil ? 175 : 230
                    )
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .background(theme.cardBackground, in: .rect(cornerRadius: 12))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 12), lineWidth: 1)

                    if !imageCaption.isEmpty {
                        Text(compactPreview(imageCaption, maxChars: 135))
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundColor(theme.foreground)
                            .lineWrap(true)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Icon(.search, size: 16)
                            .foregroundColor(theme.mutedForeground)
                        Text("Tap figure to enlarge")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.mutedForeground)
                    }
                }
                .onTapGesture {
                    enlargedImageURL = url
                    enlargedImageCaption = imageCaption
                    showImageDetail = true
                }
            }

            if let infobox = infobox {
                let visibleRows = displayedInfoboxRows(infobox, hasImage: imageURL != nil)
                if !visibleRows.isEmpty {
                    if imageURL != nil {
                        Divider(thickness: 1, color: theme.subtleBorder)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<visibleRows.count, id: \.self) { rIdx in
                            let row = visibleRows[rIdx]
                            HStack(alignment: .top, spacing: 10) {
                                Text(row[0])
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(theme.mutedForeground)
                                    .lineWrap(true)
                                    .frame(width: 146, alignment: .topLeading)
                                Text(row.count > 1 ? row[1] : "")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundColor(theme.foreground)
                                    .lineWrap(true)
                                    .lineLimit(3)
                                    .frame(alignment: .topLeading)
                                    .expand(true, fill: true)
                            }
                            if rIdx < visibleRows.count - 1 {
                                Divider(thickness: 1, color: theme.subtleBorder)
                            }
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(theme.panelBackground, in: .rect(cornerRadius: 16))
        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
        .frame(width: 484)
    }

    @ViewBuilder
    internal func renderSingleWikipediaBlock(_ block: WikiArticleBlock, theme: KindleTheme) -> some View {
        switch block.kind {
        case .subheading:
            Text(block.text)
                .font(.system(size: readerFontSize + 4, weight: .bold, design: .serif))
                .foregroundColor(theme.foreground)
                .padding(EdgeInsets(top: 10, leading: 0, bottom: 4, trailing: 0))

        case .image(let url):
            renderWikipediaInfocard(
                imageURL: url,
                imageCaption: block.text,
                infobox: nil,
                theme: theme
            )

        case .paragraph:
            Text(block.text)
                .font(.bookerly(size: readerFontSize))
                .foregroundColor(theme.foreground)
                .lineWrap(true)
                .frame(maxWidth: .infinity)

        case .linkItem(let targetTitle, let label, let detail):
            Button(action: {
                openWikipediaReader(title: targetTitle)
            }) {
                HStack(alignment: .center, spacing: 16) {
                    Icon(.book, size: 22)
                        .foregroundColor(theme.foreground)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: readerFontSize, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                            .lineLimit(1)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: max(12, readerFontSize - 2), weight: .regular))
                                .foregroundColor(theme.mutedForeground)
                                .lineWrap(true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Icon(.chevronRight, size: 20)
                        .foregroundColor(theme.mutedForeground)
                }
                .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)

        case .table(let tbl):
            let maxRowCols = tbl.rows.map(\.count).max() ?? 0
            let colLimit = min(max(tbl.headers.count, maxRowCols), 5)
            if colLimit > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    if let title = tbl.title, !title.isEmpty {
                        HStack(spacing: 8) {
                            Icon(.document, size: 18)
                                .foregroundColor(theme.mutedForeground)
                            Text(title)
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundColor(theme.foreground)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                        .background(theme.panelBackground)
                        Divider(thickness: 1, color: theme.border)
                    }

                    HStack(spacing: 12) {
                        ForEach(0..<colLimit, id: \.self) { cIdx in
                            let headerText = (cIdx < tbl.headers.count) ? tbl.headers[cIdx] : "Col \(cIdx + 1)"
                            Text(headerText)
                                .lineLimit(1)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .background(theme.panelBackground)

                    Divider(thickness: 1, color: theme.border)

                    ForEach(0..<tbl.rows.count, id: \.self) { rIdx in
                        let row = tbl.rows[rIdx]
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(0..<colLimit, id: \.self) { cIdx in
                                let cellText = (cIdx < row.count) ? row[cIdx] : ""
                                Text(cellText)
                                    .lineWrap(true)
                                    .lineLimit(2)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.foreground)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                        .background((rIdx % 2 == 1) ? theme.panelBackground : theme.cardBackground)

                        if rIdx < tbl.rows.count - 1 {
                            Divider(thickness: 1, color: theme.subtleBorder)
                        }
                    }
                }
                .background(theme.cardBackground, in: .rect(cornerRadius: 14))
                .overlay(theme.subtleBorder, in: .rect(cornerRadius: 14), lineWidth: 1)
                .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            }
        }
    }

    // MARK: - Enlarged Image Inspector Dialog / Sheet

    @ViewBuilder
    internal func enlargedImageView(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Balanced Header Bar
            HStack(alignment: .center, spacing: 18) {
                Button(action: { showImageDetail = false }) {
                    HStack(spacing: 8) {
                        Icon(.chevronLeft, size: 20)
                        Text("Back to Article")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Text(activeArticleTitle.isEmpty ? "Figure Inspector" : activeArticleTitle)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                Spacer()

                Button(action: { showImageDetail = false }) {
                    HStack(spacing: 8) {
                        Icon(.close, size: 20)
                        Text("Close")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(12)
            .background(theme.panelBackground, in: .rect(cornerRadius: 28))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 28), lineWidth: 1)

            // Centered Image Card
            if let imgURL = enlargedImageURL {
                VStack(alignment: .center, spacing: 20) {
                    Spacer()

                    AsyncImage(
                        url: imgURL,
                        altText: enlargedImageCaption.isEmpty ? activeArticleTitle : enlargedImageCaption,
                        width: 1280,
                        height: 1020
                    )
                    .padding(14)
                    .background(theme.cardBackground, in: .rect(cornerRadius: 20))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 20), lineWidth: 1)

                    if !enlargedImageCaption.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Text(enlargedImageCaption)
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundColor(theme.foreground)
                                .lineWrap(true)
                                .multilineTextAlignment(.center)
                        }
                        .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
                        .background(theme.panelBackground, in: .rect(cornerRadius: 16))
                        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
                        .frame(maxWidth: 1280)
                    }

                    Text("Tap anywhere or tap Back to return to reading")
                        .font(.caption)
                        .foregroundColor(theme.mutedForeground)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 18, leading: 32, bottom: 18, trailing: 32))
        .background(theme.background)
        .expand(true, fill: true)
        .onTapGesture {
            showImageDetail = false
        }
    }

    // MARK: - Reading Appearance (Aa) & Language Selector Sheets

    @ViewBuilder
    internal func typographySheetView(theme: KindleTheme) -> some View {
        let isDark = isDarkMode
        let presets: [(label: String, size: Int)] = [
            ("14pt · Compact", 14),
            ("16pt · Standard", 16),
            ("19pt · Large", 19),
            ("22pt · X-Large", 22)
        ]

        VStack(alignment: .leading, spacing: 22) {
            // Font Size Stepper & Presets
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Icon(.book, size: 24)
                        .foregroundColor(theme.foreground)
                    Text("Bookerly Reading Type Size")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)
                    Spacer()
                    Text("\(readerFontSize) pt")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(theme.mutedForeground)
                }

                HStack(alignment: .center, spacing: 18, homogeneous: true) {
                    Button(action: {
                        readerFontSize = max(13, readerFontSize - 1)
                        rebuildWikipediaPagination()
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.minus, size: 20)
                            Text("A−  Smaller")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(readerFontSize <= 13)

                    Button(action: {
                        readerFontSize = min(24, readerFontSize + 1)
                        rebuildWikipediaPagination()
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.plus, size: 20)
                            Text("A+  Larger")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(readerFontSize >= 24)
                }

                HStack(alignment: .center, spacing: 14, homogeneous: true) {
                    ForEach(0..<presets.count, id: \.self) { idx in
                        let preset = presets[idx]
                        let isSelected = (readerFontSize == preset.size)
                        Button(preset.label) {
                            readerFontSize = preset.size
                            rebuildWikipediaPagination()
                        }
                        .buttonStyle(isSelected ? .borderedProminent : .bordered)
                        .controlSize(.regular)
                    }
                }
            }

            Divider(thickness: 1, color: theme.subtleBorder)

            // E-Ink Display Contrast Theme
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    Icon(isDark ? .moon : .sun, size: 24)
                        .foregroundColor(theme.foreground)
                    Text("E-Ink Display Theme")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)
                    Spacer()
                }

                HStack(alignment: .center, spacing: 18, homogeneous: true) {
                    Button(action: {
                        isDarkMode = false
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.sun, size: 22)
                            Text("Light Paper Mode")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(!isDark ? .borderedProminent : .bordered)
                    .controlSize(.regular)

                    Button(action: {
                        isDarkMode = true
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.moon, size: 22)
                            Text("Dark Night Mode")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .buttonStyle(isDark ? .borderedProminent : .bordered)
                    .controlSize(.regular)
                }
            }

            // Live Typography Sample Box
            VStack(alignment: .leading, spacing: 6) {
                Text("Typography Preview (\(readerFontSize)pt Bookerly)")
                    .font(.caption)
                    .foregroundColor(theme.mutedForeground)
                Text("Electronic paper reflects ambient light like ordinary ink on paper, providing crisp, glare-free reading comfort.")
                    .font(.bookerly(size: readerFontSize))
                    .foregroundColor(theme.foreground)
                    .lineWrap(true)
                    .lineLimit(2)
            }
            .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
            .background(theme.panelBackground, in: .rect(cornerRadius: 16))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
        }
        .expand(false, fill: true)
    }

    @ViewBuilder
    internal func languageSelectorSheetView(theme: KindleTheme) -> some View {
        let langPairs = chunkIntoPages(Array(wiktLanguageOrder.prefix(12)), pageSize: 2)

        VStack(alignment: .leading, spacing: 18) {
            Text("Choose which language section to display for “\(activeWord)”:")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(theme.mutedForeground)

            Button(action: {
                selectedWiktLang = "ALL"
                wiktPageIndex = 0
                showLanguageSheet = false
            }) {
                HStack(alignment: .center, spacing: 14) {
                    Icon(.globe, size: 22)
                    Text("All Languages (\(wiktLanguageOrder.count))")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                    Spacer()
                    if selectedWiktLang == "ALL" {
                        Icon(.check, size: 20)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            }
            .buttonStyle(selectedWiktLang == "ALL" ? .borderedProminent : .bordered)
            .controlSize(.regular)

            ForEach(0..<langPairs.count, id: \.self) { rowIdx in
                let pair = langPairs[rowIdx]
                HStack(alignment: .center, spacing: 16, homogeneous: true) {
                    ForEach(pair, id: \.self) { langCode in
                        let entries = wiktDefinitionsByLang[langCode] ?? []
                        let langName = entries.first?.language ?? langCode.uppercased()
                        let isSelected = (selectedWiktLang == langCode)
                        Button(action: {
                            selectedWiktLang = langCode
                            wiktPageIndex = 0
                            showLanguageSheet = false
                        }) {
                            HStack(alignment: .center, spacing: 10) {
                                Text(langName)
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entries.count) POS")
                                    .font(.caption)
                            }
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        }
                        .buttonStyle(isSelected ? .borderedProminent : .bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
        .expand(false, fill: true)
    }

    // MARK: - Full-Screen Cover Reader (Covers Entire Window Including Bottom Bar)

    @ViewBuilder
    internal func fullScreenReaderView(theme: KindleTheme) -> some View {
        switch activeReaderKind {
        case .wikipedia:
            fullScreenWikipediaReader(theme: theme)
        case .wiktionary:
            fullScreenWiktionaryReader(theme: theme)
        }
    }

    @ViewBuilder
    internal func fullScreenWikipediaReader(theme: KindleTheme) -> some View {
        let saved = isEntrySaved(title: activeArticleTitle, kind: .wikipedia)
        let pages = wikiPages.isEmpty
            ? [WikiArticlePage(id: 0, sectionTitle: "Overview", body: activeArticleRawExtract)]
            : wikiPages

        VStack(alignment: .leading, spacing: 14) {
            // Top Reader Navigation Toolbar — Generous Touch Spacing & Unclustered Controls
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Button(action: {
                        if let prev = wikiReaderHistoryStack.popPrevious() {
                            loadWikipediaArticle(title: prev)
                        } else {
                            isReaderPresented = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Icon(.chevronLeft, size: 20)
                            Text("Back")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    if wikiSections.count > 1 {
                        Button(action: {
                            showChaptersModal = true
                        }) {
                            HStack(spacing: 8) {
                                Icon(.document, size: 20)
                                Text("Contents (\(wikiSections.count))")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                Spacer()

                HStack(alignment: .center, spacing: 14) {
                    Button(action: {
                        showTypographySheet = true
                    }) {
                        HStack(spacing: 8) {
                            Icon(.sliders, size: 20)
                            Text("Aa  \(readerFontSize)pt")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: {
                        openWiktionaryReader(word: activeArticleTitle)
                    }) {
                        HStack(spacing: 6) {
                            Icon(.document, size: 20)
                            Text("Wiktionary")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    let offlineReady = WikiReadingStore.shared.hasOffline(activeArticleTitle)
                    Button(action: {
                        toggleOfflineArticle(title: activeArticleTitle)
                    }) {
                        HStack(spacing: 6) {
                            Icon(offlineReady ? .check : .cloud, size: 20)
                            Text(offlineReady ? "Offline" : "Download")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(offlineReady ? .borderedProminent : .bordered)
                    .controlSize(.regular)

                    Button(action: {
                        toggleSaveEntry(title: activeArticleTitle, subtitle: activeArticleDescription, kind: .wikipedia)
                    }) {
                        HStack(spacing: 6) {
                            Icon(saved ? .bookmarkFill : .bookmark, size: 20)
                            Text(saved ? "Saved" : "Save")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(saved ? .borderedProminent : .bordered)
                    .controlSize(.regular)
                }
            }
            .padding(12)
            .background(theme.panelBackground, in: .rect(cornerRadius: 28))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 28), lineWidth: 1)

            if wikiLoading {
                loadingDisplay(
                    title: "Loading Article",
                    subtitle: activeArticleTitle.isEmpty
                        ? "Discovering a surprise article from Wikipedia…"
                        : "Fetching full article extract and figures for “\(activeArticleTitle)”…",
                    icon: .book,
                    theme: theme
                )
            } else if let error = wikiError {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()

                    VStack(alignment: .center, spacing: 22) {
                        VStack(alignment: .center, spacing: 0) {
                            Spacer()
                            Icon(.warning, size: 48)
                                .foregroundColor(theme.foreground)
                            Spacer()
                        }
                        .frame(width: 92, height: 92)
                        .background(theme.cardBackground, in: .rect(cornerRadius: 46))
                        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 46), lineWidth: 1)

                        Text("Article Unavailable")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                            .multilineTextAlignment(.center)

                        Text(error)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(theme.mutedForeground)
                            .multilineTextAlignment(.center)
                            .lineWrap(true)

                        HStack(alignment: .center, spacing: 20) {
                            Button("← Back") {
                                isReaderPresented = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button("Retry Loading") {
                                loadWikipediaArticle(title: activeArticleTitle)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .padding(.top, 6)
                    }
                    .padding(EdgeInsets(top: 40, leading: 44, bottom: 44, trailing: 44))
                    .background(theme.panelBackground, in: .rect(cornerRadius: 24))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 24), lineWidth: 1)
                    .frame(width: 920)

                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                KindlePager(pages: pages, currentPage: readingPageBinding) { idx, page in
                    VStack(alignment: .leading, spacing: 14) {
                        if idx == 0 {
                            // Article Title Banner on Page 0
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activeArticleTitle)
                                    .font(.system(size: 28, weight: .bold, design: .serif))
                                    .foregroundColor(theme.foreground)
                                if !activeArticleDescription.isEmpty {
                                    Text(activeArticleDescription)
                                        .font(.system(size: 15, weight: .regular, design: .serif))
                                        .foregroundColor(theme.mutedForeground)
                                        .lineWrap(true)
                                }
                                Divider(thickness: 1, color: theme.subtleBorder)
                            }
                            .padding(.bottom, 6)
                        } else {
                            // Running Header on subsequent pages
                            HStack(alignment: .center, spacing: 12) {
                                Text(activeArticleTitle)
                                    .font(.system(size: 14, weight: .bold, design: .serif))
                                    .foregroundColor(theme.mutedForeground)
                                    .lineLimit(1)
                                Spacer()
                                Text(page.sectionTitle)
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .foregroundColor(theme.mutedForeground)
                                    .lineLimit(1)
                            }
                            Divider(thickness: 1, color: theme.subtleBorder)
                        }

                        let displayRows = buildReaderDisplayRows(for: page, pageIndex: idx)
                        ForEach(displayRows) { displayRow in
                            switch displayRow {
                            case .single(let block):
                                renderSingleWikipediaBlock(block, theme: theme)

                            case .sideBySide(_, let paragraphs, let imageURL, let imageCaption, let infobox):
                                if paragraphs.isEmpty {
                                    HStack(alignment: .top, spacing: 0) {
                                        Spacer()
                                        renderWikipediaInfocard(
                                            imageURL: imageURL,
                                            imageCaption: imageCaption,
                                            infobox: infobox,
                                            theme: theme
                                        )
                                        Spacer()
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 24) {
                                        VStack(alignment: .leading, spacing: 14) {
                                            ForEach(0..<paragraphs.count, id: \.self) { pIdx in
                                                Text(paragraphs[pIdx])
                                                    .font(.bookerly(size: readerFontSize))
                                                    .foregroundColor(theme.foreground)
                                                    .lineWrap(true)
                                                    .frame(maxWidth: .infinity)
                                            }
                                        }
                                        .expand(true, fill: true)

                                        renderWikipediaInfocard(
                                            imageURL: imageURL,
                                            imageCaption: imageCaption,
                                            infobox: infobox,
                                            theme: theme
                                        )
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
                    .background(theme.cardBackground, in: .rect(cornerRadius: 20))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 20), lineWidth: 1)
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }

    @ViewBuilder
    internal func horizontalChaptersBar(pages: [WikiArticlePage]) -> some View {
        let currentSectionTitle = pages[min(pages.count - 1, max(0, wikiPageIndex))].sectionTitle
        let rows = groupSectionsIntoHorizontalRows(wikiSections)
        let totalRows = max(1, rows.count)
        let autoRowIndex = rows.firstIndex(where: { row in
            row.contains(where: { $0.title == currentSectionTitle })
        }) ?? 0
        let activeRowIndex = (wikiChapterWindowStart >= 0 && wikiChapterWindowStart < totalRows)
            ? wikiChapterWindowStart
            : autoRowIndex
        let visibleSections = rows.isEmpty ? wikiSections : rows[activeRowIndex]

        HStack(alignment: .center, spacing: 14) {
            if totalRows > 1 {
                Button("‹") {
                    wikiChapterWindowStart = max(0, activeRowIndex - 1)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(activeRowIndex == 0)
            }

            ForEach(visibleSections) { sec in
                let isCurrent = (sec.title == currentSectionTitle)
                Button(sec.displayTitle) {
                    wikiPageIndex = sec.startPage
                    wikiChapterWindowStart = -1
                    recordReadingProgress()
                }
                .buttonStyle(isCurrent ? .borderedProminent : .bordered)
                .controlSize(.regular)
            }

            Spacer()

            if totalRows > 1 {
                Badge("Row \(activeRowIndex + 1)/\(totalRows)")

                Button("›") {
                    wikiChapterWindowStart = min(totalRows - 1, activeRowIndex + 1)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(activeRowIndex >= totalRows - 1)
            }
        }
    }

    @ViewBuilder
    internal func chaptersModalView(theme: KindleTheme) -> some View {
        let pages = wikiPages.isEmpty
            ? [WikiArticlePage(id: 0, sectionTitle: "Overview", body: activeArticleRawExtract)]
            : wikiPages
        let currentSectionTitle = pages[min(pages.count - 1, max(0, wikiPageIndex))].sectionTitle
        let tocPageSize = 14
        let sectionPages = chunkIntoPages(wikiSections, pageSize: tocPageSize)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Icon(.document, size: 28)
                        .foregroundColor(theme.foreground)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Table of Contents")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                        Text("“\(activeArticleTitle)” · \(wikiSections.count) Sections · \(pages.count) Pages")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(theme.mutedForeground)
                    }
                }

                Spacer()

                Button("Done ✕") {
                    showChaptersModal = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 12))
            .background(theme.panelBackground, in: .rect(cornerRadius: 28))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 28), lineWidth: 1)

            if sectionPages.isEmpty {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    ContentUnavailableView(
                        "No Chapters",
                        icon: .document,
                        description: "This article contains a single continuous overview."
                    )
                    .frame(width: 920)
                    Spacer()
                }
                .expand(true, fill: true)
            } else if sectionPages.count == 1 {
                let pageSections = sectionPages[0]
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<pageSections.count, id: \.self) { itemIdx in
                        let sec = pageSections[itemIdx]
                        let sectionNum = itemIdx + 1
                        let isCurrent = (sec.title == currentSectionTitle)
                        let itemForeground = isCurrent ? theme.background : theme.foreground
                        let itemIconColor = isCurrent ? theme.background : theme.mutedForeground
                        Button(action: {
                            wikiPageIndex = sec.startPage
                            wikiChapterWindowStart = -1
                            recordReadingProgress()
                            showChaptersModal = false
                        }) {
                            HStack(alignment: .center, spacing: 14) {
                                Icon(isCurrent ? .check : .book, size: 20)
                                    .foregroundColor(itemIconColor)
                                Text("\(sectionNum).  \(sec.title)")
                                    .font(.system(size: 16, weight: isCurrent ? .bold : .medium, design: .serif))
                                    .foregroundColor(itemForeground)
                                    .lineLimit(1)
                                Spacer()
                                if isCurrent {
                                    Text("Current · Page \(sec.startPage + 1)")
                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                        .foregroundColor(theme.background)
                                } else {
                                    Text("Page \(sec.startPage + 1)")
                                        .font(.system(size: 14, weight: .regular, design: .serif))
                                        .foregroundColor(theme.mutedForeground)
                                }
                            }
                            .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                        .buttonStyle(isCurrent ? .borderedProminent : .bordered)
                        .controlSize(.regular)
                    }
                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                KindlePager(pages: sectionPages, currentPage: $chaptersModalPage) { pageIdx, pageSections in
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<pageSections.count, id: \.self) { itemIdx in
                            let sec = pageSections[itemIdx]
                            let sectionNum = pageIdx * tocPageSize + itemIdx + 1
                            let isCurrent = (sec.title == currentSectionTitle)
                            let itemForeground = isCurrent ? theme.background : theme.foreground
                            let itemIconColor = isCurrent ? theme.background : theme.mutedForeground
                            Button(action: {
                                wikiPageIndex = sec.startPage
                                wikiChapterWindowStart = -1
                                recordReadingProgress()
                                showChaptersModal = false
                            }) {
                                HStack(alignment: .center, spacing: 14) {
                                    Icon(isCurrent ? .check : .book, size: 20)
                                        .foregroundColor(itemIconColor)
                                    Text("\(sectionNum).  \(sec.title)")
                                        .font(.system(size: 16, weight: isCurrent ? .bold : .medium, design: .serif))
                                        .foregroundColor(itemForeground)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(isCurrent ? "Current · Page \(sec.startPage + 1)" : "Page \(sec.startPage + 1)")
                                        .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .serif))
                                        .foregroundColor(isCurrent ? theme.background : theme.mutedForeground)
                                }
                                .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            }
                            .buttonStyle(isCurrent ? .borderedProminent : .bordered)
                            .controlSize(.regular)
                        }
                        Spacer()
                    }
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
        .background(theme.background)
        .expand(true, fill: true)
    }

    @ViewBuilder
    internal func fullScreenWiktionaryReader(theme: KindleTheme) -> some View {
        let saved = isEntrySaved(title: activeWord, kind: .wiktionary)
        let currentEntries = currentLanguageEntries
        let pages = paginateWiktionaryEntry(
            headword: activeWord,
            entries: currentEntries,
            metadata: wiktMetadata
        )

        VStack(alignment: .leading, spacing: 14) {
            // Top Reader Bar — Generous Touch Spacing
            HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Button(action: {
                        isReaderPresented = false
                    }) {
                        HStack(spacing: 8) {
                            Icon(.chevronLeft, size: 20)
                            Text("Back")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    if wiktLanguageOrder.count > 1 {
                        Button(action: {
                            showLanguageSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Icon(.globe, size: 20)
                                Text("Languages (\(wiktLanguageOrder.count))")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                Spacer()

                HStack(alignment: .center, spacing: 14) {
                    Button(action: {
                        showTypographySheet = true
                    }) {
                        HStack(spacing: 8) {
                            Icon(.sliders, size: 20)
                            Text("Aa  \(readerFontSize)pt")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: {
                        openWikipediaReader(title: activeWord)
                    }) {
                        HStack(spacing: 6) {
                            Icon(.book, size: 20)
                            Text("Wikipedia →")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: {
                        let firstDef = (wiktDefinitionsByLang[selectedWiktLang] ?? []).first?.definitions.first?.cleanDefinition ?? "Dictionary Entry"
                        toggleSaveEntry(title: activeWord, subtitle: firstDef, kind: .wiktionary)
                    }) {
                        HStack(spacing: 6) {
                            Icon(saved ? .bookmarkFill : .bookmark, size: 20)
                            Text(saved ? "Saved" : "Save")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(saved ? .borderedProminent : .bordered)
                    .controlSize(.regular)
                }
            }
            .padding(12)
            .background(theme.panelBackground, in: .rect(cornerRadius: 28))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 28), lineWidth: 1)

            if wiktLoading {
                loadingDisplay(
                    title: "Looking up Definition",
                    subtitle: "Retrieving phonetics, etymology, and definitions for “\(activeWord)”…",
                    icon: .document,
                    theme: theme
                )
            } else if let error = wiktError {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()

                    VStack(alignment: .center, spacing: 22) {
                        VStack(alignment: .center, spacing: 0) {
                            Spacer()
                            Icon(.info, size: 48)
                                .foregroundColor(theme.foreground)
                            Spacer()
                        }
                        .frame(width: 92, height: 92)
                        .background(theme.cardBackground, in: .rect(cornerRadius: 46))
                        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 46), lineWidth: 1)

                        Text("No Exact Definition")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                            .multilineTextAlignment(.center)

                        Text(error)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(theme.mutedForeground)
                            .multilineTextAlignment(.center)
                            .lineWrap(true)

                        HStack(alignment: .center, spacing: 20) {
                            Button("Back to Matching Words") {
                                isReaderPresented = false
                                searchWiktionaryMatches(query: activeWord)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button("Search Wikipedia Instead") {
                                openWikipediaReader(title: activeWord)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.top, 6)
                    }
                    .padding(EdgeInsets(top: 40, leading: 44, bottom: 44, trailing: 44))
                    .background(theme.panelBackground, in: .rect(cornerRadius: 24))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 24), lineWidth: 1)
                    .frame(width: 920)

                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                KindlePager(pages: pages, currentPage: $wiktPageIndex) { idx, page in
                    VStack(alignment: .leading, spacing: 14) {
                        if idx == 0 {
                            // Word Header Banner on Page 0
                            HStack(alignment: .center, spacing: 14) {
                                Text(activeWord)
                                    .font(.system(size: 28, weight: .bold, design: .serif))
                                    .foregroundColor(theme.foreground)
                                if let ipa = wiktMetadata.ipaBadge {
                                    Text(ipa)
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                        .foregroundColor(theme.mutedForeground)
                                }
                                Spacer()
                            }
                            Divider(thickness: 1, color: theme.subtleBorder)
                        }

                        switch page.kind {
                        case .definitions(let pos, let lang, let senses):
                            HStack(alignment: .center, spacing: 12) {
                                Text(pos)
                                    .font(.system(size: 19, weight: .bold, design: .serif))
                                    .foregroundColor(theme.foreground)
                                Spacer()
                                Text(lang)
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .foregroundColor(theme.mutedForeground)
                            }

                            ForEach(senses) { sense in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(sense.number).")
                                            .font(.system(size: readerFontSize, weight: .bold, design: .serif))
                                            .foregroundColor(theme.foreground)
                                        Text(sense.text)
                                            .font(.bookerly(size: readerFontSize))
                                            .foregroundColor(theme.foreground)
                                            .lineWrap(true)
                                            .frame(maxWidth: .infinity)
                                    }

                                    if let firstExample = sense.examples.first {
                                        HStack(spacing: 10) {
                                            Rectangle()
                                                .fill(theme.subtleBorder)
                                                .frame(width: 4)
                                            Text("“\(firstExample)”")
                                                .font(.bookerly(size: max(14, readerFontSize - 2), italic: true))
                                                .foregroundColor(theme.mutedForeground)
                                                .lineWrap(true)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 6))
                                    }

                                    if !sense.relatedWords.isEmpty {
                                        HStack(alignment: .center, spacing: 14) {
                                            Text("Related:")
                                                .font(.caption)
                                                .foregroundColor(theme.mutedForeground)
                                            ForEach(sense.relatedWords, id: \.self) { rel in
                                                Button("→ \(rel)") {
                                                    openWiktionaryReader(word: rel)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.regular)
                                            }
                                            Spacer()
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                                .background(theme.cardBackground, in: .rect(cornerRadius: 16))
                                .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
                            }

                        case .notes(let heading, let body, let bullets):
                            Text(heading)
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundColor(theme.foreground)

                            Divider(thickness: 1, color: theme.subtleBorder)

                            if !body.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(body)
                                        .font(.bookerly(size: readerFontSize))
                                        .foregroundColor(theme.foreground)
                                        .lineWrap(true)
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(20)
                                .background(theme.cardBackground, in: .rect(cornerRadius: 16))
                                .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
                            }

                            if !bullets.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(bullets, id: \.self) { line in
                                        Text("• \(line)")
                                            .font(.body)
                                            .foregroundColor(theme.foreground)
                                            .lineWrap(true)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(20)
                                .background(theme.cardBackground, in: .rect(cornerRadius: 16))
                                .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
                            }
                        }

                        Spacer()
                    }
                    .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
                    .background(theme.cardBackground, in: .rect(cornerRadius: 20))
                    .overlay(theme.subtleBorder, in: .rect(cornerRadius: 20), lineWidth: 1)
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }

    internal var currentLanguageEntries: [WiktionaryPartOfSpeechEntry] {
        if selectedWiktLang == "ALL" {
            var all: [WiktionaryPartOfSpeechEntry] = []
            for code in wiktLanguageOrder {
                if let list = wiktDefinitionsByLang[code] {
                    all.append(contentsOf: list)
                }
            }
            return all
        }
        return wiktDefinitionsByLang[selectedWiktLang] ?? []
    }


}
