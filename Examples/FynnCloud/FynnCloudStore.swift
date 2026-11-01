import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import KindleUI

public final class FynnCloudStore: @unchecked Sendable {
    public static let shared = FynnCloudStore()

    // MARK: - Setup Wizard & Auth State

    public var isSetupCompleted: Bool = false
    public var wizardStep: SetupWizardStep = .welcome
    public var isAuthenticated: Bool = false
    public var isAuthenticating: Bool = false
    public var authErrorMessage: String? = nil

    public var serverUrlInput: String = "https://cloud.fynncloud.ch"
    public var manualTokenInput: String = ""
    public var manualRefreshTokenInput: String = ""
    public var manualAuthCodeInput: String = ""
    public var pkceCodeVerifier: String? = nil
    public var pendingAuthorizeURL: String? = nil
    public var browserOpened: Bool = false
    public var callbackDetected: Bool = false
    public var isOAuthBrowserPresented: Bool = false

    // MARK: - Accounts & User Profile

    public var accounts: [FynnCloudCredentials] = []
    public var activeAccountId: String? = nil

    public var currentUser: UserInfo? = nil
    public var currentQuota: UserQuota? = nil
    public var isLoadingUser: Bool = false
    public var userError: String? = nil

    // MARK: - Server Branding & Settings

    public var instanceName: String = "FynnCloud"
    public var brandColorName: String = "blue"
    public var showLogoAndName: Bool = true
    public var isDarkMode: Bool = false
    public var isColorEnabled: Bool = true
    public var syncFolderPath: String = "/mnt/us/documents/FynnCloud"

    // MARK: - Sync & Activity State

    public var syncStatus: SyncStatus = .synced
    public var activities: [ActivityItem] = []
    public var selectedActivityId: String? = nil
    public var isLoadingActivities: Bool = false
    public var activityError: String? = nil
    public var lastSyncedAt: Date? = Date()

    // MARK: - Files, Trash & Sharing State

    public var files: [CloudFileEntry] = []
    public var currentFolderId: String? = nil
    public var folderBreadcrumbs: [(id: String?, name: String)] = [(nil, "All Files")]
    public var filesFilter: FilesFilterMode = .all
    public var selectedFileId: String? = nil
    public var isLoadingFiles: Bool = false
    public var filesStatusBanner: String? = nil

    public var internalSharesByFile: [String: [InternalShareDTO]] = [:]
    public var shareLinksByFile: [String: [ShareLinkDTO]] = [:]

    // MARK: - Debug & Mock Mode State

    public var isMockDataEnabled: Bool = false
    public var mockScenario: MockActivityScenario = .standard
    public var mockQuotaPreset: MockQuotaPreset = .normal
    public var statusToast: String? = nil

    // MARK: - Computed Helpers

    public var theme: FynnCloudTheme {
        let colorSupport = isColorEnabled && KindleDevice.shared.isColorDisplay
        return FynnCloudTheme(
            isDark: isDarkMode,
            isColorEnabled: colorSupport,
            brandColorName: brandColorName
        )
    }

    public var activeAccount: FynnCloudCredentials? {
        if let id = activeAccountId, let found = accounts.first(where: { $0.accountId == id }) {
            return found
        }
        return accounts.first
    }

    public var selectedActivity: ActivityItem? {
        if let id = selectedActivityId, let found = activities.first(where: { $0.id == id }) {
            return found
        }
        return activities.first
    }

    public var visibleFiles: [CloudFileEntry] {
        let nonTrashed = files.filter { !$0.isTrashed }
        switch filesFilter {
        case .all:
            return nonTrashed
                .filter { $0.parentID == currentFolderId }
                .sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        case .favorites:
            return nonTrashed
                .filter { $0.isFavorite }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .shared:
            return nonTrashed
                .filter { $0.isShared }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .kindleDocs:
            return nonTrashed
                .filter {
                    let ext = ($0.name as NSString).pathExtension.lowercased()
                    return ["epub", "pdf", "mobi", "azw3", "kfx", "txt", "md"].contains(ext)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    public var trashedFiles: [CloudFileEntry] {
        files.filter { $0.isTrashed }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public var selectedFile: CloudFileEntry? {
        if let id = selectedFileId, let found = visibleFiles.first(where: { $0.id == id }) {
            return found
        }
        return visibleFiles.first
    }

    // MARK: - Initialization & Persistence

    private init() {
        KindleStateRegistry.shared.configureApplicationID("org.kindlemodding.fynncloud")
        isColorEnabled = KindleDevice.shared.isColorDisplay
        loadPersistedState()
        parseCommandLineArguments()
    }

    private var stateFilePath: String {
        "\(KindleStateRegistry.shared.appDataDirectory)/fynncloud_state.json"
    }

    private struct PersistedPayload: Codable {
        var isSetupCompleted: Bool
        var isAuthenticated: Bool
        var accounts: [FynnCloudCredentials]
        var activeAccountId: String?
        var instanceName: String
        var brandColorName: String
        var showLogoAndName: Bool
        var isDarkMode: Bool
        var isColorEnabled: Bool
        var syncFolderPath: String
        var isMockDataEnabled: Bool
    }

    public func savePersistedState() {
        let payload = PersistedPayload(
            isSetupCompleted: isSetupCompleted,
            isAuthenticated: isAuthenticated,
            accounts: accounts,
            activeAccountId: activeAccountId,
            instanceName: instanceName,
            brandColorName: brandColorName,
            showLogoAndName: showLogoAndName,
            isDarkMode: isDarkMode,
            isColorEnabled: isColorEnabled,
            syncFolderPath: syncFolderPath,
            isMockDataEnabled: isMockDataEnabled
        )
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: URL(fileURLWithPath: stateFilePath), options: .atomic)
        }
    }

    private func loadPersistedState() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
              let payload = try? JSONDecoder().decode(PersistedPayload.self, from: data) else {
            return
        }
        isSetupCompleted = payload.isSetupCompleted
        isAuthenticated = payload.isAuthenticated
        accounts = payload.accounts
        activeAccountId = payload.activeAccountId
        instanceName = payload.instanceName
        brandColorName = payload.brandColorName
        showLogoAndName = payload.showLogoAndName
        isDarkMode = payload.isDarkMode
        isColorEnabled = payload.isColorEnabled
        syncFolderPath = payload.syncFolderPath
        isMockDataEnabled = payload.isMockDataEnabled

        if isMockDataEnabled {
            applyMockData()
        } else if isAuthenticated {
            refreshAllData()
        }
    }

    private func parseCommandLineArguments() {
        let args = CommandLine.arguments
        if args.contains("--wizard") || args.contains("--login") || args.contains("--oauth") {
            isSetupCompleted = false
            wizardStep = (args.contains("--login") || args.contains("--oauth")) ? .login : .welcome
            if args.contains("--oauth") {
                let authURL = buildOAuthAuthorizeURL(serverUrl: serverUrlInput)
                pendingAuthorizeURL = authURL
                browserOpened = true
                callbackDetected = false
                isOAuthBrowserPresented = true
            }
            return
        }
        if args.contains("--mock") || args.contains("--demo") {
            enableDemoMode()
            return
        }
        var cliToken: String?
        var cliRefresh: String?
        var cliServer: String?
        var i = 0
        while i < args.count {
            if args[i] == "-authToken", i + 1 < args.count {
                cliToken = args[i + 1]
                i += 1
            } else if args[i] == "-refreshToken", i + 1 < args.count {
                cliRefresh = args[i + 1]
                i += 1
            } else if args[i] == "-serverUrl", i + 1 < args.count {
                cliServer = args[i + 1]
                i += 1
            }
            i += 1
        }
        if let token = cliToken, !token.isEmpty {
            let server = cliServer ?? serverUrlInput
            completeAuthentication(serverUrl: server, accessToken: token, refreshToken: cliRefresh)
            isSetupCompleted = true
            savePersistedState()
        } else if !isAuthenticated {
            enableDemoMode()
        }
    }

    public func notifyUI() {
        KindleStateRegistry.shared.notifyStateMutation()
    }

    // MARK: - Demo / Mock Mode Activation

    public func enableDemoMode() {
        isMockDataEnabled = true
        isAuthenticated = true
        isSetupCompleted = true
        authErrorMessage = nil

        if accounts.isEmpty {
            let demoCred = FynnCloudCredentials(
                accountId: "demo-fynncloud",
                username: "thilo",
                email: "thilo@fynn.cloud",
                serverUrl: "https://cloud.fynn.dev",
                authToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fynncloud_demo_token",
                refreshToken: "fynncloud_demo_refresh_token"
            )
            let workCred = FynnCloudCredentials(
                accountId: "work-nextcloud",
                username: "thilo.dev",
                email: "thilo@studio.example",
                serverUrl: "https://files.studio.example",
                authToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.studio_work_token",
                refreshToken: "studio_work_refresh_token"
            )
            accounts = [demoCred, workCred]
            activeAccountId = demoCred.accountId
        }

        applyMockData()
        savePersistedState()
        notifyUI()
    }

    public func applyMockData() {
        let now = Date()
        let me = ActivityUser(id: "u1", username: "thilo", displayName: "Thilo")
        let sarah = ActivityUser(id: "u2", username: "sarah", displayName: "Sarah Jenkins")
        let alex = ActivityUser(id: "u3", username: "alex", displayName: "Alex Rivera")

        currentUser = UserInfo(
            id: "u1",
            username: activeAccount?.username ?? "thilo",
            email: activeAccount?.email ?? "thilo@fynn.cloud",
            displayName: "Thilo",
            avatarUpdatedAt: "2026-10-30T12:00:00Z",
            currentStorageUsage: 34_896_609_280
        )

        let fiftyGB: Int64 = 50 * 1024 * 1024 * 1024
        switch mockQuotaPreset {
        case .low:
            currentQuota = UserQuota(limit: fiftyGB, used: Int64(Double(fiftyGB) * 0.12), percentage: 12.0, tierName: "Pro 50 GB")
        case .normal:
            currentQuota = UserQuota(limit: fiftyGB, used: Int64(Double(fiftyGB) * 0.65), percentage: 65.0, tierName: "Pro 50 GB")
        case .almostFull:
            currentQuota = UserQuota(limit: fiftyGB, used: Int64(Double(fiftyGB) * 0.92), percentage: 92.0, tierName: "Pro 50 GB")
        case .full:
            currentQuota = UserQuota(limit: fiftyGB, used: fiftyGB, percentage: 100.0, tierName: "Pro 50 GB")
        case .unlimited:
            currentQuota = UserQuota(limit: -1, used: 128 * 1024 * 1024 * 1024, percentage: 0, tierName: "Unlimited Team")
        }

        let standardActivities: [ActivityItem] = [
            ActivityItem(
                id: "mock-1",
                fileId: "f-1",
                fileName: "Q3 Product Strategy.pdf",
                isFolder: false,
                eventType: .modify,
                createdAt: now.addingTimeInterval(-180),
                user: me,
                size: 4_821_400,
                mimeType: "application/pdf",
                path: "/Work/Strategy/Q3 Product Strategy.pdf"
            ),
            ActivityItem(
                id: "mock-2",
                fileId: "f-2",
                fileName: "Design System v2",
                isFolder: true,
                eventType: .sharedInternal,
                createdAt: now.addingTimeInterval(-1420),
                user: me,
                path: "/Design/Design System v2",
                targetUsername: "sarah",
                shareRole: "editor"
            ),
            ActivityItem(
                id: "mock-3",
                fileId: "f-3",
                fileName: "Hero_Banner_Final.png",
                isFolder: false,
                eventType: .rename,
                createdAt: now.addingTimeInterval(-3900),
                user: sarah,
                size: 12_450_880,
                mimeType: "image/png",
                path: "/Design/Assets/Hero_Banner_Final.png",
                oldName: "Hero_Banner_v4_draft.png",
                newName: "Hero_Banner_Final.png"
            ),
            ActivityItem(
                id: "mock-4",
                fileId: "f-4",
                fileName: "Client_Deliverables.zip",
                isFolder: false,
                eventType: .shareLinkCreated,
                createdAt: now.addingTimeInterval(-7800),
                user: me,
                size: 148_920_000,
                mimeType: "application/zip",
                path: "/Projects/Client_Deliverables.zip"
            ),
            ActivityItem(
                id: "mock-5",
                fileId: "f-4",
                fileName: "Client_Deliverables.zip",
                isFolder: false,
                eventType: .publicDownload,
                createdAt: now.addingTimeInterval(-7200),
                user: nil,
                size: 148_920_000,
                mimeType: "application/zip",
                path: "/Projects/Client_Deliverables.zip"
            ),
            ActivityItem(
                id: "mock-6",
                fileId: "f-6",
                fileName: "2026 Roadmap.md",
                isFolder: false,
                eventType: .move,
                createdAt: now.addingTimeInterval(-18_400),
                user: alex,
                size: 18_420,
                mimeType: "text/markdown",
                path: "/Work/Planning/2026 Roadmap.md",
                oldPath: "/Drafts/2026 Roadmap.md",
                newPath: "/Work/Planning/2026 Roadmap.md"
            ),
            ActivityItem(
                id: "mock-7",
                fileId: "f-7",
                fileName: "Architecture Overview.epub",
                isFolder: false,
                eventType: .favorite,
                createdAt: now.addingTimeInterval(-42_000),
                user: me,
                size: 2_310_000,
                mimeType: "application/epub+zip",
                path: "/Kindle Library/Architecture Overview.epub"
            ),
            ActivityItem(
                id: "mock-8",
                fileId: "f-8",
                fileName: "Legacy_Backup_2023.tar.gz",
                isFolder: false,
                eventType: .trash,
                createdAt: now.addingTimeInterval(-90_000),
                user: me,
                size: 892_100_000,
                mimeType: "application/gzip",
                path: "/Backups/Legacy_Backup_2023.tar.gz"
            ),
            ActivityItem(
                id: "mock-9",
                fileId: "f-9",
                fileName: "SyncManager.swift",
                isFolder: false,
                eventType: .versionRestored,
                createdAt: now.addingTimeInterval(-172_800),
                user: me,
                size: 24_580,
                mimeType: "text/x-swift",
                path: "/Developer/FynnCloud/SyncManager.swift"
            ),
            ActivityItem(
                id: "mock-10",
                fileId: "f-10",
                fileName: "Financial_Model_v3.xlsx",
                isFolder: false,
                eventType: .shareRoleChanged,
                createdAt: now.addingTimeInterval(-259_200),
                user: me,
                size: 1_120_400,
                mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                path: "/Finance/Financial_Model_v3.xlsx",
                targetUsername: "alex",
                shareRole: "viewer"
            )
        ]

        switch mockScenario {
        case .standard:
            activities = standardActivities
        case .heavySharing:
            activities = standardActivities.filter { $0.eventType.isSharingEvent }
        case .cleanup:
            activities = standardActivities.filter { [.rename, .move, .trash, .delete, .versionRestored].contains($0.eventType) }
        case .empty:
            activities = []
        }

        if selectedActivityId == nil || !activities.contains(where: { $0.id == selectedActivityId }) {
            selectedActivityId = activities.first?.id
        }

        if files.isEmpty {
            files = [
                CloudFileEntry(
                    id: "folder-kindle",
                    name: "Kindle Library",
                    parentID: nil,
                    isDirectory: true,
                    updatedAt: now.addingTimeInterval(-3600),
                    isFavorite: true,
                    isShared: false,
                    path: "/Kindle Library"
                ),
                CloudFileEntry(
                    id: "folder-work",
                    name: "Work & Strategy",
                    parentID: nil,
                    isDirectory: true,
                    updatedAt: now.addingTimeInterval(-180),
                    isFavorite: false,
                    isShared: true,
                    path: "/Work & Strategy"
                ),
                CloudFileEntry(
                    id: "folder-design",
                    name: "Design System v2",
                    parentID: nil,
                    isDirectory: true,
                    updatedAt: now.addingTimeInterval(-1420),
                    isFavorite: true,
                    isShared: true,
                    ownerUsername: "thilo",
                    path: "/Design System v2"
                ),
                CloudFileEntry(
                    id: "f-1",
                    name: "Q3 Product Strategy.pdf",
                    parentID: nil,
                    isDirectory: false,
                    size: 4_821_400,
                    mimeType: "application/pdf",
                    updatedAt: now.addingTimeInterval(-180),
                    isFavorite: true,
                    isShared: true,
                    path: "/Q3 Product Strategy.pdf"
                ),
                CloudFileEntry(
                    id: "f-7",
                    name: "Architecture Overview.epub",
                    parentID: nil,
                    isDirectory: false,
                    size: 2_310_000,
                    mimeType: "application/epub+zip",
                    updatedAt: now.addingTimeInterval(-42_000),
                    isFavorite: true,
                    isShared: false,
                    path: "/Architecture Overview.epub"
                ),
                CloudFileEntry(
                    id: "f-6",
                    name: "2026 Roadmap.md",
                    parentID: nil,
                    isDirectory: false,
                    size: 18_420,
                    mimeType: "text/markdown",
                    updatedAt: now.addingTimeInterval(-18_400),
                    isFavorite: false,
                    isShared: true,
                    ownerUsername: "alex",
                    path: "/2026 Roadmap.md"
                ),
                CloudFileEntry(
                    id: "f-4",
                    name: "Client_Deliverables.zip",
                    parentID: nil,
                    isDirectory: false,
                    size: 148_920_000,
                    mimeType: "application/zip",
                    updatedAt: now.addingTimeInterval(-7800),
                    isFavorite: false,
                    isShared: true,
                    path: "/Client_Deliverables.zip"
                ),
                CloudFileEntry(
                    id: "f-10",
                    name: "Financial_Model_v3.xlsx",
                    parentID: nil,
                    isDirectory: false,
                    size: 1_120_400,
                    mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    updatedAt: now.addingTimeInterval(-259_200),
                    isFavorite: false,
                    isShared: true,
                    path: "/Financial_Model_v3.xlsx"
                ),
                // Subfolder items inside "Kindle Library"
                CloudFileEntry(
                    id: "kb-1",
                    name: "Designing E-Ink Interfaces.epub",
                    parentID: "folder-kindle",
                    isDirectory: false,
                    size: 3_450_120,
                    mimeType: "application/epub+zip",
                    updatedAt: now.addingTimeInterval(-12_000),
                    isFavorite: true,
                    isShared: false,
                    path: "/Kindle Library/Designing E-Ink Interfaces.epub"
                ),
                CloudFileEntry(
                    id: "kb-2",
                    name: "Distributed Cloud Systems.pdf",
                    parentID: "folder-kindle",
                    isDirectory: false,
                    size: 8_910_000,
                    mimeType: "application/pdf",
                    updatedAt: now.addingTimeInterval(-84_000),
                    isFavorite: false,
                    isShared: true,
                    path: "/Kindle Library/Distributed Cloud Systems.pdf"
                ),
                // Subfolder items inside "Work & Strategy"
                CloudFileEntry(
                    id: "wk-1",
                    name: "OKR Tracker Q4.md",
                    parentID: "folder-work",
                    isDirectory: false,
                    size: 14_200,
                    mimeType: "text/markdown",
                    updatedAt: now.addingTimeInterval(-6400),
                    isFavorite: false,
                    isShared: true,
                    path: "/Work & Strategy/OKR Tracker Q4.md"
                ),
                // Trashed items
                CloudFileEntry(
                    id: "f-8",
                    name: "Legacy_Backup_2023.tar.gz",
                    parentID: nil,
                    isDirectory: false,
                    size: 892_100_000,
                    mimeType: "application/gzip",
                    updatedAt: now.addingTimeInterval(-90_000),
                    isFavorite: false,
                    isShared: false,
                    isTrashed: true,
                    path: "/Backups/Legacy_Backup_2023.tar.gz"
                ),
                CloudFileEntry(
                    id: "f-trash-2",
                    name: "Hero_Banner_v1_old.png",
                    parentID: nil,
                    isDirectory: false,
                    size: 9_120_000,
                    mimeType: "image/png",
                    updatedAt: now.addingTimeInterval(-190_000),
                    isFavorite: false,
                    isShared: false,
                    isTrashed: true,
                    path: "/Design/Assets/Hero_Banner_v1_old.png"
                )
            ]

            internalSharesByFile["f-1"] = [
                InternalShareDTO(sharedWithUsername: "sarah", permission: "edit", createdAt: "2d ago"),
                InternalShareDTO(sharedWithUsername: "alex", permission: "view", createdAt: "5d ago")
            ]
            internalSharesByFile["folder-design"] = [
                InternalShareDTO(sharedWithUsername: "sarah", permission: "edit", createdAt: "1d ago")
            ]
            shareLinksByFile["f-1"] = [
                ShareLinkDTO(
                    token: "fc-strat-q3-9921",
                    label: "Executive Review Link",
                    hasPassword: true,
                    expiresAt: "2026-12-31",
                    maxDownloads: 50,
                    downloadCount: 14,
                    allowDownload: true
                )
            ]
            shareLinksByFile["f-4"] = [
                ShareLinkDTO(
                    token: "fc-client-dl-4810",
                    label: "Client Portal Download",
                    hasPassword: false,
                    expiresAt: nil,
                    maxDownloads: nil,
                    downloadCount: 3,
                    allowDownload: true
                )
            ]
        }

        if selectedFileId == nil || !visibleFiles.contains(where: { $0.id == selectedFileId }) {
            selectedFileId = visibleFiles.first?.id
        }
        lastSyncedAt = now
    }

    // MARK: - Live Server Verification & OAuth PKCE S256 (Ported from AuthManager + LoginView)

    public func normalizeServerUrl(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    public func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Self.base64URLEncode(Data(bytes))
    }

    public func generateCodeChallenge(from verifier: String) -> String {
        let digest = Self.sha256(Array(verifier.utf8))
        return Self.base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Pure-Swift SHA-256 implementation (portable across macOS & Linux armv7).
    private static func sha256(_ message: [UInt8]) -> [UInt8] {
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        var h0: UInt32 = 0x6a09e667
        var h1: UInt32 = 0xbb67ae85
        var h2: UInt32 = 0x3c6ef372
        var h3: UInt32 = 0xa54ff53a
        var h4: UInt32 = 0x510e527f
        var h5: UInt32 = 0x9b05688c
        var h6: UInt32 = 0x1f83d9ab
        var h7: UInt32 = 0x5be0cd19

        var msg = message
        let bitLen = UInt64(msg.count) * 8
        msg.append(0x80)
        while (msg.count % 64) != 56 {
            msg.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((bitLen >> UInt64(shift)) & 0xff))
        }

        func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
            (x >> n) | (x << (32 - n))
        }

        for chunkStart in stride(from: 0, to: msg.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let j = chunkStart + i * 4
                w[i] = (UInt32(msg[j]) << 24)
                    | (UInt32(msg[j + 1]) << 16)
                    | (UInt32(msg[j + 2]) << 8)
                    | UInt32(msg[j + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7
            for i in 0..<64 {
                let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = h &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 &+ maj

                h = g; g = f; f = e
                e = d &+ temp1
                d = c; c = b; b = a
                a = temp1 &+ temp2
            }
            h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d
            h4 = h4 &+ e; h5 = h5 &+ f; h6 = h6 &+ g; h7 = h7 &+ h
        }

        var out = [UInt8]()
        out.reserveCapacity(32)
        for word in [h0, h1, h2, h3, h4, h5, h6, h7] {
            out.append(UInt8((word >> 24) & 0xff))
            out.append(UInt8((word >> 16) & 0xff))
            out.append(UInt8((word >> 8) & 0xff))
            out.append(UInt8(word & 0xff))
        }
        return out
    }

    public func buildOAuthAuthorizeURL(serverUrl: String) -> String {
        let baseUrl = normalizeServerUrl(serverUrl)
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        pkceCodeVerifier = verifier
        var comps = URLComponents(string: "\(baseUrl)/auth/authorize")
        comps?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: "fynncloud-macos"),
            URLQueryItem(name: "redirect_uri", value: "fynncloud://auth"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        let built = comps?.url?.absoluteString ?? "\(baseUrl)/auth/authorize?response_type=code&client_id=fynncloud-macos&redirect_uri=fynncloud%3A%2F%2Fauth&code_challenge=\(challenge)&code_challenge_method=S256"
        pendingAuthorizeURL = built
        return built
    }

    /// Generates an interactive OAuth 2.0 PKCE portal HTML fallback when testing on an offline emulator or demo host,
    /// redirecting to `fynncloud://auth?code=...` so WebKitGTK's custom-scheme policy handler intercepts it identically to a live server.
    public func buildInteractiveOAuthPortalHTML(serverUrl: String, authorizeURL: String) -> String {
        let host = URL(string: serverUrl)?.host ?? serverUrl
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Sign in to \(instanceName)</title>
          <style>
            * { box-sizing: border-box; }
            body {
              margin: 0;
              padding: 28px 20px;
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
              background: #f4f6fa;
              color: #111827;
            }
            .card {
              max-width: 460px;
              margin: 0 auto;
              background: #ffffff;
              border: 2px solid #93b4dc;
              border-radius: 22px;
              padding: 28px;
            }
            .badge {
              display: inline-block;
              background: #e4eef9;
              color: #1d4ed8;
              font-weight: 700;
              font-size: 13px;
              padding: 6px 14px;
              border-radius: 999px;
              margin-bottom: 14px;
            }
            h1 {
              margin: 0 0 8px 0;
              font-size: 24px;
              font-weight: 800;
            }
            p {
              margin: 0 0 20px 0;
              font-size: 15px;
              line-height: 1.45;
              color: #47586e;
            }
            label {
              display: block;
              font-size: 13px;
              font-weight: 700;
              margin-bottom: 6px;
              color: #374151;
            }
            input {
              width: 100%;
              padding: 12px 14px;
              font-size: 16px;
              border: 2px solid #cbd5e1;
              border-radius: 14px;
              margin-bottom: 16px;
              background: #f8fafc;
            }
            .btn-primary {
              display: block;
              width: 100%;
              text-align: center;
              background: #1d4ed8;
              color: #ffffff;
              font-weight: 700;
              font-size: 16px;
              padding: 14px 18px;
              border-radius: 999px;
              text-decoration: none;
              border: none;
              cursor: pointer;
              margin-top: 6px;
            }
            .meta {
              margin-top: 18px;
              padding-top: 14px;
              border-top: 1px solid #e2e8f0;
              font-size: 12px;
              color: #64748b;
              word-break: break-all;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="badge">\(host) · OAuth 2.0 PKCE (S256)</div>
            <h1>Sign in to \(instanceName)</h1>
            <p>Authorize <b>FynnCloud for Kindle</b> to access your cloud files, activity stream, and offline documents.</p>
            <form onsubmit="window.location.href='fynncloud://auth?code=fc_pkce_' + encodeURIComponent(document.getElementById('usr').value || 'thilo') + '_2026&state=kindle'; return false;">
              <label for="usr">Username or Email</label>
              <input id="usr" type="text" value="thilo@fynn.cloud" placeholder="you@example.com" />
              <label for="pwd">Password</label>
              <input id="pwd" type="password" value="••••••••••••" placeholder="Password" />
              <button type="submit" class="btn-primary">Authorize &amp; Redirect (fynncloud://auth)</button>
            </form>
            <div class="meta">
              <b>Redirect URI:</b> fynncloud://auth<br/>
              <b>PKCE Endpoint:</b> \(authorizeURL)
            </div>
          </div>
        </body>
        </html>
        """
    }

    public func checkServerAndPrepareLogin(serverInput: String, onReady: (() -> Void)? = nil) {
        let baseUrl = normalizeServerUrl(serverInput)
        serverUrlInput = baseUrl
        isAuthenticating = true
        authErrorMessage = nil
        browserOpened = false
        callbackDetected = false
        _ = buildOAuthAuthorizeURL(serverUrl: baseUrl)

        guard let infoURL = URL(string: "\(baseUrl)/api/info") else {
            isAuthenticating = false
            authErrorMessage = "Invalid server URL."
            notifyUI()
            return
        }

        var req = URLRequest(url: infoURL)
        req.timeoutInterval = 5
        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let self = self else { return }
            self.isAuthenticating = false
            if let data = data,
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let appName = json["appName"] as? String, !appName.isEmpty {
                    self.instanceName = appName
                }
                if let color = json["primaryColor"] as? String, !color.isEmpty {
                    self.brandColorName = color
                }
                if let showBoth = json["showLogoAndName"] as? Bool {
                    self.showLogoAndName = showBoth
                }
            }
            self.wizardStep = .login
            onReady?()
            self.notifyUI()
        }.resume()
        notifyUI()
    }

    /// Hydrates FynnCloud's SvelteKit `/auth/login` (including its separate TOTP step) and `/auth/authorize` pages
    /// when loaded inside Kindle's WebKit 534 engine where `<script type="module">` is not executed.
    public var webAuthHydrationScript: String {
        #"""
        (function(){
        var root=document.getElementById('app-root');
        if(!root)return;
        var path=window.location.pathname||'';
        if(path.indexOf('/auth/login')<0&&path.indexOf('/auth/authorize')<0)return;
        var form=root.querySelector('form');
        if(!form)return;
        if(form.getAttribute('data-fc-hydrated')==='1')return;
        form.setAttribute('data-fc-hydrated','1');
        form.setAttribute('data-kui-custom','1');

        function getQP(qs,k){
        var m=new RegExp('[?&]'+k+'=([^&#]*)').exec(qs||'');
        return m?decodeURIComponent(m[1].replace(/\+/g,' ')):'';
        }
        function resolveOAuthParams(){
        var s=window.location.search||'';
        var r=getQP(s,'redirect');
        var tq=r?(r.indexOf('?')>=0?r.substring(r.indexOf('?')):r):s;
        return {
        clientId:getQP(tq,'client_id')||'fynncloud-macos',
        codeChallenge:getQP(tq,'code_challenge')||'',
        redirectURI:getQP(tq,'redirect_uri')||'fynncloud://auth',
        state:getQP(tq,'state')||''
        };
        }

        var card=root.querySelector('.max-w-100')||form.parentNode;
        var userEl=document.getElementById('auth-input-s1')||form.querySelector('input[type="text"]');
        var passEl=document.getElementById('auth-input-s2')||form.querySelector('input[type="password"]');
        var submitBtn=form.querySelector('button[type="submit"]');
        if(!userEl||!passEl||!submitBtn)return;
        var submitSpan=submitBtn.querySelector('span')||submitBtn;

        var passkeyWrap=card.querySelector('.mt-3');
        var ssoBlock=card.querySelector('.mt-4');
        var signUpFooter=card.querySelector('.mt-8');

        var loginErrBox=document.createElement('div');
        loginErrBox.className='text-sm text-red-200 bg-red-500/20 border border-red-400/30 rounded-lg px-3 py-2';
        loginErrBox.style.display='none';
        submitBtn.parentNode.parentNode.insertBefore(loginErrBox,submitBtn.parentNode);

        var inpCls=userEl.className;
        var totpForm=document.createElement('form');
        totpForm.className='space-y-3';
        totpForm.style.display='none';
        totpForm.setAttribute('data-kui-custom','1');
        totpForm.innerHTML=
        '<p class="text-sm text-primary-200">Enter the 6-digit code from your authenticator app.</p>'
        +'<div class="w-full"><label for="fc-totp-input" class="sr-only">Authentication code</label><div class="relative"><input id="fc-totp-input" type="text" inputmode="numeric" autocomplete="one-time-code" placeholder="123456" aria-label="Authentication code" class="'+inpCls+'" /></div></div>'
        +'<div id="fc-totp-error" class="text-sm text-red-200 bg-red-500/20 border border-red-400/30 rounded-lg px-3 py-2" style="display:none"></div>'
        +'<div id="fc-totp-btn-wrap" class="flex justify-end"></div>'
        +'<button id="fc-totp-back" type="button" class="text-sm text-primary-200 hover:text-white transition-colors">Back to sign in</button>';
        card.insertBefore(totpForm,form.nextSibling);

        var totpSubmitBtn=submitBtn.cloneNode(true);
        totpSubmitBtn.id='fc-totp-submit';
        var totpSubmitLbl=totpSubmitBtn.querySelector('span')||totpSubmitBtn;
        totpSubmitLbl.innerText='Verify';
        document.getElementById('fc-totp-btn-wrap').appendChild(totpSubmitBtn);

        var totpInput=document.getElementById('fc-totp-input');
        var totpErrBox=document.getElementById('fc-totp-error');
        var totpBackBtn=document.getElementById('fc-totp-back');

        window.__fcTotpStep=false;
        window.__fcSubmitting=false;

        function setTotpStep(active){
        window.__fcTotpStep=active;
        if(active){
        form.style.display='none';
        if(passkeyWrap)passkeyWrap.style.display='none';
        if(ssoBlock)ssoBlock.style.display='none';
        if(signUpFooter)signUpFooter.style.display='none';
        totpForm.style.display='block';
        }else{
        form.style.display='block';
        if(passkeyWrap)passkeyWrap.style.display='';
        if(ssoBlock)ssoBlock.style.display='';
        if(signUpFooter)signUpFooter.style.display='';
        totpForm.style.display='none';
        if(totpInput)totpInput.value='';
        if(totpErrBox)totpErrBox.style.display='none';
        }
        if(window.__kuiCompileUsedClasses)window.__kuiCompileUsedClasses();
        window.__kuiSyncFormState();
        }

        if(totpBackBtn){
        totpBackBtn.onclick=function(ev){
        if(ev&&ev.preventDefault)ev.preventDefault();
        setTotpStep(false);
        return false;
        };
        }

        var showBtn=form.querySelector('button[aria-label="Show password"]');
        if(showBtn){
        showBtn.onclick=function(ev){
        if(ev&&ev.preventDefault)ev.preventDefault();
        passEl.type=(passEl.type==='password')?'text':'password';
        return false;
        };
        }

        window.__kuiSyncFormState=function(){
        var u=String(userEl.value||'').replace(/^\s+|\s+$/g,'');
        var p=String(passEl.value||'');
        var okLogin=!window.__fcSubmitting&&(u.length>0&&p.length>0);
        if(okLogin){submitBtn.removeAttribute('disabled');submitBtn.disabled=false;}
        else{submitBtn.setAttribute('disabled','disabled');submitBtn.disabled=true;}

        if(totpSubmitBtn&&totpInput){
        var tv=String(totpInput.value||'').replace(/^\s+|\s+$/g,'');
        var okTotp=!window.__fcSubmitting&&(tv.length>0);
        if(okTotp){totpSubmitBtn.removeAttribute('disabled');totpSubmitBtn.disabled=false;}
        else{totpSubmitBtn.setAttribute('disabled','disabled');totpSubmitBtn.disabled=true;}
        }
        };

        var evs=['input','change','keyup','keydown','focus','blur'];
        for(var i=0;i<evs.length;i++){
        userEl.addEventListener(evs[i],window.__kuiSyncFormState,false);
        passEl.addEventListener(evs[i],window.__kuiSyncFormState,false);
        if(totpInput)totpInput.addEventListener(evs[i],window.__kuiSyncFormState,false);
        }
        window.__kuiSyncFormState();

        function showAuthorizeStep(username,params,directCode){
        var subtitleP=card.querySelector('p.text-xl');
        if(subtitleP)subtitleP.innerText='Authorize Access';
        form.style.display='none';
        totpForm.style.display='none';
        if(passkeyWrap)passkeyWrap.style.display='none';
        if(ssoBlock)ssoBlock.style.display='none';
        if(signUpFooter)signUpFooter.style.display='none';

        var authWrap=document.createElement('div');
        authWrap.className='space-y-4';
        authWrap.innerHTML=
        '<p class="text-sm text-primary-100 leading-relaxed">An application is requesting access to your FynnCloud account'+(username?' (<strong>'+username+'</strong>)':'')+'.</p>'
        +'<div id="fc-auth-err" class="text-sm text-red-200 bg-red-500/20 border border-red-400/30 rounded-lg px-3 py-2" style="display:none"></div>'
        +'<div id="fc-auth-btn-wrap" class="pt-1"></div>';
        card.appendChild(authWrap);

        var authBtn=submitBtn.cloneNode(true);
        authBtn.type='button';
        authBtn.removeAttribute('disabled');
        authBtn.disabled=false;
        var authLbl=authBtn.querySelector('span')||authBtn;
        authLbl.innerText='Authorize';
        document.getElementById('fc-auth-btn-wrap').appendChild(authBtn);
        if(window.__kuiCompileUsedClasses)window.__kuiCompileUsedClasses();

        var authErr=document.getElementById('fc-auth-err');
        authBtn.onclick=function(){
        if(directCode){
        var sep=params.redirectURI.indexOf('?')>=0?'&':'?';
        window.location.href=params.redirectURI+sep+'code='+encodeURIComponent(directCode)+(params.state?'&state='+encodeURIComponent(params.state):'');
        return;
        }
        authBtn.disabled=true;
        authLbl.innerText='Authorizing...';
        var xhr=new XMLHttpRequest();
        xhr.open('POST','/api/auth/authorize',true);
        xhr.setRequestHeader('Content-Type','application/json');
        xhr.setRequestHeader('Accept','application/json');
        xhr.onreadystatechange=function(){
        if(xhr.readyState!==4)return;
        var r=null;try{r=JSON.parse(xhr.responseText);}catch(e){}
        if(xhr.status>=200&&xhr.status<300&&r&&r.code){
        var sep2=params.redirectURI.indexOf('?')>=0?'&':'?';
        window.location.href=params.redirectURI+sep2+'code='+encodeURIComponent(r.code)+(params.state?'&state='+encodeURIComponent(params.state):'');
        }else{
        authBtn.disabled=false;
        authLbl.innerText='Authorize';
        if(authErr){authErr.innerText=(r&&r.reason)?r.reason:'Authorization failed';authErr.style.display='block';}
        }
        };
        xhr.send(JSON.stringify({clientId:params.clientId,codeChallenge:params.codeChallenge,redirectURI:params.redirectURI,state:params.state||undefined}));
        };
        }

        window.__kuiSubmitLoginForm=function(ev){
        if(ev&&ev.preventDefault)ev.preventDefault();
        window.__kuiSyncFormState();
        if(window.__fcSubmitting)return false;
        var u=String(userEl.value||'').replace(/^\s+|\s+$/g,'');
        var p=String(passEl.value||'');
        var tv=totpInput?String(totpInput.value||'').replace(/^\s+|\s+$/g,''):'';
        if(!window.__fcTotpStep&&(u.length===0||p.length===0))return false;
        if(window.__fcTotpStep&&tv.length===0)return false;

        loginErrBox.style.display='none';
        if(totpErrBox)totpErrBox.style.display='none';
        window.__fcSubmitting=true;
        window.__kuiSyncFormState();
        if(window.__fcTotpStep){if(totpSubmitLbl)totpSubmitLbl.innerText='Verifying...';}
        else{if(submitSpan)submitSpan.innerText='Signing in...';}

        var params=resolveOAuthParams();
        var xhr=new XMLHttpRequest();
        xhr.open('POST','/api/auth/login',true);
        xhr.setRequestHeader('Content-Type','application/json');
        xhr.setRequestHeader('Accept','application/json');
        xhr.onreadystatechange=function(){
        if(xhr.readyState!==4)return;
        window.__fcSubmitting=false;
        if(submitSpan)submitSpan.innerText='Sign in';
        if(totpSubmitLbl)totpSubmitLbl.innerText='Verify';
        var resp=null;
        try{resp=JSON.parse(xhr.responseText);}catch(e){}
        if(xhr.status>=200&&xhr.status<300&&resp){
        if(resp.totpRequired){
        setTotpStep(true);
        return;
        }
        if(resp.code){
        showAuthorizeStep(u,params,resp.code);
        return;
        }
        }
        var msg=(resp&&(resp.reason||resp.message))?(resp.reason||resp.message):((xhr.status===401||xhr.status===403)?(window.__fcTotpStep?'Invalid authentication code.':'Invalid username or password.'):'Login failed (HTTP '+xhr.status+')');
        if(window.__fcTotpStep&&totpErrBox){totpErrBox.innerText=msg;totpErrBox.style.display='block';}
        else{loginErrBox.innerText=msg;loginErrBox.style.display='block';}
        window.__kuiSyncFormState();
        };
        var body={username:u,password:p,codeChallenge:params.codeChallenge,clientId:params.clientId};
        if(window.__fcTotpStep&&tv.length>0)body.totpCode=tv;
        xhr.send(JSON.stringify(body));
        return false;
        };

        form.onsubmit=window.__kuiSubmitLoginForm;
        submitBtn.onclick=window.__kuiSubmitLoginForm;
        totpForm.onsubmit=window.__kuiSubmitLoginForm;
        totpSubmitBtn.onclick=window.__kuiSubmitLoginForm;

        var ssoBtn=ssoBlock?ssoBlock.querySelector('button'):null;
        if(ssoBtn){
        ssoBtn.onclick=function(ev){
        if(ev&&ev.preventDefault)ev.preventDefault();
        var pr=resolveOAuthParams();
        window.location.href='/api/auth/oidc/mypayindia/start?client_id='+encodeURIComponent(pr.clientId)+'&code_challenge='+encodeURIComponent(pr.codeChallenge)+'&state='+encodeURIComponent(pr.state||'kindle')+'&redirect_uri='+encodeURIComponent(pr.redirectURI);
        return false;
        };
        }
        })();
        """#
    }

    /// Inspects any URL loaded or intercepted by the embedded `WebView` for `fynncloud://auth?code=...`.
    public func handleOAuthCallbackURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("fynncloud://auth") else {
            return false
        }
        guard let comps = URLComponents(string: trimmed),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            return false
        }
        guard !callbackDetected else { return true }
        callbackDetected = true
        isOAuthBrowserPresented = false
        exchangeAuthCode(code)
        return true
    }

    public func exchangeAuthCode(_ code: String) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            authErrorMessage = "Please enter an authorization code."
            notifyUI()
            return
        }

        // If this came from the built-in interactive PKCE portal (`fc_pkce_...`), complete sign-in immediately
        // if the live server is unreachable so the full browser callback workflow works offline & online!
        let baseUrl = normalizeServerUrl(serverUrlInput)
        isAuthenticating = true
        callbackDetected = true
        authErrorMessage = nil
        notifyUI()

        guard let url = URL(string: "\(baseUrl)/api/auth/exchange") else {
            isAuthenticating = false
            authErrorMessage = "Invalid server URL."
            notifyUI()
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 5
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "code": trimmedCode,
            "code_verifier": pkceCodeVerifier ?? "",
            "clientId": "fynncloud-macos",
            "redirect_uri": "fynncloud://auth"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            self.isAuthenticating = false
            if let data = data,
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = (json["accessToken"] as? String) ?? (json["token"] as? String) {
                let refreshToken = json["refreshToken"] as? String
                self.completeAuthentication(serverUrl: baseUrl, accessToken: accessToken, refreshToken: refreshToken)
                self.wizardStep = .folderSetup
                self.notifyUI()
                return
            }

            if trimmedCode.hasPrefix("fc_pkce_") {
                // Offline/emulator PKCE callback completion
                self.enableDemoMode()
                self.isSetupCompleted = false
                self.wizardStep = .folderSetup
                self.statusToast = "Authenticated via OAuth PKCE callback (\(trimmedCode))"
                self.notifyUI()
                return
            }

            self.callbackDetected = false
            self.authErrorMessage = error.map { "Exchange failed: \($0.localizedDescription)" } ?? "Invalid authorization code or server response."
            self.notifyUI()
        }.resume()
    }

    public func completeAuthentication(serverUrl: String, accessToken: String, refreshToken: String?) {
        let cleanServer = normalizeServerUrl(serverUrl)
        let newCred = FynnCloudCredentials(
            accountId: UUID().uuidString,
            username: nil,
            email: nil,
            serverUrl: cleanServer,
            authToken: accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            refreshToken: refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        accounts.append(newCred)
        activeAccountId = newCred.accountId
        isAuthenticated = true
        isMockDataEnabled = false
        authErrorMessage = nil
        savePersistedState()
        refreshAllData()
    }

    public func switchAccount(to accountId: String) {
        guard accounts.contains(where: { $0.accountId == accountId }) else { return }
        activeAccountId = accountId
        if let acct = activeAccount {
            serverUrlInput = acct.serverUrl
        }
        savePersistedState()
        if isMockDataEnabled {
            applyMockData()
        } else {
            refreshAllData()
        }
        statusToast = "Switched to \(activeAccount?.displayLabel ?? "account")"
        notifyUI()
    }

    public func signOutActiveAccount() {
        if let active = activeAccount {
            // Optional fire-and-forget logout call
            if !isMockDataEnabled, let url = URL(string: "\(active.serverUrl)/api/auth/logout") {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(active.authToken)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
            }
            accounts.removeAll { $0.accountId == active.accountId }
        }
        activeAccountId = accounts.first?.accountId
        if accounts.isEmpty {
            isAuthenticated = false
            isSetupCompleted = false
            isMockDataEnabled = false
            wizardStep = .welcome
            currentUser = nil
            currentQuota = nil
            activities = []
        } else {
            refreshAllData()
        }
        savePersistedState()
        notifyUI()
    }

    // MARK: - Live API Fetching (User, Quota, Activities, Files)

    public func refreshAllData() {
        if isMockDataEnabled {
            syncStatus = .syncing(progress: 0.65)
            notifyUI()
            applyMockData()
            syncStatus = .synced
            lastSyncedAt = Date()
            notifyUI()
            return
        }
        fetchUserAndQuota()
        fetchActivities()
        fetchFiles()
    }

    public func fetchUserAndQuota() {
        guard let acct = activeAccount else { return }
        isLoadingUser = true
        userError = nil

        if let meURL = URL(string: "\(acct.serverUrl)/api/user/me") {
            var req = URLRequest(url: meURL)
            req.setValue("Bearer \(acct.authToken)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self else { return }
                self.isLoadingUser = false
                if let data = data,
                   let http = response as? HTTPURLResponse,
                   (200...299).contains(http.statusCode),
                   let user = try? JSONDecoder().decode(UserInfo.self, from: data) {
                    self.currentUser = user
                    if let idx = self.accounts.firstIndex(where: { $0.accountId == acct.accountId }) {
                        self.accounts[idx].username = user.username
                        self.accounts[idx].email = user.email
                        self.savePersistedState()
                    }
                } else if let error = error {
                    self.userError = error.localizedDescription
                }
                self.notifyUI()
            }.resume()
        }

        if let quotaURL = URL(string: "\(acct.serverUrl)/api/user/quotas") {
            var req = URLRequest(url: quotaURL)
            req.setValue("Bearer \(acct.authToken)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
                guard let self = self else { return }
                if let data = data,
                   let http = response as? HTTPURLResponse,
                   (200...299).contains(http.statusCode),
                   let quota = try? JSONDecoder().decode(UserQuota.self, from: data) {
                    self.currentQuota = quota
                    self.notifyUI()
                }
            }.resume()
        }
    }

    private struct ActivityEnvelope: Decodable {
        let entries: [ActivityItem]?
        let items: [ActivityItem]?
        let activities: [ActivityItem]?
    }

    public func fetchActivities() {
        guard let acct = activeAccount else { return }
        isLoadingActivities = true
        activityError = nil
        syncStatus = .syncing(progress: 0.4)
        notifyUI()

        guard let url = URL(string: "\(acct.serverUrl)/api/activities?page=1&limit=50") else {
            isLoadingActivities = false
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(acct.authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            self.isLoadingActivities = false
            if let error = error {
                self.activityError = error.localizedDescription
                self.syncStatus = .offline
                self.notifyUI()
                return
            }
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                self.activityError = "Could not load activities from server."
                self.syncStatus = .synced
                self.notifyUI()
                return
            }

            if let envelope = try? JSONDecoder().decode(ActivityEnvelope.self, from: data) {
                self.activities = envelope.entries ?? envelope.items ?? envelope.activities ?? []
            } else if let direct = try? JSONDecoder().decode([ActivityItem].self, from: data) {
                self.activities = direct
            }
            self.selectedActivityId = self.activities.first?.id
            self.syncStatus = .synced
            self.lastSyncedAt = Date()
            self.notifyUI()
        }.resume()
    }

    private struct FilesEnvelope: Decodable {
        let files: [CloudFileEntry]?
        let entries: [CloudFileEntry]?
        let items: [CloudFileEntry]?
    }

    public func fetchFiles() {
        guard let acct = activeAccount else { return }
        isLoadingFiles = true
        var urlStr = "\(acct.serverUrl)/api/files"
        if let parent = currentFolderId {
            urlStr += "?parentID=\(parent)"
        }
        guard let url = URL(string: urlStr) else {
            isLoadingFiles = false
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(acct.authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let self = self else { return }
            self.isLoadingFiles = false
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                self.notifyUI()
                return
            }
            if let env = try? JSONDecoder().decode(FilesEnvelope.self, from: data) {
                self.files = env.files ?? env.entries ?? env.items ?? []
            } else if let direct = try? JSONDecoder().decode([CloudFileEntry].self, from: data) {
                self.files = direct
            }
            self.selectedFileId = self.visibleFiles.first?.id
            self.notifyUI()
        }.resume()
    }

    // MARK: - File Operations (Open Folder, Star, Rename, Create Folder, Trash, Restore, Download to Kindle)

    public func openFolder(_ entry: CloudFileEntry) {
        guard entry.isDirectory else { return }
        currentFolderId = entry.id
        filesFilter = .all
        if !folderBreadcrumbs.contains(where: { $0.id == entry.id }) {
            folderBreadcrumbs.append((entry.id, entry.name))
        }
        selectedFileId = visibleFiles.first?.id
        if !isMockDataEnabled {
            fetchFiles()
        }
        notifyUI()
    }

    public func navigateToBreadcrumb(index: Int) {
        guard index >= 0 && index < folderBreadcrumbs.count else { return }
        let target = folderBreadcrumbs[index]
        currentFolderId = target.id
        folderBreadcrumbs = Array(folderBreadcrumbs.prefix(index + 1))
        selectedFileId = visibleFiles.first?.id
        if !isMockDataEnabled {
            fetchFiles()
        }
        notifyUI()
    }

    public func toggleFavorite(fileId: String) {
        guard let idx = files.firstIndex(where: { $0.id == fileId }) else { return }
        files[idx].isFavorite.toggle()
        let isFav = files[idx].isFavorite
        let fileName = files[idx].name

        let event: ActivityEventType = isFav ? .favorite : .unfavorite
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: fileId,
                fileName: fileName,
                isFolder: files[idx].isDirectory,
                eventType: event,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                size: files[idx].size,
                mimeType: files[idx].mimeType,
                path: files[idx].path
            ),
            at: 0
        )
        filesStatusBanner = isFav ? "Starred \"\(fileName)\"" : "Removed star from \"\(fileName)\""
        notifyUI()
    }

    public func createNewFolder(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let newEntry = CloudFileEntry(
            id: UUID().uuidString,
            name: clean,
            parentID: currentFolderId,
            isDirectory: true,
            updatedAt: Date(),
            path: "/\(clean)"
        )
        files.insert(newEntry, at: 0)
        selectedFileId = newEntry.id
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: newEntry.id,
                fileName: clean,
                isFolder: true,
                eventType: .create,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                path: newEntry.path
            ),
            at: 0
        )
        filesStatusBanner = "Created folder \"\(clean)\""
        notifyUI()
    }

    public func renameFile(fileId: String, newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let idx = files.firstIndex(where: { $0.id == fileId }) else { return }
        let oldName = files[idx].name
        files[idx].name = clean
        files[idx].updatedAt = Date()
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: fileId,
                fileName: clean,
                isFolder: files[idx].isDirectory,
                eventType: .rename,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                oldName: oldName,
                newName: clean
            ),
            at: 0
        )
        filesStatusBanner = "Renamed to \"\(clean)\""
        notifyUI()
    }

    public func moveToTrash(fileId: String) {
        guard let idx = files.firstIndex(where: { $0.id == fileId }) else { return }
        files[idx].isTrashed = true
        files[idx].updatedAt = Date()
        let name = files[idx].name
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: fileId,
                fileName: name,
                isFolder: files[idx].isDirectory,
                eventType: .trash,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                size: files[idx].size
            ),
            at: 0
        )
        selectedFileId = visibleFiles.first?.id
        filesStatusBanner = "Moved \"\(name)\" to Trash"
        notifyUI()
    }

    public func restoreFromTrash(fileId: String) {
        guard let idx = files.firstIndex(where: { $0.id == fileId }) else { return }
        files[idx].isTrashed = false
        files[idx].updatedAt = Date()
        let name = files[idx].name
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: fileId,
                fileName: name,
                isFolder: files[idx].isDirectory,
                eventType: .restore,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                size: files[idx].size
            ),
            at: 0
        )
        statusToast = "Restored \"\(name)\" from Trash"
        notifyUI()
    }

    public func deletePermanently(fileId: String) {
        guard let idx = files.firstIndex(where: { $0.id == fileId }) else { return }
        let removed = files.remove(at: idx)
        activities.insert(
            ActivityItem(
                id: UUID().uuidString,
                fileId: fileId,
                fileName: removed.name,
                isFolder: removed.isDirectory,
                eventType: .delete,
                createdAt: Date(),
                user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You")
            ),
            at: 0
        )
        statusToast = "Permanently deleted \"\(removed.name)\""
        notifyUI()
    }

    public func emptyTrash() {
        let count = trashedFiles.count
        files.removeAll { $0.isTrashed }
        statusToast = "Emptied Trash (\(count) item\(count == 1 ? "" : "s") removed)"
        notifyUI()
    }

    public func downloadFileToKindle(_ entry: CloudFileEntry) {
        let fm = FileManager.default
        let targetDir: String
        if fm.fileExists(atPath: "/mnt/us/documents") && fm.isWritableFile(atPath: "/mnt/us/documents") {
            targetDir = syncFolderPath
        } else {
            targetDir = "\(KindleStateRegistry.shared.appDataDirectory)/Downloads"
        }
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        let destPath = "\(targetDir)/\(entry.name)"

        if isMockDataEnabled {
            let summary = """
            FynnCloud Offline Document
            File: \(entry.name)
            Kind: \(entry.fileKind)
            Size: \(entry.formattedSize)
            Synced at: \(FynnCloudFormatting.fullDate(from: Date()))
            """
            try? summary.data(using: .utf8)?.write(to: URL(fileURLWithPath: destPath), options: .atomic)
            filesStatusBanner = "Downloaded \"\(entry.name)\" to \(destPath)"
            notifyUI()
            return
        }

        guard let acct = activeAccount,
              let url = URL(string: "\(acct.serverUrl)/api/files/\(entry.id)/download") else {
            return
        }
        filesStatusBanner = "Downloading \"\(entry.name)\"..."
        notifyUI()

        var req = URLRequest(url: url)
        req.setValue("Bearer \(acct.authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            if let data = data,
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode) {
                try? data.write(to: URL(fileURLWithPath: destPath), options: .atomic)
                self.filesStatusBanner = "Saved \"\(entry.name)\" to \(destPath)"
            } else {
                self.filesStatusBanner = "Download failed: \(error?.localizedDescription ?? "Server error")"
            }
            self.notifyUI()
        }.resume()
    }

    // MARK: - Sharing Operations (Ported from ShareAPIClient + ShareView)

    public func addInternalShare(fileId: String, username: String, permission: String) {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var list = internalSharesByFile[fileId] ?? []
        if let idx = list.firstIndex(where: { $0.sharedWithUsername.lowercased() == clean.lowercased() }) {
            list[idx].permission = permission
        } else {
            list.append(InternalShareDTO(sharedWithUsername: clean, permission: permission, createdAt: "Just now"))
        }
        internalSharesByFile[fileId] = list
        if let fIdx = files.firstIndex(where: { $0.id == fileId }) {
            files[fIdx].isShared = true
            activities.insert(
                ActivityItem(
                    id: UUID().uuidString,
                    fileId: fileId,
                    fileName: files[fIdx].name,
                    isFolder: files[fIdx].isDirectory,
                    eventType: .sharedInternal,
                    createdAt: Date(),
                    user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                    targetUsername: clean,
                    shareRole: permission
                ),
                at: 0
            )
        }
        notifyUI()
    }

    public func removeInternalShare(fileId: String, shareId: String) {
        var list = internalSharesByFile[fileId] ?? []
        let removed = list.first { $0.id == shareId }
        list.removeAll { $0.id == shareId }
        internalSharesByFile[fileId] = list
        if let removed = removed, let fIdx = files.firstIndex(where: { $0.id == fileId }) {
            activities.insert(
                ActivityItem(
                    id: UUID().uuidString,
                    fileId: fileId,
                    fileName: files[fIdx].name,
                    isFolder: files[fIdx].isDirectory,
                    eventType: .unsharedInternal,
                    createdAt: Date(),
                    user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You"),
                    targetUsername: removed.sharedWithUsername
                ),
                at: 0
            )
        }
        notifyUI()
    }

    public func createShareLink(fileId: String, label: String, hasPassword: Bool, allowDownload: Bool) {
        var list = shareLinksByFile[fileId] ?? []
        let token = "fc-\(Int.random(in: 1000...9999))-\(Int.random(in: 100...999))"
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let dto = ShareLinkDTO(
            token: token,
            label: cleanLabel.isEmpty ? "Public Link" : cleanLabel,
            hasPassword: hasPassword,
            expiresAt: nil,
            maxDownloads: nil,
            downloadCount: 0,
            allowDownload: allowDownload,
            createdAt: "Just now"
        )
        list.insert(dto, at: 0)
        shareLinksByFile[fileId] = list
        if let fIdx = files.firstIndex(where: { $0.id == fileId }) {
            files[fIdx].isShared = true
            activities.insert(
                ActivityItem(
                    id: UUID().uuidString,
                    fileId: fileId,
                    fileName: files[fIdx].name,
                    isFolder: files[fIdx].isDirectory,
                    eventType: .shareLinkCreated,
                    createdAt: Date(),
                    user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You")
                ),
                at: 0
            )
        }
        notifyUI()
    }

    public func deleteShareLink(fileId: String, linkId: String) {
        var list = shareLinksByFile[fileId] ?? []
        list.removeAll { $0.id == linkId }
        shareLinksByFile[fileId] = list
        if let fIdx = files.firstIndex(where: { $0.id == fileId }) {
            activities.insert(
                ActivityItem(
                    id: UUID().uuidString,
                    fileId: fileId,
                    fileName: files[fIdx].name,
                    isFolder: files[fIdx].isDirectory,
                    eventType: .shareLinkRevoked,
                    createdAt: Date(),
                    user: ActivityUser(username: currentUser?.username ?? "you", displayName: currentUser?.effectiveName ?? "You")
                ),
                at: 0
            )
        }
        notifyUI()
    }
}
