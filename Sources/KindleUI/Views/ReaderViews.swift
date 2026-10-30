import Foundation

// MARK: - Kindle-Specific Paginated Reader (KindlePager & BookReaderView)

/// A paginated E-Ink container that displays one page at a time with swipe gestures,
/// Prev/Next controls, and automatic ghosting-free E-Ink refreshes.
public struct KindlePager<PageData, PageContent: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let pages: [PageData]
    public let currentPage: Binding<Int>
    public let fullRefreshEvery: Int
    private let pageBuilder: (Int, PageData) -> PageContent

    public init(
        pages: [PageData],
        currentPage: Binding<Int>,
        fullRefreshEvery: Int = 5,
        @ViewBuilder pageContent: @escaping (Int, PageData) -> PageContent
    ) {
        self.pages = pages
        self.currentPage = currentPage
        self.fullRefreshEvery = max(1, fullRefreshEvery)
        self.pageBuilder = pageContent
    }

    public func _makeNode() -> RenderNode {
        guard !pages.isEmpty else {
            return ContentUnavailableView("No Pages", icon: .book, description: "There is no content to display.")
                .buildRenderTree()
        }

        let total = pages.count
        let idx = max(0, min(total - 1, currentPage.wrappedValue))
        let binding = currentPage
        let flashEvery = fullRefreshEvery

        let goPrev: () -> Void = {
            guard idx > 0 else { return }
            let nextIdx = idx - 1
            if nextIdx % flashEvery == 0 {
                KindleStateRegistry.shared.pendingFullRefresh = true
            }
            binding.wrappedValue = nextIdx
        }

        let goNext: () -> Void = {
            guard idx + 1 < total else { return }
            let nextIdx = idx + 1
            if nextIdx % flashEvery == 0 {
                KindleStateRegistry.shared.pendingFullRefresh = true
            }
            binding.wrappedValue = nextIdx
        }

        if total <= 1 {
            return VStack(alignment: .leading, spacing: 16) {
                pageBuilder(0, pages[0])
            }
            .expand(true, fill: true)
            .buildRenderTree()
        }

        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                pageBuilder(idx, pages[idx])
            }
            .expand(true, fill: true)
            .onSwipeGesture(onLeft: goNext, onRight: goPrev)

            HStack(alignment: .center, spacing: 20) {
                Button("← Prev Page", action: goPrev)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(idx == 0)

                Spacer()

                let pct = Int(round(Double(idx + 1) / Double(max(1, total)) * 100))
                Text("Page \(idx + 1) of \(total)  ·  \(pct)%")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(KindleTheme.current.mutedForeground)

                Spacer()

                Button("Next Page →", action: goNext)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(idx + 1 >= total)
            }
        }
        .expand(true, fill: true)
        .buildRenderTree()
    }
}

/// A Kindle Bookerly paginated text reader that automatically splits long articles or books
/// into discrete E-Ink pages with swipe & tap page turning.
public struct BookReaderView: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let authorOrSource: String?
    public let text: String
    public let page: Binding<Int>
    public let fontSize: Int
    public let charactersPerPage: Int

    public init(
        title: String,
        authorOrSource: String? = nil,
        text: String,
        page: Binding<Int>,
        fontSize: Int = 16,
        charactersPerPage: Int = 1400
    ) {
        self.title = title
        self.authorOrSource = authorOrSource
        self.text = text
        self.page = page
        self.fontSize = max(11, min(28, fontSize))
        self.charactersPerPage = max(180, charactersPerPage)
    }

    public init(
        title: String,
        text: String,
        fontSize: Int = 16,
        wordsPerPage: Int = 210,
        currentPage: Binding<Int>
    ) {
        self.title = title
        self.authorOrSource = nil
        self.text = text
        self.page = currentPage
        self.fontSize = max(11, min(28, fontSize))
        self.charactersPerPage = max(40, wordsPerPage * 6)
    }

    public static func paginateText(_ text: String, maxCharsPerPage: Int) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return ["(Empty document)"] }
        let words = cleaned.split(omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
        var pages: [String] = []
        var current = ""

        for word in words {
            let w = String(word)
            if current.isEmpty {
                current = w
            } else if current.count + 1 + w.count <= maxCharsPerPage {
                current += " " + w
            } else {
                pages.append(current)
                current = w
            }
        }
        if !current.isEmpty {
            pages.append(current)
        }
        return pages.isEmpty ? [cleaned] : pages
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let chunks = Self.paginateText(text, maxCharsPerPage: charactersPerPage)
        let fSize = fontSize
        let docTitle = title
        let source = authorOrSource

        return KindlePager(pages: chunks, currentPage: page) { idx, chunk in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Icon(.book, size: 36)
                        .foregroundColor(theme.mutedForeground)
                    Text(docTitle)
                        .font(.headline)
                        .foregroundColor(theme.foreground)
                    Spacer()
                    if let source = source, !source.isEmpty {
                        Text(source)
                            .font(.caption)
                            .foregroundColor(theme.mutedForeground)
                    }
                }

                Divider(thickness: 1, color: theme.subtleBorder)

                Text(chunk)
                    .lineWrap(true)
                    .font(.bookerly(size: fSize))
                    .foregroundColor(theme.foreground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                Spacer()
            }
            .padding(EdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32))
            .background(theme.cardBackground, cornerRadius: 20)
            .border(theme.subtleBorder, width: 1, cornerRadius: 20)
            .expand(true, fill: true)
        }
        .expand(true, fill: true)
        .buildRenderTree()
    }
}
