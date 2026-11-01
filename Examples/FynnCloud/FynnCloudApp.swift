import Foundation
import KindleUI

@main
struct FynnCloudApp: App {
    static let applicationID = "org.kindlemodding.fynncloud"

    init() {}

    var body: some Scene {
        WindowGroup(id: Self.applicationID) {
            FynnCloudRootView()
        }
    }
}

struct FynnCloudRootView: View {
    internal static var didBootstrap: Bool = false

    @State internal var selectedTab: DashboardTab = {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--tab"), idx + 1 < args.count {
            let raw = args[idx + 1].lowercased()
            for tab in DashboardTab.allCases where tab.rawValue.lowercased() == raw {
                return tab
            }
        }
        return .activity
    }()

    @State internal var filesPageIndex: Int = 0

    // Setup Wizard Text Inputs & Embedded OAuth WebKit Controller
    @State internal var serverUrlField: String = "https://cloud.fynncloud.ch"
    @State internal var tokenField: String = ""
    @State internal var instanceNameField: String = "FynnCloud"
    @State internal var oauthWebController: WebViewController = {
        let store = FynnCloudStore.shared
        let authURL = store.pendingAuthorizeURL ?? store.buildOAuthAuthorizeURL(serverUrl: store.serverUrlInput)
        return WebViewController(
            id: "fynncloud-oauth-browser",
            url: authURL,
            html: nil,
            baseURL: store.serverUrlInput,
            zoomLevel: 1.5
        )
    }()
    @State internal var oauthAddressBar: String = ""

    // Sheet Presentation States (matching iOS sheets in DashboardView / ActivityTab)
    @State internal var showActivityDetailSheet: Bool = false
    @State internal var showFilesSheet: Bool = false

    @State internal var showShareSheet: Bool = false
    @State internal var shareTargetFileId: String = ""
    @State internal var shareCollaboratorInput: String = ""
    @State internal var shareRoleSelection: String = "edit"
    @State internal var shareLinkLabelInput: String = ""

    @State internal var showNewFolderSheet: Bool = false
    @State internal var newFolderNameInput: String = ""

    @State internal var showRenameSheet: Bool = false
    @State internal var renameTargetFileId: String = ""
    @State internal var renameFileInput: String = ""

    @State internal var showDebugTokenSheet: Bool = false

    var body: some View {
        let store = FynnCloudStore.shared
        let theme = store.theme

        let oauthPresentedBinding = Binding<Bool>(
            get: { store.isOAuthBrowserPresented },
            set: {
                store.isOAuthBrowserPresented = $0
                store.notifyUI()
            }
        )

        return VStack(alignment: .leading, spacing: 12) {
            if !store.isSetupCompleted {
                setupWizardContainer(theme: theme)
                    .expand(true, fill: true)
            } else {
                // iOS Large Navigation Title Header + Toolbar (ported from DashboardView.swift)
                iosLargeNavigationHeader(theme: theme)

                if let toast = store.statusToast {
                    HStack(alignment: .center, spacing: 10) {
                        Icon(.info, size: 16)
                            .foregroundColor(theme.brandAccent)
                        Text(toast)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryInk)
                            .expand(true, fill: true)
                        Button("OK") {
                            store.statusToast = nil
                            store.notifyUI()
                        }
                        .buttonStyle(.capsule)
                        .controlSize(.mini)
                    }
                    .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                    .background(theme.cardBg, cornerRadius: 12)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 12)
                }

                // Active Dashboard Tab Content
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case .activity:
                        activityTabView(theme: theme)
                            .expand(true, fill: true)
                    case .account:
                        accountTabView(theme: theme)
                            .expand(true, fill: true)
                    case .settings:
                        settingsTabView(theme: theme)
                            .expand(true, fill: true)
                    case .trash:
                        trashTabView(theme: theme)
                            .expand(true, fill: true)
                    case .debug:
                        debugTabView(theme: theme)
                            .expand(true, fill: true)
                    }
                }
                .expand(true, fill: true)

                // iOS Bottom Navigation Bar (ported 1:1 from BottomNavigationBar.swift)
                fynnCloudBottomCapsuleNavBar(theme: theme)
            }
        }
        .expand(true, fill: true)
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 6, trailing: 20))
        .background(theme.pageBg)
        .preferredColorScheme(store.isDarkMode ? .dark : .light)
        .einkRefreshPolicy(.automatic)
        .fullScreenCover(isPresented: oauthPresentedBinding) {
            oauthBrowserModalView(theme: theme)
        }
        .sheet(isPresented: $showActivityDetailSheet, title: "Activity Details", detent: .large) {
            activityDetailSheetView(theme: theme)
        }
        .sheet(isPresented: $showFilesSheet, title: "\(store.instanceName) Files", detent: .large) {
            filesBrowserSheetView(theme: theme)
        }
        .sheet(isPresented: $showShareSheet, title: "Share & Permissions", detent: .fit) {
            shareSheetView(theme: theme)
        }
        .sheet(isPresented: $showNewFolderSheet, title: "Create New Folder", detent: .fit) {
            newFolderSheetView(theme: theme)
        }
        .sheet(isPresented: $showRenameSheet, title: "Rename Item", detent: .fit) {
            renameFileSheetView(theme: theme)
        }
        .sheet(isPresented: $showDebugTokenSheet, title: "Debug Token Editor", detent: .fit) {
            debugTokenSheetView(theme: theme)
        }
        .onAppear {
            if !Self.didBootstrap {
                Self.didBootstrap = true
                let args = CommandLine.arguments
                if args.contains("--wizard") || args.contains("--login") || args.contains("--oauth") {
                    store.isSetupCompleted = false
                    store.wizardStep = (args.contains("--login") || args.contains("--oauth")) ? .login : .welcome
                    store.notifyUI()
                } else if !store.isAuthenticated {
                    store.enableDemoMode()
                }
            }
        }
    }

    // MARK: - iOS Large Title Navigation Header + Toolbar (Ported 1:1 from DashboardView.swift)

    internal func iosLargeNavigationHeader(theme: FynnCloudTheme) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(selectedTab.rawValue)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(theme.primaryInk)
                .expand(false, fill: false)

            Spacer()

            // On Activity tab, show the iOS `viewFilesToolbarButton` ("Files" capsule button in primary brand color)
            if selectedTab == .activity {
                Button(action: {
                    showFilesSheet = true
                }) {
                    HStack(alignment: .center, spacing: 7) {
                        Icon(.folder, size: 16)
                            .foregroundColor(theme.cardBg)
                        Text("Files")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.cardBg)
                            .expand(false, fill: false)
                    }
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .background(theme.brandAccent, cornerRadius: 999)
                }
                .buttonStyle(.plain)
                .expand(false, fill: false)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 2, trailing: 4))
    }

    // MARK: - Floating Capsule Bottom Navigation Bar (Ported 1:1 from BottomNavigationBar.swift)

    internal func fynnCloudBottomCapsuleNavBar(theme: FynnCloudTheme) -> some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                let isSelected = (selectedTab == tab)
                let isTrash = (tab == .trash)
                let activeAccent = isTrash ? theme.dangerColor : theme.brandAccent
                let itemBg: EInkColor = isSelected ? theme.cardBg : theme.brandAccent
                let itemFg: EInkColor = isSelected ? activeAccent : theme.cardBg

                Button(action: {
                    KindleKeyboardManager.shared.dismiss()
                    selectedTab = tab
                }) {
                    VStack(alignment: .center, spacing: 3) {
                        Icon(tab.icon, size: 18)
                            .foregroundColor(itemFg)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(itemFg)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .expand(false, fill: false)
                    }
                    .expand(true, fill: true)
                }
                .buttonStyle(.plain)
                .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
                .background(itemBg, cornerRadius: 999)
                .expand(true, fill: true)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        .background(theme.brandAccent, cornerRadius: 999)
    }

    // MARK: - 3-Step Setup Wizard (Ported 1:1 from SetupWizardView, WelcomeView, LoginView, FolderSetupView)

    internal func setupWizardContainer(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared

        return VStack(alignment: .center, spacing: 14) {
            // Subtle top-right action bar for Demo / Close on Kindle
            HStack(alignment: .center, spacing: 10) {
                Spacer()
                Button(action: {
                    store.enableDemoMode()
                }) {
                    HStack(spacing: 6) {
                        Icon(.clock, size: 15)
                        Text("Dashboard Demo")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .buttonStyle(.capsule)
                .controlSize(.small)

                Button(action: {
                    KindleDevice.shared.quitApplication()
                }) {
                    Icon(.close, size: 16)
                }
                .buttonStyle(.capsule)
                .controlSize(.small)
            }

            switch store.wizardStep {
            case .welcome:
                welcomeWizardStep(theme: theme)
            case .login:
                loginWizardStep(theme: theme)
            case .folderSetup:
                folderSetupWizardStep(theme: theme)
            }
        }
        .expand(true, fill: true)
    }

    // Step 1: WelcomeView.swift 1:1 port
    internal func welcomeWizardStep(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .center, spacing: 24) {
            Spacer()

            // Header Branding (AppLogo + Welcome to FynnCloud + Subtitle)
            VStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 0) {
                    Icon(.cloud, size: 36)
                        .foregroundColor(theme.cardBg)
                }
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
                .background(theme.brandAccent, cornerRadius: 22)
                .expand(false, fill: false)

                Text("Welcome to \(store.instanceName)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.primaryInk)
                    .multilineTextAlignment(.center)

                Text("Your self-hosted cloud storage, seamlessly synchronized across all your devices.")
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryInk)
                    .multilineTextAlignment(.center)
            }

            // Elevated Connection Card (matching WelcomeView.connectionCard)
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect to Server")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.primaryInk)

                Text("Enter your server address to get started.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryInk)

                Text("Server Address")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.secondaryInk)

                TextField("https://cloud.example.com", text: $serverUrlField, onCommit: {
                    store.checkServerAndPrepareLogin(serverInput: serverUrlField)
                })

                if let err = store.authErrorMessage {
                    Text(err)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.dangerColor)
                }

                Button(action: {
                    store.checkServerAndPrepareLogin(serverInput: serverUrlField)
                }) {
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text(store.isAuthenticating ? "Connecting…" : "Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.cardBg)
                            .expand(false, fill: false)
                        Icon(.chevronRight, size: 16)
                            .foregroundColor(theme.cardBg)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .background(theme.brandAccent, cornerRadius: 12)
                }
                .buttonStyle(.plain)

                Button(action: {
                    showDebugTokenSheet = true
                }) {
                    HStack(alignment: .center, spacing: 6) {
                        Spacer()
                        Icon(.bug, size: 14)
                            .foregroundColor(theme.secondaryInk)
                        Text("Developer: Enter Tokens Manually")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.secondaryInk)
                            .expand(false, fill: false)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 6, leading: 8, bottom: 2, trailing: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(theme.cardBg, cornerRadius: 18)
            .border(theme.borderSubtle, width: 1, cornerRadius: 18)

            Spacer()
        }
        .expand(true, fill: true)
    }

    // Step 2: LoginView.swift 1:1 port
    internal func loginWizardStep(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let cleanHost = URL(string: store.serverUrlInput)?.host ?? store.serverUrlInput

        return VStack(alignment: .center, spacing: 24) {
            Spacer()

            VStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 0) {
                    Icon(.cloud, size: 36)
                        .foregroundColor(theme.cardBg)
                }
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
                .background(theme.brandAccent, cornerRadius: 22)
                .expand(false, fill: false)

                Text("Sign In")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.primaryInk)
                    .multilineTextAlignment(.center)

                Text("Sign in with your browser to connect this device to your cloud.")
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryInk)
                    .multilineTextAlignment(.center)

                // Server Badge Pill (matching LoginView.serverBadge)
                HStack(alignment: .center, spacing: 6) {
                    Icon(.server, size: 14)
                        .foregroundColor(theme.brandAccent)
                    Text(cleanHost)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondaryInk)
                        .expand(false, fill: false)
                }
                .expand(false, fill: false)
                .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                .background(theme.cardBg, cornerRadius: 999)
                .border(theme.borderSubtle, width: 1, cornerRadius: 999)
            }

            // Elevated Login Card (matching LoginView.loginCard)
            VStack(alignment: .leading, spacing: 14) {
                Text("Browser Sign In")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.primaryInk)

                Text("A browser window will open to authenticate your account and redirect back automatically.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryInk)

                if store.callbackDetected {
                    HStack(alignment: .center, spacing: 10) {
                        Icon(.check, size: 22)
                            .foregroundColor(theme.successColor)
                        Text(store.isAuthenticating ? "Signing you in…" : "Successfully signed in!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.primaryInk)
                    }
                    .padding(14)
                    .background(theme.brandSoftTint, cornerRadius: 12)
                } else {
                    Button(action: {
                        openOAuthBrowser()
                    }) {
                        HStack(alignment: .center, spacing: 8) {
                            Spacer()
                            Icon(.globe, size: 18)
                                .foregroundColor(theme.cardBg)
                            Text(store.browserOpened ? "Reopen Browser" : "Open Browser")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(theme.cardBg)
                                .expand(false, fill: false)
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .background(theme.brandAccent, cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }

                if let err = store.authErrorMessage {
                    Text(err)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.dangerColor)
                }

                Button(action: {
                    showDebugTokenSheet = true
                }) {
                    HStack(alignment: .center, spacing: 6) {
                        Spacer()
                        Icon(.bug, size: 14)
                            .foregroundColor(theme.secondaryInk)
                        Text("Developer: Enter Tokens Manually")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryInk)
                            .expand(false, fill: false)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Divider()

                HStack(alignment: .center, spacing: 12) {
                    Button(action: {
                        store.wizardStep = .welcome
                        store.notifyUI()
                    }) {
                        HStack(spacing: 6) {
                            Icon(.chevronLeft, size: 14)
                                .foregroundColor(theme.secondaryInk)
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                    }
                    .buttonStyle(.plain)
                    .expand(false, fill: false)

                    Spacer()
                }
            }
            .padding(24)
            .background(theme.cardBg, cornerRadius: 18)
            .border(theme.borderSubtle, width: 1, cornerRadius: 18)

            Spacer()
        }
        .expand(true, fill: true)
    }

    internal func openOAuthBrowser() {
        let store = FynnCloudStore.shared
        let targetServer = store.serverUrlInput.isEmpty ? serverUrlField : store.serverUrlInput
        let authUrl = store.buildOAuthAuthorizeURL(serverUrl: targetServer)
        oauthAddressBar = authUrl
        store.browserOpened = true
        store.callbackDetected = false
        store.isOAuthBrowserPresented = true

        let host = (URL(string: targetServer)?.host ?? "").lowercased()
        if host == "cloud.fynn.dev" || host == "cloud.example.com" || host.isEmpty {
            let portalHTML = store.buildInteractiveOAuthPortalHTML(serverUrl: targetServer, authorizeURL: authUrl)
            oauthWebController.loadHTML(portalHTML, baseURL: targetServer, title: "Sign in to \(store.instanceName)")
        } else {
            oauthWebController.load(url: authUrl)
        }
        store.notifyUI()
    }

    internal func oauthBrowserModalView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    store.isOAuthBrowserPresented = false
                    store.notifyUI()
                }) {
                    HStack(spacing: 6) {
                        Icon(.close, size: 16)
                        Text("Close")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .buttonStyle(.capsule)
                .controlSize(.small)

                HStack(alignment: .center, spacing: 8) {
                    Icon(.lock, size: 14)
                        .foregroundColor(theme.successColor)
                    Text(oauthAddressBar.isEmpty ? (store.pendingAuthorizeURL ?? store.serverUrlInput) : oauthAddressBar)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(theme.secondaryInk)
                        .lineLimit(1)
                        .expand(true, fill: true)
                }
                .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .expand(true, fill: true)
                .background(theme.pageBg, cornerRadius: 999)
                .border(theme.borderSubtle, width: 1, cornerRadius: 999)

                Button(action: {
                    _ = store.handleOAuthCallbackURL("fynncloud://auth?code=fc_pkce_thilo_2026&state=kindle")
                }) {
                    HStack(spacing: 6) {
                        Icon(.check, size: 16)
                            .foregroundColor(theme.cardBg)
                        Text("Authorize Callback")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .cornerRadius(999)
            }
            .padding(12)
            .background(theme.cardBg, cornerRadius: 16)
            .border(theme.borderSubtle, width: 1, cornerRadius: 16)

            WebView(
                controller: oauthWebController,
                minHeight: 700,
                onLoadFinished: {
                    let current = oauthWebController.currentURL
                    if !current.isEmpty {
                        oauthAddressBar = current
                        if store.handleOAuthCallbackURL(current) {
                            return
                        }
                    }
                    oauthWebController.evaluateJavaScript(store.webAuthHydrationScript)
                }
            )
            .expand(true, fill: true)
        }
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .expand(true, fill: true)
        .background(theme.pageBg)
    }

    // Step 3: FolderSetupView.swift 1:1 port ("You're All Set")
    internal func folderSetupWizardStep(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let username = store.activeAccount?.displayLabel ?? "thilo"

        return VStack(alignment: .center, spacing: 24) {
            Spacer()

            VStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 0) {
                    Icon(.cloud, size: 36)
                        .foregroundColor(theme.cardBg)
                }
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
                .background(theme.brandAccent, cornerRadius: 22)
                .expand(false, fill: false)

                Text("You're All Set")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.primaryInk)
                    .multilineTextAlignment(.center)

                Text("\(store.instanceName) is connected. Your files will appear in the Files view automatically.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryInk)
                    .multilineTextAlignment(.center)
            }

            // Elevated Ready Card (matching FolderSetupView.readyCard)
            VStack(alignment: .leading, spacing: 14) {
                // Account Connected Tile
                HStack(alignment: .center, spacing: 12) {
                    Icon(.user, size: 22)
                        .foregroundColor(theme.brandAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(username)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.primaryInk)
                        Text("Account Connected")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryInk)
                    }
                    .expand(true, fill: true)
                    Icon(.check, size: 18)
                        .foregroundColor(theme.successColor)
                }
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                .background(theme.pageBg, cornerRadius: 12)

                // Files Cloud Storage Location Tile
                HStack(alignment: .center, spacing: 12) {
                    Icon(.folder, size: 20)
                        .foregroundColor(theme.secondaryInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Files (\(store.syncFolderPath))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primaryInk)
                        Text("Cloud storage location")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryInk)
                    }
                    .expand(true, fill: true)
                    Text("Ready")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondaryInk)
                        .expand(false, fill: false)
                }
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                .background(theme.pageBg, cornerRadius: 12)

                HStack(alignment: .center, spacing: 12) {
                    Button(action: {
                        store.wizardStep = .login
                        store.notifyUI()
                    }) {
                        HStack(spacing: 6) {
                            Icon(.chevronLeft, size: 14)
                                .foregroundColor(theme.secondaryInk)
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                    }
                    .buttonStyle(.plain)
                    .expand(false, fill: false)

                    Spacer()

                    Button(action: {
                        store.isSetupCompleted = true
                        store.savePersistedState()
                        store.notifyUI()
                    }) {
                        HStack(alignment: .center, spacing: 8) {
                            Icon(.check, size: 16)
                                .foregroundColor(theme.cardBg)
                            Text("Finish")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.cardBg)
                                .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 22))
                        .background(theme.brandAccent, cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .expand(false, fill: false)
                }
            }
            .padding(20)
            .background(theme.cardBg, cornerRadius: 18)
            .border(theme.borderSubtle, width: 1, cornerRadius: 18)

            Spacer()
        }
        .expand(true, fill: true)
    }
}
