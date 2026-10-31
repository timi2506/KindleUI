import Foundation
import KindleUI

extension KindleWikiRootView {
    internal func loadingDisplay(
        title: String,
        subtitle: String,
        icon: KindleIconName = .search,
        theme: KindleTheme
    ) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()

            VStack(alignment: .center, spacing: 24) {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    Icon(icon, size: 48)
                        .foregroundColor(theme.foreground)
                    Spacer()
                }
                .frame(width: 92, height: 92)
                .background(theme.cardBackground, in: .rect(cornerRadius: 46))
                .overlay(theme.subtleBorder, in: .rect(cornerRadius: 46), lineWidth: 1)

                VStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .lineWrap(true)
                        .lineLimit(3)
                }
                .padding(.horizontal, 28)

                ProgressView(value: 0.65)
                    .frame(width: 620, height: 18)
                    .padding(.top, 6)
            }
            .padding(EdgeInsets(top: 44, leading: 44, bottom: 48, trailing: 44))
            .background(theme.panelBackground, in: .rect(cornerRadius: 24))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 24), lineWidth: 1)
            .frame(width: 960)

            Spacer()
        }
        .expand(true, fill: true)
    }

    // MARK: - Tab 1: Paginated Wikipedia Matching Items List & Welcome State

    @ViewBuilder
    internal func wikipediaMatchListView(theme: KindleTheme) -> some View {
        let hitPages = chunkIntoPages(wikiSearchHits, pageSize: 6)

        VStack(alignment: .leading, spacing: 14) {
            if !activeWikiQuery.isEmpty && !wikiSearching {
                HStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Icon(.search, size: 22)
                            .foregroundColor(theme.mutedForeground)
                        Text("Results for “\(compactPreview(activeWikiQuery, maxChars: 26))”")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                            .lineLimit(1)
                        Text("·  \(wikiSearchHits.count) found")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(theme.mutedForeground)
                    }

                    Spacer()

                    if !activeArticleRawExtract.isEmpty {
                        Button("Resume Article →") {
                            activeReaderKind = .wikipedia
                            isReaderPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
            }

            if wikiSearching {
                loadingDisplay(
                    title: "Searching Wikipedia",
                    subtitle: "Querying Wikipedia for articles matching “\(activeWikiQuery)”…",
                    icon: .search,
                    theme: theme
                )
            } else if activeWikiQuery.isEmpty {
                wikipediaWelcomeView(theme: theme)
            } else if hitPages.isEmpty {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    ContentUnavailableView(
                        "No Matching Articles",
                        icon: .search,
                        description: "No Wikipedia articles matched “\(activeWikiQuery)”. Try a broader keyword or browse curated topics.",
                        actionTitle: "Return to Explore",
                        action: {
                            searchInput = ""
                            activeWikiQuery = ""
                            wikiSearchHits = []
                            wikiSearchPageIndex = 0
                        }
                    )
                    .frame(width: 960)
                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                KindlePager(pages: hitPages, currentPage: $wikiSearchPageIndex) { _, pageHits in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(pageHits) { hit in
                            let saved = isEntrySaved(title: hit.title, kind: .wikipedia)
                            let preview = compactPreview(hit.cleanSnippet, maxChars: 170)
                            HStack(alignment: .center, spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hit.title)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(theme.foreground)
                                        .lineLimit(1)

                                    if !preview.isEmpty {
                                        Text(preview)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(theme.mutedForeground)
                                            .lineWrap(true)
                                            .lineLimit(2)
                                    }
                                }
                                .expand(true, fill: true)

                                HStack(alignment: .center, spacing: 14) {
                                    Button(action: {
                                        toggleSaveEntry(
                                            title: hit.title,
                                            subtitle: preview.isEmpty ? "Wikipedia Article" : preview,
                                            kind: .wikipedia
                                        )
                                    }) {
                                        HStack(spacing: 6) {
                                            Icon(saved ? .bookmarkFill : .bookmark, size: 20)
                                            Text(saved ? "Saved" : "Save")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .buttonStyle(saved ? .borderedProminent : .bordered)
                                    .controlSize(.regular)

                                    Button(action: {
                                        openWikipediaReader(title: hit.title)
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("Read Article")
                                                .font(.system(size: 14, weight: .bold))
                                            Icon(.chevronRight, size: 20)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 14))
                            .background(theme.cardBackground, in: .rect(cornerRadius: 30))
                            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 30), lineWidth: 1)
                            .onTapGesture {
                                openWikipediaReader(title: hit.title)
                            }
                        }
                        Spacer()
                    }
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }

    @ViewBuilder
    internal func wikipediaWelcomeView(theme: KindleTheme) -> some View {
        let recentArticles = Array(historyEntries.filter { $0.kind == .wikipedia }.prefix(2))

        VStack(alignment: .leading, spacing: 18) {
            if !recentArticles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continue Reading")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)

                    HStack(alignment: .center, spacing: 16, homogeneous: true) {
                        ForEach(recentArticles, id: \.id) { entry in
                            let progress = WikiReadingStore.shared.progress(for: entry.title) ?? 0
                            let hasProgress = (progress > 0.02 && progress < Self.finishedFraction)
                            Button(action: {
                                openSavedOrHistoryEntry(entry)
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    Icon(.book, size: 20)
                                        .foregroundColor(theme.mutedForeground)
                                    Text(compactPreview(entry.title, maxChars: hasProgress ? 25 : 30))
                                        .font(.system(size: 15, weight: .bold, design: .serif))
                                        .foregroundColor(theme.foreground)
                                        .lineLimit(1)
                                    Spacer()
                                    if hasProgress {
                                        Text("\(Int((progress * 100).rounded()))%")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(theme.mutedForeground)
                                    }
                                    Icon(.chevronRight, size: 18)
                                        .foregroundColor(theme.mutedForeground)
                                }
                                .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        if recentArticles.count == 1 {
                            Spacer()
                        }
                    }
                }
            }

            // Curated Topic Categories in Clean 2-Column Homogeneous Touch Grids
            ForEach(Self.suggestedWikiTopics, id: \.category) { category, topics in
                let topicRows = chunkIntoPages(topics, pageSize: 2)
                VStack(alignment: .leading, spacing: 10) {
                    Text(category)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)

                    ForEach(0..<topicRows.count, id: \.self) { rowIdx in
                        let rowTopics = topicRows[rowIdx]
                        HStack(alignment: .center, spacing: 16, homogeneous: true) {
                            ForEach(rowTopics, id: \.self) { topic in
                                Button(action: {
                                    KindleKeyboardManager.shared.dismiss()
                                    openWikipediaReader(title: topic)
                                }) {
                                    HStack(alignment: .center, spacing: 12) {
                                        Icon(.book, size: 20)
                                            .foregroundColor(theme.mutedForeground)
                                        Text(topic)
                                            .font(.system(size: 15, weight: .bold, design: .serif))
                                            .foregroundColor(theme.foreground)
                                            .lineLimit(1)
                                        Spacer()
                                        Icon(.chevronRight, size: 18)
                                            .foregroundColor(theme.mutedForeground)
                                    }
                                    .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    // MARK: - Tab 2: Paginated Wiktionary Matching Items List & Welcome State

    @ViewBuilder
    internal func wiktionaryMatchListView(theme: KindleTheme) -> some View {
        let hitPages = chunkIntoPages(wiktSearchHits, pageSize: 6)

        VStack(alignment: .leading, spacing: 14) {
            if !activeWiktQuery.isEmpty && !wiktSearching {
                HStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Icon(.document, size: 22)
                            .foregroundColor(theme.mutedForeground)
                        Text("Matches for “\(compactPreview(activeWiktQuery, maxChars: 26))”")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                            .lineLimit(1)
                        Text("·  \(wiktSearchHits.count) entries")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(theme.mutedForeground)
                    }

                    Spacer()

                    if !wiktDefinitionsByLang.isEmpty {
                        Button("Resume Entry →") {
                            activeReaderKind = .wiktionary
                            isReaderPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
            }

            if wiktSearching {
                loadingDisplay(
                    title: "Searching Wiktionary",
                    subtitle: "Querying dictionary entries matching “\(activeWiktQuery)”…",
                    icon: .search,
                    theme: theme
                )
            } else if activeWiktQuery.isEmpty {
                wiktionaryWelcomeView(theme: theme)
            } else if hitPages.isEmpty {
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    ContentUnavailableView(
                        "No Matching Words",
                        icon: .search,
                        description: "No Wiktionary entries matched “\(activeWiktQuery)”. Check spelling or browse featured vocabulary.",
                        actionTitle: "Return to Explore",
                        action: {
                            searchInput = ""
                            activeWiktQuery = ""
                            wiktSearchHits = []
                            wiktSearchPageIndex = 0
                        }
                    )
                    .frame(width: 960)
                    Spacer()
                }
                .expand(true, fill: true)
            } else {
                KindlePager(pages: hitPages, currentPage: $wiktSearchPageIndex) { _, pageHits in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(pageHits) { hit in
                            let saved = isEntrySaved(title: hit.title, kind: .wiktionary)
                            let preview = compactPreview(hit.cleanSnippet, maxChars: 170)
                            HStack(alignment: .center, spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hit.title)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(theme.foreground)
                                        .lineLimit(1)

                                    if !preview.isEmpty {
                                        Text(preview)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(theme.mutedForeground)
                                            .lineWrap(true)
                                            .lineLimit(2)
                                    }
                                }
                                .expand(true, fill: true)

                                HStack(alignment: .center, spacing: 14) {
                                    Button(action: {
                                        toggleSaveEntry(
                                            title: hit.title,
                                            subtitle: preview.isEmpty ? "Dictionary Entry" : preview,
                                            kind: .wiktionary
                                        )
                                    }) {
                                        HStack(spacing: 6) {
                                            Icon(saved ? .bookmarkFill : .bookmark, size: 20)
                                            Text(saved ? "Saved" : "Save")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .buttonStyle(saved ? .borderedProminent : .bordered)
                                    .controlSize(.regular)

                                    Button(action: {
                                        openWiktionaryReader(word: hit.title)
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("Define")
                                                .font(.system(size: 14, weight: .bold))
                                            Icon(.chevronRight, size: 20)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 14))
                            .background(theme.cardBackground, in: .rect(cornerRadius: 30))
                            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 30), lineWidth: 1)
                            .onTapGesture {
                                openWiktionaryReader(word: hit.title)
                            }
                        }
                        Spacer()
                    }
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }

    @ViewBuilder
    internal func wiktionaryWelcomeView(theme: KindleTheme) -> some View {
        let recentWords = Array(historyEntries.filter { $0.kind == .wiktionary }.prefix(2))

        VStack(alignment: .leading, spacing: 18) {
            if !recentWords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Lookups")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)

                    HStack(alignment: .center, spacing: 16, homogeneous: true) {
                        ForEach(recentWords, id: \.id) { entry in
                            Button(action: {
                                openSavedOrHistoryEntry(entry)
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    Icon(.document, size: 20)
                                        .foregroundColor(theme.mutedForeground)
                                    Text(compactPreview(entry.title, maxChars: 28))
                                        .font(.system(size: 15, weight: .bold, design: .serif))
                                        .foregroundColor(theme.foreground)
                                        .lineLimit(1)
                                    Spacer()
                                    Icon(.chevronRight, size: 18)
                                        .foregroundColor(theme.mutedForeground)
                                }
                                .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        if recentWords.count == 1 {
                            Spacer()
                        }
                    }
                }
            }

            // Curated Vocabulary Categories in Clean 2-Column Homogeneous Touch Grids
            ForEach(Self.suggestedWiktionaryCategories, id: \.category) { category, words in
                let wordRows = chunkIntoPages(words, pageSize: 2)
                VStack(alignment: .leading, spacing: 10) {
                    Text(category)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)

                    ForEach(0..<wordRows.count, id: \.self) { rowIdx in
                        let pair = wordRows[rowIdx]
                        HStack(alignment: .center, spacing: 16, homogeneous: true) {
                            ForEach(pair, id: \.self) { word in
                                Button(action: {
                                    KindleKeyboardManager.shared.dismiss()
                                    openWiktionaryReader(word: word)
                                }) {
                                    HStack(alignment: .center, spacing: 12) {
                                        Icon(.document, size: 20)
                                            .foregroundColor(theme.mutedForeground)
                                        Text(word)
                                            .font(.system(size: 15, weight: .bold, design: .serif))
                                            .foregroundColor(theme.foreground)
                                            .lineLimit(1)
                                        Spacer()
                                        Icon(.chevronRight, size: 18)
                                            .foregroundColor(theme.mutedForeground)
                                    }
                                    .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    // MARK: - Tab 3: Paginated Saved Bookmarks & History

    @ViewBuilder
    internal func savedBookmarksView(theme: KindleTheme) -> some View {
        let items = displayedSavedItems
        let itemPages = chunkIntoPages(items, pageSize: 5)
        let isFiltering = (selectedTab == .saved && !searchInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                Picker(selection: $savedMode) { _ in
                    savedPageIndex = 0
                }
                .pickerStyle(.segmented)

                Text("\(items.count) \(items.count == 1 ? "item" : "items")")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(theme.mutedForeground)

                if savedMode == .history && !historyEntries.isEmpty {
                    Button(action: {
                        historyEntries.removeAll()
                        persistHistory()
                        savedPageIndex = 0
                    }) {
                        HStack(spacing: 8) {
                            Icon(.close, size: 18)
                            Text("Clear History")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            if itemPages.isEmpty {
                if isFiltering {
                    VStack(alignment: .center, spacing: 0) {
                        Spacer()
                        ContentUnavailableView(
                            "No Matches Found",
                            icon: .search,
                            description: "No \(savedMode == .bookmarks ? "saved bookmarks" : "recent history items") match “\(searchInput)”.",
                            actionTitle: "Clear Filter",
                            action: {
                                searchInput = ""
                            }
                        )
                        .frame(width: 960)
                        Spacer()
                    }
                    .expand(true, fill: true)
                } else {
                    VStack(alignment: .center, spacing: 0) {
                        Spacer()

                        VStack(alignment: .center, spacing: 22) {
                            VStack(alignment: .center, spacing: 0) {
                                Spacer()
                                Icon(.bookmark, size: 48)
                                    .foregroundColor(theme.foreground)
                                Spacer()
                            }
                            .frame(width: 92, height: 92)
                            .background(theme.cardBackground, in: .rect(cornerRadius: 46))
                            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 46), lineWidth: 1)

                            Text(savedMode == .bookmarks ? "No Saved Bookmarks Yet" : "No Recent History")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundColor(theme.foreground)
                                .multilineTextAlignment(.center)

                            Text(savedMode == .bookmarks
                                ? "Tap Save on any Wikipedia article or Wiktionary definition to keep it here for quick and offline access."
                                : "Articles and dictionary definitions you open will automatically appear here for instant resumption.")
                                .font(.system(size: 15, weight: .regular, design: .serif))
                                .foregroundColor(theme.mutedForeground)
                                .multilineTextAlignment(.center)
                                .lineWrap(true)

                            HStack(alignment: .center, spacing: 20) {
                                Button("Explore Wikipedia") {
                                    selectedTab = .wikipedia
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)

                                Button("Explore Wiktionary") {
                                    selectedTab = .wiktionary
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                            .padding(.top, 6)
                        }
                        .padding(EdgeInsets(top: 40, leading: 44, bottom: 44, trailing: 44))
                        .background(theme.panelBackground, in: .rect(cornerRadius: 24))
                        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 24), lineWidth: 1)
                        .frame(width: 960)

                        Spacer()
                    }
                    .expand(true, fill: true)
                }
            } else {
                KindlePager(pages: itemPages, currentPage: $savedPageIndex) { _, pageItems in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(pageItems) { item in
                            let saved = isEntrySaved(title: item.title, kind: item.kind)
                            let preview = compactPreview(item.subtitle, maxChars: 160)
                            HStack(alignment: .center, spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .center, spacing: 10) {
                                        Icon(item.kind == .wikipedia ? .book : .document, size: 22)
                                            .foregroundColor(theme.mutedForeground)
                                        Text(item.title)
                                            .font(.system(size: 19, weight: .bold, design: .serif))
                                            .foregroundColor(theme.foreground)
                                            .lineLimit(1)
                                        let metaParts: [String] = {
                                            var parts = [item.kind.rawValue]
                                            if item.kind == .wikipedia && WikiReadingStore.shared.hasOffline(item.title) {
                                                parts.append("Offline")
                                            }
                                            if item.kind == .wikipedia,
                                               let p = WikiReadingStore.shared.progress(for: item.title), p > 0.02 {
                                                parts.append("\(Int((p * 100).rounded()))% read")
                                            }
                                            return parts
                                        }()
                                        Text("·  " + metaParts.joined(separator: " · "))
                                            .font(.system(size: 13, weight: .regular, design: .serif))
                                            .foregroundColor(theme.mutedForeground)
                                        Spacer()
                                    }

                                    if !preview.isEmpty {
                                        Text(preview)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(theme.mutedForeground)
                                            .lineWrap(true)
                                            .lineLimit(2)
                                    }
                                }
                                .expand(true, fill: true)

                                HStack(alignment: .center, spacing: 16) {
                                    if item.kind == .wikipedia {
                                        let hasOffline = WikiReadingStore.shared.hasOffline(item.title)
                                        Button(action: {
                                            toggleOfflineArticle(title: item.title)
                                        }) {
                                            HStack(spacing: 6) {
                                                Icon(hasOffline ? .check : .cloud, size: 20)
                                                Text(hasOffline ? "Offline" : "Download")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                        }
                                        .buttonStyle(hasOffline ? .borderedProminent : .bordered)
                                        .controlSize(.regular)
                                    }

                                    Button(action: {
                                        toggleSaveEntry(title: item.title, subtitle: item.subtitle, kind: item.kind)
                                    }) {
                                        HStack(spacing: 6) {
                                            Icon(saved ? .bookmarkFill : .bookmark, size: 20)
                                            Text(saved ? "Saved" : "Save")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .buttonStyle(saved ? .borderedProminent : .bordered)
                                    .controlSize(.regular)

                                    Button(action: {
                                        openSavedOrHistoryEntry(item)
                                    }) {
                                        HStack(spacing: 8) {
                                            Text("Open")
                                                .font(.system(size: 14, weight: .bold))
                                            Icon(.chevronRight, size: 20)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 14))
                            .background(theme.cardBackground, in: .rect(cornerRadius: 30))
                            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 30), lineWidth: 1)
                            .onTapGesture {
                                openSavedOrHistoryEntry(item)
                            }
                        }
                        Spacer()
                    }
                    .expand(true, fill: true)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }


}
