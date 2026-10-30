import Foundation
import KindleUI

// MARK: - Tab 2: Library & NavigationStack

extension KindleShowcaseRootView {
    internal var filteredBooks: [BookItem] {
        books.filter { book in
            let matchesCategory = (selectedCategory == .all || book.category == selectedCategory)
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = q.isEmpty
                || book.title.lowercased().contains(q)
                || book.author.lowercased().contains(q)
            return matchesCategory && matchesSearch
        }
    }

    internal func navigationTab(theme: KindleTheme) -> some View {
        NavigationStack(id: "library-stack", path: $navPath) {
            VStack(alignment: .leading, spacing: 18) {
                // Category Filter Bar
                HStack(alignment: .center, spacing: 10) {
                    ForEach(LibraryCategory.allCases, id: \.self) { cat in
                        Button(cat.rawValue) {
                            selectedCategory = cat
                        }
                        .buttonStyle(selectedCategory == cat ? .borderedProminent : .capsule)
                        .controlSize(.small)
                    }

                    Spacer()

                    Button(listEditMode.isEditing ? "Done" : "Edit") {
                        listEditMode = listEditMode.isEditing ? .inactive : .active
                    }
                    .buttonStyle(listEditMode.isEditing ? .borderedProminent : .bordered)
                    .controlSize(.small)

                    if books.count < initialBooks.count {
                        Button("Restore") {
                            books = initialBooks
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Editorial Section Heading (Directly on Background, like KindleWiki)
                Text("Reading List")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)

                if filteredBooks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Volumes",
                        icon: .search,
                        description: "No books matched “\(searchQuery.isEmpty ? selectedCategory.rawValue : searchQuery)”.",
                        actionTitle: "Reset Filter",
                        action: {
                            selectedCategory = .all
                            searchQuery = ""
                        }
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredBooks) { book in
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(theme.foreground)
                                    Text("\(book.author)  ·  \(book.category.rawValue)  ·  \(book.pages) pages  ·  \(Int(book.progress * 100))% read")
                                        .font(.caption)
                                        .foregroundColor(theme.mutedForeground)
                                }

                                Spacer()

                                if listEditMode.isEditing {
                                    Button("Remove") {
                                        books.removeAll { $0.id == book.id }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }

                                NavigationLink("Read", value: book)
                            }
                            .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                            .background(theme.cardBackground, in: .rect(cornerRadius: 14))
                            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 14), lineWidth: 1)
                        }
                    }
                }

                Spacer()
            }
            .expand(true, fill: true)
            .navigationDestination(for: BookItem.self) { book in
                bookDetailDestination(book: book, theme: theme)
            }
            .searchable(text: $searchQuery, prompt: "Search library by title or author…")
        }
    }

    internal func bookDetailDestination(book: BookItem, theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Surface(book.title) {
                Text("\(book.author)  ·  \(book.category.rawValue)  ·  \(book.pages) pages")
                    .font(.caption)
                    .foregroundColor(theme.mutedForeground)

                Text(book.summary)
                    .font(.system(size: 18, weight: .regular, design: .serif))

                Gauge("Progress (\(Int(book.progress * 100))%)", value: book.progress, in: 0...1)

                HStack(spacing: 12) {
                    Button("Open Reader") {
                        showReaderCover = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("+10% Progress") {
                        if let idx = books.firstIndex(where: { $0.id == book.id }) {
                            books[idx].progress = min(1.0, books[idx].progress + 0.10)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Back to Library") {
                        navPath = NavigationPath()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Surface("Chapters") {
                OutlineGroup(sampleOutlineTree, children: \.children) { node in
                    HStack(spacing: 10) {
                        Text(node.title)
                            .font(.headline)
                        Spacer()
                        Text(node.subtitle)
                            .font(.caption)
                            .foregroundColor(theme.mutedForeground)
                    }
                }
            }

            Spacer()
        }
        .expand(true, fill: true)
        .navigationTitle(book.title)
    }
}
