import Foundation
import KindleUI

// MARK: - Application Entry Point

@main
struct KindleWikiApp: App {
    static let applicationID = "org.kindlemodding.kindlewiki"

    init() {}

    var body: some Scene {
        WindowGroup(id: Self.applicationID) {
            KindleWikiRootView()
        }
    }
}

// MARK: - Root View

struct KindleWikiRootView: View {
    internal static var didInitialBootstrap: Bool = false

    internal static let suggestedWikiTopics: [(category: String, topics: [String])] = [
        ("Science & Technology", ["Quantum mechanics", "Electronic paper", "James Webb Space Telescope", "Artificial intelligence"]),
        ("History & Civilization", ["Ancient Egypt", "Renaissance", "Solar System", "Philosophy of mind"]),
        ("Nature & Earth", ["Amazon rainforest", "Plate tectonics", "Honey bee", "Mount Everest"]),
        ("Arts & Culture", ["Leonardo da Vinci", "Jazz", "Haiku", "Gothic architecture"])
    ]

    internal static let suggestedDictionaryWords: [String] = [
        "ephemeral", "eloquent", "quintessential", "allegory",
        "pragmatic", "paradigm", "dichotomy", "empirical",
        "petrichor", "luminescent", "halcyon", "zenith",
        "serendipity", "solitude", "lucid", "resilient"
    ]

    internal static let suggestedWiktionaryCategories: [(category: String, words: [String])] = [
        ("Literature & Rhetoric", ["ephemeral", "eloquent", "quintessential", "allegory"]),
        ("Thought & Philosophy", ["pragmatic", "paradigm", "dichotomy", "empirical"]),
        ("Nature & Senses", ["petrichor", "luminescent", "halcyon", "zenith"]),
        ("Character & Mood", ["serendipity", "solitude", "lucid", "resilient"])
    ]

    internal static let sampleBookmarks: [WikiHistoryEntry] = [
        WikiHistoryEntry(
            id: "Wikipedia:Electronic paper",
            title: "Electronic paper",
            subtitle: "Display technology that mimics ordinary ink on paper, enabling low-power reading on E-Ink devices.",
            kind: .wikipedia
        ),
        WikiHistoryEntry(
            id: "Wiktionary:ephemeral",
            title: "ephemeral",
            subtitle: "Lasting for a very short time; transitory, fleeting, impermanent.",
            kind: .wiktionary
        )
    ]

    internal static let sampleHistory: [WikiHistoryEntry] = [
        WikiHistoryEntry(
            id: "Wikipedia:Quantum mechanics",
            title: "Quantum mechanics",
            subtitle: "Fundamental physical theory describing the behavior of matter and light on atomic scales.",
            kind: .wikipedia
        )
    ]

    @State internal var selectedTab: WikiAppTab = {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--page"), idx + 1 < args.count,
           let tab = WikiAppTab(rawValue: args[idx + 1].lowercased()) {
            return tab
        }
        return .wikipedia
    }()

    @AppStorage("kindlewiki.fontSize") internal var readerFontSize: Int = 16
    @AppStorage("kindlewiki.darkMode") internal var isDarkMode: Bool = false

    // Shared Header Search Input
    @State internal var searchInput: String = {
        let args = CommandLine.arguments
        if args.contains("--loading-search") || args.contains("--loading-reader") {
            return "Quantum mechanics"
        } else if args.contains("--loading-wikt-search") || args.contains("--loading-wikt-reader") {
            return "Serendipity"
        }
        return ""
    }()

    // Full-Screen Reader Cover & Sheet State
    @State internal var isReaderPresented: Bool = {
        CommandLine.arguments.contains("--open-reader") ||
        CommandLine.arguments.contains("--loading-reader") ||
        CommandLine.arguments.contains("--loading-wikt-reader")
    }()
    @State internal var activeReaderKind: ActiveReaderKind = {
        let args = CommandLine.arguments
        if args.contains("--loading-wikt-reader") {
            return .wiktionary
        }
        if let idx = args.firstIndex(of: "--page"), idx + 1 < args.count,
           args[idx + 1].lowercased() == "wiktionary" {
            return .wiktionary
        }
        return .wikipedia
    }()
    @State internal var showTypographySheet: Bool = false
    @State internal var showLanguageSheet: Bool = false

    // Wikipedia State
    @State internal var activeWikiQuery: String = {
        CommandLine.arguments.contains("--loading-search") ? "Quantum mechanics" : ""
    }()
    @State internal var wikiSearchHits: [MediaWikiSearchResponse.Query.SearchHit] = []
    @State internal var wikiSearchPageIndex: Int = 0
    @State internal var wikiSearching: Bool = {
        CommandLine.arguments.contains("--loading-search")
    }()

    @State internal var activeArticleTitle: String = {
        CommandLine.arguments.contains("--loading-reader") ? "Quantum mechanics" : ""
    }()
    @State internal var activeArticleDescription: String = ""
    @State internal var activeArticleRawExtract: String = ""
    @State internal var activeArticleLeadImageURL: String? = nil
    @State internal var activeArticleSectionImages: [Int: [(url: String, caption: String)]] = [:]
    @State internal var enlargedImageURL: String? = nil
    @State internal var enlargedImageCaption: String = ""
    @State internal var showImageDetail: Bool = false
    @State internal var showChaptersModal: Bool = false
    @State internal var chaptersModalPage: Int = 0
    @State internal var wikiPages: [WikiArticlePage] = []
    @State internal var wikiSections: [WikiSectionJump] = []
    @State internal var wikiChapterWindowStart: Int = -1
    @State internal var wikiPageIndex: Int = 0
    @State internal var wikiLoading: Bool = {
        CommandLine.arguments.contains("--loading-reader")
    }()
    @State internal var wikiError: String? = nil
    @State internal var wikiReaderHistoryStack = WikiReaderBackStack()
    @State internal var activeArticleTables: [Int: [WikiTableData]] = [:]
    @State internal var activeArticleLinks: [String] = []
    @State internal var activeArticleIsDisambiguation: Bool = false
    /// Bumped for every article load; late network results of an older load are discarded.
    @State internal var wikiLoadGeneration: Int = 0
    /// `true` once the plain-text extract of the article being loaded has arrived (images/tables may arrive earlier).
    @State internal var articleExtractReady: Bool = false
    /// Bumped for every pagination request; only the newest result is applied.
    @State internal var wikiPaginationToken: Int = 0
    /// The article load (`wikiLoadGeneration`) that `wikiPages` was last paginated for; -1 if none yet.
    @State internal var wikiPagesGeneration: Int = -1
    /// `true` while the figure list of the article being loaded is still in flight.
    @State internal var articleMediaPending: Bool = false
    /// `true` while the lead section (`section=0`) infobox scrape is still in flight.
    @State internal var articleInfoboxPending: Bool = false
    /// `true` until the (low priority) table scrape of the article being loaded has finished.
    /// `true` once the figure list of the article being read has been loaded (possibly empty).
    @State internal var articleMediaLoaded: Bool = false
    @State internal var articleTablesRequested: Bool = false
    @State internal var articleRequestedTitle: String = ""

    // Wiktionary State
    @State internal var activeWiktQuery: String = {
        CommandLine.arguments.contains("--loading-wikt-search") ? "Serendipity" : ""
    }()
    @State internal var wiktSearchHits: [MediaWikiSearchResponse.Query.SearchHit] = []
    @State internal var wiktSearchPageIndex: Int = 0
    @State internal var wiktSearching: Bool = {
        CommandLine.arguments.contains("--loading-wikt-search")
    }()

    @State internal var activeWord: String = {
        CommandLine.arguments.contains("--loading-wikt-reader") ? "Serendipity" : ""
    }()
    @State internal var wiktDefinitionsByLang: [String: [WiktionaryPartOfSpeechEntry]] = [:]
    @State internal var wiktLanguageOrder: [String] = []
    @State internal var selectedWiktLang: String = "en"
    @State internal var wiktMetadata: WiktionaryExtractMetadata = WiktionaryExtractMetadata()
    @State internal var wiktPageIndex: Int = 0
    @State internal var wiktLoading: Bool = {
        CommandLine.arguments.contains("--loading-wikt-reader")
    }()
    @State internal var wiktError: String? = nil

    // Saved & History State
    @State internal var savedMode: SavedViewMode = .bookmarks
    @State internal var savedPageIndex: Int = 0
    @State internal var savedEntries: [WikiHistoryEntry] = []
    @State internal var historyEntries: [WikiHistoryEntry] = []

    internal var charsPerWikiPage: Int {
        max(1250, 2200 - (readerFontSize - 15) * 130)
    }

    internal var displayedSavedItems: [WikiHistoryEntry] {
        let baseItems = (savedMode == .bookmarks) ? savedEntries : historyEntries
        let query = searchInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty && selectedTab == .saved else { return baseItems }
        return baseItems.filter {
            $0.title.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
        }
    }

    var body: some View {
        let theme = KindleTheme.current

        return VStack(alignment: .leading, spacing: 18) {
            topAppHeader(theme: theme)
            headerSearchBar(theme: theme)

            TabView(
                selection: $selectedTab,
                onTabChange: { newTab in
                    KindleKeyboardManager.shared.dismiss()
                    switch newTab {
                    case .wikipedia:
                        searchInput = activeWikiQuery
                    case .wiktionary:
                        searchInput = activeWiktQuery
                    case .saved:
                        searchInput = ""
                    }
                }
            ) {
                Tab("Wikipedia", icon: .book, value: WikiAppTab.wikipedia) {
                    wikipediaMatchListView(theme: theme)
                        .expand(true, fill: true)
                }
                Tab("Wiktionary", icon: .document, value: WikiAppTab.wiktionary) {
                    wiktionaryMatchListView(theme: theme)
                        .expand(true, fill: true)
                }
                Tab("Saved", icon: .bookmark, value: WikiAppTab.saved) {
                    savedBookmarksView(theme: theme)
                        .expand(true, fill: true)
                }
            }
            .tabViewStyle(.bottomBar)
            .expand(true, fill: true)
        }
        .expand(true, fill: true)
        .padding(EdgeInsets(top: 18, leading: 36, bottom: 18, trailing: 36))
        .background(theme.background)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .einkRefreshPolicy(.automatic)
        .fullScreenCover(isPresented: $isReaderPresented) {
            fullScreenReaderView(theme: theme)
        }
        .fullScreenCover(isPresented: $showImageDetail) {
            enlargedImageView(theme: theme)
        }
        .fullScreenCover(isPresented: $showChaptersModal) {
            chaptersModalView(theme: theme)
        }
        .sheet(isPresented: $showTypographySheet, title: "Reading Appearance (Aa)", detent: .fit) {
            typographySheetView(theme: theme)
        }
        .sheet(isPresented: $showLanguageSheet, title: "Select Dictionary Language", detent: .fit) {
            languageSelectorSheetView(theme: theme)
        }
        .onAppear {
            if !Self.didInitialBootstrap {
                Self.didInitialBootstrap = true
                loadPersistedData()
                let args = CommandLine.arguments
                if args.contains("--loading-search") {
                    selectedTab = .wikipedia
                    activeWikiQuery = "Quantum mechanics"
                    searchInput = "Quantum mechanics"
                    wikiSearching = true
                } else if args.contains("--loading-reader") {
                    selectedTab = .wikipedia
                    activeArticleTitle = "Quantum mechanics"
                    searchInput = "Quantum mechanics"
                    isReaderPresented = true
                    activeReaderKind = .wikipedia
                    wikiLoading = true
                } else if let idx = args.firstIndex(of: "--article"), idx + 1 < args.count {
                    let initialArticle = args[idx + 1]
                    searchInput = initialArticle
                    performWikipediaSearch(query: initialArticle)
                    if isReaderPresented {
                        openWikipediaReader(title: initialArticle)
                    }
                } else if let idx = args.firstIndex(of: "--word"), idx + 1 < args.count {
                    let initialWord = args[idx + 1]
                    selectedTab = .wiktionary
                    searchInput = initialWord
                    searchWiktionaryMatches(query: initialWord)
                    if isReaderPresented {
                        openWiktionaryReader(word: initialWord)
                    }
                }
            }
        }
    }

    // MARK: - Persistence & Storage Helpers

    internal func loadPersistedData() {
        if let savedJSON = KindleStateRegistry.shared.appStorageValue(forKey: "kindlewiki.savedEntries"),
           let data = savedJSON.data(using: .utf8),
           let list = try? JSONDecoder().decode([WikiHistoryEntry].self, from: data),
           !list.isEmpty {
            savedEntries = list
        } else {
            savedEntries = Self.sampleBookmarks
            persistBookmarks()
        }

        if let histJSON = KindleStateRegistry.shared.appStorageValue(forKey: "kindlewiki.historyEntries"),
           let data = histJSON.data(using: .utf8),
           let list = try? JSONDecoder().decode([WikiHistoryEntry].self, from: data),
           !list.isEmpty {
            historyEntries = list
        } else {
            historyEntries = Self.sampleHistory
            persistHistory()
        }
    }

    internal func persistBookmarks() {
        if let data = try? JSONEncoder().encode(savedEntries),
           let str = String(data: data, encoding: .utf8) {
            KindleStateRegistry.shared.setAppStorageValue(str, forKey: "kindlewiki.savedEntries")
        }
    }

    internal func persistHistory() {
        if let data = try? JSONEncoder().encode(historyEntries),
           let str = String(data: data, encoding: .utf8) {
            KindleStateRegistry.shared.setAppStorageValue(str, forKey: "kindlewiki.historyEntries")
        }
    }

    // MARK: - Top App Header & Search Bar

    internal func topAppHeader(theme: KindleTheme) -> some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Icon(.book, size: 32)
                    .foregroundColor(theme.foreground)
                Text("KindleWiki")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)
                Text("·  Encyclopedia & Dictionary")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(theme.mutedForeground)
            }

            Spacer()

            HStack(alignment: .center, spacing: 16) {
                Button(action: {
                    KindleKeyboardManager.shared.dismiss()
                    showTypographySheet = true
                }) {
                    HStack(spacing: 8) {
                        Icon(.sliders, size: 22)
                        Text("Aa  \(readerFontSize)pt")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: {
                    KindleDevice.shared.quitApplication()
                }) {
                    HStack(spacing: 8) {
                        Icon(.close, size: 20)
                        Text("Close")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    internal func headerSearchBar(theme: KindleTheme) -> some View {
        let isSaved = (selectedTab == .saved)
        let isWiktionary = (selectedTab == .wiktionary)

        let placeholder: String
        if isSaved {
            placeholder = "Filter saved bookmarks & reading history…"
        } else if isWiktionary {
            placeholder = "Search Wiktionary words & definitions…"
        } else {
            placeholder = "Search Wikipedia articles & topics…"
        }

        let hasActiveSearch = !searchInput.isEmpty
            || (selectedTab == .wikipedia && !activeWikiQuery.isEmpty)
            || (selectedTab == .wiktionary && !activeWiktQuery.isEmpty)

        return HStack(alignment: .center, spacing: 16) {
            TextField(
                placeholder,
                text: $searchInput,
                onCommit: {
                    submitHeaderSearch()
                }
            )

            if hasActiveSearch {
                Button(action: {
                    searchInput = ""
                    KindleKeyboardManager.shared.dismiss()
                    if selectedTab == .wikipedia {
                        activeWikiQuery = ""
                        wikiSearchHits = []
                        wikiSearchPageIndex = 0
                    } else if selectedTab == .wiktionary {
                        activeWiktQuery = ""
                        wiktSearchHits = []
                        wiktSearchPageIndex = 0
                    }
                }) {
                    HStack(spacing: 8) {
                        Icon(.close, size: 20)
                        Text("Clear")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            if !isSaved {
                Button(action: {
                    KindleKeyboardManager.shared.dismiss()
                    if isWiktionary {
                        let word = Self.suggestedDictionaryWords.randomElement() ?? "ephemeral"
                        searchInput = word
                        searchWiktionaryMatches(query: word)
                        openWiktionaryReader(word: word)
                    } else {
                        fetchRandomWikipediaArticle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Icon(.refresh, size: 20)
                        Text("Random")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: {
                    submitHeaderSearch()
                }) {
                    HStack(spacing: 8) {
                        Icon(.search, size: 20)
                        Text("Search")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(12)
        .background(theme.panelBackground, in: .rect(cornerRadius: 28))
        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 28), lineWidth: 1)
    }

    internal func submitHeaderSearch() {
        KindleKeyboardManager.shared.dismiss()
        let query = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if selectedTab == .wiktionary {
            searchWiktionaryMatches(query: query)
        } else if selectedTab == .saved {
            // Already live filtering via displayedSavedItems
        } else {
            performWikipediaSearch(query: query)
        }
    }

    internal func compactPreview(_ raw: String, maxChars: Int = 160) -> String {
        Self.compactPreviewText(raw, maxChars: maxChars)
    }

    internal static func compactPreviewText(_ raw: String, maxChars: Int = 160) -> String {
        let flat = raw.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > maxChars else { return flat }
        let slice = flat.prefix(maxChars)
        if let lastSpace = slice.lastIndex(of: " "), flat.distance(from: flat.startIndex, to: lastSpace) > maxChars / 2 {
            return String(flat[..<lastSpace]) + "…"
        }
        return String(slice) + "…"
    }


}
