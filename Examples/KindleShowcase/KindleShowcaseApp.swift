import Foundation
import KindleUI

// MARK: - Application Entry Point

@main
struct KindleShowcaseApp: App {
    static let applicationID = "org.kindlemodding.KindleShowcase"

    init() {}

    var body: some Scene {
        WindowGroup(id: Self.applicationID) {
            KindleShowcaseRootView()
        }
    }
}

// MARK: - Root View

struct KindleShowcaseRootView: View {
    // Persistent AppStorage state across launches
    @AppStorage("showcase.darkTheme") internal var useDarkTheme: Bool = false
    @AppStorage("showcase.refreshMode") internal var refreshMode: RefreshModeOption = .balanced
    @AppStorage("showcase.frontlight") internal var frontlightLevel: Double = 65
    @AppStorage("showcase.warmth") internal var warmthStep: Int = 4
    @AppStorage("showcase.launchCount") internal var launchCount: Int = 1

    // Tab Navigation
    @State internal var selectedTab: AppTab = {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--tab"), idx + 1 < args.count,
           let tab = AppTab.fromAppStorageString(args[idx + 1]) {
            return tab
        }
        return .controls
    }()
    @State internal var statusBanner: String = "Ready"

    // Tab 1: Controls & Inputs state
    @State internal var airplaneMode: Bool = false
    @State internal var syncAnnotations: Bool = true
    @State internal var boldTypography: Bool = false
    @State internal var readerName: String = "Marcus Aurelius"
    @State internal var wifiPassphrase: String = "stoic-citadel"
    @State internal var notesText: String = "Book IV, §3: Men seek retreats for themselves, houses in the country, sea-shores, and mountains…"
    @State internal var targetDate: Date = Date()
    @State internal var batteryLevel: Double = 0.84

    // Modal & Overlay Presentations
    @State internal var showDisplaySheet: Bool = false
    @State internal var showReaderCover: Bool = false
    @State internal var showQuickPopover: Bool = CommandLine.arguments.contains("--popover")
    @State internal var showExportDialog: Bool = false
    @State internal var showResetAlert: Bool = false

    // Tab 2: Library state
    @State internal var navPath = NavigationPath()
    @State internal var books: [BookItem] = initialBooks
    @State internal var selectedCategory: LibraryCategory = .all
    @State internal var searchQuery: String = ""
    @State internal var expandAdvancedMetrics: Bool = true
    @State internal var listEditMode: EditMode = .inactive
    @State internal var refreshCounter: Int = 0

    // Tab 3: Canvas, Shapes & Grayscale state
    @State internal var sketchBuffer = KindleCanvasBuffer(width: 1120, height: 280, fill: 255)
    @State internal var sketchDidSeed: Bool = false
    @State internal var sketchSeededWidth: Int = 0
    @State internal var penThickness: Int = 3
    @State internal var strokeCount: Int = 0

    // Tab 4: Embedded WebKit Browser state
    @State internal var browserWeb = WebViewController(id: "showcase-browser")
    @State internal var browserURL: String = "https://kindle.local/welcome"
    @State internal var browserStatus: String = "Ready"
    @State internal var browserDidSeed: Bool = false

    // Tab 5: Charts state
    @State internal var chartSeriesMode: Int = 0
    @State internal var timelineRefreshTick: Int = 0

    // Tab 6: Settings state
    @State internal var splitVisibility: NavigationSplitViewVisibility = .all
    @State internal var selectedSettingsSection: SettingsSection = .display
    @State internal var showStorageInspector: Bool = false

    var body: some View {
        let theme = KindleTheme.current

        return VStack(alignment: .leading, spacing: 18) {
            topAppHeader(theme: theme)

            TabView(selection: $selectedTab) {
                Tab("Controls", icon: .sliders, value: AppTab.controls) {
                    controlsTab(theme: theme)
                }
                Tab("Library", icon: .book, value: AppTab.navigation) {
                    navigationTab(theme: theme)
                }
                Tab("Canvas", icon: .pencil, value: AppTab.canvas) {
                    canvasTab(theme: theme)
                }
                Tab("Browser", icon: .globe, value: AppTab.browser) {
                    browserTab(theme: theme)
                }
                Tab("Charts", icon: .star, value: AppTab.charts) {
                    chartsTab(theme: theme)
                }
                Tab("Settings", icon: .gear, value: AppTab.settings) {
                    settingsTab(theme: theme)
                }
            }
            .tabViewStyle(.bottomBar)
            .expand(true, fill: true)
        }
        .expand(true, fill: true)
        .padding(EdgeInsets(top: 18, leading: 32, bottom: 18, trailing: 32))
        .background(theme.background)
        .preferredColorScheme(useDarkTheme ? .dark : .light)
        .einkRefreshPolicy(.automatic)
        .sheet(isPresented: $showDisplaySheet, title: "Display Settings", detent: .medium) {
            displaySheetContent(theme: theme)
        }
        .fullScreenCover(isPresented: $showReaderCover) {
            distractionFreeReaderCover(theme: theme)
        }
        .confirmationDialog(
            "Export Reading Notes",
            isPresented: $showExportDialog,
            message: "Choose a format for your highlights and notes.",
            actions: [
                AlertButton("Export Markdown (.md)") {
                    statusBanner = "Exported Markdown"
                },
                AlertButton("Export JSON (.json)") {
                    statusBanner = "Exported JSON"
                },
                AlertButton("Clear Highlights", role: .destructive) {
                    statusBanner = "Cleared highlights"
                },
                AlertButton("Cancel", role: .cancel) {}
            ]
        )
        .alert(
            "Reset Defaults?",
            isPresented: $showResetAlert,
            message: "Restore default library items, controls, and canvas.",
            primaryButton: AlertButton("Reset", role: .destructive) {
                resetAllState()
            },
            secondaryButton: AlertButton("Cancel", role: .cancel) {}
        )
        .inspector(isPresented: $showStorageInspector, columnWidth: 480) {
            storageInspectorDrawer(theme: theme)
        }
        .onAppear {
            if !sketchDidSeed {
                sketchDidSeed = true
                seedDefaultSketch()
            }
            if !browserDidSeed {
                browserDidSeed = true
                loadWelcomeHTML()
            }
        }
    }

    // MARK: - Persistent Top App Header

    internal func topAppHeader(theme: KindleTheme) -> some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Icon(.star, size: 28)
                    .foregroundColor(theme.foreground)
                Text("KindleShowcase")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)
                Text("·  \(selectedTab.subtitle)")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(theme.mutedForeground)
                    .lineLimit(1)
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    useDarkTheme.toggle()
                }) {
                    HStack(spacing: 8) {
                        Icon(useDarkTheme ? .sun : .moon, size: 20)
                        Text(useDarkTheme ? "Light" : "Dark")
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

    // MARK: - State Reset Helper

    internal func resetAllState() {
        books = initialBooks
        selectedCategory = .all
        searchQuery = ""
        frontlightLevel = 65
        warmthStep = 4
        batteryLevel = 0.84
        useDarkTheme = false
        seedDefaultSketch()
        statusBanner = "Ready"
    }
}
