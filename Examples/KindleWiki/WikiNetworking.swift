import Foundation
import KindleUI

extension KindleWikiRootView {
    // MARK: - Live Wikimedia API Networking

    internal func openWikipediaReader(title: String) {
        KindleKeyboardManager.shared.dismiss()
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        wikiReaderHistoryStack.willOpen(
            clean,
            from: activeArticleTitle,
            readerIsOpen: isReaderPresented && activeReaderKind == .wikipedia
        )
        activeReaderKind = .wikipedia
        isReaderPresented = true
        loadWikipediaArticle(title: clean)
    }

    internal func openWiktionaryReader(word: String) {
        KindleKeyboardManager.shared.dismiss()
        activeReaderKind = .wiktionary
        isReaderPresented = true
        lookupWiktionaryWord(word)
    }

    internal func performWikipediaSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeWikiQuery = trimmed
        wikiSearching = true
        wikiSearchPageIndex = 0
        let encoded = encodeWikiComponent(trimmed)
        let url = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&utf8=1&format=json&srlimit=30"

        KindleHTTP.getJSON(MediaWikiSearchResponse.self, from: url, timeoutSeconds: 10) { result in
            guard activeWikiQuery == trimmed else { return } // a newer search superseded this one
            wikiSearching = false
            switch result {
            case .failure:
                wikiSearchHits = []
            case .success(let response):
                wikiSearchHits = response.query?.search ?? []
            }
        }
    }

    internal static var initialReaderPage: Int = {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--reader-page"), idx + 1 < args.count, let p = Int(args[idx + 1]) {
            return p
        }
        return 0
    }()

    internal func loadWikipediaArticle(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        wikiLoadGeneration += 1
        let generation = wikiLoadGeneration
        wikiError = nil
        wikiPageIndex = Self.initialReaderPage
        wikiChapterWindowStart = -1
        activeArticleTitle = trimmed
        activeArticleLeadImageURL = nil
        activeArticleSectionImages = [:]
        activeArticleTables = [:]
        activeArticleLinks = []
        activeArticleIsDisambiguation = false
        articleExtractReady = false
        articleMediaPending = false
        articleInfoboxPending = false
        articleMediaLoaded = false
        articleTablesRequested = false
        articleRequestedTitle = trimmed

        if let cached = WikiArticleCache.shared.lookup(trimmed) {
            apply(cachedArticle: cached, generation: generation)
            return
        }
        wikiLoading = true

        // Saved articles are stored on the device: open them without the network. Decoding happens off the UI thread.
        if WikiReadingStore.shared.hasOffline(trimmed) {
            DispatchQueue.global(qos: .userInitiated).async {
                let offline = WikiReadingStore.shared.loadOffline(title: trimmed)
                KindleMainThread.async {
                    guard generation == wikiLoadGeneration else { return }
                    if let offline = offline {
                        let entry = offline.makeCacheEntry()
                        WikiArticleCache.shared.store(entry, requestedTitle: trimmed)
                        apply(cachedArticle: entry, generation: generation)
                    } else {
                        fetchArticleFromNetwork(trimmed, generation: generation)
                    }
                }
            }
            return
        }
        fetchArticleFromNetwork(trimmed, generation: generation)
    }

    internal func fetchArticleFromNetwork(_ trimmed: String, generation: Int) {
        let encodedTitle = encodeWikiComponent(trimmed)
        let extractURL = "https://en.wikipedia.org/w/api.php?action=query&prop=extracts%7Cdescription%7Cpageimages%7Clinks&piprop=thumbnail&pithumbsize=960&explaintext=1&pllimit=100&titles=\(encodedTitle)&format=json&redirects=1"

        KindleHTTP.getJSON(MediaWikiExtractsResponse.self, from: extractURL, timeoutSeconds: 12) { extractResult in
            let isCurrent = generation == wikiLoadGeneration
            switch extractResult {
            case .failure(let err):
                guard isCurrent else { return }
                wikiLoading = false
                wikiError = err.localizedDescription
            case .success(let extractResp):
                guard let pagesDict = extractResp.query?.pages,
                      let firstPage = pagesDict.values.first(where: { ($0.extract ?? "").isEmpty == false }) ?? pagesDict.values.first,
                      let fullText = firstPage.extract,
                      !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    guard isCurrent else { return }
                    wikiLoading = false
                    wikiError = "No Wikipedia article found for “\(trimmed)”."
                    return
                }
                let resolvedTitle = firstPage.title ?? trimmed
                let desc = firstPage.description ?? "Wikipedia Encyclopedia Article"
                let links = firstPage.links?.map(\.title) ?? []
                let isDisambiguation = isDisambiguationArticle(title: resolvedTitle, description: desc, extract: fullText)

                // Cache the text right away, even if the reader already left: a later visit then starts from here.
                let entry = WikiArticleCache.Entry(
                    title: resolvedTitle,
                    description: desc,
                    rawExtract: fullText,
                    leadImageURL: firstPage.thumbnail?.source,
                    links: links,
                    isDisambiguation: isDisambiguation,
                    sectionImages: isCurrent && articleMediaLoaded ? activeArticleSectionImages : WikiArticleCache.shared.peek(trimmed)?.sectionImages,
                    tables: isCurrent && !activeArticleTables.isEmpty ? activeArticleTables : WikiArticleCache.shared.peek(trimmed)?.tables
                )
                WikiArticleCache.shared.store(entry, requestedTitle: trimmed)
                refreshOfflineCopyIfSaved(entry)
                guard isCurrent else { return }

                activeArticleTitle = resolvedTitle
                activeArticleDescription = desc
                activeArticleRawExtract = fullText
                activeArticleLeadImageURL = firstPage.thumbnail?.source
                if let lead = firstPage.thumbnail?.source, !lead.isEmpty {
                    AsyncImage.prefetch(url: lead)
                }
                activeArticleLinks = links
                activeArticleIsDisambiguation = isDisambiguation
                articleExtractReady = true
                attemptInitialPagination(generation: generation)
                recordHistory(title: resolvedTitle, subtitle: desc, kind: .wikipedia)
                if CommandLine.arguments.contains("--enlarge-image"), let lead = firstPage.thumbnail?.source {
                    enlargedImageURL = lead
                    enlargedImageCaption = desc
                    showImageDetail = true
                }
            }
        }

        // Request the compact lead section (`section=0`) infobox and figure list in parallel
        // with the primary extract request so the first pagination pass already includes them.
        requestArticleLeadInfobox(generation: generation)
        requestArticleMedia(generation: generation)
    }

    /// Waits briefly (`figureGraceSeconds`) for the parallel lead-infobox and figure-list requests
    /// before running the first pagination pass so the article does not re-layout multiple times after opening.
    internal static let figureGraceSeconds: TimeInterval = 0.55

    internal func attemptInitialPagination(generation: Int) {
        guard generation == wikiLoadGeneration, articleExtractReady else { return }
        if !articleInfoboxPending && !articleMediaPending {
            schedulePagination()
            return
        }
        guard wikiPagesGeneration != generation else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.figureGraceSeconds) {
            guard generation == self.wikiLoadGeneration,
                  self.articleExtractReady,
                  self.wikiPagesGeneration != generation else { return }
            self.schedulePagination()
        }
    }

    /// Requests the article's figure list. The result is attached to the cache entry even if the reader has
    /// already moved on, and applied to the screen only while this article is still the one being read.
    internal func requestArticleMedia(generation: Int) {
        let requested = articleRequestedTitle
        articleMediaPending = true
        let mediaTitle = encodeWikiComponent(requested, underscoreSpaces: true)
        let mediaURL = "https://en.wikipedia.org/api/rest_v1/page/media-list/\(mediaTitle)"
        KindleHTTP.getJSON(
            WikipediaMediaListResponse.self,
            from: mediaURL,
            timeoutSeconds: 10,
            qos: .userInitiated,
            transform: { mediaResp -> [Int: [(url: String, caption: String)]] in
                Self.sectionImages(from: mediaResp)
            }
        ) { mediaResult in
            let isCurrent = generation == wikiLoadGeneration
            if case .success(let bySection) = mediaResult, let entry = WikiArticleCache.shared.peek(requested) {
                entry.sectionImages = bySection
                refreshOfflineCopyIfSaved(entry)
            }
            guard isCurrent else { return }
            articleMediaPending = false
            if case .success(let bySection) = mediaResult {
                articleMediaLoaded = true
                for fig in bySection.values.flatMap({ $0 }).prefix(3) {
                    AsyncImage.prefetch(url: fig.url)
                }
                if !bySection.isEmpty {
                    activeArticleSectionImages = bySection
                    if CommandLine.arguments.contains("--enlarge-image") {
                        let candidate = bySection.values.flatMap { $0 }.first(where: { !$0.caption.isEmpty }) ?? bySection.values.first?.first
                        if let img = candidate {
                            enlargedImageURL = img.url
                            enlargedImageCaption = img.caption
                            showImageDetail = true
                        }
                    }
                    if wikiPagesGeneration != generation {
                        attemptInitialPagination(generation: generation)
                    } else if wikiPageIndex == 0 {
                        schedulePagination()
                    }
                } else if wikiPagesGeneration != generation {
                    attemptInitialPagination(generation: generation)
                }
            } else if wikiPagesGeneration != generation {
                attemptInitialPagination(generation: generation)
            }
        }
    }

    /// Requests only `section=0` (~25 KB) in parallel with the extract so the lead Infobox is ready for the first paint.
    internal func requestArticleLeadInfobox(generation: Int) {
        let requested = articleRequestedTitle
        articleInfoboxPending = true
        let mediaTitle = encodeWikiComponent(requested, underscoreSpaces: true)
        let parseURL = "https://en.wikipedia.org/w/api.php?action=parse&page=\(mediaTitle)&prop=text&section=0&format=json&redirects=1"
        KindleHTTP.getJSON(
            MediaWikiParseResponse.self,
            from: parseURL,
            timeoutSeconds: 10,
            qos: .userInitiated,
            transform: { parseResp -> [WikiTableData] in
                guard let html = parseResp.parse?.text?.html else { return [] }
                return parseMediaWikiTables(from: html)
            }
        ) { parseResult in
            let isCurrent = generation == wikiLoadGeneration
            var didAddTables = false
            if case .success(let tables) = parseResult, !tables.isEmpty {
                let bySection: [Int: [WikiTableData]] = [0: tables]
                if let entry = WikiArticleCache.shared.peek(requested) {
                    entry.tables = bySection
                    refreshOfflineCopyIfSaved(entry)
                }
                if isCurrent {
                    activeArticleTables = bySection
                    didAddTables = true
                }
            }
            guard isCurrent else { return }
            articleInfoboxPending = false
            if wikiPagesGeneration != generation {
                attemptInitialPagination(generation: generation)
            } else if didAddTables && wikiPageIndex == 0 {
                schedulePagination()
            }
        }
    }

    /// Scrapes the article's full-body tables. Large and rarely essential, so it runs at low priority, after the first paint.
    /// Like the figure list, the result is cached even if the reader has moved on in the meantime.
    internal func requestArticleTables(generation: Int) {
        guard !articleTablesRequested else { return }
        articleTablesRequested = true
        let requested = articleRequestedTitle
        let mediaTitle = encodeWikiComponent(requested, underscoreSpaces: true)
        let parseURL = "https://en.wikipedia.org/w/api.php?action=parse&page=\(mediaTitle)&prop=text&format=json&redirects=1"
        KindleHTTP.getJSON(
            MediaWikiParseResponse.self,
            from: parseURL,
            timeoutSeconds: 15,
            qos: .utility,
            transform: { parseResp -> [WikiTableData] in
                guard let html = parseResp.parse?.text?.html else { return [] }
                return parseMediaWikiTables(from: html)
            }
        ) { parseResult in
            guard case .success(let tables) = parseResult, !tables.isEmpty else { return }
            let bySection: [Int: [WikiTableData]] = [0: tables]
            if let entry = WikiArticleCache.shared.peek(requested) {
                entry.tables = bySection
                refreshOfflineCopyIfSaved(entry)
            }
            guard generation == wikiLoadGeneration else { return }
            let hadInfobox = activeArticleTables.values.flatMap({ $0 }).contains(where: { $0.id.hasPrefix("infobox_") })
            let newNonInfoboxCount = tables.filter({ !$0.id.hasPrefix("infobox_") }).count
            let oldNonInfoboxCount = activeArticleTables.values.flatMap({ $0 }).filter({ !$0.id.hasPrefix("infobox_") }).count
            activeArticleTables = bySection
            if !hadInfobox || newNonInfoboxCount != oldNonInfoboxCount {
                schedulePagination()
            }
        }
    }

    /// Groups the media-list items of an article by section, dropping duplicates and non-gallery items.
    internal static func sectionImages(from mediaResp: WikipediaMediaListResponse) -> [Int: [(url: String, caption: String)]] {
        var bySection: [Int: [(url: String, caption: String)]] = [:]
        guard let items = mediaResp.items else { return bySection }
        var seenImageKeys: Set<String> = []
        for item in items {
            let preferredSrc = item.srcset?.last(where: { !$0.src.contains("thumbnail_unscaled") })?.src
                ?? item.srcset?.first?.src
            guard item.type == "image",
                  item.showInGallery != false,
                  let rawSrc = preferredSrc,
                  !rawSrc.isEmpty else { continue }
            let fullURL = rawSrc.hasPrefix("//") ? ("https:" + rawSrc) : rawSrc
            let key = item.title ?? (fullURL.split(separator: "/").last.map(String.init) ?? fullURL)
            if seenImageKeys.contains(key) { continue }
            seenImageKeys.insert(key)

            let rawCap = stripMediaWikiHTML(item.caption?.text ?? "")
            let cleanCap = Self.compactPreviewText(rawCap, maxChars: 320)
            bySection[item.section_id ?? 0, default: []].append((url: fullURL, caption: cleanCap))
        }
        return bySection
    }

    internal func apply(cachedArticle cached: WikiArticleCache.Entry, generation: Int) {
        activeArticleTitle = cached.title
        activeArticleDescription = cached.description
        activeArticleRawExtract = cached.rawExtract
        activeArticleLeadImageURL = cached.leadImageURL
        activeArticleLinks = cached.links
        activeArticleIsDisambiguation = cached.isDisambiguation
        activeArticleSectionImages = cached.sectionImages ?? [:]
        activeArticleTables = cached.tables ?? [:]
        articleExtractReady = true
        articleMediaLoaded = cached.sectionImages != nil
        // Only fetch what the earlier visit didn't get to (e.g. the reader left before the tables arrived).
        articleTablesRequested = cached.tables != nil
        wikiLoading = true
        if cached.sectionImages == nil {
            requestArticleMedia(generation: generation)
        }
        if cached.tables == nil {
            requestArticleLeadInfobox(generation: generation)
        }
        schedulePagination()
        recordHistory(title: cached.title, subtitle: cached.description, kind: .wikipedia)
    }

    /// Articles read at least this far count as finished and reopen from the first page.
    internal static let finishedFraction: Double = 0.97

    /// The pager's page binding; every page turn also records how far the article has been read.
    internal var readingPageBinding: Binding<Int> {
        Binding(
            get: { wikiPageIndex },
            set: { newIndex in
                wikiPageIndex = newIndex
                recordReadingProgress()
            }
        )
    }

    internal func recordReadingProgress() {
        // Ignore stale pages while a different article is still loading.
        guard wikiPagesGeneration == wikiLoadGeneration,
              !activeArticleTitle.isEmpty, !wikiPages.isEmpty else { return }
        let fraction = wikiPages.count > 1 ? Double(wikiPageIndex) / Double(wikiPages.count - 1) : 0
        let title = activeArticleTitle
        DispatchQueue.global(qos: .utility).async {
            WikiReadingStore.shared.setProgress(fraction, for: title)
        }
    }

    /// Pre-downloads the lead and section figures of `article` into the persistent on-disk image cache.
    internal static func prefetchArticleImages(_ article: WikiOfflineArticle) {
        if let lead = article.leadImageURL, !lead.isEmpty {
            AsyncImage.prefetch(url: lead)
        }
        if let sections = article.sectionImages {
            for figures in sections.values {
                for fig in figures.prefix(2) {
                    AsyncImage.prefetch(url: fig.url)
                }
            }
        }
    }

    /// Writes `entry` to the offline store (off the UI thread) if its article is already downloaded offline.
    internal func refreshOfflineCopyIfSaved(_ entry: WikiArticleCache.Entry) {
        guard WikiReadingStore.shared.hasOffline(entry.title) else { return }
        let article = WikiOfflineArticle(entry)
        Self.prefetchArticleImages(article)
        DispatchQueue.global(qos: .utility).async {
            WikiReadingStore.shared.saveOffline(article)
            KindleMainThread.async {
                KindleStateRegistry.shared.notifyStateMutation()
            }
        }
    }

    /// Toggles the on-disk offline copy of `title` independently of its bookmark state.
    internal func toggleOfflineArticle(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if WikiReadingStore.shared.hasOffline(trimmed) {
            WikiReadingStore.shared.removeOffline(title: trimmed)
            KindleStateRegistry.shared.notifyStateMutation()
        } else {
            saveArticleOffline(title: trimmed)
        }
    }

    /// Stores a just-bookmarked article for offline reading, fetching its text first if it hasn't been opened yet.
    internal func saveArticleOffline(title: String) {
        if let entry = WikiArticleCache.shared.peek(title) {
            let article = WikiOfflineArticle(entry)
            Self.prefetchArticleImages(article)
            DispatchQueue.global(qos: .utility).async {
                WikiReadingStore.shared.saveOffline(article)
                KindleMainThread.async {
                    KindleStateRegistry.shared.notifyStateMutation()
                }
            }
            return
        }
        let url = "https://en.wikipedia.org/w/api.php?action=query&prop=extracts%7Cdescription%7Cpageimages%7Clinks&piprop=thumbnail&pithumbsize=960&explaintext=1&pllimit=100&titles=\(encodeWikiComponent(title))&format=json&redirects=1"
        KindleHTTP.getJSON(
            MediaWikiExtractsResponse.self,
            from: url,
            timeoutSeconds: 12,
            qos: .utility,
            transform: { resp -> String? in
                guard let pages = resp.query?.pages,
                      let page = pages.values.first(where: { ($0.extract ?? "").isEmpty == false }),
                      let text = page.extract else { return nil }
                let resolved = page.title ?? title
                let desc = page.description ?? "Wikipedia Encyclopedia Article"
                let offline = WikiOfflineArticle(
                    title: title, // keyed by the title the bookmark uses
                    description: desc,
                    rawExtract: text,
                    leadImageURL: page.thumbnail?.source,
                    links: page.links?.map(\.title) ?? [],
                    isDisambiguation: isDisambiguationArticle(title: resolved, description: desc, extract: text)
                )
                WikiReadingStore.shared.saveOffline(offline)
                return page.thumbnail?.source
            },
            completion: { result in
                if case .success(let leadURL) = result {
                    if let leadURL = leadURL, !leadURL.isEmpty {
                        AsyncImage.prefetch(url: leadURL)
                    }
                    KindleStateRegistry.shared.notifyStateMutation()
                }
            }
        )
    }

    /// Re-paginates the current article (e.g. after the font size changed).
    internal func rebuildWikipediaPagination() {
        schedulePagination()
    }

    /// Paginates the current article on a background queue and applies the newest result on the main thread.
    /// Images and tables arrive independently of the text, so several requests may be in flight; stale ones are dropped.
    internal func schedulePagination() {
        guard articleExtractReady, !activeArticleRawExtract.isEmpty else { return }
        wikiPaginationToken += 1
        let token = wikiPaginationToken
        let generation = wikiLoadGeneration

        let rawExtract = activeArticleRawExtract
        let charsPerPage = charsPerWikiPage
        let fontSize = readerFontSize
        let leadImage = activeArticleLeadImageURL
        let caption = activeArticleDescription
        let images = activeArticleSectionImages
        let tables = activeArticleTables
        let links = activeArticleLinks
        let isDisambiguation = activeArticleIsDisambiguation

        DispatchQueue.global(qos: .userInitiated).async {
            let (pages, sections) = paginateWikipediaExtract(
                rawExtract,
                charsPerPage: charsPerPage,
                fontSize: fontSize,
                leadImageURL: leadImage,
                leadImageCaption: caption,
                sectionImages: images,
                sectionTables: tables,
                linkedTitles: links,
                isDisambiguation: isDisambiguation
            )
            KindleMainThread.async {
                guard generation == wikiLoadGeneration, token == wikiPaginationToken else { return }
                let previousCount = wikiPages.count
                let previousIndex = wikiPageIndex
                let isFirstLayout = wikiPagesGeneration != generation
                wikiPages = pages
                wikiSections = sections
                wikiPagesGeneration = generation
                if !isFirstLayout, previousCount > 1 {
                    // Re-layout of the article being read (font size, late figures/tables): keep the reading position.
                    let fraction = Double(previousIndex) / Double(previousCount - 1)
                    wikiPageIndex = Int((fraction * Double(pages.count - 1)).rounded())
                } else if isFirstLayout, Self.initialReaderPage == 0,
                          let saved = WikiReadingStore.shared.progress(for: activeArticleTitle),
                          saved < Self.finishedFraction, pages.count > 1 {
                    // Resume where the reader left off (finished articles start from the top again).
                    wikiPageIndex = Int((saved * Double(pages.count - 1)).rounded())
                }
                if wikiPageIndex >= pages.count {
                    wikiPageIndex = max(0, pages.count - 1)
                }
                wikiLoading = false
            }
        }
    }

    internal func fetchRandomWikipediaArticle() {
        KindleKeyboardManager.shared.dismiss()
        activeReaderKind = .wikipedia
        isReaderPresented = true
        wikiLoading = true
        wikiError = nil
        wikiPageIndex = 0
        let url = "https://en.wikipedia.org/api/rest_v1/page/random/summary"

        KindleHTTP.getJSON(WikipediaSummaryResponse.self, from: url, timeoutSeconds: 10) { result in
            switch result {
            case .failure(let err):
                wikiLoading = false
                wikiError = err.localizedDescription
            case .success(let summary):
                searchInput = summary.title
                loadWikipediaArticle(title: summary.title)
            }
        }
    }

    internal func searchWiktionaryMatches(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeWiktQuery = trimmed
        wiktSearching = true
        wiktSearchPageIndex = 0
        let encoded = encodeWikiComponent(trimmed)
        let url = "https://en.wiktionary.org/w/api.php?action=query&list=search&srsearch=\(encoded)&utf8=1&format=json&srlimit=30"

        KindleHTTP.getJSON(MediaWikiSearchResponse.self, from: url, timeoutSeconds: 10) { result in
            wiktSearching = false
            switch result {
            case .failure:
                wiktSearchHits = []
            case .success(let response):
                wiktSearchHits = response.query?.search ?? []
            }
        }
    }

    internal func lookupWiktionaryWord(_ rawWord: String) {
        let trimmed = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        wiktLoading = true
        wiktError = nil
        wiktPageIndex = Self.initialReaderPage
        activeWord = trimmed
        let encoded = encodeWikiComponent(trimmed, underscoreSpaces: true)
        let defURL = "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)"

        KindleHTTP.getJSON([String: [WiktionaryPartOfSpeechEntry]].self, from: defURL, timeoutSeconds: 10) { result in
            switch result {
            case .failure(let err):
                let lower = trimmed.lowercased()
                if lower != trimmed {
                    lookupWiktionaryLowercaseFallback(lower, originalError: err.localizedDescription)
                } else {
                    wiktLoading = false
                    wiktError = "No definition found for “\(trimmed)”."
                }
            case .success(let dict):
                applyWiktionaryDefinitions(word: trimmed, dict: dict)
            }
        }
    }

    internal func lookupWiktionaryLowercaseFallback(_ lowerWord: String, originalError: String) {
        let encoded = encodeWikiComponent(lowerWord, underscoreSpaces: true)
        let defURL = "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)"

        KindleHTTP.getJSON([String: [WiktionaryPartOfSpeechEntry]].self, from: defURL, timeoutSeconds: 10) { result in
            switch result {
            case .failure:
                wiktLoading = false
                wiktError = "No definition found for “\(activeWord)”."
            case .success(let dict):
                activeWord = lowerWord
                applyWiktionaryDefinitions(word: lowerWord, dict: dict)
            }
        }
    }

    internal func applyWiktionaryDefinitions(word: String, dict: [String: [WiktionaryPartOfSpeechEntry]]) {
        wiktDefinitionsByLang = dict
        let sortedLangs = dict.keys.sorted { a, b in
            if a == "en" { return true }
            if b == "en" { return false }
            return a < b
        }
        wiktLanguageOrder = sortedLangs
        if dict["en"] != nil {
            selectedWiktLang = "en"
        } else if let first = sortedLangs.first {
            selectedWiktLang = first
        } else {
            selectedWiktLang = "ALL"
        }
        wiktMetadata = WiktionaryExtractMetadata()
        wiktLoading = false

        let firstDef = (dict["en"] ?? dict.values.first ?? []).first?.definitions.first?.cleanDefinition ?? "Dictionary Entry"
        recordHistory(title: word, subtitle: firstDef, kind: .wiktionary)

        let encoded = encodeWikiComponent(word)
        let extractURL = "https://en.wiktionary.org/w/api.php?action=query&prop=extracts&explaintext=1&titles=\(encoded)&format=json&redirects=1"
        KindleHTTP.getJSON(MediaWikiExtractsResponse.self, from: extractURL, timeoutSeconds: 10) { extractResult in
            if case .success(let resp) = extractResult,
               let firstPage = resp.query?.pages?.values.first,
               let rawExtract = firstPage.extract {
                wiktMetadata = parseWiktionaryExtractMetadata(from: rawExtract)
            }
        }
    }

    // MARK: - Bookmarks & History Helpers

    internal func isEntrySaved(title: String, kind: WikiHistoryEntry.Kind) -> Bool {
        savedEntries.contains {
            $0.kind == kind && $0.title.caseInsensitiveCompare(title) == .orderedSame
        }
    }

    internal func toggleSaveEntry(title: String, subtitle: String, kind: WikiHistoryEntry.Kind) {
        if let idx = savedEntries.firstIndex(where: {
            $0.kind == kind && $0.title.caseInsensitiveCompare(title) == .orderedSame
        }) {
            savedEntries.remove(at: idx)
        } else {
            let entry = WikiHistoryEntry(
                id: "\(kind.rawValue):\(title)",
                title: title,
                subtitle: subtitle,
                kind: kind
            )
            savedEntries.insert(entry, at: 0)
        }
        persistBookmarks()
    }

    internal func recordHistory(title: String, subtitle: String, kind: WikiHistoryEntry.Kind) {
        historyEntries.removeAll {
            $0.kind == kind && $0.title.caseInsensitiveCompare(title) == .orderedSame
        }
        let entry = WikiHistoryEntry(
            id: "\(kind.rawValue):\(title)",
            title: title,
            subtitle: subtitle,
            kind: kind
        )
        historyEntries.insert(entry, at: 0)
        if historyEntries.count > 25 {
            historyEntries = Array(historyEntries.prefix(25))
        }
        persistHistory()
    }

    internal func openSavedOrHistoryEntry(_ entry: WikiHistoryEntry) {
        KindleKeyboardManager.shared.dismiss()
        switch entry.kind {
        case .wikipedia:
            openWikipediaReader(title: entry.title)
        case .wiktionary:
            openWiktionaryReader(word: entry.title)
        }
    }
}
