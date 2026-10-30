import Foundation
import KindleUI

// MARK: - Navigation & Domain Models

enum AppTab: String, CaseIterable, Hashable, AppStorageConvertible {
    case controls = "Controls"
    case navigation = "Navigation"
    case canvas = "Canvas"
    case browser = "Browser"
    case charts = "Charts"
    case settings = "Settings"

    var subtitle: String {
        switch self {
        case .controls: return "Controls"
        case .navigation: return "Library"
        case .canvas: return "Canvas"
        case .browser: return "Browser"
        case .charts: return "Analytics"
        case .settings: return "Settings"
        }
    }

    func toAppStorageString() -> String { rawValue }
    static func fromAppStorageString(_ raw: String) -> AppTab? {
        if let exact = AppTab(rawValue: raw) { return exact }
        return AppTab.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
    }
}

enum RefreshModeOption: String, CaseIterable, CustomStringConvertible, AppStorageConvertible {
    case fast = "Fast"
    case balanced = "Balanced"
    case crisp = "Crisp"

    var description: String { rawValue }
    func toAppStorageString() -> String { rawValue }
    static func fromAppStorageString(_ raw: String) -> RefreshModeOption? { RefreshModeOption(rawValue: raw) }
}

enum LibraryCategory: String, CaseIterable, Hashable, CustomStringConvertible {
    case all = "All"
    case philosophy = "Philosophy"
    case sciFi = "Sci-Fi"
    case classics = "Classics"
    case technical = "Technical"

    var description: String { rawValue }
}

struct BookItem: Identifiable, Hashable {
    let id: String
    var title: String
    let author: String
    let category: LibraryCategory
    var progress: Double
    let pages: Int
    let summary: String
}

let initialBooks: [BookItem] = [
    BookItem(
        id: "meditations",
        title: "Meditations",
        author: "Marcus Aurelius",
        category: .philosophy,
        progress: 0.78,
        pages: 254,
        summary: "Personal stoic reflections written during military campaigns along the Danube."
    ),
    BookItem(
        id: "dune",
        title: "Dune",
        author: "Frank Herbert",
        category: .sciFi,
        progress: 0.45,
        pages: 688,
        summary: "Epic struggle over Arrakis and the desert ecology of melange."
    ),
    BookItem(
        id: "odyssey",
        title: "The Odyssey",
        author: "Homer",
        category: .classics,
        progress: 0.92,
        pages: 416,
        summary: "Ten-year homeward voyage of Odysseus from Troy to Ithaca."
    ),
    BookItem(
        id: "kr-c",
        title: "The C Programming Language",
        author: "Kernighan & Ritchie",
        category: .technical,
        progress: 0.64,
        pages: 272,
        summary: "Concise foundational treatise on systems programming and portable C."
    ),
    BookItem(
        id: "neuromancer",
        title: "Neuromancer",
        author: "William Gibson",
        category: .sciFi,
        progress: 0.31,
        pages: 292,
        summary: "Cyberspace heist novel that defined the cyberpunk genre."
    )
]

struct GenreStat: Identifiable {
    let id: String
    let subject: String
    let volumes: String
    let hoursRead: String
    let completion: String
}

let sampleGenreStats: [GenreStat] = [
    GenreStat(id: "phil", subject: "Philosophy", volumes: "4 volumes", hoursRead: "18.5 hrs", completion: "82%"),
    GenreStat(id: "scifi", subject: "Science Fiction", volumes: "6 volumes", hoursRead: "24.0 hrs", completion: "64%"),
    GenreStat(id: "classics", subject: "Classical Literature", volumes: "3 volumes", hoursRead: "14.2 hrs", completion: "91%"),
    GenreStat(id: "tech", subject: "Computer Science", volumes: "5 volumes", hoursRead: "11.8 hrs", completion: "58%")
]

struct OutlineNode: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    var children: [OutlineNode]? = nil
}

let sampleOutlineTree: [OutlineNode] = [
    OutlineNode(
        id: "part-1",
        title: "Part I — Books I to IV",
        subtitle: "Pages 1–96",
        children: [
            OutlineNode(id: "ch-1", title: "Book I: Debts and Lessons", subtitle: "Pages 1–24"),
            OutlineNode(id: "ch-2", title: "Book II: On the River Gran", subtitle: "Pages 25–48"),
            OutlineNode(id: "ch-3", title: "Book III: In Carnuntum", subtitle: "Pages 49–72"),
            OutlineNode(id: "ch-4", title: "Book IV: The Inner Citadel", subtitle: "Pages 73–96")
        ]
    ),
    OutlineNode(
        id: "part-2",
        title: "Part II — Books V to VIII",
        subtitle: "Pages 97–198",
        children: [
            OutlineNode(id: "ch-5", title: "Book V: At Dawn", subtitle: "Pages 97–142"),
            OutlineNode(id: "ch-6", title: "Book VI: Nature's Order", subtitle: "Pages 143–198")
        ]
    )
]

struct BrowserPreset: Identifiable {
    let id: String
    let title: String
    let url: String
}

let browserPresets: [BrowserPreset] = [
    BrowserPreset(id: "welcome", title: "Home", url: "https://kindle.local/welcome"),
    BrowserPreset(id: "wiki", title: "Wikipedia", url: "https://en.m.wikipedia.org/wiki/Electronic_paper"),
    BrowserPreset(id: "example", title: "Example.com", url: "https://example.com"),
    BrowserPreset(id: "gutenberg", title: "Gutenberg", url: "https://www.gutenberg.org")
]

enum SettingsSection: String, CaseIterable, Hashable, CustomStringConvertible {
    case display = "Display"
    case reading = "Reading"
    case storage = "Storage"
    case device = "About"

    var description: String { rawValue }
}

// MARK: - Editorial Section Helper (`Surface`)

struct Surface<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        _ = subtitle
        self.content = content()
    }

    var body: some View {
        let theme = KindleTheme.current
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundColor(theme.foreground)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(EdgeInsets(top: 18, leading: 22, bottom: 18, trailing: 22))
            .background(theme.cardBackground, in: .rect(cornerRadius: 16))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
        }
    }
}
